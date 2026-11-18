from pathlib import Path
import os,subprocess,tempfile,shutil
root=Path.cwd();w=root/'.git/codex-issue-work';sdk=w/'sdk-350/flutter/bin';env=os.environ.copy();env['PATH']=str(sdk)+':'+env['PATH']
accepted='98a16be36b5db4768aed4f8b225652bca3ab4318';base='797573efca9fdb8cc1788bee66ff6f5566ad0ff5';test='test/features/auth/presentation/screens/auth_form_keyboard_test.dart';guardbytes=b'      if (!mounted) return;\n'
with (w/'1345-independent-tests.log').open('a') as log:
 def run(args,cwd,expect=0,marker=None):
  log.write('\n$ '+' '.join(args)+'\n');log.flush();p=subprocess.run(args,cwd=cwd,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);log.write(p.stdout+f'\nEXIT {p.returncode}\n');log.flush()
  assert (p.returncode==0)==(expect==0),p.stdout[-2000:]
  if marker:assert marker in p.stdout,p.stdout[-2000:]
  return p.stdout
 folder=Path(tempfile.mkdtemp(prefix='flutter-review-1345-'))
 try:
  run(['git','clone','--shared','--quiet','--no-checkout',str(root),str(folder)],root)
  run(['git','checkout','--quiet',accepted],folder)
  (folder/'.dart_tool').mkdir();shutil.copy(root/'.dart_tool/package_config.json',folder/'.dart_tool/package_config.json')
  run(['flutter','pub','get','--offline'],folder)
  current=(root/test).read_bytes()
  run(['git','checkout','--quiet',base],folder);(folder/test).write_bytes(current)
  out=run(['flutter','test','--no-pub',test,'--plain-name','fields carry keyboard actions and autofill hints','--reporter','expanded'],folder,expect=1,marker="Actual: ['email']")
  assert out.count('[E]')==2,out[-2000:]
  log.write('DISCRIMINATION PASS: both final username-hint assertions fail original source\n');log.flush()
  run(['git','reset','--hard',accepted],folder)
  for name,case in [('login','leaving while the sign-in runs does not throw'),('register','leaving while registration runs does not throw')]:
   path=folder/f'lib/features/auth/presentation/screens/{name}_screen.dart';s=path.read_bytes();assert s.count(guardbytes)==1;path.write_bytes(s.replace(guardbytes,b'',1))
   try:run(['flutter','test','--no-pub',test,'--plain-name',case,'--reporter','expanded'],folder,expect=1,marker='Using "ref" when a widget is about to or has been unmounted is unsafe')
   finally:path.write_bytes(s)
   log.write(f'DISCRIMINATION PASS: {name} unmount test detects missing mounted guard\n');log.flush()
  # Additional independent failed-request completion paths after disposal.
  s=(folder/test).read_text();s=s.replace('reply.complete(const Success(_user));',"reply.complete(const ResultFailure(AuthFailure('no')));")
  (folder/test).write_text(s)
  run(['flutter','test','--no-pub',test,'--plain-name','leaving while','--reporter','expanded'],folder)
  log.write('ADJACENT CONTROLS PASS: both disposed screens tolerate failed late replies\n');log.flush()
  # Check registration autofill success/cancel paths with the unchanged platform log helper.
  s=current.decode();needle="    testWidgets('a rejected sign-in, then leaving, saves nothing', ("
  extra="""    for (final success in [true, false]) {
      testWidgets('independent registration autofill save=$success', (tester) async {
        when(() => register(any(), any(), any())).thenAnswer((_) async => success ? const Success(_user) : const ResultFailure(AuthFailure('no')));
        await pump(tester, AppRoutes.register);
        await tester.enterText(find.widgetWithText(TextFormField, _l10n.name), 'Ann');
        await fill(tester);
        await tester.tap(find.widgetWithText(ElevatedButton, _l10n.register));
        await tester.pumpAndSettle();
        if (success) {
          expect(finished(tester), contains(true));
        } else {
          router.go(AppRoutes.login);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(RegisterScreen, skipOffstage: false), findsNothing);
          expect(finished(tester), isNot(contains(true)));
        }
      });
    }

"""
  assert needle in s;(folder/test).write_text(s.replace(needle,extra+needle))
  run(['flutter','test','--no-pub',test,'--plain-name','independent registration autofill','--reporter','expanded'],folder)
  log.write('ADJACENT CONTROLS PASS: registration commits on success and cancels rejected credentials\n')
  log.write('INDEPENDENT DISCRIMINATION COMPLETE\n')
 finally:shutil.rmtree(folder)
print('Independent baseline/mutation/adjacent checks complete')
