// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flags_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(featureFlagsLocalDataSource)
final featureFlagsLocalDataSourceProvider =
    FeatureFlagsLocalDataSourceProvider._();

final class FeatureFlagsLocalDataSourceProvider
    extends
        $FunctionalProvider<
          FeatureFlagsLocalDataSource,
          FeatureFlagsLocalDataSource,
          FeatureFlagsLocalDataSource
        >
    with $Provider<FeatureFlagsLocalDataSource> {
  FeatureFlagsLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsLocalDataSourceProvider',
        isAutoDispose: false,
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
    r'b48c95abbd03a952050ac6e1b65dea64bbfc0876';

@ProviderFor(featureFlagsRemoteDataSource)
final featureFlagsRemoteDataSourceProvider =
    FeatureFlagsRemoteDataSourceProvider._();

final class FeatureFlagsRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          FeatureFlagsRemoteDataSource,
          FeatureFlagsRemoteDataSource,
          FeatureFlagsRemoteDataSource
        >
    with $Provider<FeatureFlagsRemoteDataSource> {
  FeatureFlagsRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsRemoteDataSourceProvider',
        isAutoDispose: false,
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
    r'11a9a1e7c807f548d90cbf2d9828748c99551883';

@ProviderFor(featureFlagsRepository)
final featureFlagsRepositoryProvider = FeatureFlagsRepositoryProvider._();

final class FeatureFlagsRepositoryProvider
    extends
        $FunctionalProvider<
          FeatureFlagsRepository,
          FeatureFlagsRepository,
          FeatureFlagsRepository
        >
    with $Provider<FeatureFlagsRepository> {
  FeatureFlagsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsRepositoryProvider',
        isAutoDispose: false,
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
    r'6e10a57ee934b44c50961e37292ac69acb232626';

@ProviderFor(featureFlagsManager)
final featureFlagsManagerProvider = FeatureFlagsManagerProvider._();

final class FeatureFlagsManagerProvider
    extends
        $FunctionalProvider<
          FeatureFlagsManager,
          FeatureFlagsManager,
          FeatureFlagsManager
        >
    with $Provider<FeatureFlagsManager> {
  FeatureFlagsManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsManagerProvider',
        isAutoDispose: false,
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
    r'ed650be829fabbec0cd4f99dafa0e7aef30efd51';

/// Initializes and fetches the remote source once per container.
///
/// Every flag read awaits it, so the first read starts it and no read sees
/// the remote source before it is ready. It never fails: a remote that cannot
/// initialize is logged and the flags resolve from local values and defaults.

@ProviderFor(featureFlagsInitialization)
final featureFlagsInitializationProvider =
    FeatureFlagsInitializationProvider._();

/// Initializes and fetches the remote source once per container.
///
/// Every flag read awaits it, so the first read starts it and no read sees
/// the remote source before it is ready. It never fails: a remote that cannot
/// initialize is logged and the flags resolve from local values and defaults.

final class FeatureFlagsInitializationProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Initializes and fetches the remote source once per container.
  ///
  /// Every flag read awaits it, so the first read starts it and no read sees
  /// the remote source before it is ready. It never fails: a remote that cannot
  /// initialize is logged and the flags resolve from local values and defaults.
  FeatureFlagsInitializationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsInitializationProvider',
        isAutoDispose: false,
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
    r'0b98c4dbb7c127d24ff2d3c342789a81c34a7432';

@ProviderFor(isFeatureEnabled)
final isFeatureEnabledProvider = IsFeatureEnabledFamily._();

final class IsFeatureEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  IsFeatureEnabledProvider._({
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

String _$isFeatureEnabledHash() => r'e5defaf639878d8849f88c2d8ea5786be3f0cf4a';

final class IsFeatureEnabledFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, FeatureFlagKey> {
  IsFeatureEnabledFamily._()
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
final featureFlagProvider = FeatureFlagFamily._();

final class FeatureFlagProvider
    extends
        $FunctionalProvider<
          AsyncValue<FeatureFlag?>,
          FeatureFlag?,
          FutureOr<FeatureFlag?>
        >
    with $FutureModifier<FeatureFlag?>, $FutureProvider<FeatureFlag?> {
  FeatureFlagProvider._({
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

String _$featureFlagHash() => r'33b747aafa7c8e53348eb8ef154448542efcb2ca';

final class FeatureFlagFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FeatureFlag?>, FeatureFlagKey> {
  FeatureFlagFamily._()
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

/// Every flag the repository knows, plus every [FeatureFlags.all] key.
///
/// A [FeatureFlags.all] key no source sets appears at its
/// [FeatureFlagKey.defaultValue] - the value [FeatureFlagsManager.isEnabled]
/// falls back to - so the debug screen can show and toggle the flags the app
/// actually gates on.

@ProviderFor(allFeatureFlags)
final allFeatureFlagsProvider = AllFeatureFlagsProvider._();

/// Every flag the repository knows, plus every [FeatureFlags.all] key.
///
/// A [FeatureFlags.all] key no source sets appears at its
/// [FeatureFlagKey.defaultValue] - the value [FeatureFlagsManager.isEnabled]
/// falls back to - so the debug screen can show and toggle the flags the app
/// actually gates on.

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
  /// Every flag the repository knows, plus every [FeatureFlags.all] key.
  ///
  /// A [FeatureFlags.all] key no source sets appears at its
  /// [FeatureFlagKey.defaultValue] - the value [FeatureFlagsManager.isEnabled]
  /// falls back to - so the debug screen can show and toggle the flags the app
  /// actually gates on.
  AllFeatureFlagsProvider._()
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

String _$allFeatureFlagsHash() => r'd19e27938a41e95857f0e7b04bbbc620c7d80e37';
