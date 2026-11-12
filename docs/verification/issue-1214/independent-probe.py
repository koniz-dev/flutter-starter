from pathlib import Path
import subprocess,hashlib,json,os
root=Path.cwd();w=root/'.git/codex-issue-work';head='653bb6725442a64eaa0f4e14abf777631e35bd8b';base='91131bf5f6c55f3ff0d634be4d49008846a6b99d';log=w/'1214-review.log';sdk=w/'sdk-350/flutter/bin/dart';packages=root/'.dart_tool/package_config.json'
os.environ['PATH']=str(w/'sdk-350/flutter/bin')+os.pathsep+os.environ['PATH']
def record(s):
 with log.open('a') as f:f.write(str(s)+'\n')
def run(args,cwd=root,expect=(0,),raw=True):
 p=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True,text=True)
 record('$ '+repr(list(map(str,args)))+'\ncwd: '+str(cwd)+'\n'+(p.stdout if raw else '<output recorded separately>')+p.stderr+'\nexit:'+str(p.returncode));assert p.returncode in expect,(args,p.returncode,p.stderr);return p
log.write_text('Fresh independent adversarial premerge tooling review PR1238 / issue1214\nBase '+base+'; accepted '+head+'\nRead-only tracked source; scratch fixtures only under W. IsolatedSDK3.50 PATH is inherited by nested tool processes. First inconsistent PATH harness was retained as invalid in1214-review-first-invalid.log.\n')
run(['which','dart']);run([sdk,'--version']);run(['git','status','--porcelain']);run(['git','diff',base,head,'--']);record((w/'1214-review-issue.json').read_text())
archive=w/'1214-review-sdk350-template.tar';subprocess.run(['git','archive','--format=tar','-o',str(archive),head],check=True)
def fixture(name,old=False):
 repo=w/('1214 review sdk350 '+name);assert not repo.exists();app=repo/'apps/app with spaces';app.mkdir(parents=True)
 run(['tar','-xf',archive,'-C',app]);
 if old:(app/'tool/strip_sample_features.dart').write_bytes(subprocess.check_output(['git','show',base+':tool/strip_sample_features.dart']))
 sibling=repo/'outside sibling ü notes.txt';sibling.write_text('baseline sibling\n')
 run(['git','init','-q'],repo);run(['git','add','--all'],repo);run(['git','-c','core.hooksPath=/dev/null','-c','user.name=Review fixture','-c','user.email=review@example.invalid','commit','-qm','baseline'],repo)
 assert not run(['git','status','--porcelain'],repo).stdout
 return repo,app,sibling

def strip(app,args,expected):
 return run([sdk,'--packages='+str(packages),app/'tool/strip_sample_features.dart','--apply',*args],app,expect=(expected,))
def hashfile(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def ls_scope(repo,app,sibling):
 p=subprocess.run(['git','ls-files','-v','-z'],cwd=app,capture_output=True,check=True)
 names=p.stdout.decode().split('\0');artifact=w/(repo.name.replace(' ','_')+'-ls-files.txt');artifact.write_text('\n'.join(names));assert all(sibling.name not in n for n in names)
 record('$ git ls-files -v -z (cwd app)\nRaw entries: '+str(artifact)+'\nSibling excluded: yes\nFlagged app entries: '+repr([n for n in names if n and (n[0]=='S' or n[0].islower())]))

# Actual strip succeeds despite staged plus unusual untracked outside paths.
repo,app,sib=fixture('staged sibling');sib.write_text('staged outside work\n');run(['git','add','--',sib.name],repo);extra=repo/'untracked\noutside.txt';extra.write_text('untracked outside work\n');before=(hashfile(sib),hashfile(extra),run(['git','show',':'+sib.name],repo).stdout);ls_scope(repo,app,sib)
strip(app,['--remove-tasks'],0);assert not (app/'lib/features/tasks').exists();assert before==(hashfile(sib),hashfile(extra),run(['git','show',':'+sib.name],repo).stdout);record('PASS deep nested app/path spaces; staged and unusual untracked outside bytes/index preserved.')
# ls-files must not feed hidden sibling paths into app-relative hash checks.
for flag in ['assume-unchanged','skip-worktree']:
 repo,app,sib=fixture('outside '+flag);run(['git','update-index','--'+flag,sib.name],repo);sib.write_text('hidden outside work\n');ls_scope(repo,app,sib);before=hashfile(sib);strip(app,['--remove-tasks'],0);assert hashfile(sib)==before;record('PASS hidden-index outside '+flag+' excluded; app strips successfully and outside work is preserved.')
# Hidden project deletion targets remain protected even with outside edits.
for flag in ['assume-unchanged','skip-worktree']:
 repo,app,sib=fixture('inside '+flag);sib.write_text('outside work\n');target=app/'lib/features/tasks/domain/entities/task.dart';relative=target.relative_to(repo);run(['git','update-index','--'+flag,str(relative)],repo);target.write_text(target.read_text()+'\n// private app work\n');before=hashfile(target);ls_scope(repo,app,sib);p=strip(app,['--remove-tasks'],2);assert 'modified tracked file' in p.stderr;assert (app/'lib/features/tasks').exists() and hashfile(target)==before;record('PASS own '+flag+' app deletion target refuses before deletion and preserves bytes.')
# The keep-samples/bricks-only caller shares the same guard.
repo,app,sib=fixture('bricks only');sib.write_text('staged outside work\n');run(['git','add','--',sib.name],repo);before=hashfile(sib);strip(app,['--keep-samples','--remove-bricks'],0);assert not (app/'bricks').exists() and (app/'lib/features/tasks').exists() and hashfile(sib)==before;record('PASS bricks-only caller accepts unrelated sibling changes while preserving samples and sibling bytes.')
# Counterfactual uses the old production tool in an otherwise clean real fixture.
repo,app,sib=fixture('old counterfactual',old=True);sib.write_text('staged outside work\n');run(['git','add','--',sib.name],repo);p=strip(app,['--remove-tasks'],2);assert 'Refusing to strip an edited working tree' in p.stderr;assert (app/'lib/features/tasks').exists();record('PASS counterfactual: original tool refuses on outside-only staged edit; no deletion. New tool succeeds for equivalent staged-sibling case.')
record('Independent probes complete: six positive/safety executions and one failing-old-tool counterfactual behaved as asserted. No tracked edits, issue mutations or global settings changes.')
print('Independent strip probes complete.')
