
import 'package:flutter/material.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '/Users/nguyenanhkiet/Playground/flutter-starter/test/helpers/pump_app.dart';
class Login extends Mock implements LoginUseCase {}
class Register extends Mock implements RegisterUseCase {}
void main() {
  for (final registration in [false, true]) {
    final screen = registration ? 'register' : 'login';
    for (final entry in <String, String?>{
      '': null,
      '   ': null,
      'bad-address ': null,
      'a b@example.com ': null,
      'a@ example.com ': null,
      'a@@example.com ': null,
      'a@example.com': 'a@example.com',
      '  a@example.com  ': 'a@example.com',
      '\t a@example.com \n': 'a@example.com',
      'a+tag@example.com ': 'a+tag@example.com',
      'josé@example.com ': 'josé@example.com',
    }.entries) {
      testWidgets('$screen email ${entry.key.codeUnits}', (tester) async {
        final login=Login(); final register=Register();
        when(() => login(any(), any())).thenAnswer((_) async => const ResultFailure(ServerFailure('review')));
        when(() => register(any(), any(), any())).thenAnswer((_) async => const ResultFailure(ServerFailure('review')));
        await pumpApp(tester, registration ? const RegisterScreen() : const LoginScreen(), overrides: [loginUseCaseProvider.overrideWithValue(login),registerUseCaseProvider.overrideWithValue(register)]);
        final fields=find.byType(TextFormField);
        if(registration) await tester.enterText(fields.at(0),'  New User  ');
        await tester.enterText(fields.at(registration ? 1 : 0),entry.key);
        const password=' Password123! ';
        await tester.enterText(fields.at(registration ? 2 : 1),password);
        final submit=find.byKey(registration ? UiKeys.registerSubmit : UiKeys.loginSubmit);
        await tester.ensureVisible(submit); await tester.tap(submit); await tester.pumpAndSettle();
        if(entry.value==null) {
          verifyNever(() => login(any(),any()));
          verifyNever(() => register(any(),any(),any()));
          expect(find.text(entry.key.trim().isEmpty ? 'Please enter your email' : 'Please enter a valid email address'),findsOneWidget);
        } else if(registration) {
          verify(() => register(entry.value!,password,'New User')).called(1);
        } else {
          verify(() => login(entry.value!,password)).called(1);
        }
      });
    }
    for(final password in ['', 'short']) {
      testWidgets('$screen rejects password $password', (tester) async {
        final login=Login(); final register=Register();
        await pumpApp(tester, registration ? const RegisterScreen() : const LoginScreen(), overrides: [loginUseCaseProvider.overrideWithValue(login),registerUseCaseProvider.overrideWithValue(register)]);
        final fields=find.byType(TextFormField);
        if(registration) await tester.enterText(fields.at(0),'New User');
        await tester.enterText(fields.at(registration ? 1 : 0),' a@example.com ');
        await tester.enterText(fields.at(registration ? 2 : 1),password);
        final submit=find.byKey(registration ? UiKeys.registerSubmit : UiKeys.loginSubmit);
        await tester.ensureVisible(submit); await tester.tap(submit); await tester.pumpAndSettle();
        verifyNever(() => login(any(),any())); verifyNever(() => register(any(),any(),any()));
      });
    }
  }
}
