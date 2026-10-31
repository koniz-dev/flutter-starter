// The ordering queue was a field of each SecureTokenStore. AuthInterceptor
// builds its own store from `secureStorageService:`, so its refresh write and
// the repository store's logout clear ran on two queues, and on web - where a
// write lands after an async encryption but a delete at once - the clear could
// land first and leave a live token on a signed-out browser. The queue now
// belongs to the SecureStorageService, shared by every store over it.

import 'dart:async';

import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements SecureStorageService {}

/// Writes land after an asynchronous step (web encryption), deletes at once.
_MockSecureStorage _webLike(Map<String, String> values) {
  final storage = _MockSecureStorage();
  when(() => storage.getStringOrThrow(any())).thenAnswer(
    (i) async => values[i.positionalArguments[0] as String],
  );
  when(() => storage.setString(any(), any())).thenAnswer((i) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    values[i.positionalArguments[0] as String] =
        i.positionalArguments[1] as String;
    return true;
  });
  when(() => storage.remove(any())).thenAnswer((i) async {
    values.remove(i.positionalArguments[0] as String);
    return true;
  });
  return storage;
}

void main() {
  test('a clear through one store lands after a write pending on another '
      'store over the same service', () async {
    final values = <String, String>{};
    final service = _webLike(values);
    // As the legacy path builds them: the interceptor wraps the service in
    // its own store, the repository has another.
    final interceptorStore = SecureTokenStore(service);
    final repositoryStore = SecureTokenStore(service);

    final write = interceptorStore.setAccessToken('refreshed');
    final clear = repositoryStore.clearAllTokens();
    await (write, clear).wait;

    expect(values[AppConstants.tokenKey], isNull);
    expect(await repositoryStore.getAccessToken(), isNull);
    expect(await interceptorStore.getAccessToken(), isNull);
  });

  test('stores over different services do not wait for each other', () async {
    final slow = Completer<bool>();
    final blocked = _MockSecureStorage();
    when(() => blocked.setString(any(), any())).thenAnswer((_) => slow.future);
    final other = _webLike({});

    unawaited(SecureTokenStore(blocked).setAccessToken('stuck'));
    await expectLater(
      SecureTokenStore(other).getAccessToken(),
      completion(isNull),
    );
    slow.complete(true);
  });
}
