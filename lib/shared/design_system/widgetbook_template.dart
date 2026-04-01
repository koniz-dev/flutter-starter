// TEMPLATE: Optional Widgetbook host; not the default `flutter run` target.
//
// IMPORTANT: To run the Design System Storybook
// 1. Run: flutter pub add widgetbook
// 2. Run: flutter pub add --dev widgetbook_generator
// 3. Uncomment the import below
// import 'package:widgetbook/widgetbook.dart';
// import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// Template entrypoint for the UI Component Library (Widgetbook).
///
/// Run this file directly (`flutter run -t lib/shared/design_system/widgetbook_template.dart`)
/// to view your components in isolation without launching the full app context.
library;

/*
// Execute `dart run build_runner build` to generate the widgetbook directories

void main() {
  runApp(const WidgetbookApp());
}

@widgetbook.App()
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [], // Will be populated dynamically when generator runs
      addons: [
        ThemeAddon(
          themes: [
            WidgetbookTheme(
              name: 'Light',
              data: ThemeData.light(),
            ),
            WidgetbookTheme(
              name: 'Dark',
              data: ThemeData.dark(),
            ),
          ],
          initialTheme: WidgetbookTheme(name: 'Light', data: ThemeData.light()),
        ),
        DeviceFrameAddon(
          devices: [
            Devices.ios.iPhone13,
            Devices.android.samsungGalaxyS20,
          ],
        ),
      ],
    );
  }
}
*/
