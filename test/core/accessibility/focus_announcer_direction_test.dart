// Regression tests for koniz-dev/flutter-starter#65, criterion 6.
//
// `sendAnnouncement` used to be called with a literal `TextDirection.ltr` for
// every locale, and the announcement strings were hardcoded English. These
// tests intercept the platform message that actually leaves the framework, so
// they assert what a screen reader would really be handed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_starter/core/accessibility/focus_announcer.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget _appIn(Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: LocalizationService.supportedLocales,
    home: const Scaffold(body: _Probe()),
  );
}

void main() {
  late List<Map<Object?, Object?>> announcements;

  setUp(() {
    announcements = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
          message,
        ) async {
          if (message is Map && message['type'] == 'announce') {
            announcements.add(message['data']! as Map<Object?, Object?>);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        );
  });

  group('FocusAnnouncer text direction', () {
    testWidgets('announces right-to-left under ar', (tester) async {
      await tester.pumpWidget(_appIn(const Locale('ar')));
      final context = tester.element(find.byType(_Probe));

      FocusAnnouncer.announce(context, 'رسالة');
      await tester.pump();

      expect(announcements, hasLength(1));
      expect(announcements.single['message'], 'رسالة');
      expect(
        announcements.single['textDirection'],
        TextDirection.rtl.index,
        reason: 'an Arabic announcement must not be sent as ltr',
      );
      expect(FocusAnnouncer.textDirectionOf(context), TextDirection.rtl);
    });

    testWidgets('announces left-to-right under en', (tester) async {
      await tester.pumpWidget(_appIn(const Locale('en')));
      final context = tester.element(find.byType(_Probe));

      FocusAnnouncer.announce(context, 'message');
      await tester.pump();

      expect(announcements.single['textDirection'], TextDirection.ltr.index);
      expect(FocusAnnouncer.textDirectionOf(context), TextDirection.ltr);
    });
  });

  group('FocusAnnouncer message localization', () {
    testWidgets('focus and page announcements follow the locale', (
      tester,
    ) async {
      final vi = lookupAppLocalizations(const Locale('vi'));
      await tester.pumpWidget(_appIn(const Locale('vi')));
      final context = tester.element(find.byType(_Probe));

      FocusAnnouncer.announceFocusChange(context, 'Nut');
      FocusAnnouncer.announcePageChange(context, 'Trang chu');
      await tester.pump();

      expect(announcements.map((a) => a['message']).toList(), [
        vi.focusedOn('Nut'),
        vi.navigatedTo('Trang chu'),
      ]);
      for (final announcement in announcements) {
        expect(announcement['message'].toString(), isNot(contains('Focused')));
        expect(
          announcement['message'].toString(),
          isNot(contains('Navigated')),
        );
      }
    });
  });
}
