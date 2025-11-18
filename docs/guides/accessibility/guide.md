# Accessibility Guide

This guide provides comprehensive information about accessibility implementation in the Flutter Starter app, including best practices, testing procedures, and common patterns.

## Table of Contents

1. [Overview](#overview)
2. [Accessibility Standards](#accessibility-standards)
3. [Implementation](#implementation)
4. [Testing](#testing)
5. [Common Patterns](#common-patterns)
6. [Best Practices](#best-practices)
7. [Resources](#resources)

## Overview

Accessibility ensures that your app can be used by everyone, including people with disabilities. This app follows WCAG 2.1 Level AA guidelines and implements Flutter's accessibility features to support:

- **Screen readers** (TalkBack on Android, VoiceOver on iOS)
- **Keyboard navigation**
- **High contrast modes**
- **Text scaling**
- **Touch target sizes**

## Accessibility Standards

### WCAG 2.1 Compliance

The app follows WCAG 2.1 Level AA standards:

- **Contrast Ratios:**
  - Normal text: 4.5:1 minimum
  - Large text (18pt+ or 14pt+ bold): 3:1 minimum
  - Enhanced (AAA): 7:1 for normal text

- **Touch Targets:**
  - Minimum size: 48x48 logical pixels
  - Minimum spacing: 8 logical pixels between targets

- **Semantic Labels:**
  - All interactive elements have descriptive labels
  - Images have alt text
  - Form fields have associated labels

### Flutter Accessibility Features

- **Semantics API:** Provides semantic information to assistive technologies
- **Focus Management:** Supports keyboard navigation
- **Text Scaling:** Respects system font size preferences
- **Screen Reader Support:** Works with TalkBack and VoiceOver

## Implementation

### Accessibility Widgets

The app provides several accessible widget wrappers:

#### AccessibleButton

A button widget with proper semantics and touch targets:

```dart
AccessibleButton(
  label: 'Submit',
  onPressed: () => _handleSubmit(),
  semanticLabel: 'Submit form',
  semanticHint: 'Submits the current form data',
  isLoading: false,
  isEnabled: true,
)
```

#### AccessibleIconButton

An icon button with proper semantic labels:

```dart
AccessibleIconButton(
  icon: Icons.settings,
  onPressed: () => _openSettings(),
  semanticLabel: 'Settings',
  tooltip: 'Open settings',
  semanticHint: 'Opens application settings',
)
```

#### AccessibleText

Text widget with semantic information:

```dart
AccessibleText(
  'Welcome to the app',
  style: Theme.of(context).textTheme.headlineMedium,
  semanticLabel: 'Welcome message',
)
```

#### AccessibleImage

Image widget with alt text:

```dart
AccessibleImage(
  image: Image.asset('assets/logo.png'),
  semanticLabel: 'Company logo',
  isDecorative: false,
)
```

### Semantic Labels

Always provide semantic labels for interactive elements:

```dart
Semantics(
  label: 'Submit button',
  hint: 'Submits the form',
  button: true,
  child: ElevatedButton(
    onPressed: () => _submit(),
    child: Text('Submit'),
  ),
)
```

### Headers

Mark headers with semantic information:

```dart
Semantics(
  header: true,
  child: Text(
    'Section Title',
    style: Theme.of(context).textTheme.headlineMedium,
  ),
)
```

### Form Fields

Ensure form fields have proper labels:

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Email',
    hintText: 'Enter your email address',
  ),
  // Flutter automatically associates label with field
)
```

### Focus Management

Use Focus widgets to manage keyboard navigation:

```dart
Focus(
  autofocus: true,
  onFocusChange: (hasFocus) {
    if (hasFocus) {
      FocusAnnouncer.announceFocusChange(context, 'Email field');
    }
  },
  child: TextField(
    decoration: InputDecoration(labelText: 'Email'),
  ),
)
```

### Focus Announcements

Announce important changes to screen readers:

```dart
// Announce page navigation
FocusAnnouncer.announcePageChange(context, 'Settings Screen');

// Announce action results
FocusAnnouncer.announceActionResult(context, 'Form submitted successfully');

// Announce focus changes
FocusAnnouncer.announceFocusChange(context, 'Submit button');
```

## Testing

### Automated Testing

Use the accessibility test helpers to verify accessibility features:

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

  expect(
    AccessibilityTestHelpers.hasSemanticLabel(tester, find.text('Submit')),
    isTrue,
  );
});
```

### Manual Testing Checklist

#### Screen Reader Testing

1. **Enable Screen Reader:**
   - Android: Settings > Accessibility > TalkBack
   - iOS: Settings > Accessibility > VoiceOver

2. **Navigate the App:**
   - Swipe right to move forward
   - Swipe left to move backward
   - Double-tap to activate
   - Verify all interactive elements are announced

3. **Check Semantic Labels:**
   - All buttons have descriptive labels
   - Images have alt text
   - Form fields have associated labels
   - Headers are properly marked

#### Keyboard Navigation

1. **Enable Keyboard Navigation:**
   - Connect a physical keyboard or use on-screen keyboard
   - Use Tab to navigate between elements
   - Use Enter/Space to activate

2. **Verify Navigation:**
   - All interactive elements are reachable
   - Focus order is logical
   - Focus indicators are visible

#### Touch Target Testing

1. **Verify Touch Targets:**
   - All buttons are at least 48x48 pixels
   - Spacing between targets is at least 8 pixels
   - Targets are not too close together

#### Contrast Testing

1. **Check Text Contrast:**
   - Use accessibility helpers to verify contrast ratios
   - Test in both light and dark themes
   - Verify all text meets WCAG AA standards

2. **Tools:**
   - Use `AccessibilityHelpers.getContrastRatio()` to check ratios
   - Use `AccessibilityHelpers.meetsContrastRatioAA()` to verify compliance

### Testing Tools

#### Flutter Inspector

Use Flutter Inspector to view the semantics tree:

1. Run app in debug mode
2. Open Flutter Inspector
3. Enable "Show Semantics" overlay
4. Verify semantic labels are present

#### Accessibility Scanner

Use accessibility testing tools:

- **Android:** Accessibility Scanner app
- **iOS:** Accessibility Inspector (Xcode)
- **Web:** axe DevTools, Lighthouse

## Common Patterns

### Loading States

Announce loading states to screen readers:

```dart
AccessibleButton(
  label: 'Submit',
  onPressed: () => _submit(),
  isLoading: true,
  // Automatically announces "Loading, Submit"
)
```

### Error Messages

Provide accessible error messages:

```dart
Semantics(
  label: 'Error: Email is required',
  liveRegion: true, // Announces immediately
  child: Text(
    'Email is required',
    style: TextStyle(color: Colors.red),
  ),
)
```

### Success Messages

Announce success messages:

```dart
FocusAnnouncer.announceActionResult(
  context,
  'Form submitted successfully',
);
```

### Disabled States

Indicate disabled states:

```dart
AccessibleButton(
  label: 'Submit',
  onPressed: null, // Disabled
  isEnabled: false,
  // Automatically announces "Submit, Disabled"
)
```

### Progress Indicators

Provide semantic information for progress:

```dart
AccessibleProgressIndicator(
  value: 0.5,
  semanticLabel: 'Upload progress',
  semanticValue: '50 percent',
)
```

### Lists

Mark list items properly:

```dart
ListView(
  children: items.map((item) {
    return Semantics(
      label: item.title,
      child: ListTile(
        title: Text(item.title),
        subtitle: Text(item.description),
      ),
    );
  }).toList(),
)
```

## Best Practices

### 1. Always Provide Semantic Labels

Every interactive element should have a semantic label:

```dart
// Good
AccessibleIconButton(
  icon: Icons.delete,
  semanticLabel: 'Delete item',
  onPressed: () => _delete(),
)

// Bad
IconButton(
  icon: Icon(Icons.delete),
  onPressed: () => _delete(),
)
```

### 2. Use Descriptive Labels

Labels should be clear and descriptive:

```dart
// Good
semanticLabel: 'Delete selected item'

// Bad
semanticLabel: 'Button'
```

### 3. Provide Hints When Needed

Use hints to provide additional context:

```dart
AccessibleButton(
  label: 'Submit',
  semanticHint: 'Submits the form and saves your data',
  onPressed: () => _submit(),
)
```

### 4. Mark Decorative Elements

Hide decorative elements from screen readers:

```dart
AccessibleImage(
  image: Image.asset('assets/decoration.png'),
  semanticLabel: '',
  isDecorative: true,
)
```

### 5. Ensure Minimum Touch Targets

All interactive elements should meet minimum size requirements:

```dart
// Automatically handled by AccessibleButton
AccessibleButton(
  label: 'Submit',
  onPressed: () => _submit(),
)
```

### 6. Test with Screen Readers

Always test with actual screen readers:

- Test on both Android (TalkBack) and iOS (VoiceOver)
- Verify all functionality is accessible
- Check that labels are clear and helpful

### 7. Maintain Logical Focus Order

Ensure keyboard navigation follows a logical order:

```dart
FocusTraversalGroup(
  child: Column(
    children: [
      TextField(keyboardType: TextInputType.emailAddress),
      TextField(keyboardType: TextInputType.visiblePassword),
      ElevatedButton(onPressed: () => _submit()),
    ],
  ),
)
```

### 8. Support Text Scaling

Don't hardcode font sizes; use theme text styles:

```dart
// Good
Text('Hello', style: Theme.of(context).textTheme.bodyLarge)

// Bad
Text('Hello', style: TextStyle(fontSize: 16))
```

### 9. Provide Alternative Text for Images

All images should have descriptive alt text:

```dart
AccessibleImage(
  image: Image.asset('assets/logo.png'),
  semanticLabel: 'Company logo showing a stylized letter A',
)
```

### 10. Announce Important Changes

Use announcements for important state changes:

```dart
// When navigation occurs
FocusAnnouncer.announcePageChange(context, 'Settings');

// When actions complete
FocusAnnouncer.announceActionResult(context, 'Saved successfully');
```

## Resources

### Documentation

- [Flutter Accessibility Documentation](https://docs.flutter.dev/accessibility-and-localization/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)

### Tools

- **Flutter Inspector:** Built-in tool for viewing semantics tree
- **Accessibility Scanner (Android):** Google's accessibility testing app
- **Accessibility Inspector (iOS):** Xcode tool for testing accessibility
- **axe DevTools:** Browser extension for web accessibility testing

### Testing

- **TalkBack (Android):** Built-in screen reader
- **VoiceOver (iOS):** Built-in screen reader
- **Accessibility Test Helpers:** Custom helpers in `accessibility_test_helpers.dart`

### Code Examples

See the following files for implementation examples:

- `lib/shared/accessibility/accessibility_widgets.dart` - Accessible widget implementations
- `lib/shared/accessibility/accessibility_helpers.dart` - Helper functions
- `lib/features/auth/presentation/widgets/auth_button.dart` - Example of accessible button
- `lib/shared/widgets/error_widget.dart` - Example of accessible error handling

## Conclusion

Accessibility is an ongoing process. Always:

1. Test with screen readers
2. Verify touch target sizes
3. Check contrast ratios
4. Provide semantic labels
5. Test keyboard navigation
6. Follow WCAG guidelines

For questions or issues, refer to the Flutter accessibility documentation or the accessibility test helpers in the codebase.

