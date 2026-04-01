{{#include_tests}}
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/datasources/{{feature_name}}_remote_datasource.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/repositories/{{feature_name}}_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements {{class_name}}RemoteDataSource {}

void main() {
  group('{{class_name}}RepositoryImpl', () {
    test('returns Success when datasource returns JSON', () async {
      final remote = _MockRemote();
      when(() => remote.fetchById('1')).thenAnswer((_) async => {'id': '1'});

      final repo = {{class_name}}RepositoryImpl(remoteDataSource: remote);
      final result = await repo.getById('1');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.id, '1');
    });

    test('returns Failure when datasource throws AppException', () async {
      final remote = _MockRemote();
      when(() => remote.fetchById('1')).thenThrow(
        const NetworkException('boom'),
      );

      final repo = {{class_name}}RepositoryImpl(remoteDataSource: remote);
      final result = await repo.getById('1');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isNotEmpty);
    });
  });
}
{{/include_tests}}

