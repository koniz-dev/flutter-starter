import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Remote extends Mock implements AuthRemoteDataSource {}

class _Local extends Mock implements AuthLocalDataSource {}

const _messages = <String, ({String rejected, String limited})>{
  'en': (
    rejected: 'The request was rejected. Please check your information.',
    limited: 'Too many requests. Please wait before trying again.',
  ),
  'es': (
    rejected: 'La solicitud fue rechazada. Revisa la información.',
    limited: 'Demasiadas solicitudes. Espera antes de volver a intentarlo.',
  ),
  'vi': (
    rejected: 'Yêu cầu bị từ chối. Vui lòng kiểm tra thông tin.',
    limited: 'Có quá nhiều yêu cầu. Vui lòng chờ trước khi thử lại.',
  ),
  'ar': (
    rejected: 'تم رفض الطلب. يرجى التحقق من المعلومات.',
    limited: 'طلبات كثيرة جدًا. يرجى الانتظار قبل المحاولة مرة أخرى.',
  ),
};

Future<void> _submitRejected(
  WidgetTester tester, {
  required bool register,
  required String language,
  required int status,
  required String expected,
}) async {
  final remote = _Remote();
  final error = ServerException('raw backend detail', statusCode: status);
  when(() => remote.login(any(), any())).thenThrow(error);
  when(() => remote.register(any(), any(), any())).thenThrow(error);
  final repository = AuthRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: _Local(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: register ? const RegisterScreen() : const LoginScreen(),
      ),
    ),
  );
  final fields = find.byType(TextFormField);
  if (register) await tester.enterText(fields.at(0), 'New User');
  await tester.enterText(fields.at(register ? 1 : 0), 'a@example.com');
  await tester.enterText(fields.at(register ? 2 : 1), 'password123');
  final submit = find.byKey(
    register ? UiKeys.registerSubmit : UiKeys.loginSubmit,
  );
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();

  if (register) {
    verify(() => remote.register('a@example.com', 'password123', 'New User'))
        .called(1);
  } else {
    verify(() => remote.login('a@example.com', 'password123')).called(1);
  }
  expect(find.text(expected), findsOneWidget);
  expect(find.textContaining('raw backend detail'), findsNothing);
}

void main() {
  for (final MapEntry(key: language, value: messages) in _messages.entries) {
    for (final register in [false, true]) {
      for (final status in [400, 409, 429]) {
        testWidgets('$language ${register ? 'register' : 'login'} $status '
            'explains rejection or waiting instead of a server outage', (
          tester,
        ) async {
          await _submitRejected(
            tester,
            register: register,
            language: language,
            status: status,
            expected: status == 429 ? messages.limited : messages.rejected,
          );
          final l10n = lookupAppLocalizations(Locale(language));
          expect(find.text(l10n.failureServer), findsNothing);
        });
      }
    }
  }

  for (final register in [false, true]) {
    testWidgets(
      '503 ${register ? 'register' : 'login'} still shows server failure',
      (tester) async {
        await _submitRejected(
          tester,
          register: register,
          language: 'en',
          status: 503,
          expected: lookupAppLocalizations(const Locale('en')).failureServer,
        );
      },
    );
  }
}
