param (
    [Parameter(Mandatory=$true)]
    [string]$FeatureName
)

# Convert feature_name to PascalCase (e.g., test_feature -> TestFeature)
$FeaturePascal = (Culture).TextInfo.ToTitleCase($FeatureName.Replace('_', ' ')).Replace(' ', '')

# Convert to camelCase (e.g., TestFeature -> testFeature)
$FeatureCamel = $FeaturePascal.Substring(0,1).ToLower() + $FeaturePascal.Substring(1)

$BaseDir = "lib\features\$FeatureName"

Write-Host "Creating feature: $FeatureName"

New-Item -ItemType Directory -Force -Path "$BaseDir\data\datasources" | Out-Null
New-Item -ItemType Directory -Force -Path "$BaseDir\data\models" | Out-Null
New-Item -ItemType Directory -Force -Path "$BaseDir\data\repositories" | Out-Null
New-Item -ItemType Directory -Force -Path "$BaseDir\di" | Out-Null
New-Item -ItemType Directory -Force -Path "$BaseDir\domain\entities" | Out-Null
New-Item -ItemType Directory -Force -Path "$BaseDir\domain\repositories" | Out-Null
New-Item -ItemType Directory -Force -Path "$BaseDir\domain\usecases" | Out-Null
New-Item -ItemType Directory -Force -Path "$BaseDir\presentation\providers" | Out-Null
New-Item -ItemType Directory -Force -Path "$BaseDir\presentation\screens" | Out-Null
New-Item -ItemType Directory -Force -Path "$BaseDir\presentation\widgets" | Out-Null

# Create Entity
@"
class ${FeaturePascal} {
  const ${FeaturePascal}();
}
"@ | Out-File -FilePath "$BaseDir\domain\entities\${FeatureName}.dart" -Encoding UTF8

# Create Repository Interface
@"
import '../entities/${FeatureName}.dart';

abstract class ${FeaturePascal}Repository {
  Future<${FeaturePascal}> get${FeaturePascal}();
}
"@ | Out-File -FilePath "$BaseDir\domain\repositories\${FeatureName}_repository.dart" -Encoding UTF8

# Create UseCase
@"
import '../entities/${FeatureName}.dart';
import '../repositories/${FeatureName}_repository.dart';

class Get${FeaturePascal}UseCase {
  final ${FeaturePascal}Repository repository;

  Get${FeaturePascal}UseCase(this.repository);

  Future<${FeaturePascal}> call() {
    return repository.get${FeaturePascal}();
  }
}
"@ | Out-File -FilePath "$BaseDir\domain\usecases\get_${FeatureName}_usecase.dart" -Encoding UTF8

# Create Model
@"
import '../../domain/entities/${FeatureName}.dart';

class ${FeaturePascal}Model extends ${FeaturePascal} {
  const ${FeaturePascal}Model();

  factory ${FeaturePascal}Model.fromJson(Map<String, dynamic> json) {
    return const ${FeaturePascal}Model();
  }

  Map<String, dynamic> toJson() {
    return {};
  }
}
"@ | Out-File -FilePath "$BaseDir\data\models\${FeatureName}_model.dart" -Encoding UTF8

# Create Local Datasource
@"
import '../models/${FeatureName}_model.dart';

abstract class ${FeaturePascal}LocalDataSource {
  Future<${FeaturePascal}Model> get${FeaturePascal}();
}

class ${FeaturePascal}LocalDataSourceImpl implements ${FeaturePascal}LocalDataSource {
  @override
  Future<${FeaturePascal}Model> get${FeaturePascal}() async {
    // TODO: implement
    throw UnimplementedError();
  }
}
"@ | Out-File -FilePath "$BaseDir\data\datasources\${FeatureName}_local_datasource.dart" -Encoding UTF8

# Create Repository Impl
@"
import '../../domain/entities/${FeatureName}.dart';
import '../../domain/repositories/${FeatureName}_repository.dart';
import '../datasources/${FeatureName}_local_datasource.dart';

class ${FeaturePascal}RepositoryImpl implements ${FeaturePascal}Repository {
  final ${FeaturePascal}LocalDataSource localDataSource;

  ${FeaturePascal}RepositoryImpl({required this.localDataSource});

  @override
  Future<${FeaturePascal}> get${FeaturePascal}() async {
    return await localDataSource.get${FeaturePascal}();
  }
}
"@ | Out-File -FilePath "$BaseDir\data\repositories\${FeatureName}_repository_impl.dart" -Encoding UTF8

# Create Providers
@"
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/${FeatureName}_local_datasource.dart';
import '../data/repositories/${FeatureName}_repository_impl.dart';
import '../domain/repositories/${FeatureName}_repository.dart';
import '../domain/usecases/get_${FeatureName}_usecase.dart';

final ${FeatureCamel}LocalDataSourceProvider = Provider<${FeaturePascal}LocalDataSource>((ref) {
  return ${FeaturePascal}LocalDataSourceImpl();
});

final ${FeatureCamel}RepositoryProvider = Provider<${FeaturePascal}Repository>((ref) {
  return ${FeaturePascal}RepositoryImpl(
    localDataSource: ref.watch(${FeatureCamel}LocalDataSourceProvider),
  );
});

final get${FeaturePascal}UseCaseProvider = Provider<Get${FeaturePascal}UseCase>((ref) {
  return Get${FeaturePascal}UseCase(
    ref.watch(${FeatureCamel}RepositoryProvider),
  );
});
"@ | Out-File -FilePath "$BaseDir\di\${FeatureName}_providers.dart" -Encoding UTF8

# Create UI Provider
@"
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/${FeatureName}.dart';
import '../../di/${FeatureName}_providers.dart';

final ${FeatureCamel}NotifierProvider = AsyncNotifierProvider<${FeaturePascal}Notifier, ${FeaturePascal}>(() {
  return ${FeaturePascal}Notifier();
});

class ${FeaturePascal}Notifier extends AsyncNotifier<${FeaturePascal}> {
  @override
  Future<${FeaturePascal}> build() async {
    final get${FeaturePascal} = ref.read(get${FeaturePascal}UseCaseProvider);
    return await get${FeaturePascal}();
  }
}
"@ | Out-File -FilePath "$BaseDir\presentation\providers\${FeatureName}_provider.dart" -Encoding UTF8

# Create Screen
@"
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/${FeatureName}_provider.dart';

class ${FeaturePascal}Screen extends ConsumerWidget {
  const ${FeaturePascal}Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(${FeatureCamel}NotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('${FeaturePascal}'),
      ),
      body: state.when(
        data: (data) => Center(child: Text(data.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: `$err')),
      ),
    );
  }
}
"@ | Out-File -FilePath "$BaseDir\presentation\screens\${FeatureName}_screen.dart" -Encoding UTF8

# Create Widgets (e.g. empty)
New-Item -ItemType File -Force -Path "$BaseDir\presentation\widgets\.gitkeep" | Out-Null

Write-Host "Feature $FeatureName created successfully at $BaseDir"

