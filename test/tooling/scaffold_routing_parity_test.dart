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

/// The brick's template with each script's own variable names filled in.
String _templateFor({
  required String name,
  required String pascal,
  required String camel,
  required String param,
}) =>
    File(_brick)
        .readAsStringSync()
        .replaceAll('{{feature_name.paramCase()}}', param)
        .replaceAll('{{class_name.camelCase()}}', camel)
        .replaceAll('{{feature_name}}', name)
        .replaceAll('{{class_name}}', pascal);

void main() {
  test('the brick generates a route module that is not registered yet', () {
    final template = File(_brick).readAsStringSync();

    expect(template, contains('GoRoute build{{class_name}}Route(Ref ref)'));
    // Its own constants, so the slice compiles before AppRoutes knows it.
    expect(template, contains("RoutePath = '/{{feature_name.paramCase()}}'"));
    expect(template, isNot(contains('AppRoutes.')));
    expect(template, isNot(contains("core/routing/app_routes.dart';")));
  });

  test('create_feature.sh writes the same route module', () {
    final script = File('scripts/dev/create_feature.sh').readAsStringSync();
    final expected = _templateFor(
      name: r'${FEATURE_NAME}',
      pascal: r'${FEATURE_PASCAL}',
      camel: r'${FEATURE_CAMEL}',
      param: r'${FEATURE_PARAM}',
      // A backtick would start a command substitution in the heredoc.
    ).replaceAll('`', r'\`');

    expect(
      script,
      contains(
        'cat > "\$BASE_DIR/routing/\${FEATURE_NAME}_routes.dart" <<EOF\n'
        '${expected}EOF\n',
      ),
    );
    expect(script, contains(r'FEATURE_PARAM="${FEATURE_NAME//_/-}"'));
  });

  test('create_feature.ps1 writes the same route module', () {
    final script = File('scripts/dev/create_feature.ps1').readAsStringSync();
    final expected = _templateFor(
      name: r'${FeatureName}',
      pascal: r'${FeaturePascal}',
      camel: r'${FeatureCamel}',
      param: r'${FeatureParam}',
      // A backtick is PowerShell's escape character in a here-string.
    ).replaceAll('`', '``');

    const path =
        r'lib/features/$($FeatureName)/routing/$($FeatureName)_routes.dart';
    const opening = 'Write-GeneratedFile "$path" @"';

    expect(
      script.replaceAll('\r\n', '\n'),
      contains('$opening\n$expected"@\n'),
    );
    expect(script, contains(r"$FeatureParam = $FeatureName.Replace('_', '-')"));
  });
}
