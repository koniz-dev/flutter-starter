from pathlib import Path
import os,subprocess,tempfile,shutil
root=Path.cwd();w=root/'.git/codex-issue-work';sdk=w/'sdk-350/flutter/bin';env=dict(os.environ,PATH=str(sdk)+os.pathsep+os.environ['PATH']);head='bdc5279d47b64568652870af8f7f37a9dffabaae';base='1b8bef170d4f457af7e7f6f3b6c96c20e8093eb9';test='test/docs/bricks_removal_instructions_test.dart'
with (w/'1342-independent-tests.log').open('w') as log:
 def run(cmd,cwd=root,expected=0):
  log.write('\n$ '+' '.join(cmd)+'\n');log.flush();r=subprocess.run(cmd,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT);log.write(f'EXIT {r.returncode}\n');log.flush();assert r.returncode==expected,(cmd,r.returncode,expected)
 run(['flutter','test',test,'test/tooling/strip_bricks_prose_test.dart','--reporter','expanded'])
 for name,ref,args in [('actual-base',base,None),('tasks-retain-bricks',head,['--remove-tasks']),('keep-samples-remove-bricks',head,['--keep-samples','--remove-bricks']),('both-remove-bricks',head,['--remove-bricks'])]:
  fixture=Path(tempfile.mkdtemp(prefix='review-1342-'+name+'-'))
  try:
   run(['git','clone','--quiet','--shared','--no-hardlinks',str(root),str(fixture)])
   run(['git','checkout','--quiet','--detach',ref],fixture)
   (fixture/'.dart_tool').mkdir(exist_ok=True);shutil.copy(root/'.dart_tool/package_config.json',fixture/'.dart_tool/package_config.json')
   if args is None:
    shutil.copy(root/test,fixture/test);run(['flutter','test',test,'--reporter','expanded'],fixture,expected=1)
   else:
    run(['dart','tool/strip_sample_features.dart','--apply',*args,'--force'],fixture)
    run(['flutter','test',test,'--reporter','expanded'],fixture)
    run(['dart','run','tool/check_docs.dart'],fixture)
   log.write('FIXTURE PASS '+name+'\n');log.flush()
  finally:shutil.rmtree(fixture)
 log.write('\nINDEPENDENT CHECKS COMPLETE\n')
print('Independent focused and three stripped fixtures passed; actual-base tests fail as expected')
