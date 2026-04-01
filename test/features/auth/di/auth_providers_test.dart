import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth_providers (smoke)', () {
    test('should build core auth providers with default DI', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(networkClientProvider), isNotNull);
      expect(
        container.read(authLocalDataSourceProvider),
        isA<AuthLocalDataSource>(),
      );
      expect(
        container.read(authRemoteDataSourceProvider),
        isA<AuthRemoteDataSource>(),
      );
      expect(container.read(authRepositoryProvider), isA<AuthRepository>());
    });
  });
}
