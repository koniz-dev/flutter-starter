// The security blueprints' SessionManager times a session out with a Timer,
// but a suspended app runs no timers: the first code to run on return is the
// lifecycle resume handler. If that handler only extends the session, an app
// left in the background never times out. This runs the documented manager
// and the call the documented tracker makes on resume, with the isolate
// blocked past the timeout the way suspension blocks it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'doc_snippets.dart';

/// The repository's package config: `dart <file>` with it skips `dart run`'s
/// build-hook step, whose native-asset bundling crashed when several tests
/// ran it at once.
final String _packages = File(
  '.dart_tool/package_config.json',
).absolute.path;

String _section(String text, String start, String end) =>
    text.substring(text.indexOf(start), text.indexOf(end, text.indexOf(start)));

List<String> _blocks(String markdown) => RegExp(
  r'^```dart\s*\n(.*?)^```',
  multiLine: true,
  dotAll: true,
).allMatches(markdown).map((match) => match.group(1)!).toList();

void main() {
  test('resuming after the timeout signs out exactly once', () {
    final blocks = _blocks(
      _section(
        File('docs/guides/security/blueprints.md').readAsStringSync(),
        '## Session management',
        '## GDPR',
      ),
    );
    final manager = blocks[0];
    final tracker = blocks[1];

    // The call the tracker makes when the app comes back to the foreground.
    final resumed = RegExp(
      r'AppLifecycleState\.resumed\)\s*\{([^}]*)\}',
    ).firstMatch(tracker);
    expect(resumed, isNotNull, reason: 'the tracker handles resumed');
    final call = RegExp(
      r'_sessionManager\.(\w+)\(\)',
    ).firstMatch(resumed!.group(1)!);
    expect(call, isNotNull, reason: 'the resume handler calls the manager');

    // A 24-hour timeout, shortened so the test can outlast it.
    final timeout = RegExp(r'sessionTimeout = Duration\([^)]*\)');
    expect(manager, contains(timeout));
    final source = forPackage(manager, currentPackageName()).replaceFirst(
      timeout,
      'sessionTimeout = Duration(milliseconds: 300)',
    );

    final dir = Directory.systemTemp.createTempSync('session_timeout_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final driver = File('${dir.path}/driver.dart')
      ..writeAsStringSync('''
import 'dart:io' show sleep;
$source
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
  // Suspended: nothing runs on the isolate, so the timer cannot fire.
  sleep(const Duration(milliseconds: 600));
  manager.${call!.group(1)}();
  // Shorter than the timeout, so a timer the resume restarted cannot be
  // what signs out.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('signOuts=\$signOuts');
  manager.dispose();
}
''');

    final result = Process.runSync('dart', [
      '--packages=$_packages',
      driver.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect('${result.stdout}'.trim(), 'signOuts=1');
  });
}
