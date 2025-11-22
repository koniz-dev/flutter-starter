import 'package:flutter/foundation.dart';
import 'package:flutter_starter/features/feature_flags/data/services/local_feature_flags_service.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalFeatureFlagsService', () {
    group('getLocalFlag', () {
      test('should return flag with compile-time default', () {
        final flag = LocalFeatureFlagsService.instance.getLocalFlag(
          'test_flag',
          compileTimeDefault: true,
          description: 'Test flag',
        );

        expect(flag, isNotNull);
        expect(flag!.key, 'test_flag');
        expect(flag.value, isTrue);
        expect(flag.source, FeatureFlagSource.compileTime);
        expect(flag.description, 'Test flag');
        expect(flag.defaultValue, isTrue);
      });

      test('should return flag with debug default in debug mode', () {
        final flag = LocalFeatureFlagsService.instance.getLocalFlag(
          'test_flag',
          debugDefault: true,
          releaseDefault: false,
        );

        if (kDebugMode) {
          expect(flag, isNotNull);
          expect(flag!.value, isTrue);
          expect(flag.source, FeatureFlagSource.buildMode);
        } else {
          // In release mode, should use releaseDefault
          expect(flag, isNotNull);
          expect(flag!.value, isFalse);
          expect(flag.source, FeatureFlagSource.buildMode);
        }
      });

      test('should return flag with release default in release mode', () {
        final flag = LocalFeatureFlagsService.instance.getLocalFlag(
          'test_flag',
          releaseDefault: true,
        );

        if (kReleaseMode) {
          expect(flag, isNotNull);
          expect(flag!.value, isTrue);
          expect(flag.source, FeatureFlagSource.buildMode);
        }
      });

      test('should return null when no defaults provided', () {
        final flag =
            LocalFeatureFlagsService.instance.getLocalFlag('test_flag');

        expect(flag, isNull);
      });

      test('should prioritize build mode over compile-time default', () {
        final flag = LocalFeatureFlagsService.instance.getLocalFlag(
          'test_flag',
          compileTimeDefault: true,
          debugDefault: false,
        );

        expect(flag, isNotNull);
        // In debug mode, build mode (debugDefault) takes priority over
        // compile-time
        if (kDebugMode) {
          expect(flag!.value, isFalse);
          expect(flag.source, FeatureFlagSource.buildMode);
        } else {
          // In release mode, compile-time default is used
          expect(flag!.value, isTrue);
          expect(flag.source, FeatureFlagSource.compileTime);
        }
      });
    });

    group('getAllLocalFlags', () {
      test('should return map of local flags', () {
        final flags = LocalFeatureFlagsService.instance.getAllLocalFlags();

        expect(flags, isA<Map<String, FeatureFlag>>());
        // Should include flags from _localFlagDefinitions
        expect(flags.containsKey('enable_debug_menu'), isTrue);
        expect(flags.containsKey('enable_experimental_features'), isTrue);
      });

      test('should include debug menu flag', () {
        final flags = LocalFeatureFlagsService.instance.getAllLocalFlags();

        final debugMenuFlag = flags['enable_debug_menu'];
        expect(debugMenuFlag, isNotNull);
        expect(debugMenuFlag!.key, 'enable_debug_menu');
        expect(debugMenuFlag.description, contains('debug menu'));
      });

      test('should include experimental features flag', () {
        final flags = LocalFeatureFlagsService.instance.getAllLocalFlags();

        final experimentalFlag = flags['enable_experimental_features'];
        expect(experimentalFlag, isNotNull);
        expect(experimentalFlag!.key, 'enable_experimental_features');
        expect(experimentalFlag.description, contains('experimental'));
      });
    });

    group('LocalFlagDefinition', () {
      test('should create definition with all properties', () {
        const definition = LocalFlagDefinition(
          key: 'test_key',
          compileTimeDefault: true,
          debugDefault: false,
          releaseDefault: true,
          description: 'Test description',
        );

        expect(definition.key, 'test_key');
        expect(definition.compileTimeDefault, isTrue);
        expect(definition.debugDefault, isFalse);
        expect(definition.releaseDefault, isTrue);
        expect(definition.description, 'Test description');
      });

      test('should create definition with minimal properties', () {
        const definition = LocalFlagDefinition(key: 'test_key');

        expect(definition.key, 'test_key');
        expect(definition.compileTimeDefault, isNull);
        expect(definition.debugDefault, isNull);
        expect(definition.releaseDefault, isNull);
        expect(definition.description, isNull);
      });
    });
  });
}
