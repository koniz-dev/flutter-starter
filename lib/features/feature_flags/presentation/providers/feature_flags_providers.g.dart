// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flags_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(featureFlagsLocalDataSource)
const featureFlagsLocalDataSourceProvider =
    FeatureFlagsLocalDataSourceProvider._();

final class FeatureFlagsLocalDataSourceProvider
    extends
        $FunctionalProvider<
          FeatureFlagsLocalDataSource,
          FeatureFlagsLocalDataSource,
          FeatureFlagsLocalDataSource
        >
    with $Provider<FeatureFlagsLocalDataSource> {
  const FeatureFlagsLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsLocalDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagsLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<FeatureFlagsLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeatureFlagsLocalDataSource create(Ref ref) {
    return featureFlagsLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureFlagsLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureFlagsLocalDataSource>(value),
    );
  }
}

String _$featureFlagsLocalDataSourceHash() =>
    r'aa73de633fe231d845337fa574953d51da9524c2';

@ProviderFor(featureFlagsRemoteDataSource)
const featureFlagsRemoteDataSourceProvider =
    FeatureFlagsRemoteDataSourceProvider._();

final class FeatureFlagsRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          FeatureFlagsRemoteDataSource,
          FeatureFlagsRemoteDataSource,
          FeatureFlagsRemoteDataSource
        >
    with $Provider<FeatureFlagsRemoteDataSource> {
  const FeatureFlagsRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagsRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<FeatureFlagsRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeatureFlagsRemoteDataSource create(Ref ref) {
    return featureFlagsRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureFlagsRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureFlagsRemoteDataSource>(value),
    );
  }
}

String _$featureFlagsRemoteDataSourceHash() =>
    r'4cb08139f8b25263f3fa2b499c0c1eafce6c586f';

@ProviderFor(featureFlagsRepository)
const featureFlagsRepositoryProvider = FeatureFlagsRepositoryProvider._();

final class FeatureFlagsRepositoryProvider
    extends
        $FunctionalProvider<
          FeatureFlagsRepository,
          FeatureFlagsRepository,
          FeatureFlagsRepository
        >
    with $Provider<FeatureFlagsRepository> {
  const FeatureFlagsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagsRepositoryHash();

  @$internal
  @override
  $ProviderElement<FeatureFlagsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeatureFlagsRepository create(Ref ref) {
    return featureFlagsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureFlagsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureFlagsRepository>(value),
    );
  }
}

String _$featureFlagsRepositoryHash() =>
    r'd0730b681f2e1924a27b654e5cf6ff8eed542708';

@ProviderFor(featureFlagsManager)
const featureFlagsManagerProvider = FeatureFlagsManagerProvider._();

final class FeatureFlagsManagerProvider
    extends
        $FunctionalProvider<
          FeatureFlagsManager,
          FeatureFlagsManager,
          FeatureFlagsManager
        >
    with $Provider<FeatureFlagsManager> {
  const FeatureFlagsManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagsManagerHash();

  @$internal
  @override
  $ProviderElement<FeatureFlagsManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeatureFlagsManager create(Ref ref) {
    return featureFlagsManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureFlagsManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureFlagsManager>(value),
    );
  }
}

String _$featureFlagsManagerHash() =>
    r'85723c5f453bdae6e014b3f196f99c4dd2a3a94b';

@ProviderFor(featureFlagsInitialization)
const featureFlagsInitializationProvider =
    FeatureFlagsInitializationProvider._();

final class FeatureFlagsInitializationProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const FeatureFlagsInitializationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsInitializationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagsInitializationHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return featureFlagsInitialization(ref);
  }
}

String _$featureFlagsInitializationHash() =>
    r'8eab227c2ec9162c70758bdf3064c98bdb4c8c11';

@ProviderFor(isFeatureEnabled)
const isFeatureEnabledProvider = IsFeatureEnabledFamily._();

final class IsFeatureEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  const IsFeatureEnabledProvider._({
    required IsFeatureEnabledFamily super.from,
    required FeatureFlagKey super.argument,
  }) : super(
         retry: null,
         name: r'isFeatureEnabledProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isFeatureEnabledHash();

  @override
  String toString() {
    return r'isFeatureEnabledProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as FeatureFlagKey;
    return isFeatureEnabled(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsFeatureEnabledProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isFeatureEnabledHash() => r'a73a0b59675ba3996aa5f3f380e3f15521ce58a7';

final class IsFeatureEnabledFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, FeatureFlagKey> {
  const IsFeatureEnabledFamily._()
    : super(
        retry: null,
        name: r'isFeatureEnabledProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  IsFeatureEnabledProvider call(FeatureFlagKey key) =>
      IsFeatureEnabledProvider._(argument: key, from: this);

  @override
  String toString() => r'isFeatureEnabledProvider';
}

@ProviderFor(featureFlag)
const featureFlagProvider = FeatureFlagFamily._();

final class FeatureFlagProvider
    extends
        $FunctionalProvider<
          AsyncValue<FeatureFlag?>,
          FeatureFlag?,
          FutureOr<FeatureFlag?>
        >
    with $FutureModifier<FeatureFlag?>, $FutureProvider<FeatureFlag?> {
  const FeatureFlagProvider._({
    required FeatureFlagFamily super.from,
    required FeatureFlagKey super.argument,
  }) : super(
         retry: null,
         name: r'featureFlagProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$featureFlagHash();

  @override
  String toString() {
    return r'featureFlagProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FeatureFlag?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FeatureFlag?> create(Ref ref) {
    final argument = this.argument as FeatureFlagKey;
    return featureFlag(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FeatureFlagProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$featureFlagHash() => r'49d55e5447defd7845f4eab3891c2892b96c907a';

final class FeatureFlagFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FeatureFlag?>, FeatureFlagKey> {
  const FeatureFlagFamily._()
    : super(
        retry: null,
        name: r'featureFlagProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FeatureFlagProvider call(FeatureFlagKey key) =>
      FeatureFlagProvider._(argument: key, from: this);

  @override
  String toString() => r'featureFlagProvider';
}

@ProviderFor(allFeatureFlags)
const allFeatureFlagsProvider = AllFeatureFlagsProvider._();

final class AllFeatureFlagsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, FeatureFlag?>>,
          Map<String, FeatureFlag?>,
          FutureOr<Map<String, FeatureFlag?>>
        >
    with
        $FutureModifier<Map<String, FeatureFlag?>>,
        $FutureProvider<Map<String, FeatureFlag?>> {
  const AllFeatureFlagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allFeatureFlagsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allFeatureFlagsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, FeatureFlag?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, FeatureFlag?>> create(Ref ref) {
    return allFeatureFlags(ref);
  }
}

String _$allFeatureFlagsHash() => r'5320b309e0aabc695ee07aefc75bf98002fbc6a9';
