from pathlib import Path
import subprocess
import json
root=Path.cwd();w=root/'.git/codex-issue-work';clone=w/'1213-sdk350 fresh clone'
assert not clone.exists(), 'Preserve an existing verification clone; inspect before reusing'
subprocess.run(['git','clone','--no-hardlinks','--single-branch','--branch','codex/fix-stable-native-config-migrations',str(root),str(clone)],check=True,stdout=subprocess.DEVNULL)
assert not subprocess.check_output(['git','status','--porcelain'],cwd=clone,text=True).strip()
results=[]
for platform,command in [('ios',['flutter','build','ios','--config-only','--no-codesign']),('macos',['flutter','build','macos','--config-only'])]:
 p=w/f'1213-sdk350-fresh-{platform}.log'
 with p.open('w') as log:
  log.write('Fresh clone of '+subprocess.check_output(['git','rev-parse','HEAD'],cwd=clone,text=True).strip()+'\nWorking directory: '+str(clone)+'\nCommand: '+repr(command)+'\n');log.flush()
  code=subprocess.run(command,cwd=clone,stdout=log,stderr=subprocess.STDOUT).returncode
  status=subprocess.check_output(['git','status','--porcelain','--untracked-files=all'],cwd=clone,text=True)
  log.write(f'\nexit: {code}\nGit status after command:\n{status or "(clean)"}\n')
  if status:log.write(subprocess.check_output(['git','diff'],cwd=clone,text=True))
 results.append({'platform':platform,'exit':code,'status':status});print(results[-1],flush=True)
(w/'1213-sdk350-fresh-results.json').write_text(json.dumps(results,indent=2)+'\n')
assert all(r['exit']==0 and not r['status'].strip() for r in results), 'Fresh clone verification failed; inspect logs'
