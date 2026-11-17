import '../../lib/core/utils/validators.dart';
void main() {
 final cases = <String,bool>{
  'http://example.com:+80':false, 'http://example.com:-0':false,
  'http://user:pass@[::1]:+80':false, 'http://user:+80@example.com':true,
  'http://user:pass@[::1]:':true, 'http://user:pass@[::1]:00080':true,
  'http://example.com:':true, 'http://example.com:00065535':true,
  'http://example.com:65536':false,'http://example.com:0':true,
  'http://[::1]:65535':true,'http://[::1]:65536':false,
  'http://[::1]x:80':false, 'http://[::1]:-0':false,
  'http://example.com:0x50':false, 'http://example.com:%38%30':false,
  'http://example.com:80?x=:+80':true,'http://example.com:80/#:+80':true,
  'http://user:pass@example.com:443':true,
  'http://user%40name:pass@example.com:80':true,
  'http://user:pass@example.com:+80':false,
  'http://example.com:${'0'*10000}80':true,
  'http://example.com:${'9'*10000}':false,
  'http://example.com/%C2%85':true,
 };
 for (var code=0;code<=0x9f;code++) {
  if(code<=0x20 || code>=0x7f) cases['http://example.com/a${String.fromCharCode(code)}z']=false;
 }
 var count=0;
 for(final e in cases.entries) {
  final result=Validators.isValidUrl(e.key);
  if(result!=e.value) throw StateError('Unexpected ${e.key.codeUnits}: $result expected ${e.value}');
  count++;
 }
 print('PASS $count raw port/IPv6/userinfo/zero-padding/C0/C1/encoded control cases');
}
