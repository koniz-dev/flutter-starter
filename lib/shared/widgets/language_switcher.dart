import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// Language switcher widget
///
/// Displays a button that opens a dialog to select the app language.
/// The selected language is persisted and the app updates immediately.
class LanguageSwitcher extends ConsumerWidget {
  /// Creates a [LanguageSwitcher] widget
  const LanguageSwitcher({
    super.key,
    this.icon = Icons.language,
    this.tooltip,
  });

  /// Icon to display
  final IconData icon;

  /// Tooltip text
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch<Locale>(localeStateProvider);

    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip ?? l10n.selectLanguage,
      onPressed: () => _showLanguageDialog(context, ref, currentLocale),
    );
  }

  Future<void> _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    Locale currentLocale,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final localizationService =
        ref.read<LocalizationService>(localizationServiceProvider);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: RadioGroup<Locale>(
          groupValue: currentLocale,
          onChanged: (locale) async {
            if (locale != null) {
              await localizationService.setCurrentLocale(locale);
              ref.read(localeStateProvider.notifier).locale = locale;
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SupportedLocale.values.map((supportedLocale) {
              return RadioListTile<Locale>(
                title: Text(supportedLocale.displayName),
                value: supportedLocale.locale,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
  }
}

/// Language switcher as a dropdown menu item
///
/// Can be used in AppBar actions or other menus
class LanguageSwitcherMenuItem extends ConsumerWidget {
  /// Creates a [LanguageSwitcherMenuItem] widget
  const LanguageSwitcherMenuItem({
    super.key,
    this.icon = Icons.language,
  });

  /// Icon to display
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch<Locale>(localeStateProvider);

    return ListTile(
      leading: Icon(icon),
      title: Text(l10n.language),
      subtitle: Text(
        SupportedLocale.values
            .firstWhere(
              (locale) =>
                  locale.locale.languageCode == currentLocale.languageCode,
            )
            .displayName,
      ),
      onTap: () => _showLanguageDialog(context, ref, currentLocale),
    );
  }

  Future<void> _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    Locale currentLocale,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final localizationService =
        ref.read<LocalizationService>(localizationServiceProvider);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: RadioGroup<Locale>(
          groupValue: currentLocale,
          onChanged: (locale) async {
            if (locale != null) {
              await localizationService.setCurrentLocale(locale);
              ref.read(localeStateProvider.notifier).locale = locale;
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SupportedLocale.values.map((supportedLocale) {
              return RadioListTile<Locale>(
                title: Text(supportedLocale.displayName),
                value: supportedLocale.locale,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
  }
}

/// Language selection screen
///
/// A full screen for language selection
class LanguageSelectionScreen extends ConsumerWidget {
  /// Creates a [LanguageSelectionScreen] widget
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch<Locale>(localeStateProvider);
    final localizationService =
        ref.read<LocalizationService>(localizationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLanguage),
      ),
      body: RadioGroup<Locale>(
        groupValue: currentLocale,
        onChanged: (locale) async {
          if (locale != null) {
            await localizationService.setCurrentLocale(locale);
            ref.read(localeStateProvider.notifier).locale = locale;
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        child: ListView(
          children: SupportedLocale.values.map((supportedLocale) {
            final isSelected =
                currentLocale.languageCode ==
                    supportedLocale.locale.languageCode;
            return RadioListTile<Locale>(
              title: Text(supportedLocale.displayName),
              subtitle: Text(
                _getLanguageDescription(supportedLocale.locale.languageCode),
              ),
              value: supportedLocale.locale,
              secondary: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getLanguageDescription(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English (United States)';
      case 'es':
        return 'Español (España)';
      case 'ar':
        return 'العربية (السعودية)';
      default:
        return '';
    }
  }
}
