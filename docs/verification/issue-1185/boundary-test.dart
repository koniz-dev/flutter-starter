import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '/Users/nguyenanhkiet/Playground/flutter-starter/test/helpers/in_memory_stores.dart';

class _RotatingServer implements AuthRemoteDataSource {
  final started = Completer<void>();
  final release = Completer<void>();
  final calls = <String>[];
  String validToken = 'R1';
  bool fail = false;

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    calls.add(refreshToken);
    if (!started.isCompleted) started.complete();
    if (refreshToken != validToken) {
      throw const AuthException('Refresh token reuse');
    }
    final next = 'R${calls.length + 1}';
    final shouldFail = fail;
    if (!shouldFail) validToken = next;
    await release.future;
    if (shouldFail) throw const ServerException('temporarily unavailable');
    return AuthResponseModel(
      user: const UserModel(id: 'a', email: 'a@example.com'),
      token: 'access-$next',
      refreshToken: next,
    );
  }

  @override
  Future<void> logout({String? refreshToken, String? accessToken}) async {}

  @override
  Future<AuthResponseModel> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => throw UnimplementedError();
}

class _Reply implements HttpClientAdapter {
  _Reply(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'ok': status == 200}),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _SeparateServer extends _RotatingServer {
  final gates = <Completer<void>>[];
  @override
  Future<AuthResponseModel> refreshToken(String token) async {
    calls.add(token);
    final id = calls.length;
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return AuthResponseModel(user: const UserModel(id: 'u', email: 'u@x.test'), token: 'A$id', refreshToken: 'R$id');
  }
}
class _HeldWriteLocal extends AuthLocalDataSourceImpl {
  _HeldWriteLocal({required super.storageService,required super.tokenStore});
  final entered = Completer<void>(); final releaseWrite = Completer<void>();
  @override Future<void> cacheToken(String token) async {
    if (!entered.isCompleted) entered.complete();
    await releaseWrite.future;
    await super.cacheToken(token);
  }
}
void main() {
  late InMemoryTokenStore tokens;
  late InMemoryKeyValueStore prefs;
  late _RotatingServer server;
  late SessionGeneration generation;
  late AuthRepositoryImpl repository;

  setUp(() {
    tokens = InMemoryTokenStore()
      ..accessToken = 'access-R1'
      ..refreshToken = 'R1';
    prefs = InMemoryKeyValueStore();
    server = _RotatingServer();
    generation = SessionGeneration();
    repository = AuthRepositoryImpl(
      remoteDataSource: server,
      localDataSource: AuthLocalDataSourceImpl(
        storageService: prefs,
        tokenStore: tokens,
      ),
      sessionGeneration: generation,
    );
  });

  test('concurrent repository refreshes share one rotating response', () async {
    final first = repository.refreshToken();
    await server.started.future;
    final second = repository.refreshToken();
    await pumpEventQueue();
    server.release.complete();
    final results = await Future.wait([first, second]);

    expect(server.calls, ['R1']);
    expect(results.every((r) => r.isSuccess), isTrue);
    expect(identical(results[0], results[1]), isTrue);
    expect(tokens.refreshToken, server.validToken);
    expect(tokens.accessToken, 'access-${server.validToken}');
  });

  test('notifier shares an interceptor refresh already in flight', () async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(authNotifierProvider, (_, _) {});
    addTearDown(subscription.close);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = _Reply(401)
      ..interceptors.add(
        AuthInterceptor(
          tokenStore: tokens,
          keyValueStore: prefs,
          refreshToken: repository.refreshToken,
          sessionGeneration: generation,
          retryDioFactory: () => Dio()..httpClientAdapter = _Reply(200),
        ),
      );
    addTearDown(() => dio.close(force: true));
    final request = dio
        .get<dynamic>('/profile')
        .then<Object?>(
          (response) => response.statusCode,
          onError: (Object error) => error,
        );
    await server.started.future;
    final manual = container.read(authNotifierProvider.notifier).refreshToken();
    await pumpEventQueue();
    server.release.complete();
    await manual;

    expect(await request, 200);
    expect(server.calls, ['R1']);
    expect(tokens.refreshToken, server.validToken);
    expect(tokens.accessToken, 'access-${server.validToken}');
  });

  test('a failed shared refresh can be retried', () async {
    server.fail = true;
    final first = repository.refreshToken();
    await server.started.future;
    final second = repository.refreshToken();
    await pumpEventQueue();
    server.release.complete();
    final results = await Future.wait([first, second]);
    expect(server.calls, ['R1']);
    expect(results.every((r) => r.isFailure), isTrue);
    expect(identical(results[0], results[1]), isTrue);
    server.fail = false;

    expect((await repository.refreshToken()).isSuccess, isTrue);
    expect(server.calls, ['R1', 'R1']);
    expect(tokens.refreshToken, server.validToken);
  });

  test('a new session never joins an older session refresh', () async {
    final old = repository.refreshToken();
    await server.started.future;
    generation.invalidate();
    tokens.refreshToken = server.validToken = 'fresh-session';
    final current = repository.refreshToken();
    await pumpEventQueue();
    server.release.complete();
    expect((await old).isFailure, isTrue);
    expect((await current).isSuccess, isTrue);
    expect(server.calls, ['R1', 'fresh-session']);
    expect(tokens.refreshToken, server.validToken);
  });
  test('independent: old generation completion cannot remove newer flight', () async {
    final remote = _SeparateServer();
    final repo = AuthRepositoryImpl(remoteDataSource: remote, localDataSource: AuthLocalDataSourceImpl(storageService:prefs, tokenStore:tokens), sessionGeneration:generation);
    final old = repo.refreshToken();
    await pumpEventQueue(); expect(remote.calls.length,1);
    generation.invalidate(); tokens.refreshToken='different-user';
    final newer = repo.refreshToken();
    await pumpEventQueue(); expect(remote.calls.length,2);
    remote.gates[0].complete(); expect((await old).isFailure,isTrue);
    final joined = repo.refreshToken();
    await pumpEventQueue(); expect(remote.calls.length,2);
    expect(identical(newer,joined),isTrue);
    remote.gates[1].complete();
    final results=await Future.wait([newer,joined]);
    expect(results.every((r)=>r.isSuccess),isTrue);
    expect(identical(results[0],results[1]),isTrue);
    expect(tokens.refreshToken,'R2');
  });
  test('independent: persistence remains part of shared operation', () async {
    final local=_HeldWriteLocal(storageService:prefs,tokenStore:tokens);
    final repo=AuthRepositoryImpl(remoteDataSource:server,localDataSource:local,sessionGeneration:generation);
    server.release.complete();
    final first=repo.refreshToken(); await local.entered.future;
    final second=repo.refreshToken(); await pumpEventQueue();
    expect(server.calls,['R1']); expect(identical(first,second),isTrue);
    local.releaseWrite.complete();
    final results=await Future.wait([first,second]);
    expect(results.every((r)=>r.isSuccess),isTrue);
    expect(tokens.refreshToken,server.validToken);
  });
  test('independent: interceptor joins earlier notifier refresh', () async {
    final container=ProviderContainer(overrides:[authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    final sub=container.listen(authNotifierProvider,(_,_){});addTearDown(sub.close);
    final manual=container.read(authNotifierProvider.notifier).refreshToken(); await server.started.future;
    final dio=Dio(BaseOptions(baseUrl:'https://example.invalid'))..httpClientAdapter=_Reply(401)..interceptors.add(AuthInterceptor(tokenStore:tokens,keyValueStore:prefs,refreshToken:repository.refreshToken,sessionGeneration:generation,retryDioFactory:()=>Dio()..httpClientAdapter=_Reply(200)));
    addTearDown(()=>dio.close(force:true));
    final request=dio.get<dynamic>('/profile').then<Object?>((r)=>r.statusCode,onError:(Object e)=>e);
    await pumpEventQueue();expect(server.calls,['R1']);server.release.complete();
    await manual;expect(await request,200);expect(server.calls,['R1']);expect(tokens.refreshToken,server.validToken);
  });

  test('boundary: repository settles before delayed interceptor callback returns', () async {
    final returned=Completer<void>();final returnGate=Completer<void>();
    final dio=Dio(BaseOptions(baseUrl:'https://example.invalid'))..httpClientAdapter=_Reply(401)..interceptors.add(AuthInterceptor(tokenStore:tokens,keyValueStore:prefs,sessionGeneration:generation,refreshToken:()async {final result=await repository.refreshToken();returned.complete();await returnGate.future;return result;},retryDioFactory:()=>Dio()..httpClientAdapter=_Reply(200)));
    addTearDown(()=>dio.close(force:true));
    final request=dio.get<dynamic>('/profile').then<Object?>((r)=>r.statusCode,onError:(Object e)=>e);
    await server.started.future;server.release.complete();await returned.future;
    expect((await repository.refreshToken()).isSuccess,isTrue);
    final before=tokens.accessToken;
    returnGate.complete();expect(await request,200);
    print('boundary before interceptor returns: $before; finalaccess=${tokens.accessToken}; finalrefresh=${tokens.refreshToken}; servervalid=${server.validToken}');
    expect(tokens.accessToken,'access-${server.validToken}');
  });

}
