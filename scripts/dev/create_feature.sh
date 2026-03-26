#!/bin/bash

# Check if feature name is provided
if [ -z "$1" ]; then
    echo "Usage: ./scripts/dev/create_feature.sh <feature_name>"
    exit 1
fi

FEATURE_NAME=$1

# Convert feature_name to PascalCase (e.g. test_feature -> TestFeature)
FEATURE_PASCAL=$(echo "$FEATURE_NAME" | awk -F_ '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}} 1' OFS="")

# Convert to camelCase
FEATURE_CAMEL="$(tr '[:upper:]' '[:lower:]' <<< ${FEATURE_PASCAL:0:1})${FEATURE_PASCAL:1}"

BASE_DIR="lib/features/$FEATURE_NAME"

echo "Creating feature: $FEATURE_NAME"

mkdir -p "$BASE_DIR/data/datasources"
mkdir -p "$BASE_DIR/data/models"
mkdir -p "$BASE_DIR/data/repositories"
mkdir -p "$BASE_DIR/di"
mkdir -p "$BASE_DIR/domain/entities"
mkdir -p "$BASE_DIR/domain/repositories"
mkdir -p "$BASE_DIR/domain/usecases"
mkdir -p "$BASE_DIR/presentation/providers"
mkdir -p "$BASE_DIR/presentation/screens"
mkdir -p "$BASE_DIR/presentation/widgets"

# Create Entity
cat > "$BASE_DIR/domain/entities/${FEATURE_NAME}.dart" << EOL
class ${FEATURE_PASCAL} {
  const ${FEATURE_PASCAL}();
}
EOL

# Create Repository Interface
cat > "$BASE_DIR/domain/repositories/${FEATURE_NAME}_repository.dart" << EOL
import '../entities/${FEATURE_NAME}.dart';

abstract class ${FEATURE_PASCAL}Repository {
  Future<${FEATURE_PASCAL}> get${FEATURE_PASCAL}();
}
EOL

# Create UseCase
cat > "$BASE_DIR/domain/usecases/get_${FEATURE_NAME}_usecase.dart" << EOL
import '../entities/${FEATURE_NAME}.dart';
import '../repositories/${FEATURE_NAME}_repository.dart';

class Get${FEATURE_PASCAL}UseCase {
  final ${FEATURE_PASCAL}Repository repository;

  Get${FEATURE_PASCAL}UseCase(this.repository);

  Future<${FEATURE_PASCAL}> call() {
    return repository.get${FEATURE_PASCAL}();
  }
}
EOL

# Create Model
cat > "$BASE_DIR/data/models/${FEATURE_NAME}_model.dart" << EOL
import '../../domain/entities/${FEATURE_NAME}.dart';

class ${FEATURE_PASCAL}Model extends ${FEATURE_PASCAL} {
  const ${FEATURE_PASCAL}Model();

  factory ${FEATURE_PASCAL}Model.fromJson(Map<String, dynamic> json) {
    return const ${FEATURE_PASCAL}Model();
  }

  Map<String, dynamic> toJson() {
    return {};
  }
}
EOL

# Create Local Datasource
cat > "$BASE_DIR/data/datasources/${FEATURE_NAME}_local_datasource.dart" << EOL
import '../models/${FEATURE_NAME}_model.dart';

abstract class ${FEATURE_PASCAL}LocalDataSource {
  Future<${FEATURE_PASCAL}Model> get${FEATURE_PASCAL}();
}

class ${FEATURE_PASCAL}LocalDataSourceImpl implements ${FEATURE_PASCAL}LocalDataSource {
  @override
  Future<${FEATURE_PASCAL}Model> get${FEATURE_PASCAL}() async {
    // TODO: implement
    throw UnimplementedError();
  }
}
EOL

# Create Repository Impl
cat > "$BASE_DIR/data/repositories/${FEATURE_NAME}_repository_impl.dart" << EOL
import '../../domain/entities/${FEATURE_NAME}.dart';
import '../../domain/repositories/${FEATURE_NAME}_repository.dart';
import '../datasources/${FEATURE_NAME}_local_datasource.dart';

class ${FEATURE_PASCAL}RepositoryImpl implements ${FEATURE_PASCAL}Repository {
  final ${FEATURE_PASCAL}LocalDataSource localDataSource;

  ${FEATURE_PASCAL}RepositoryImpl({required this.localDataSource});

  @override
  Future<${FEATURE_PASCAL}> get${FEATURE_PASCAL}() async {
    return await localDataSource.get${FEATURE_PASCAL}();
  }
}
EOL

# Create Providers
cat > "$BASE_DIR/di/${FEATURE_NAME}_providers.dart" << EOL
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/${FEATURE_NAME}_local_datasource.dart';
import '../data/repositories/${FEATURE_NAME}_repository_impl.dart';
import '../domain/repositories/${FEATURE_NAME}_repository.dart';
import '../domain/usecases/get_${FEATURE_NAME}_usecase.dart';

final ${FEATURE_CAMEL}LocalDataSourceProvider = Provider<${FEATURE_PASCAL}LocalDataSource>((ref) {
  return ${FEATURE_PASCAL}LocalDataSourceImpl();
});

final ${FEATURE_CAMEL}RepositoryProvider = Provider<${FEATURE_PASCAL}Repository>((ref) {
  return ${FEATURE_PASCAL}RepositoryImpl(
    localDataSource: ref.watch(${FEATURE_CAMEL}LocalDataSourceProvider),
  );
});

final get${FEATURE_PASCAL}UseCaseProvider = Provider<Get${FEATURE_PASCAL}UseCase>((ref) {
  return Get${FEATURE_PASCAL}UseCase(
    ref.watch(${FEATURE_CAMEL}RepositoryProvider),
  );
});
EOL

# Create UI Provider
cat > "$BASE_DIR/presentation/providers/${FEATURE_NAME}_provider.dart" << EOL
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/${FEATURE_NAME}.dart';
import '../../di/${FEATURE_NAME}_providers.dart';

final ${FEATURE_CAMEL}NotifierProvider = AsyncNotifierProvider<${FEATURE_PASCAL}Notifier, ${FEATURE_PASCAL}>(() {
  return ${FEATURE_PASCAL}Notifier();
});

class ${FEATURE_PASCAL}Notifier extends AsyncNotifier<${FEATURE_PASCAL}> {
  @override
  Future<${FEATURE_PASCAL}> build() async {
    final get${FEATURE_PASCAL} = ref.read(get${FEATURE_PASCAL}UseCaseProvider);
    return await get${FEATURE_PASCAL}();
  }
}
EOL

# Create Screen
cat > "$BASE_DIR/presentation/screens/${FEATURE_NAME}_screen.dart" << EOL
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/${FEATURE_NAME}_provider.dart';

class ${FEATURE_PASCAL}Screen extends ConsumerWidget {
  const ${FEATURE_PASCAL}Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(${FEATURE_CAMEL}NotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('${FEATURE_PASCAL}'),
      ),
      body: state.when(
        data: (data) => Center(child: Text(data.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: \$err')),
      ),
    );
  }
}
EOL

# Create Widgets (e.g. empty)
touch "$BASE_DIR/presentation/widgets/.gitkeep"

echo "Feature $FEATURE_NAME created successfully at $BASE_DIR"

