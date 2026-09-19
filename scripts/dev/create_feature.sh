#!/usr/bin/env bash
# Scaffolds a Clean Architecture feature slice under lib/features/, plus its
# mirrored test under test/features/.
#
# Usage: ./scripts/dev/create_feature.sh <feature_name>   # snake_case
#
# Output is kept byte-identical to scripts/dev/create_feature.ps1 and to
# `mason make feature_clean`: all three are generated from the same verified
# source (issue #57). Whatever changes here changes there.
set -euo pipefail

if [ $# -ne 1 ] || [ -z "${1:-}" ]; then
    echo "Usage: ./scripts/dev/create_feature.sh <feature_name>" >&2
    exit 1
fi

FEATURE_NAME="$1"

if ! [[ "$FEATURE_NAME" =~ ^[a-z][a-z0-9]*(_[a-z0-9]+)*$ ]]; then
    echo "Error: feature name must be snake_case, got '$FEATURE_NAME'" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

BASE_DIR="lib/features/$FEATURE_NAME"
TEST_DIR="test/features/$FEATURE_NAME"

if [ -e "$BASE_DIR" ] || [ -e "$TEST_DIR" ]; then
    echo "Error: $BASE_DIR or $TEST_DIR already exists; refusing to overwrite" >&2
    exit 1
fi

# snake_case -> PascalCase (test_feature -> TestFeature)
FEATURE_PASCAL=$(echo "$FEATURE_NAME" | awk -F_ '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}} 1' OFS="")
# PascalCase -> camelCase (TestFeature -> testFeature)
FEATURE_CAMEL="$(tr '[:upper:]' '[:lower:]' <<< "${FEATURE_PASCAL:0:1}")${FEATURE_PASCAL:1}"

echo "Creating feature: $FEATURE_NAME"

mkdir -p \
    "$BASE_DIR/data/datasources" \
    "$BASE_DIR/data/models" \
    "$BASE_DIR/data/repositories" \
    "$BASE_DIR/di" \
    "$BASE_DIR/domain/entities" \
    "$BASE_DIR/domain/repositories" \
    "$BASE_DIR/domain/usecases" \
    "$BASE_DIR/presentation/providers" \
    "$BASE_DIR/presentation/screens" \
    "$TEST_DIR"

cat > "$BASE_DIR/domain/entities/${FEATURE_NAME}.dart" <<EOF
import 'package:equatable/equatable.dart';

/// Domain entity for the ${FEATURE_PASCAL} feature.
final class ${FEATURE_PASCAL}Entity extends Equatable {
  /// Creates a [${FEATURE_PASCAL}Entity] with the given [id].
  const ${FEATURE_PASCAL}Entity({required this.id});

  /// Stable identifier of this ${FEATURE_PASCAL}.
  final String id;

  @override
  List<Object?> get props => [id];
}
EOF

cat > "$BASE_DIR/domain/repositories/${FEATURE_NAME}_repository.dart" <<EOF
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/domain/entities/${FEATURE_NAME}.dart';

/// Data-layer contract for the ${FEATURE_PASCAL} feature.
// Scaffolds start with one method; drop the ignore once a second one lands.
// ignore: one_member_abstracts
abstract interface class ${FEATURE_PASCAL}Repository {
  /// Loads the [${FEATURE_PASCAL}Entity] identified by [id].
  Future<Result<${FEATURE_PASCAL}Entity>> getById(String id);
}
EOF

cat > "$BASE_DIR/domain/usecases/get_${FEATURE_NAME}_by_id_usecase.dart" <<EOF
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/domain/entities/${FEATURE_NAME}.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/domain/repositories/${FEATURE_NAME}_repository.dart';

/// Loads a single [${FEATURE_PASCAL}Entity] by id.
final class Get${FEATURE_PASCAL}ByIdUseCase {
  /// Creates a [Get${FEATURE_PASCAL}ByIdUseCase].
  const Get${FEATURE_PASCAL}ByIdUseCase(this._repository);

  final ${FEATURE_PASCAL}Repository _repository;

  /// Runs the use case for [id].
  Future<Result<${FEATURE_PASCAL}Entity>> call(String id) => _repository.getById(id);
}
EOF

cat > "$BASE_DIR/data/datasources/${FEATURE_NAME}_remote_datasource.dart" <<EOF
/// Remote source of raw ${FEATURE_PASCAL} data.
///
/// Implement this against \`ApiClient\` (see lib/core/network/), then
/// override the provider declared in the feature's \`di/\` directory.
// Scaffolds start with one method; drop the ignore once a second one lands.
// ignore: one_member_abstracts
abstract interface class ${FEATURE_PASCAL}RemoteDataSource {
  /// Fetches the raw JSON for [id].
  Future<Map<String, dynamic>> fetchById(String id);
}
EOF

cat > "$BASE_DIR/data/models/${FEATURE_NAME}_model.dart" <<EOF
import 'package:flutter_starter/features/${FEATURE_NAME}/domain/entities/${FEATURE_NAME}.dart';

/// Data-layer representation of a ${FEATURE_PASCAL}.
final class ${FEATURE_PASCAL}Model {
  /// Creates a [${FEATURE_PASCAL}Model] with the given [id].
  const ${FEATURE_PASCAL}Model({required this.id});

  /// Builds a [${FEATURE_PASCAL}Model] from decoded [json].
  factory ${FEATURE_PASCAL}Model.fromJson(Map<String, dynamic> json) {
    return ${FEATURE_PASCAL}Model(id: (json['id'] ?? '').toString());
  }

  /// Stable identifier of this ${FEATURE_PASCAL}.
  final String id;

  /// Converts this model into its domain entity.
  ${FEATURE_PASCAL}Entity toEntity() => ${FEATURE_PASCAL}Entity(id: id);
}
EOF

cat > "$BASE_DIR/data/repositories/${FEATURE_NAME}_repository_impl.dart" <<EOF
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/data/datasources/${FEATURE_NAME}_remote_datasource.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/data/models/${FEATURE_NAME}_model.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/domain/entities/${FEATURE_NAME}.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/domain/repositories/${FEATURE_NAME}_repository.dart';

/// Default [${FEATURE_PASCAL}Repository] implementation.
final class ${FEATURE_PASCAL}RepositoryImpl implements ${FEATURE_PASCAL}Repository {
  /// Creates a [${FEATURE_PASCAL}RepositoryImpl].
  const ${FEATURE_PASCAL}RepositoryImpl({required this.remoteDataSource});

  /// Source of raw ${FEATURE_PASCAL} data.
  final ${FEATURE_PASCAL}RemoteDataSource remoteDataSource;

  @override
  Future<Result<${FEATURE_PASCAL}Entity>> getById(String id) async {
    try {
      final json = await remoteDataSource.fetchById(id);
      return Success(${FEATURE_PASCAL}Model.fromJson(json).toEntity());
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }
}
EOF

cat > "$BASE_DIR/di/${FEATURE_NAME}_providers.dart" <<EOF
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/data/datasources/${FEATURE_NAME}_remote_datasource.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/data/repositories/${FEATURE_NAME}_repository_impl.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/domain/repositories/${FEATURE_NAME}_repository.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/domain/usecases/get_${FEATURE_NAME}_by_id_usecase.dart';

/// Remote data source for the ${FEATURE_PASCAL} feature.
///
/// Deliberately unimplemented: override this provider with a real
/// implementation in main.dart or in a test's \`ProviderScope\`.
final ${FEATURE_CAMEL}RemoteDataSourceProvider = Provider<${FEATURE_PASCAL}RemoteDataSource>((
  ref,
) {
  throw UnimplementedError(
    'Override this provider with a real '
    '${FEATURE_PASCAL}RemoteDataSource implementation.',
  );
});

/// Repository for the ${FEATURE_PASCAL} feature.
final ${FEATURE_CAMEL}RepositoryProvider = Provider<${FEATURE_PASCAL}Repository>((ref) {
  return ${FEATURE_PASCAL}RepositoryImpl(
    remoteDataSource: ref.watch(${FEATURE_CAMEL}RemoteDataSourceProvider),
  );
});

/// Use case that loads one ${FEATURE_PASCAL} by id.
final get${FEATURE_PASCAL}ByIdUseCaseProvider = Provider<Get${FEATURE_PASCAL}ByIdUseCase>((ref) {
  return Get${FEATURE_PASCAL}ByIdUseCase(ref.watch(${FEATURE_CAMEL}RepositoryProvider));
});
EOF

cat > "$BASE_DIR/presentation/providers/${FEATURE_NAME}_provider.dart" <<EOF
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/di/${FEATURE_NAME}_providers.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/domain/entities/${FEATURE_NAME}.dart';

/// UI state for the ${FEATURE_PASCAL} screen.
final ${FEATURE_CAMEL}StateProvider =
    NotifierProvider<${FEATURE_PASCAL}Notifier, AsyncValue<${FEATURE_PASCAL}Entity?>>(
      ${FEATURE_PASCAL}Notifier.new,
    );

/// Loads a ${FEATURE_PASCAL} for the screen.
final class ${FEATURE_PASCAL}Notifier extends Notifier<AsyncValue<${FEATURE_PASCAL}Entity?>> {
  @override
  AsyncValue<${FEATURE_PASCAL}Entity?> build() => const AsyncData(null);

  /// Loads the ${FEATURE_PASCAL} identified by [id].
  Future<void> load(String id) async {
    state = const AsyncLoading();
    final result = await ref.read(get${FEATURE_PASCAL}ByIdUseCaseProvider)(id);
    state = result.when(
      success: AsyncData.new,
      failureCallback: (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}
EOF

cat > "$BASE_DIR/presentation/screens/${FEATURE_NAME}_screen.dart" <<EOF
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/presentation/providers/${FEATURE_NAME}_provider.dart';

/// Screen showing a single ${FEATURE_PASCAL}.
class ${FEATURE_PASCAL}Screen extends ConsumerWidget {
  /// Creates a [${FEATURE_PASCAL}Screen] for [id].
  const ${FEATURE_PASCAL}Screen({required this.id, super.key});

  /// Identifier of the ${FEATURE_PASCAL} to display.
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(${FEATURE_CAMEL}StateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('${FEATURE_PASCAL}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          data: (entity) => Text(entity?.id ?? 'Not loaded'),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Error: \$error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(${FEATURE_CAMEL}StateProvider.notifier).load(id),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
EOF

cat > "$TEST_DIR/${FEATURE_NAME}_repository_impl_test.dart" <<EOF
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/data/datasources/${FEATURE_NAME}_remote_datasource.dart';
import 'package:flutter_starter/features/${FEATURE_NAME}/data/repositories/${FEATURE_NAME}_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Mock${FEATURE_PASCAL}RemoteDataSource extends Mock
    implements ${FEATURE_PASCAL}RemoteDataSource {}

void main() {
  group('${FEATURE_PASCAL}RepositoryImpl', () {
    test('returns Success when the data source returns JSON', () async {
      final remote = _Mock${FEATURE_PASCAL}RemoteDataSource();
      when(() => remote.fetchById('1')).thenAnswer((_) async => {'id': '1'});

      final repository = ${FEATURE_PASCAL}RepositoryImpl(remoteDataSource: remote);
      final result = await repository.getById('1');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.id, '1');
    });

    test('returns a Failure when the data source throws', () async {
      final remote = _Mock${FEATURE_PASCAL}RemoteDataSource();
      when(() => remote.fetchById('1')).thenThrow(
        const NetworkException('boom'),
      );

      final repository = ${FEATURE_PASCAL}RepositoryImpl(remoteDataSource: remote);
      final result = await repository.getById('1');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, 'boom');
    });
  });
}
EOF


# The formatter, not this script, decides where long generated lines wrap, so
# the result satisfies `dart format --set-exit-if-changed` for any name length.
if command -v dart >/dev/null 2>&1; then
    dart format "$BASE_DIR" "$TEST_DIR" > /dev/null
else
    echo "Warning: dart not on PATH; run 'dart format $BASE_DIR $TEST_DIR'" >&2
fi

echo "Feature $FEATURE_NAME created:"
echo "  $BASE_DIR"
echo "  $TEST_DIR"
echo "Next: flutter analyze && flutter test $TEST_DIR"
