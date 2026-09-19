#!/usr/bin/env python3
"""Minimal Android binary XML (AXML) decoder.

Decodes the AndroidManifest.xml stored inside an APK back to readable XML so
the merged release manifest can be inspected without the Android SDK.
"""
import struct
import sys
import zipfile

RES_STRING_POOL = 0x0001
RES_XML_START_NS = 0x0100
RES_XML_END_NS = 0x0101
RES_XML_START_ELEM = 0x0102
RES_XML_END_ELEM = 0x0103
RES_XML_CDATA = 0x0104
RES_XML_RESOURCE_MAP = 0x0180

TYPE_NULL = 0x00
TYPE_REFERENCE = 0x01
TYPE_STRING = 0x03
TYPE_FLOAT = 0x04
TYPE_INT_DEC = 0x10
TYPE_INT_HEX = 0x11
TYPE_INT_BOOLEAN = 0x12


def parse_string_pool(data, off):
    ctype, header_size, size = struct.unpack_from('<HHI', data, off)
    assert ctype == RES_STRING_POOL, hex(ctype)
    string_count, style_count, flags, strings_start, styles_start = \
        struct.unpack_from('<IIIII', data, off + 8)
    is_utf8 = bool(flags & (1 << 8))
    offsets = struct.unpack_from('<%dI' % string_count, data, off + header_size)
    base = off + strings_start
    out = []
    for o in offsets:
        p = base + o
        if is_utf8:
            n, p = decode_len8(data, p)
            n, p = decode_len8(data, p)
            out.append(data[p:p + n].decode('utf-8', 'replace'))
        else:
            n, p = decode_len16(data, p)
            out.append(data[p:p + n * 2].decode('utf-16-le', 'replace'))
    return out, off + size


def decode_len8(data, p):
    n = data[p]
    p += 1
    if n & 0x80:
        n = ((n & 0x7F) << 8) | data[p]
        p += 1
    return n, p


def decode_len16(data, p):
    n = struct.unpack_from('<H', data, p)[0]
    p += 2
    if n & 0x8000:
        n = ((n & 0x7FFF) << 16) | struct.unpack_from('<H', data, p)[0]
        p += 2
    return n, p


def s(strings, idx):
    if idx == 0xFFFFFFFF or idx >= len(strings):
        return None
    return strings[idx]


def fmt_value(strings, raw, dtype, ddata):
    v = s(strings, raw)
    if v is not None:
        return v
    if dtype == TYPE_STRING:
        return s(strings, ddata) or ''
    if dtype == TYPE_INT_BOOLEAN:
        return 'true' if ddata else 'false'
    if dtype == TYPE_REFERENCE:
        return '@0x%08x' % ddata
    if dtype == TYPE_INT_HEX:
        return '0x%x' % ddata
    if dtype == TYPE_NULL:
        return ''
    return str(struct.unpack('<i', struct.pack('<I', ddata))[0])


def decode(data):
    ctype, header_size, size = struct.unpack_from('<HHI', data, 0)
    assert ctype == 0x0003, 'not an AXML file (type=%s)' % hex(ctype)
    off = header_size
    strings, off = parse_string_pool(data, off)

    lines = ['<?xml version="1.0" encoding="utf-8"?>']
    ns_map = {}
    depth = 0
    while off < len(data):
        ctype, header_size, csize = struct.unpack_from('<HHI', data, off)
        if ctype == RES_XML_START_NS:
            prefix, uri = struct.unpack_from('<II', data, off + 16)
            ns_map[s(strings, uri)] = s(strings, prefix)
        elif ctype == RES_XML_END_NS:
            pass
        elif ctype == RES_XML_START_ELEM:
            ns, name, attr_start, attr_size, attr_count = \
                struct.unpack_from('<IIHHH', data, off + 16)
            tag = s(strings, name)
            attrs = []
            abase = off + 16 + attr_start
            for i in range(attr_count):
                ao = abase + i * attr_size
                a_ns, a_name, a_raw = struct.unpack_from('<III', data, ao)
                _vsize, _res0, dtype, ddata = struct.unpack_from('<HBBI', data, ao + 12)
                prefix = ns_map.get(s(strings, a_ns))
                aname = s(strings, a_name) or ''
                if prefix:
                    aname = '%s:%s' % (prefix, aname)
                attrs.append('%s="%s"' % (aname, fmt_value(strings, a_raw, dtype, ddata)))
            pad = '    ' * depth
            if attrs:
                lines.append('%s<%s %s>' % (pad, tag, ' '.join(attrs)))
            else:
                lines.append('%s<%s>' % (pad, tag))
            depth += 1
        elif ctype == RES_XML_END_ELEM:
            ns, name = struct.unpack_from('<II', data, off + 16)
            depth -= 1
            lines.append('%s</%s>' % ('    ' * depth, s(strings, name)))
        elif ctype == RES_XML_CDATA:
            pass
        elif ctype == RES_XML_RESOURCE_MAP:
            pass
        off += csize
    return '\n'.join(lines)


def main():
    path = sys.argv[1]
    if path.endswith('.apk') or path.endswith('.zip'):
        with zipfile.ZipFile(path) as z:
            raw = z.read('AndroidManifest.xml')
    else:
        with open(path, 'rb') as f:
            raw = f.read()
    print(decode(raw))


if __name__ == '__main__':
    main()
