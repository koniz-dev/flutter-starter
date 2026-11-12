// AppTheme bound the concrete DefaultDesignTokens at compile time, so the
// AppDesignTokens contract had no consumer: implementing it changed nothing.
// AppTheme is now typed on the contract and builds either theme from any
// implementation of it.

import 'package:flutter_starter/core/contracts/design_tokens_contracts.dart';
import 'package:flutter_starter/shared/design_system/tokens/default_design_tokens.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A token set that shares no colour with the default one.
class _BrandTokens implements AppDesignTokens {
  const _BrandTokens();

  @override
  Color get primary => const Color(0xFF112233);
  @override
  Color get secondary => const Color(0xFF223344);
  @override
  Color get background => const Color(0xFF334455);
  @override
  Color get surface => const Color(0xFF445566);
  @override
  Color get error => const Color(0xFF556677);
  @override
  Color get textPrimary => const Color(0xFF667788);
  @override
  Color get textSecondary => const Color(0xFF778899);
  @override
  Color get textOnPrimary => const Color(0xFF8899AA);
  @override
  Color get textSecondaryOnDark => const Color(0xFF99AABB);
  @override
  Color get success => const Color(0xFFAABBCC);
  @override
  Color get warning => const Color(0xFFBBCCDD);
  @override
  Color get info => const Color(0xFFCCDDEE);
  @override
  TextStyle get displayLarge => const TextStyle(fontSize: 41);
  @override
  TextStyle get displayMedium => const TextStyle(fontSize: 31);
  @override
  TextStyle get bodyLarge => const TextStyle(fontSize: 21);
  @override
  TextStyle get bodyMedium => const TextStyle(fontSize: 19);
  @override
  TextStyle get labelLarge => const TextStyle(fontSize: 17);
}

void main() {
  const brand = _BrandTokens();

  test('a light theme carries the colours and type of the tokens it is '
      'built from', () {
    final theme = AppTheme.light(brand);

    expect(theme.colorScheme.primary, brand.primary);
    expect(theme.colorScheme.secondary, brand.secondary);
    expect(theme.colorScheme.surface, brand.surface);
    expect(theme.colorScheme.error, brand.error);
    expect(theme.colorScheme.onPrimary, brand.textOnPrimary);
    expect(theme.colorScheme.onSurface, brand.textPrimary);
    expect(theme.colorScheme.onSurfaceVariant, brand.textSecondary);
    expect(theme.scaffoldBackgroundColor, brand.background);
    expect(theme.appBarTheme.backgroundColor, brand.primary);
    expect(theme.textTheme.displayLarge?.fontSize, 41);
    expect(theme.textTheme.bodyMedium?.fontSize, 19);
  });

  test('a dark theme takes its text colours and filled buttons from the '
      'tokens', () {
    final theme = AppTheme.dark(brand);

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.secondary, brand.secondary);
    expect(theme.colorScheme.onSurface, brand.textOnPrimary);
    expect(theme.colorScheme.onSurfaceVariant, brand.textSecondaryOnDark);
    expect(theme.textTheme.bodyLarge?.color, brand.textOnPrimary);
    expect(theme.textTheme.bodyMedium?.color, brand.textSecondaryOnDark);
    expect(theme.textTheme.displayLarge?.fontSize, 41);
    expect(
      theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}),
      brand.primary,
    );
  });

  test('the default themes are the ones built from DefaultDesignTokens', () {
    const defaults = DefaultDesignTokens();

    expect(AppTheme.lightTheme, AppTheme.light(defaults));
    expect(AppTheme.darkTheme, AppTheme.dark(defaults));
    expect(AppTheme.lightTheme.colorScheme.primary, defaults.primary);
    expect(AppTheme.lightTheme.colorScheme.primary, isNot(brand.primary));
  });
}
