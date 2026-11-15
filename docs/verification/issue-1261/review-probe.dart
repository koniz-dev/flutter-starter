import 'package:flutter/widgets.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
class _Local extends Mock implements AuthLocalDataSource {}
class _Remote extends Mock implements AuthRemoteDataSource {}
void main() {
 for (final language in ['en','es','vi','ar']) {
  test('independent $language code and status precedence controls', () {
   final l = lookupAppLocalizations(Locale(language));
   expect(const ServerFailure('raw',statusCode:409,code:'INVALID_AUTH_RESPONSE').localizedMessage(l),l.failureRequestRejected);
   expect(const ServerFailure('raw',statusCode:429,code:FailureCodes.invalidCredentials).localizedMessage(l),l.failureRateLimited);
   expect(const ServerFailure('raw',statusCode:503).localizedMessage(l),l.failureServer);
   expect(const ServerFailure('raw').localizedMessage(l),l.failureServer);
   expect(const UnknownFailure('raw',code:'CONNECTION_TIMEOUT').localizedMessage(l),l.failureTimeout);
   expect(const AuthFailure('raw',code:FailureCodes.invalidCredentials).localizedMessage(l),l.failureInvalidCredentials);
  });
 }
 for(final status in [400,429,503]) {
  test('refresh $status retains the preexisting domain contract', () async {
   final local=_Local();final remote=_Remote();
   when(local.getRefreshToken).thenAnswer((_)async=>'fixture-refresh');
   when(()=>remote.refreshToken('fixture-refresh')).thenThrow(ServerException('fixture-error',statusCode:status));
   final repo=AuthRepositoryImpl(remoteDataSource:remote,localDataSource:local);
   final result=await repo.refreshToken();
   final f=result.failureOrNull!;
   final en=lookupAppLocalizations(const Locale('en'));
   if(status==400){expect(f,isA<AuthFailure>());expect(f.code,AuthErrorCodes.refreshTokenExpired);expect(f.localizedMessage(en),en.failureAuth);}
   else {expect(f,isA<ServerFailure>());expect((f as ServerFailure).statusCode,status);expect(f.localizedMessage(en),status==429?en.failureRateLimited:en.failureServer);}
   verifyNever(local.clearCache);
  });
 }
}
