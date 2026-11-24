# Builds a runnable driver from a blueprints.md: the documented SessionManager,
# timeout shortened to 300 ms, the isolate blocked 600 ms (no timer can fire,
# as under suspension), then the call the documented tracker makes on resume.
import re, sys
md = open(sys.argv[1]).read()
sec = md[md.index('## Session management'):md.index('## GDPR')]
blocks = re.findall(r'^```dart\s*\n(.*?)^```', sec, re.M | re.S)
manager, tracker = blocks[0], blocks[1]
resumed = re.search(r'AppLifecycleState\.resumed\)\s*\{([^}]*)\}', tracker).group(1)
call = re.search(r'_sessionManager\.(\w+)\(\)', resumed).group(1)
manager = re.sub(r'sessionTimeout = Duration\([^)]*\)', 'sessionTimeout = Duration(milliseconds: 300)', manager, count=1)
print("import 'dart:io' show sleep;\n" + manager + '''
class _Tokens implements ITokenStore {
  String? token = 'access';
  @override
  Future<String?> getAccessToken() async => token;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main() async {
  final tokens = _Tokens();
  var signOuts = 0;
  final manager = SessionManager(
    tokenStore: tokens,
    signOut: () async {
      signOuts++;
      tokens.token = null;
    },
  )..initialize();
  sleep(const Duration(milliseconds: 600));
  print('resume handler calls: %s');
  print('before resume: timeUntilTimeout=${manager.getTimeUntilTimeout()}');
  manager.%s();
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('after resume: signOuts=$signOuts');
  manager.dispose();
}
''' % (call, call))
