# Scaffolds a Clean Architecture feature slice under lib/features/, plus its
# mirrored test under test/features/.
#
# Usage: pwsh scripts/dev/create_feature.ps1 <feature_name>   # snake_case
#
# Output is byte-identical to scripts/dev/create_feature.sh (LF endings, UTF-8
# without BOM); both are generated from the same verified source (issue #57).
param (
    [Parameter(Mandatory = $true)]
    [string]$FeatureName
)

$ErrorActionPreference = 'Stop'

if ($FeatureName -cnotmatch '^[a-z][a-z0-9]*(_[a-z0-9]+)*$') {
    Write-Error "Feature name must be snake_case, got '$FeatureName'"
    exit 1
}

$Root = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
Set-Location $Root

$BaseDir = "lib/features/$FeatureName"
$TestDir = "test/features/$FeatureName"

if ((Test-Path $BaseDir) -or (Test-Path $TestDir)) {
    Write-Error "$BaseDir or $TestDir already exists; refusing to overwrite"
    exit 1
}

# snake_case -> PascalCase (test_feature -> TestFeature). `Get-Culture`, not
# `Culture`: the latter is not a cmdlet and aborted this script on line 1.
$FeaturePascal = (Get-Culture).TextInfo.ToTitleCase($FeatureName.Replace('_', ' ')).Replace(' ', '')
# PascalCase -> camelCase (TestFeature -> testFeature)
$FeatureCamel = $FeaturePascal.Substring(0, 1).ToLower() + $FeaturePascal.Substring(1)

Write-Host "Creating feature: $FeatureName"

# LF endings and UTF-8 without a BOM, so the output matches create_feature.sh
# byte for byte no matter what core.autocrlf did to this file on checkout.
function Write-GeneratedFile {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $normalized = $Content -replace "`r`n", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $Path), $normalized, $utf8NoBom)
}

Write-GeneratedFile "lib/features/$($FeatureName)/domain/entities/$($FeatureName).dart" @"
import 'package:equatable/equatable.dart';

/// Domain entity for the ${FeaturePascal} feature.
final class ${FeaturePascal}Entity extends Equatable {
  /// Creates a [${FeaturePascal}Entity] with the given [id].
  const ${FeaturePascal}Entity({required this.id});

  /// Stable identifier of this ${FeaturePascal}.
  final String id;

  @override
  List<Object?> get props => [id];
}
"@

Write-GeneratedFile "lib/features/$($FeatureName)/domain/repositories/$($FeatureName)_repository.dart" @"
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FeatureName}/domain/entities/${FeatureName}.dart';

/// Data-layer contract for the ${FeaturePascal} feature.
// Scaffolds start with one method; drop the ignore once a second one lands.
// ignore: one_member_abstracts
abstract interface class ${FeaturePascal}Repository {
  /// Loads the [${FeaturePascal}Entity] identified by [id].
  Future<Result<${FeaturePascal}Entity>> getById(String id);
}
"@

Write-GeneratedFile "lib/features/$($FeatureName)/domain/usecases/get_$($FeatureName)_by_id_usecase.dart" @"
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FeatureName}/domain/entities/${FeatureName}.dart';
import 'package:flutter_starter/features/${FeatureName}/domain/repositories/${FeatureName}_repository.dart';

/// Loads a single [${FeaturePascal}Entity] by id.
final class Get${FeaturePascal}ByIdUseCase {
  /// Creates a [Get${FeaturePascal}ByIdUseCase].
  const Get${FeaturePascal}ByIdUseCase(this._repository);

  final ${FeaturePascal}Repository _repository;

  /// Runs the use case for [id].
  Future<Result<${FeaturePascal}Entity>> call(String id) => _repository.getById(id);
}
"@

Write-GeneratedFile "lib/features/$($FeatureName)/data/datasources/$($FeatureName)_remote_datasource.dart" @"
/// Remote source of raw ${FeaturePascal} data.
///
/// Implement this against ``ApiClient`` (see lib/core/network/), then
/// override the provider declared in the feature's ``di/`` directory.
// Scaffolds start with one method; drop the ignore once a second one lands.
// ignore: one_member_abstracts
abstract interface class ${FeaturePascal}RemoteDataSource {
  /// Fetches the raw JSON for [id].
  Future<Map<String, dynamic>> fetchById(String id);
}
"@

Write-GeneratedFile "lib/features/$($FeatureName)/data/models/$($FeatureName)_model.dart" @"
import 'package:flutter_starter/features/${FeatureName}/domain/entities/${FeatureName}.dart';

/// Data-layer representation of a ${FeaturePascal}.
final class ${FeaturePascal}Model {
  /// Creates a [${FeaturePascal}Model] with the given [id].
  const ${FeaturePascal}Model({required this.id});

  /// Builds a [${FeaturePascal}Model] from decoded [json].
  factory ${FeaturePascal}Model.fromJson(Map<String, dynamic> json) {
    return ${FeaturePascal}Model(id: (json['id'] ?? '').toString());
  }

  /// Stable identifier of this ${FeaturePascal}.
  final String id;

  /// Converts this model into its domain entity.
  ${FeaturePascal}Entity toEntity() => ${FeaturePascal}Entity(id: id);
}
"@

Write-GeneratedFile "lib/features/$($FeatureName)/data/repositories/$($FeatureName)_repository_impl.dart" @"
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FeatureName}/data/datasources/${FeatureName}_remote_datasource.dart';
import 'package:flutter_starter/features/${FeatureName}/data/models/${FeatureName}_model.dart';
import 'package:flutter_starter/features/${FeatureName}/domain/entities/${FeatureName}.dart';
import 'package:flutter_starter/features/${FeatureName}/domain/repositories/${FeatureName}_repository.dart';

/// Default [${FeaturePascal}Repository] implementation.
final class ${FeaturePascal}RepositoryImpl implements ${FeaturePascal}Repository {
  /// Creates a [${FeaturePascal}RepositoryImpl].
  const ${FeaturePascal}RepositoryImpl({required this.remoteDataSource});

  /// Source of raw ${FeaturePascal} data.
  final ${FeaturePascal}RemoteDataSource remoteDataSource;

  @override
  Future<Result<${FeaturePascal}Entity>> getById(String id) async {
    try {
      final json = await remoteDataSource.fetchById(id);
      return Success(${FeaturePascal}Model.fromJson(json).toEntity());
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }
}
"@

Write-GeneratedFile "lib/features/$($FeatureName)/di/$($FeatureName)_providers.dart" @"
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/${FeatureName}/data/datasources/${FeatureName}_remote_datasource.dart';
import 'package:flutter_starter/features/${FeatureName}/data/repositories/${FeatureName}_repository_impl.dart';
import 'package:flutter_starter/features/${FeatureName}/domain/repositories/${FeatureName}_repository.dart';
import 'package:flutter_starter/features/${FeatureName}/domain/usecases/get_${FeatureName}_by_id_usecase.dart';

/// Remote data source for the ${FeaturePascal} feature.
///
/// Deliberately unimplemented: override this provider with a real
/// implementation in main.dart or in a test's ``ProviderScope``.
final ${FeatureCamel}RemoteDataSourceProvider = Provider<${FeaturePascal}RemoteDataSource>((
  ref,
) {
  throw UnimplementedError(
    'Override this provider with a real '
    '${FeaturePascal}RemoteDataSource implementation.',
  );
});

/// Repository for the ${FeaturePascal} feature.
final ${FeatureCamel}RepositoryProvider = Provider<${FeaturePascal}Repository>((ref) {
  return ${FeaturePascal}RepositoryImpl(
    remoteDataSource: ref.watch(${FeatureCamel}RemoteDataSourceProvider),
  );
});

/// Use case that loads one ${FeaturePascal} by id.
final get${FeaturePascal}ByIdUseCaseProvider = Provider<Get${FeaturePascal}ByIdUseCase>((ref) {
  return Get${FeaturePascal}ByIdUseCase(ref.watch(${FeatureCamel}RepositoryProvider));
});
"@

Write-GeneratedFile "lib/features/$($FeatureName)/presentation/providers/$($FeatureName)_provider.dart" @"
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FeatureName}/di/${FeatureName}_providers.dart';
import 'package:flutter_starter/features/${FeatureName}/domain/entities/${FeatureName}.dart';

/// UI state for the ${FeaturePascal} screen.
final ${FeatureCamel}StateProvider =
    NotifierProvider<${FeaturePascal}Notifier, AsyncValue<${FeaturePascal}Entity?>>(
      ${FeaturePascal}Notifier.new,
    );

/// Loads a ${FeaturePascal} for the screen.
final class ${FeaturePascal}Notifier extends Notifier<AsyncValue<${FeaturePascal}Entity?>> {
  @override
  AsyncValue<${FeaturePascal}Entity?> build() => const AsyncData(null);

  /// Loads the ${FeaturePascal} identified by [id].
  Future<void> load(String id) async {
    state = const AsyncLoading();
    final result = await ref.read(get${FeaturePascal}ByIdUseCaseProvider)(id);
    state = result.when(
      success: AsyncData.new,
      failureCallback: (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}
"@

Write-GeneratedFile "lib/features/$($FeatureName)/presentation/screens/$($FeatureName)_screen.dart" @"
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/${FeatureName}/presentation/providers/${FeatureName}_provider.dart';

/// Screen showing a single ${FeaturePascal}.
class ${FeaturePascal}Screen extends ConsumerWidget {
  /// Creates a [${FeaturePascal}Screen] for [id].
  const ${FeaturePascal}Screen({required this.id, super.key});

  /// Identifier of the ${FeaturePascal} to display.
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(${FeatureCamel}StateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('${FeaturePascal}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          data: (entity) => Text(entity?.id ?? 'Not loaded'),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Error: `$error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(${FeatureCamel}StateProvider.notifier).load(id),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
"@

Write-GeneratedFile "test/features/$($FeatureName)/$($FeatureName)_repository_impl_test.dart" @"
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/${FeatureName}/data/datasources/${FeatureName}_remote_datasource.dart';
import 'package:flutter_starter/features/${FeatureName}/data/repositories/${FeatureName}_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Mock${FeaturePascal}RemoteDataSource extends Mock
    implements ${FeaturePascal}RemoteDataSource {}

void main() {
  group('${FeaturePascal}RepositoryImpl', () {
    test('returns Success when the data source returns JSON', () async {
      final remote = _Mock${FeaturePascal}RemoteDataSource();
      when(() => remote.fetchById('1')).thenAnswer((_) async => {'id': '1'});

      final repository = ${FeaturePascal}RepositoryImpl(remoteDataSource: remote);
      final result = await repository.getById('1');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.id, '1');
    });

    test('returns a Failure when the data source throws', () async {
      final remote = _Mock${FeaturePascal}RemoteDataSource();
      when(() => remote.fetchById('1')).thenThrow(
        const NetworkException('boom'),
      );

      final repository = ${FeaturePascal}RepositoryImpl(remoteDataSource: remote);
      final result = await repository.getById('1');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, 'boom');
    });
  });
}
"@


# The formatter, not this script, decides where long generated lines wrap, so
# the result satisfies `dart format --set-exit-if-changed` for any name length.
if (Get-Command dart -ErrorAction SilentlyContinue) {
    dart format $BaseDir $TestDir | Out-Null
} else {
    Write-Warning "dart not on PATH; run 'dart format $BaseDir $TestDir'"
}

Write-Host "Feature $FeatureName created:"
Write-Host "  $BaseDir"
Write-Host "  $TestDir"
Write-Host "Next: flutter analyze && flutter test $TestDir"
