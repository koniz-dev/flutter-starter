import io,os,pathlib,shutil,subprocess,tarfile,tempfile
root=pathlib.Path.cwd();w=root/'.git/codex-issue-work';scratch=pathlib.Path(tempfile.mkdtemp(prefix='1266-cli-scratch-',dir=w));(w/'1266-cli-scratch-path.txt').write_text(str(scratch)+'\n')
archive=subprocess.check_output(['git','archive','HEAD'])
with tarfile.open(fileobj=io.BytesIO(archive)) as a:a.extractall(scratch,filter='data')
for name in ['bricks/flutter_starter_setup/hooks/pre_gen.dart','bricks/flutter_starter_setup/hooks/post_gen.dart','docs/guides/onboarding/fork-and-customize.md','test/tooling/setup_brick_rerun_test.dart','test/tooling/setup_brick_log_test.dart']:
 shutil.copy2(root/name,scratch/name)
env=os.environ.copy();env['PATH']=str(w/'sdk-350/flutter/bin')+os.pathsep+env['PATH']
log=(w/'1266-cli-probe.log').open('w',buffering=1)
def run(args,ok=True):
 log.write('$ '+(' '.join(args) if len(args)<30 else ' '.join(args[:3])+' [... enumerated '+str(len(args)-3)+' file paths]')+'\n');r=subprocess.run(args,cwd=scratch,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);log.write(r.stdout+f'\nexit: {r.returncode}\n');
 if ok and r.returncode:raise RuntimeError('Command failed; inspect CLI probe log')
 return r
run(['git','init','-q'])
files=subprocess.check_output(['git','ls-tree','-r','--name-only','HEAD'],cwd=root,text=True).splitlines()+['test/tooling/setup_brick_rerun_test.dart']
run(['git','add','--',*files])
commit=['git','-c','user.name=Test','-c','user.email=test@example.invalid','-c','commit.gpgsign=false','-c','core.hooksPath='+str(scratch/'no-hooks'),'commit','-qm']
run([*commit,'initial fixture'])
accepted=subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=root,text=True).strip()
initial=subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=scratch,text=True).strip()
assert accepted==initial
log.write('Initial fixture source-tree parity: '+accepted+'\n')
cli=['dart','--packages=/Users/nguyenanhkiet/.pub-cache/global_packages/mason_cli/.dart_tool/package_config.json','/Users/nguyenanhkiet/.pub-cache/hosted/pub.dev/mason_cli-0.1.4/bin/mason.dart']
run([*cli,'get'])
def make(package,identifier,display):return [*cli,'make','flutter_starter_setup','--package_name',package,'--application_id',identifier,'--ios_bundle_id',identifier,'--app_display_name',display,'--strip_sample_features','false','--include_tasks_sample','true','--include_feature_flags_sample','true','--on-conflict','overwrite']
run(make('acme_shop','io.acme.shop.app','Acme Shop'))
assert 'name: acme_shop' in (scratch/'pubspec.yaml').read_text()
assert 'io.acme.shop.app' in (scratch/'android/app/build.gradle.kts').read_text()
assert (scratch/'android/app/src/main/kotlin/io/acme/shop/app/MainActivity.kt').exists()
assert 'io.acme.shop.app' in (scratch/'ios/Runner.xcodeproj/project.pbxproj').read_text()
run(['git','add','-u'])
new=subprocess.check_output(['git','ls-files','--others','--exclude-standard','-z'],cwd=scratch).decode().split('\0');new=[p for p in new if p]
if new:run(['git','add','--',*new])
run([*commit,'first complete setup'])
assert not run(['git','status','--porcelain']).stdout.strip()
second=run(make('zeta_two','org.zeta.two','Zeta Two'),ok=False)
assert second.returncode!=0
assert 'already customized' in second.stdout and 'fork-and-customize.md' in second.stdout
assert not any(s in second.stdout for s in ['Renamed','Updated','Setup complete'])
assert not run(['git','status','--porcelain']).stdout.strip()
log.write('PASS: actual Mason first setup completed; second setup refused before generation; git status empty; no false completion messages.\n');log.close()
print(scratch)
