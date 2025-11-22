# Internationalization (i18n) Implementation Guide

This guide provides a comprehensive overview of the internationalization system implemented in the Flutter Starter app.

## Table of Contents

1. [Overview](#overview)
2. [Setup](#setup)
3. [Text Localization](#text-localization)
4. [Format Localization](#format-localization)
5. [Asset Localization](#asset-localization)
6. [Language Switching](#language-switching)
7. [RTL Support](#rtl-support)
8. [Best Practices](#best-practices)
9. [Examples](#examples)

## Overview

The internationalization system supports:
- **3 Languages**: English (en), Spanish (es), Arabic (ar)
- **RTL Support**: Automatic text direction for Arabic
- **Pluralization**: ICU message format for plural forms
- **Formatting**: Date, time, number, and currency formatting
- **Persistent Preferences**: Language selection saved to storage
- **Runtime Switching**: Change language without app restart

## Setup

### Dependencies

The following dependencies are already configured in `pubspec.yaml`:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2
```

### Configuration Files

1. **l10n.yaml**: Configuration for localization generation
   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_en.arb
   output-localization-file: app_localizations.dart
   output-class: AppLocalizations
   ```

2. **ARB Files**: Located in `lib/l10n/`
   - `app_en.arb` - English translations
   - `app_es.arb` - Spanish translations
   - `app_ar.arb` - Arabic translations

### Generating Localization Files

After modifying ARB files, generate the localization code:

```bash
flutter gen-l10n
```

This command generates `AppLocalizations` class in `.dart_tool/flutter_gen/gen_l10n/`.

## Text Localization

### Using Localized Strings

Access localized strings using `AppLocalizations`:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Text(l10n.welcome);
  }
}
```

### Adding New Translations

1. **Add to English ARB file** (`lib/l10n/app_en.arb`):
   ```json
   {
     "myNewString": "My new string",
     "@myNewString": {
       "description": "Description of the string"
     }
   }
   ```

2. **Add translations to other languages**:
   - `lib/l10n/app_es.arb` for Spanish
   - `lib/l10n/app_ar.arb` for Arabic

3. **Generate localization files**:
   ```bash
   flutter gen-l10n
   ```

4. **Use in code**:
   ```dart
   final l10n = AppLocalizations.of(context)!;
   Text(l10n.myNewString);
   ```

### Pluralization

Use ICU message format for pluralization:

**ARB File:**
```json
{
  "itemCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
  "@itemCount": {
    "description": "Pluralized item count",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

**Usage:**
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.itemCount(5)); // "5 items"
Text(l10n.itemCount(1)); // "1 item"
Text(l10n.itemCount(0)); // "No items"
```

### Context-Based Translations

For context-specific translations, use different keys:

```json
{
  "saveButton": "Save",
  "saveButtonContext": "Save Changes",
  "@saveButtonContext": {
    "description": "Save button in edit context"
  }
}
```

## Format Localization

### Date Formatting

Use `LocalizedFormatters` for date formatting:

```dart
import 'package:flutter_starter/core/localization/localized_formatters.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeStateProvider);
    final date = DateTime.now();
    
    // Default format
    final formatted = LocalizedFormatters.formatDate(date, locale: locale);
    
    // Custom format
    final custom = LocalizedFormatters.formatDate(
      date,
      locale: locale,
      format: 'yyyy-MM-dd',
    );
    
    return Text(formatted);
  }
}
```

### Time Formatting

```dart
final time = DateTime.now();
final formatted = LocalizedFormatters.formatTime(time, locale: locale);
```

### Number Formatting

```dart
final number = 1234.56;
final formatted = LocalizedFormatters.formatNumber(
  number,
  locale: locale,
  decimalDigits: 2,
);
// English: "1,234.56"
// Spanish: "1.234,56"
// Arabic: "١٬٢٣٤٫٥٦"
```

### Currency Formatting

```dart
final amount = 1234.56;
final formatted = LocalizedFormatters.formatCurrency(
  amount,
  locale: locale,
  currencyCode: 'USD',
);
// English: "$1,234.56"
// Spanish: "1.234,56 €"
// Arabic: "ر.س ١٬٢٣٤٫٥٦"
```

### Percentage Formatting

```dart
final value = 0.15; // 15%
final formatted = LocalizedFormatters.formatPercentage(
  value,
  locale: locale,
);
```

### Compact Number Formatting

```dart
final number = 1234567;
final formatted = LocalizedFormatters.formatCompactNumber(
  number,
  locale: locale,
);
// "1.2M" (English)
```

### Relative Time Formatting

```dart
final dateTime = DateTime.now().subtract(Duration(hours: 2));
final formatted = LocalizedFormatters.formatRelativeTime(
  dateTime,
  locale: locale,
);
// "2 hours ago"
```

## Asset Localization

### Language-Specific Images

Store language-specific images in:

```
assets/
  images/
    en/
      logo.png
    es/
      logo.png
    ar/
      logo.png
```

**Usage:**
```dart
import 'package:flutter_starter/core/localization/localization_providers.dart';

class LocalizedImage extends ConsumerWidget {
  final String imagePath;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeStateProvider);
    final languageCode = locale.languageCode;
    
    return Image.asset('assets/images/$languageCode/$imagePath');
  }
}
```

### Language-Specific Configs

Store language-specific configuration:

```
assets/
  config/
    en.json
    es.json
    ar.json
```

## Language Switching

### Using Language Switcher Widget

The app includes a ready-to-use language switcher:

```dart
import 'package:flutter_starter/shared/widgets/language_switcher.dart';

// As an icon button in AppBar
AppBar(
  actions: [
    const LanguageSwitcher(),
  ],
)

// As a menu item
LanguageSwitcherMenuItem()

// As a full screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const LanguageSelectionScreen(),
  ),
);
```

### Programmatic Language Switching

```dart
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizationService = ref.read(localizationServiceProvider);
    
    return ElevatedButton(
      onPressed: () async {
        // Switch to Spanish
        await localizationService.setCurrentLocale(
          const Locale('es', 'ES'),
        );
        ref.read(localeStateProvider.notifier).state = 
          const Locale('es', 'ES');
      },
      child: const Text('Switch to Spanish'),
    );
  }
}
```

### Getting Current Locale

```dart
final locale = ref.watch(localeStateProvider);
final languageCode = locale.languageCode; // 'en', 'es', 'ar'
```

## RTL Support

### Automatic RTL Detection

RTL is automatically handled for Arabic and other RTL languages:

```dart
import 'package:flutter_starter/core/localization/localization_providers.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRTL = ref.watch(isRTLProvider);
    final textDirection = ref.watch(textDirectionProvider);
    
    return Directionality(
      textDirection: textDirection,
      child: YourWidget(),
    );
  }
}
```

### Manual RTL Check

```dart
final isRTL = LocalizationService.isRTL(locale);
final textDirection = LocalizationService.getTextDirection(locale);
```

### RTL-Aware Widgets

Flutter widgets automatically handle RTL when `Directionality` is set correctly. The app's `MaterialApp` builder already wraps content with `Directionality`.

## Best Practices

### 1. Always Use Localized Strings

❌ **Don't:**
```dart
Text('Welcome')
```

✅ **Do:**
```dart
Text(AppLocalizations.of(context)!.welcome)
```

### 2. Handle Null Safety

```dart
final l10n = AppLocalizations.of(context);
if (l10n != null) {
  Text(l10n.welcome);
} else {
  Text('Welcome'); // Fallback
}
```

Or use the null assertion operator if you're sure the context has localizations:

```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.welcome);
```

### 3. Use Meaningful Keys

❌ **Don't:**
```json
{
  "msg1": "Hello",
  "msg2": "Goodbye"
}
```

✅ **Do:**
```json
{
  "greeting": "Hello",
  "farewell": "Goodbye"
}
```

### 4. Provide Descriptions

Always add descriptions to ARB entries:

```json
{
  "saveButton": "Save",
  "@saveButton": {
    "description": "Button label for saving changes"
  }
}
```

### 5. Test All Languages

Test your app in all supported languages to ensure:
- Text fits in UI elements
- RTL layout works correctly
- No missing translations
- Formatting displays correctly

### 6. Use Formatting Utilities

Always use `LocalizedFormatters` instead of hardcoding formats:

❌ **Don't:**
```dart
Text('${date.year}-${date.month}-${date.day}');
```

✅ **Do:**
```dart
Text(LocalizedFormatters.formatDate(date, locale: locale));
```

## Examples

### Complete Example: Localized Form

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localized_formatters.dart';

class LocalizedFormExample extends ConsumerStatefulWidget {
  @override
  ConsumerState<LocalizedFormExample> createState() => 
    _LocalizedFormExampleState();
}

class _LocalizedFormExampleState extends ConsumerState<LocalizedFormExample> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.name,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.nameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_selectedDate != null)
                Text(
                  LocalizedFormatters.formatDate(
                    _selectedDate!,
                    locale: locale,
                  ),
                ),
              ElevatedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                child: Text('Select Date'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.welcome)),
                    );
                  }
                },
                child: Text(l10n.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Example: Currency Display

```dart
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localized_formatters.dart';

class PriceDisplay extends ConsumerWidget {
  final double price;
  final String currencyCode;

  const PriceDisplay({
    required this.price,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeStateProvider);
    
    return Text(
      LocalizedFormatters.formatCurrency(
        price,
        locale: locale,
        currencyCode: currencyCode,
      ),
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
```

### Example: Pluralized Messages

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ItemList extends StatelessWidget {
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        Text(l10n.itemCount(items.length)),
        ...items.map((item) => ListTile(title: Text(item))),
      ],
    );
  }
}
```

## Troubleshooting

### Localization Not Working

1. **Check ARB files are valid JSON**
2. **Run `flutter gen-l10n`** after modifying ARB files
3. **Ensure `MaterialApp` has `localizationsDelegates`**
4. **Verify locale is set correctly in `localeStateProvider`**

### RTL Not Working

1. **Check `Directionality` widget is wrapping content**
2. **Verify locale is RTL language (ar, he, fa, ur)**
3. **Check `textDirectionProvider` is being watched**

### Missing Translations

1. **Add missing keys to all ARB files**
2. **Run `flutter gen-l10n`**
3. **Check for typos in key names**

## Additional Resources

- [Flutter Internationalization](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [ARB File Format](https://github.com/google/app-resource-bundle)
- [ICU Message Format](https://unicode-org.github.io/icu/userguide/format_parse/messages/)

