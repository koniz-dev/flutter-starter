import re,sys
s=open('docs/guides/features/storage-migration-guide.md').read()
fs=re.findall(r'```dart\n(.*?)```',s,re.S)
strip=lambda f:'\n'.join(l for l in f.splitlines() if not l.startswith('import '))
out=["""// Scratch: the storage-migration guide's dart fences, assembled verbatim
// (fences 0, 3, 4, 5, 6, 7, 8, 9, 11, 16) so they are analyzed, plus a
// behavioural test of the guide's complete example on SecureStorageService.
// The pattern fences are wrapped in functions nothing calls.
// ignore_for_file: unused_element
import 'package:flutter/services.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';
"""]
out.append('// fence 3\n'+strip(fs[3]))
out.append('// fence 0\n'+strip(fs[0]))
out.append('// fence 7\n'+fs[7])
out.append('// fence 16\n'+fs[16])
for i in [4,5,6,8,9,11]:
    body='\n'.join('  '+l for l in fs[i].splitlines())
    out.append(f'// fence {i}\nFuture<void> _pattern{i}(IStorageService storage) async {{\n{body}\n}}\n')
out.append(open(sys.argv[1]).read())
open('test/scratch_guide_snippets_test.dart','w').write('\n'.join(out))
