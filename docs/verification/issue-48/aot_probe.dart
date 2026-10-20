// This is a console evidence probe, not app code: printing to stdout is the
// entire point of it, so avoid_print does not apply.
// ignore_for_file: avoid_print
//
// Evidence probe for koniz-dev/flutter-starter#48. Standalone: it is not part
// of the app and is never imported by lib/ or test/.
//
// Reproduces both dart-define lookup forms outside Flutter so the program can
// be AOT-compiled with `dart compile exe` - the same AOT pipeline that
// `flutter build apk --release` uses for Dart code.
//
// Reproduce:
//   dart compile exe docs/verification/issue-48/aot_probe.dart -o /tmp/probe \
//     -DBASE_URL=https://api.example.com -DENVIRONMENT=production
//   /tmp/probe
//
// Expected: the runtime-keyed lookup prints "", the const-table lookup prints
// the supplied value. See aot_probe.log for the recorded output.

// The broken form: the key is a runtime parameter, so the call can never be
// const. This is what lib/core/config/env_config.dart used to do.
String runtimeLookup(String key) => String.fromEnvironment(key);

// The fixed form: a const table with literal keys, resolved at compile time.
// This is what lib/core/config/dart_defines.dart does.
const Map<String, String> constTable = <String, String>{
  'BASE_URL': String.fromEnvironment('BASE_URL'),
  'ENVIRONMENT': String.fromEnvironment('ENVIRONMENT'),
};

String constLookup(String key) => constTable[key] ?? '';

void main() {
  print('runtimeLookup("BASE_URL")    = "${runtimeLookup('BASE_URL')}"');
  print('constLookup("BASE_URL")      = "${constLookup('BASE_URL')}"');
  print('runtimeLookup("ENVIRONMENT") = "${runtimeLookup('ENVIRONMENT')}"');
  print('constLookup("ENVIRONMENT")   = "${constLookup('ENVIRONMENT')}"');
}
