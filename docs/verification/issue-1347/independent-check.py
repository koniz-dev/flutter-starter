from pathlib import Path
import os,subprocess,tempfile,shutil,pty,select,time,json
R=Path.cwd();W=R/'.git/codex-issue-work';BASE='7ee7aa0cc01fac2ba8510639290b9a368ea4e7eb';HEAD=os.environ.get('REVIEW_ACCEPTED','faeadb27f8b7ab5c1a49f76ce36ea145f764c4d5');E=os.environ.copy();E['PATH']=str(W/'sdk-350/flutter/bin')+':'+E['PATH']
log=(W/'1347-independent-resume-tests.log').open('w',buffering=1)
def run(args,cwd=R,env=E,expected=0,input=None):
 log.write('\n$ '+' '.join(map(str,args))+'\n');p=subprocess.run(args,cwd=cwd,env=env,input=input,text=True,capture_output=True);log.write(p.stdout+p.stderr+f'\nEXIT {p.returncode}\n');assert (p.returncode==0)==(expected==0),(args,p.returncode);return p
run(['/bin/bash','--version'])
run(['/bin/bash','scripts/test/release_scripts_test.sh'])
run(['shellcheck','-S','warning','-s','bash','.githooks/pre-push','.githooks/pre-commit','scripts/ci/release.sh','scripts/ci/generate_changelog.sh','scripts/test/release_scripts_test.sh'])
run(['flutter','test','test/tooling/pre_push_refs_test.dart','test/tooling/setup_git_hooks_test.dart','test/tooling/create_feature_ps1_culture_test.dart','test/tooling/scaffold_routing_parity_test.dart','--reporter','expanded'])
with tempfile.TemporaryDirectory(prefix='review-1347-') as name:
 t=Path(name);old=t/'old';old.mkdir()
 for f in ['release.sh','generate_changelog.sh','bump_version.sh']:(old/f).write_bytes(subprocess.check_output(['git','show',f'{BASE}:scripts/ci/{f}']));(old/f).chmod(0o755)
 ee=E.copy();ee['SCRIPTS_UNDER_TEST']=str(old)
 b=run(['/bin/bash','scripts/test/release_scripts_test.sh'],env=ee,expected=1);assert '2 release-script test(s) failed.' in b.stdout.splitlines();log.write('BASELINE PASS exactly2 new release failures\n')
 # Independent hook probes use actual accepted/base bytes, Bash3.2, a stub
 # Flutter, monorepo layout, Git environment poison, SHA256-width zeros and TTY.
 case=t/'mono';app=case/'packages/app';(app/'.githooks').mkdir(parents=True);(t/'bin').mkdir();calls=t/'calls'
 flutter=t/'bin/flutter';flutter.write_text('#!/bin/bash\nprintf "%s|%s|%s|%s\\n" "$PWD" "$*" "${GIT_DIR-unset}" "${GIT_INDEX_FILE-unset}" >> "$CALLS"\nexit "${FLUTTER_RESULT:-0}"\n');flutter.chmod(0o755)
 ee=E.copy();ee.update(PATH=str(t/'bin')+':'+E['PATH'],CALLS=str(calls),GIT_DIR='/poison/git',GIT_INDEX_FILE='/poison/index')
 hook=app/'.githooks/pre-push';hook.write_bytes(subprocess.check_output(['git','show',f'{HEAD}:.githooks/pre-push']))
 zeros='0'*64;sha='1'*64;branch=f'HEAD {sha} refs/heads/new {zeros}\n';tag=f'HEAD {sha} refs/tags/v1 {zeros}\n';delete=f'(delete) {zeros} refs/heads/old {sha}\n'
 for label,refs,want in [('tag64',tag,False),('delete64',delete,False),('mixed tag/delete',tag+delete,False),('branch64',branch,True),('delete then branch',delete+branch,True),('branch then delete',branch+delete,True),('localtag remote branch',f'refs/tags/v1 {sha} refs/heads/new {zeros}\n',True),('emptyEOF','',True)]:
  calls.unlink(missing_ok=True);run(['/bin/bash',str(hook)],cwd=case,env=ee,input=refs);assert calls.exists()==want,label
  if want:assert calls.read_text().strip()==f'{app.resolve()}|test --reporter compact --timeout 15m|unset|unset',calls.read_text()
  log.write('INDEPENDENT HOOK PASS '+label+'\n')
 calls.unlink(missing_ok=True);ee['FLUTTER_RESULT']='7';p=run(['/bin/bash',str(hook)],cwd=case,env=ee,input=branch,expected=1);assert p.returncode==1;ee.pop('FLUTTER_RESULT')
 # A TTY manual invocation must not wait for EOF/ref lines.
 calls.unlink(missing_ok=True);master,slave=pty.openpty();p=subprocess.Popen(['/bin/bash',str(hook)],cwd=case,env=ee,stdin=slave,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);os.close(slave)
 try:out,err=p.communicate(timeout=10)
 finally:os.close(master)
 log.write('TTY OUTPUT\n'+out+err+f'EXIT {p.returncode}\n');assert p.returncode==0 and calls.exists();log.write('INDEPENDENT HOOK PASS TTY does not block\n')
 # Demonstrate original hook fails3 skip cases while branch control stays.
 hook.write_bytes(subprocess.check_output(['git','show',f'{BASE}:.githooks/pre-push']))
 for label,refs in [('tag',tag),('deletion',delete),('both',tag+delete)]:
  calls.unlink(missing_ok=True);run(['/bin/bash',str(hook)],cwd=case,env=ee,input=refs);assert calls.exists();log.write('BASE DISCRIMINATION '+label+' wrongly called Flutter\n')
with tempfile.TemporaryDirectory(prefix='review-format-1347-') as name:
 t=Path(name);f=t/'app';f.mkdir()
 for path in ['scripts/ci/release.sh','scripts/ci/generate_changelog.sh','scripts/ci/bump_version.sh','scripts/dev/format_dart.sh']:
  target=f/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/path,target)
 for path in ['lib','test','integration_test','tool','examples']:(f/path).mkdir()
 (f/'lib/bad.dart').write_text('void main(){print(1);}')
 (f/'pubspec.yaml').write_text('name: fixture\nversion: 1.0.0\nenvironment:\n  sdk: ">=3.14.0 <4.0.0"\n')
 (f/'CHANGELOG.md').write_text('# Changelog\n\n## [Unreleased]\n')
 (t/'bin').mkdir();calls=t/'calls';stub=t/'bin/flutter';stub.write_text('#!/bin/bash\necho "$*" >> "$CALLS"\nexit 9\n');stub.chmod(0o755)
 ee=E.copy();ee.update(PATH=str(t/'bin')+':'+E['PATH'],CALLS=str(calls))
 def git(*args):return subprocess.check_output(['git','-c','core.hooksPath=/dev/null','-c','user.name=fixture','-c','user.email=fixture@example.com',*args],cwd=f,text=True).strip()
 git('init','-q','-b','main');git('add','.');git('commit','-qm','chore: fixture');git('tag','v1.0.0');before=git('rev-parse','HEAD')
 p=run(['/bin/bash','scripts/ci/release.sh','patch'],cwd=f,env=ee,input='',expected=1)
 assert p.returncode==1 and '1 changed' in p.stdout and 'Step 1:' not in p.stdout and not calls.exists()
 assert git('branch','--show-current')=='main' and git('status','--porcelain')=='' and git('rev-parse','HEAD')==before
 log.write('REAL FORMATTER PASS rejection before Step1, source/branch/history unchanged\n')
 (f/'lib/bad.dart').write_text('void main() {\n  print(1);\n}\n');git('add','.');git('commit','-qm','style: fixture');before=git('rev-parse','HEAD')
 p=run(['/bin/bash','scripts/ci/release.sh','patch'],cwd=f,env=ee,input='',expected=1)
 assert p.returncode==9 and 'Step 1:' in p.stdout and calls.read_text().splitlines()==['test']
 assert git('branch','--show-current')=='main' and git('status','--porcelain')=='' and git('rev-parse','HEAD')==before
 log.write('REAL FORMATTER PASS clean source reaches Step1, failed Flutter stops without mutation\n')
log.write('\nINDEPENDENT REVIEW CHECKS COMPLETE\n');log.close()
