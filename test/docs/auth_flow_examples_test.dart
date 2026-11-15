import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/routing/routes_registry.dart';
import 'package:flutter_starter/core/routing/session_status.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/in_memory_stores.dart';
import '../tooling/import_rules_test.dart' as architecture;
import 'doc_snippets.dart';

class _Remote extends Mock implements AuthRemoteDataSource {}

String _section(String text, String start, String end) =>
    text.substring(text.indexOf(start), text.indexOf(end, text.indexOf(start)));

List<String> _blocks(String markdown) => RegExp(
  r'^```dart\s*\n(.*?)^```',
  multiLine: true,
  dotAll: true,
).allMatches(markdown).map((match) => match.group(1)!).toList();

Future<
  ({ProviderContainer container, WidgetRef ref, InMemoryTokenStore tokens})
>
_graph(WidgetTester tester) async {
  final remote = _Remote();
  when(() => remote.login('doc@example.com', 'password123')).thenAnswer(
    (_) async => const AuthResponseModel(
      user: UserModel(id: 'doc-user', email: 'doc@example.com'),
      token: 'doc-access',
      refreshToken: 'doc-refresh',
    ),
  );
  when(
    () => remote.logout(
      refreshToken: any(named: 'refreshToken'),
      accessToken: any(named: 'accessToken'),
    ),
  ).thenAnswer((_) async {});
  final tokens = InMemoryTokenStore();
  final container = ProviderContainer(
    overrides: [
      ...authModuleOverrides,
      storageServiceProvider.overrideWithValue(InMemoryStorage()),
      tokenStoreProvider.overrideWithValue(tokens),
      authRemoteDataSourceProvider.overrideWithValue(remote),
    ],
  );
  addTearDown(container.dispose);
  late WidgetRef widgetRef;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, child) {
          widgetRef = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await container.read(sessionRestorationProvider.future);
  expect(container.read(sessionStatusProvider), SessionStatus.signedOut);
  return (container: container, ref: widgetRef, tokens: tokens);
}

void main() {
  final integration = File('docs/api/examples/api-integration.md')
      .readAsStringSync();
  final blueprints = File('docs/guides/security/blueprints.md')
      .readAsStringSync();
  final sessionBlocks = _blocks(
    _section(blueprints, '## Session management', '## GDPR'),
  );

  testWidgets('the documented login call publishes the signed-in session', (
    tester,
  ) async {
    final example = _section(
      integration,
      '### Complete Login Flow',
      '### Check Authentication Status',
    );
    final selector = RegExp(
      r'ref\.read\((loginUseCaseProvider|authNotifierProvider\.notifier)\)',
    ).firstMatch(example);
    expect(
      selector,
      isNotNull,
      reason: 'compile and execute the documented API',
    );
    final graph = await _graph(tester);
    // Both documented API shapes compile here. Selecting the actual quoted
    // one makes the old usecase-only example fail on real session state.
    if (selector!.group(1) == 'loginUseCaseProvider') {
      await graph.ref.read(loginUseCaseProvider)(
        'doc@example.com',
        'password123',
      );
    } else {
      await graph.ref
          .read(authNotifierProvider.notifier)
          .login('doc@example.com', 'password123');
    }
    await tester.pump();
    expect(graph.tokens.accessToken, 'doc-access');
    expect(graph.container.read(sessionStatusProvider), SessionStatus.signedIn);
  });

  test('the session blueprint obeys the import guard where it is placed', () {
    final path = RegExp(r'Blueprint: (lib/[^\s]+\.dart)')
        .firstMatch(sessionBlocks.first)!
        .group(1)!;
    final source = forPackage(sessionBlocks.first, currentPackageName());
    final violations = [
      for (final directive in architecture.parseDirectives(source))
        ...architecture.violationsFor(path, directive),
    ];
    expect(
      violations,
      isEmpty,
      reason: violations.map((v) => v.rule.id).join(', '),
    );
    // Compile both blueprint pieces together without pretending that the
    // optional session_manager.dart already exists in the starter.
    final imports = <String>{};
    final bodies = <String>[];
    for (final block in sessionBlocks.take(2)) {
      final body = <String>[];
      for (final line in block.split('\n')) {
        if (line.startsWith('import ')) {
          if (!line.contains('/core/security/session_manager.dart')) {
            imports.add(line);
          }
        } else {
          body.add(line);
        }
      }
      bodies.add(body.join('\n'));
    }
    expect(
      analyzeSnippets('auth_blueprint', [
        '${imports.join('\n')}\n${bodies.join('\n')}',
      ]),
      isEmpty,
    );
  });

  testWidgets('the blueprint sign-out action ends the visible session', (
    tester,
  ) async {
    final graph = await _graph(tester);
    await graph.ref
        .read(authNotifierProvider.notifier)
        .login('doc@example.com', 'password123');
    expect(graph.container.read(sessionStatusProvider), SessionStatus.signedIn);
    if (sessionBlocks.first.contains('await authRepository.logout()')) {
      await graph.ref.read(authRepositoryProvider).logout();
    } else {
      expect(sessionBlocks.first, contains('await signOut()'));
      expect(sessionBlocks[1], contains('ref.read(signOutProvider)'));
      await graph.ref.read(signOutProvider)();
    }
    await tester.pump();
    expect(graph.tokens.accessToken, isNull);
    expect(
      graph.container.read(sessionStatusProvider),
      SessionStatus.signedOut,
    );
  });

  test('the Logout contract documents revocation body and bearer header', () {
    final guide = File('docs/guides/onboarding/getting-started.md')
        .readAsStringSync();
    final contract = _section(guide, '| Logout |', '`user` is an object');
    final row = contract.split('\n').first.split('|');
    expect(row[3], contains('`refresh_token`'));
    expect(contract, contains('Authorization: Bearer'));
  });

  test('both refresh examples end only an expired session '
      'without token writes', () {
    final usecases = File('docs/api/features/auth/usecases.md')
        .readAsStringSync();
    for (final example in [
      _section(integration, '### Manual Token Refresh', '## Related APIs'),
      _section(usecases, '## RefreshTokenUseCase', '## Usage Pattern'),
    ]) {
      final normalized = example
          .replaceAll(RegExp(r'\s*/// ?'), '')
          .replaceAll(RegExp(r'\s+'), '');
      expect(
        normalized,
        contains(
          'if(result.failureOrNull?.code==AuthErrorCodes.refreshTokenExpired)',
        ),
      );
      expect(example, isNot(contains('updateTokenInStorage')));
      expect(example, isNot(contains('cacheToken(')));
      expect(example, contains('signOutProvider'));
    }
  });
}
