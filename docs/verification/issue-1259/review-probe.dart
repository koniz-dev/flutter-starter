import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../test/helpers/in_memory_stores.dart';
class Remote extends Mock implements AuthRemoteDataSource {}
class DelayedLocal extends AuthLocalDataSourceImpl {
  DelayedLocal({required super.storageService, required super.tokenStore});
  Completer<UserModel?>? cachedRead;
  final entered = Completer<void>();
  @override
  Future<UserModel?> getCachedUser() {
    final held = cachedRead;
    if (held == null) return super.getCachedUser();
    entered.complete();
    return held.future;
  }
}
class Unauthorized implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => ResponseBody.fromString('{}',401);
  @override
  void close({bool force=false}) {}
}
void main() {
  for (final access in <String?>[null, '', 'actual-access']) {
    test('401 refresh gate for certified access state $access', () async {
      final tokens=InMemoryTokenStore()..accessToken=access;
      var calls=0;
      final auth=AuthInterceptor(tokenStore:tokens,refreshToken:() async {
        calls++;
        return const ResultFailure<String>(UnknownFailure('no refresh'));
      });
      final dio=Dio(BaseOptions(baseUrl:AppConfig.baseUrl))..httpClientAdapter=Unauthorized()..interceptors.add(auth);
      addTearDown(() { dio.close(force:true); auth.dispose(); });
      await expectLater(dio.get<dynamic>('/users/me').timeout(const Duration(seconds:5)),throwsA(isA<DioException>()));
      expect(calls,access == 'actual-access' ? 1 : 0);
    });
  }

  const user = UserModel(id: 'next', email: 'next@example.com');
  test('orphan eviction prevents an earlier refresh response from persisting either token', () async {
    final tokens = InMemoryTokenStore()..accessToken='old'..refreshToken='old-refresh';
    final local = AuthLocalDataSourceImpl(storageService: InMemoryKeyValueStore(), tokenStore: tokens);
    final remote = Remote();
    final response = Completer<AuthResponseModel>();
    final entered = Completer<void>();
    when(() => remote.refreshToken('old-refresh')).thenAnswer((_) { entered.complete(); return response.future; });
    final repo = AuthRepositoryImpl(localDataSource: local, remoteDataSource: remote);
    final refreshing = repo.refreshToken();
    await entered.future;
    expect((await repo.getCurrentUser()).isSuccess, true);
    expect(tokens.accessToken, isNull);
    expect(tokens.refreshToken, isNull);
    response.complete(const AuthResponseModel(user:user,token:'rotated',refreshToken:'rotated-refresh'));
    expect((await refreshing).isFailure, true);
    expect(tokens.accessToken, isNull);
    expect(tokens.refreshToken, isNull);
  });
  test('a stale error from cached-user read cannot erase successful newer sign-in', () async {
    final tokens = InMemoryTokenStore()..accessToken='old'..refreshToken='old-refresh';
    final prefs = InMemoryKeyValueStore();
    final local = DelayedLocal(storageService:prefs,tokenStore:tokens)..cachedRead=Completer<UserModel?>();
    final remote = Remote();
    when(() => remote.login(any(),any())).thenAnswer((_) async => const AuthResponseModel(user:user,token:'next',refreshToken:'next-refresh'));
    final repo = AuthRepositoryImpl(localDataSource:local,remoteDataSource:remote,sessionGeneration:SessionGeneration());
    final restoring = repo.getCurrentUser();
    await local.entered.future;
    expect((await repo.login('next@example.com','pw')).isSuccess,true);
    local.cachedRead!.completeError(StateError('late decode error'));
    expect((await restoring).isFailure,true);
    expect(tokens.accessToken,'next');
    expect(tokens.refreshToken,'next-refresh');
    local.cachedRead=null;
    expect((await repo.getCurrentUser()).dataOrNull?.id,'next');
  });
  test('a stale successful user read cannot restore the user after logout', () async {
    final tokens = InMemoryTokenStore()..accessToken='old'..refreshToken='old-refresh';
    final local = DelayedLocal(storageService:InMemoryKeyValueStore(),tokenStore:tokens)..cachedRead=Completer<UserModel?>();
    final remote=Remote();
    when(() => remote.logout(refreshToken:any(named:'refreshToken'),accessToken:any(named:'accessToken'))).thenAnswer((_) async {});
    final repo=AuthRepositoryImpl(localDataSource:local,remoteDataSource:remote);
    final restoring=repo.getCurrentUser();
    await local.entered.future;
    expect((await repo.logout()).isSuccess,true);
    local.cachedRead!.complete(user);
    expect((await restoring).isFailure,true);
    expect(tokens.accessToken,isNull);
    expect(tokens.refreshToken,isNull);
  });
}
