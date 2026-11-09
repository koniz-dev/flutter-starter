import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import '/Users/nguyenanhkiet/Playground/flutter-starter/test/helpers/in_memory_stores.dart';
class _Local extends AuthLocalDataSourceImpl {
 _Local(this.tokens, this.prefs, this.failAccess, this.failRefresh):super(storageService:prefs,tokenStore:tokens);
 final InMemoryTokenStore tokens; final InMemoryKeyValueStore prefs; final bool failAccess,failRefresh;
 @override Future<String?> getToken() async {if(failAccess) throw StateError('read access failed'); return super.getToken();}
 @override Future<String?> getRefreshToken() async {if(failRefresh) throw StateError('read refresh failed'); return super.getRefreshToken();}
}
class _Remote implements AuthRemoteDataSource {
 String? access,refresh;int calls=0;
 @override Future<void> logout({String? refreshToken,String? accessToken})async {calls++; access=accessToken;refresh=refreshToken;}
 @override Future<AuthResponseModel> login(String email,String password)=>throw UnimplementedError();
 @override Future<AuthResponseModel> register(String email,String password,String name)=>throw UnimplementedError();
 @override Future<AuthResponseModel> refreshToken(String token)=>throw UnimplementedError();
}
void main(){for(final a in [false,true]) {for(final r in [false,true]) {test('independent credential snapshots survive read errors access=$a refresh=$r',()async {
 final tokens=InMemoryTokenStore()..accessToken='old-access'..refreshToken='old-refresh';final prefs=InMemoryKeyValueStore();final remote=_Remote();
 final repo=AuthRepositoryImpl(remoteDataSource:remote,localDataSource:_Local(tokens,prefs,a,r));
 final result=await repo.logout();expect(result.isSuccess,isTrue);expect(remote.calls,1);expect(remote.access,a?null:'old-access');expect(remote.refresh,r?null:'old-refresh');expect(tokens.accessToken,isNull);expect(tokens.refreshToken,isNull);
});}}}
