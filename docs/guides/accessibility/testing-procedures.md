# Accessibility Testing Procedures

This document outlines the procedures for testing accessibility in the Flutter Starter app.

## Table of Contents

1. [Pre-Testing Setup](#pre-testing-setup)
2. [Automated Testing](#automated-testing)
3. [Manual Testing](#manual-testing)
4. [Screen Reader Testing](#screen-reader-testing)
5. [Keyboard Navigation Testing](#keyboard-navigation-testing)
6. [Visual Testing](#visual-testing)
7. [Testing Checklist](#testing-checklist)

## Pre-Testing Setup

### Enable Semantics in Tests

Before running accessibility tests, ensure semantics are enabled:

```dart
void main() {
  testWidgets('accessibility test', (tester) async {
    // Semantics are enabled by default in testWidgets
    await tester.pumpWidget(MyApp());
    
    // Verify semantics
    final semantics = tester.getSemantics(find.byType(ElevatedButton));
    expect(semantics?.label, isNotNull);
  });
}
```

### Install Testing Tools

1. **Android:**
   - Install Accessibility Scanner from Google Play
   - Enable Developer Options
   - Enable TalkBack for testing

2. **iOS:**
   - Install Xcode
   - Enable Accessibility Inspector
   - Enable VoiceOver for testing

3. **Web:**
   - Install axe DevTools browser extension
   - Use Chrome DevTools Lighthouse

## Automated Testing

### Unit Tests for Accessibility Helpers

Test accessibility helper functions:

```dart
test('contrast ratio calculation', () {
  final ratio = AccessibilityHelpers.getContrastRatio(
    Colors.black,
    Colors.white,
  );
  expect(ratio, greaterThan(15.0));
});
```

### Widget Tests for Semantic Labels

Test that widgets have proper semantic labels:

```dart
testWidgets('button has semantic label', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AccessibleButton(
        label: 'Submit',
        onPressed: () {},
      ),
    ),
  );

  final semantics = tester.getSemantics(find.byType(AccessibleButton));
  expect(semantics?.label, contains('Submit'));
});
```

### Widget Tests for Touch Targets

Test that interactive elements meet minimum size requirements:

```dart
testWidgets('button meets minimum touch target', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AccessibleButton(
        label: 'Submit',
        onPressed: () {},
      ),
    ),
  );

  final renderObject = tester.getRenderObject(
    find.byType(AccessibleButton),
  );
  final size = renderObject?.size;
  
  expect(size?.width, greaterThanOrEqualTo(48.0));
  expect(size?.height, greaterThanOrEqualTo(48.0));
});
```

### Widget Tests for Contrast Ratios

Test that text colors meet contrast requirements:

```dart
test('text meets contrast requirements', () {
  final meetsAA = AccessibilityHelpers.meetsContrastRatioAA(
    AppColors.textPrimary,
    AppColors.background,
  );
  expect(meetsAA, isTrue);
});
```

## Manual Testing

### Basic Accessibility Checks

1. **Enable Screen Reader:**
   - Navigate through the app using screen reader gestures
   - Verify all interactive elements are announced
   - Check that labels are clear and descriptive

2. **Test Touch Targets:**
   - Verify all buttons are at least 48x48 pixels
   - Check spacing between interactive elements
   - Ensure no targets are too close together

3. **Test Text Scaling:**
   - Increase system font size
   - Verify app respects font size changes
   - Check that UI doesn't break with large text

4. **Test High Contrast:**
   - Enable high contrast mode (if available)
   - Verify all text is readable
   - Check that interactive elements are visible

## Screen Reader Testing

### Android TalkBack

1. **Enable TalkBack:**
   - Settings > Accessibility > TalkBack
   - Toggle TalkBack on

2. **Navigate the App:**
   - Swipe right: Move to next element
   - Swipe left: Move to previous element
   - Double-tap: Activate element
   - Swipe up then right: Open TalkBack menu

3. **Verify Announcements:**
   - All buttons announce their labels
   - Images announce their alt text
   - Form fields announce their labels
   - Headers are properly identified
   - Loading states are announced
   - Error messages are announced

4. **Check Navigation:**
   - Verify logical navigation order
   - Check that all content is reachable
   - Ensure no elements are skipped

### iOS VoiceOver

1. **Enable VoiceOver:**
   - Settings > Accessibility > VoiceOver
   - Toggle VoiceOver on

2. **Navigate the App:**
   - Swipe right: Move to next element
   - Swipe left: Move to previous element
   - Double-tap: Activate element
   - Two-finger tap: Pause/resume VoiceOver

3. **Verify Announcements:**
   - All buttons announce their labels
   - Images announce their alt text
   - Form fields announce their labels
   - Headers are properly identified
   - Loading states are announced
   - Error messages are announced

4. **Check Navigation:**
   - Use Rotor to navigate by headings, links, etc.
   - Verify logical navigation order
   - Check that all content is reachable

## Keyboard Navigation Testing

### Desktop/Web Testing

1. **Enable Keyboard Navigation:**
   - Connect physical keyboard or use on-screen keyboard
   - Ensure focus indicators are visible

2. **Navigate the App:**
   - Tab: Move to next element
   - Shift+Tab: Move to previous element
   - Enter/Space: Activate element
   - Arrow keys: Navigate within groups

3. **Verify Navigation:**
   - All interactive elements are reachable
   - Focus order is logical
   - Focus indicators are visible
   - No keyboard traps (can't escape from a section)

4. **Test Form Navigation:**
   - Tab through form fields in order
   - Verify labels are associated with fields
   - Check error messages are announced
   - Test form submission with keyboard

### Mobile Keyboard Testing

1. **Enable On-Screen Keyboard:**
   - Connect external keyboard or use on-screen keyboard
   - Enable keyboard navigation mode

2. **Navigate the App:**
   - Use Tab to move between elements
   - Verify focus is visible
   - Check that all elements are reachable

## Visual Testing

### Contrast Testing

1. **Check Text Contrast:**
   - Use `AccessibilityHelpers.getContrastRatio()` to calculate ratios
   - Verify normal text meets 4.5:1 ratio
   - Verify large text meets 3:1 ratio
   - Test in both light and dark themes

2. **Check Interactive Elements:**
   - Verify buttons have sufficient contrast
   - Check that disabled states are distinguishable
   - Ensure focus indicators are visible

### Touch Target Testing

1. **Measure Touch Targets:**
   - Use Flutter Inspector to measure widget sizes
   - Verify all buttons are at least 48x48 pixels
   - Check spacing between targets (minimum 8 pixels)

2. **Test on Different Devices:**
   - Test on phones (small screens)
   - Test on tablets (medium screens)
   - Verify targets are appropriately sized

## Testing Checklist

### Pre-Release Checklist

- [ ] All buttons have semantic labels
- [ ] All images have alt text (or marked decorative)
- [ ] All form fields have associated labels
- [ ] All headers are properly marked
- [ ] All interactive elements meet minimum touch target size
- [ ] All text meets contrast ratio requirements
- [ ] Keyboard navigation works for all features
- [ ] Screen reader testing completed on Android
- [ ] Screen reader testing completed on iOS
- [ ] Focus indicators are visible
- [ ] Loading states are announced
- [ ] Error messages are announced
- [ ] Success messages are announced
- [ ] Text scaling works correctly
- [ ] High contrast mode works (if applicable)

### Feature-Specific Checklist

#### Forms
- [ ] All fields have labels
- [ ] Error messages are associated with fields
- [ ] Required fields are indicated
- [ ] Form can be submitted with keyboard
- [ ] Validation errors are announced

#### Navigation
- [ ] All navigation elements are accessible
- [ ] Current page is announced
- [ ] Navigation order is logical
- [ ] Back button is accessible

#### Lists
- [ ] List items have semantic labels
- [ ] List length is announced
- [ ] Current position is announced
- [ ] List items are actionable

#### Images
- [ ] All images have alt text
- [ ] Decorative images are marked
- [ ] Images are announced appropriately

#### Buttons
- [ ] All buttons have labels
- [ ] Button states are announced (enabled/disabled/loading)
- [ ] Button actions are clear
- [ ] Buttons meet minimum touch target size

## Running Tests

### Run All Accessibility Tests

```bash
flutter test test/shared/accessibility/
```

### Run Specific Test File

```bash
flutter test test/shared/accessibility/accessibility_helpers_test.dart
```

### Run Tests with Coverage

```bash
flutter test --coverage test/shared/accessibility/
```

## Reporting Issues

When reporting accessibility issues, include:

1. **Device/Platform:** Android, iOS, Web, Desktop
2. **Screen Reader:** TalkBack, VoiceOver, None
3. **Issue Description:** What's not working
4. **Expected Behavior:** What should happen
5. **Steps to Reproduce:** How to trigger the issue
6. **Screenshots/Videos:** If applicable

## Continuous Improvement

Accessibility is an ongoing process. Regularly:

1. Review new features for accessibility
2. Test with actual screen readers
3. Gather feedback from users with disabilities
4. Update tests as features change
5. Stay updated with accessibility guidelines

