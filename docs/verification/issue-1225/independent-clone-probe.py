from pathlib import Path
import subprocess,json,hashlib
root=Path.cwd();w=root/'.git/codex-issue-work';dest=w/'1237 review clone';flutter=w/'sdk-350/flutter/bin/flutter';log=w/'1237-review.log'
def run(args,cwd=root,okay=(0,)):
 p=subprocess.run(list(map(str,args)),cwd=cwd,text=True,capture_output=True);s='$ '+repr(list(map(str,args)))+'\ncwd: '+str(cwd)+'\n'+p.stdout+p.stderr+f'\nexit:{p.returncode}\n';log.open('a').write(s);assert p.returncode in okay,s[-1000:];return p.stdout
assert not dest.exists();run(['git','clone','--no-hardlinks','--no-checkout',root,dest]);run(['git','checkout','--detach','6fbc814064a8a9be359ca4fe150b26e96d913c8a'],dest)
run([flutter,'--no-version-check','pub','get'],dest);assert not run(['git','status','--porcelain'],dest)
# Delete all generated output and let the supported command recreate it.
for p in (dest/'lib/l10n').glob('*.dart'):p.unlink()
run([flutter,'--no-version-check','gen-l10n'],dest);assert not run(['git','status','--porcelain'],dest)
run([flutter,'--no-version-check','gen-l10n'],dest);assert not run(['git','status','--porcelain'],dest)
for p in (dest/'lib').rglob('*.dart'):
 s=p.read_text();s=s.replace('package:flutter_starter/','package:review_renamed/');p.write_text(s)
p=dest/'pubspec.yaml';p.write_text(p.read_text().replace('name: flutter_starter\n','name: review_renamed\n',1))
run([flutter,'--no-version-check','pub','get'],dest);run([flutter,'--no-version-check','gen-l10n'],dest)
probe=dest/'.git/1237_renamed_probe_test.dart';probe.write_text((w/'1237_probe_test.dart').read_text().replace('package:flutter_starter/','package:review_renamed/'))
run([flutter,'--no-version-check','test','--no-pub',probe,'--reporter','expanded'],dest)
log.open('a').write('Independent fresh clone: deleting and regenerating all localization Dart files twice returns an exactly clean tree. Independent package rename: review_renamed pub get + gen-l10n + actual Riverpod/Patrol standalone widget probes pass. Scratch clone only; root tracked sources not edited.\n')
print('Fresh generation and renamed-package probes complete.')
