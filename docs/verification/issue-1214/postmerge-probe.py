from pathlib import Path
import subprocess,hashlib,json,os
root=Path.cwd();w=root/'.git/codex-issue-work';log=w/'1214-postmerge.log';merged='f48cf28f4d3fbb14aac4f8029c40eb83f84f73fe';sdk=w/'sdk-350/flutter/bin/dart';packages=root/'.dart_tool/package_config.json';os.environ['PATH']=str(sdk.parent)+os.pathsep+os.environ['PATH']
def record(s):
 with log.open('a') as f:f.write(str(s)+'\n')
def run(args,cwd=root,expected=0):
 p=subprocess.run(list(map(str,args)),cwd=cwd,text=True,capture_output=True);record('$ '+repr(list(map(str,args)))+'\ncwd: '+str(cwd)+'\n'+p.stdout+p.stderr+'\nexit:'+str(p.returncode));assert p.returncode==expected;return p.stdout+p.stderr
run(['which','dart']);run([sdk,'--version']);archive=w/'1214-postmerge-template.tar';run(['git','archive','--format=tar','-o',archive,merged])
def fixture(name):
 repo=w/('1214 postmerge valid '+name);assert not repo.exists();app=repo/'packages/app with spaces';app.mkdir(parents=True);run(['tar','-xf',archive,'-C',app]);sib=repo/'outside-work.txt';sib.write_text('baseline\n');run(['git','init','-q'],repo);run(['git','add','--all'],repo);run(['git','-c','core.hooksPath=/dev/null','-c','user.name=Review fixture','-c','user.email=review@example.invalid','commit','-qm','baseline'],repo);return repo,app,sib

def snapshot(app):
 paths=subprocess.check_output(['git','ls-files','-z'],cwd=app).decode().split('\0');return {p:hashlib.sha256((app/p).read_bytes()).hexdigest() for p in paths if p}
def check_unchanged(before,app):
 after=snapshot(app);assert before==after;record('All '+str(len(before))+' tracked app-file bytes unchanged after refusal; snapshotSHA256 '+hashlib.sha256(json.dumps(before,sort_keys=True).encode()).hexdigest())
def strip(app,args,expected):return run([sdk,'--packages='+str(packages),app/'tool/strip_sample_features.dart','--apply',*args],app,expected)
# Sample caller: outside index bytes survive while actual own edits still stop it.
repo,app,sib=fixture('sample caller');sib.write_text('staged outside work\n');run(['git','add','--',sib.name],repo);index_before=run(['git','show',':'+sib.name],repo);readme=app/'README.md';original=readme.read_bytes();readme.write_bytes(original+b'\nOwn unfinished app work\n');before=snapshot(app);out=strip(app,['--remove-tasks'],2);assert 'README.md' in out;check_unchanged(before,app);assert (app/'lib/features/tasks').exists();readme.write_bytes(original);strip(app,['--remove-tasks'],0);assert not (app/'lib/features/tasks').exists();assert sib.read_text()=='staged outside work\n' and run(['git','show',':'+sib.name],repo)==index_before;record('PASS merged sample caller: own tracked edit refuses before deletion; restored app strips despite staged outside work, preserving outside file/index.')
# Bricks-only caller: own hidden-index deletion work still stops it.
repo,app,sib=fixture('bricks caller');extra=repo/'untracked outside notes.txt';extra.write_text('untracked outside work\n');target=app/'bricks/README.md';original=target.read_bytes();relative=target.relative_to(repo);run(['git','update-index','--skip-worktree',relative],repo);target.write_bytes(original+b'\nOwn hidden brick work\n');before=snapshot(app);out=strip(app,['--keep-samples','--remove-bricks'],2);assert 'modified tracked file' in out;check_unchanged(before,app);assert (app/'bricks').exists();target.write_bytes(original);run(['git','update-index','--no-skip-worktree',relative],repo);strip(app,['--keep-samples','--remove-bricks'],0);assert not (app/'bricks').exists() and (app/'lib/features/tasks').exists() and (app/'lib/features/feature_flags').exists();assert extra.read_text()=='untracked outside work\n' and sib.read_text()=='baseline\n';record('PASS merged bricks-only caller: own hidden deletion target refuses before deletion; restored app removes bricks despite untracked outside work and keeps both samples/outside bytes.')
record('Bounded independent merged-source execution complete: two own-data refusals and two successful strip callers, all on fresh fixtures and inheritedSDK3.50 PATH. No full-suite duplication or tracked root edits.')
print('Bounded merged probes complete')
