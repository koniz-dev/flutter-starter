// A generated slice had no routing/ directory, although every slice that
// owns a screen declares its routes there and the guide told the reader to
// write that file by hand. The brick and both create_feature scripts now
// generate routing/<feature>_routes.dart, and the three must stay the same
// file: the scripts are documented as byte-identical siblings of the brick.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _brick =
    'bricks/feature_clean/__brick__/lib/features/{{feature_name}}/routing/'
    '{{feature_name}}_routes.dart';

/// The route module create_feature.sh writes, as the text between the
/// heredoc's opening line and its closing `EOF`.
String _shellBlock() {
  final script = File('scripts/dev/create_feature.sh').readAsStringSync();
  const opening =
      r'cat > "$BASE_DIR/routing/${FEATURE_NAME}_routes.dart" <<EOF';
  final start = script.indexOf('$opening\n');
  expect(start, isNot(-1), reason: 'create_feature.sh writes no route module');
  final body = start + opening.length + 1;
  return script.substring(body, script.indexOf('\nEOF\n', body) + 1);
}

void main() {
  test('create_feature.sh writes a route module that is not registered '
      'yet', () {
    final block = _shellBlock();

    expect(block, contains(r'GoRoute build${FEATURE_PASCAL}Route(Ref ref)'));
    // Its own constants, so the slice compiles before AppRoutes knows it.
    expect(block, contains(r"RoutePath = '/${FEATURE_PARAM}'"));
    expect(block, isNot(contains('AppRoutes.')));
    expect(block, isNot(contains("core/routing/app_routes.dart';")));
    expect(
      File('scripts/dev/create_feature.sh').readAsStringSync(),
      contains(r'FEATURE_PARAM="${FEATURE_NAME//_/-}"'),
    );
  });

  // dart format does not rewrap comments, and infos are fatal: a comment
  // line carrying the class name overflowed 80 columns for a long name.
  test('no comment line of the route module carries a templated name '
      'beyond a short prefix', () {
    final risky = [
      for (final line in _shellBlock().split('\n'))
        if (line.startsWith('///') &&
            line.contains(r'${') &&
            line.replaceAll(RegExp(r'\$\{\w+\}'), '').length > 40)
          line,
    ];

    expect(risky, isEmpty);
  });

  test('create_feature.ps1 writes the same route module', () {
    final script = File(
      'scripts/dev/create_feature.ps1',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    // The shell block in PowerShell's spelling: its variable names, and a
    // doubled backtick where the heredoc escapes one.
    final expected = _shellBlock()
        .replaceAll(r'${FEATURE_NAME}', r'${FeatureName}')
        .replaceAll(r'${FEATURE_PASCAL}', r'${FeaturePascal}')
        .replaceAll(r'${FEATURE_CAMEL}', r'${FeatureCamel}')
        .replaceAll(r'${FEATURE_PARAM}', r'${FeatureParam}')
        .replaceAll(r'\`', '``');
    const path =
        r'lib/features/$($FeatureName)/routing/$($FeatureName)_routes.dart';

    expect(
      script,
      contains('Write-GeneratedFile "$path" @"\n$expected"@\n'),
    );
    expect(script, contains(r"$FeatureParam = $FeatureName.Replace('_', '-')"));
  });

  test('the brick template is the same route module', () {
    final brick = File(_brick);
    if (!brick.existsSync()) {
      markTestSkipped('bricks/ is not in this tree');
      return;
    }
    final expected = brick
        .readAsStringSync()
        .replaceAll('{{feature_name.paramCase()}}', r'${FEATURE_PARAM}')
        .replaceAll('{{class_name.camelCase()}}', r'${FEATURE_CAMEL}')
        .replaceAll('{{feature_name}}', r'${FEATURE_NAME}')
        .replaceAll('{{class_name}}', r'${FEATURE_PASCAL}')
        // A backtick would start a command substitution in the heredoc.
        .replaceAll('`', r'\`');

    expect(_shellBlock(), expected);
  });
}
