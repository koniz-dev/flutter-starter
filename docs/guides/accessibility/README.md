# Accessibility

Accessibility implementation guides and documentation for the Flutter Starter app.

## Documentation

1. **[Guide](./guide.md)** - Comprehensive implementation guide with examples and best practices
2. **[Testing Procedures](./testing-procedures.md)** - Detailed testing procedures for accessibility
3. **[Quick Reference](./quick-reference.md)** - Quick reference for common patterns

## Quick Start

New to accessibility? Start here:

1. Read the [Quick Reference](./quick-reference.md) for common patterns
2. Review the [Guide](./guide.md) for comprehensive implementation details
3. Follow the [Testing Procedures](./testing-procedures.md) to verify accessibility

## Overview

The app implements comprehensive accessibility features following WCAG 2.1 Level AA guidelines, ensuring that the app is usable by everyone, including people with disabilities.

## Features

### ✅ Screen Reader Support
- Semantic labels for all interactive elements
- Proper heading structure
- Image alt text
- Form field labels
- State announcements (loading, errors, success)

### ✅ Touch Target Sizes
- Minimum 48x48 logical pixels for all interactive elements
- Proper spacing between touch targets (8px minimum)

### ✅ Color Contrast
- WCAG AA compliant contrast ratios
- 4.5:1 for normal text
- 3:1 for large text
- Helper functions to verify contrast

### ✅ Keyboard Navigation
- Full keyboard support
- Logical focus order
- Visible focus indicators
- No keyboard traps

### ✅ Text Scaling
- Respects system font size preferences
- UI adapts to larger text sizes

## Implementation

### Accessibility Widgets

The app provides accessible widget wrappers:

- `AccessibleButton` - Button with proper semantics and touch targets
- `AccessibleIconButton` - Icon button with semantic labels
- `AccessibleText` - Text with semantic information
- `AccessibleImage` - Image with alt text support
- `AccessibleProgressIndicator` - Progress indicator with semantic value

### Helper Functions

- `AccessibilityHelpers` - Contrast checking, color utilities
- `FocusAnnouncer` - Screen reader announcements
- `AccessibilityConstants` - WCAG-compliant constants

### Testing

- `AccessibilityTestHelpers` - Automated testing utilities
- Unit tests for accessibility helpers
- Widget tests for semantic labels
- Manual testing procedures

## Quick Examples

### Using Accessible Widgets

```dart
// Replace standard buttons
AccessibleButton(
  label: 'Submit',
  onPressed: () => _submit(),
  semanticLabel: 'Submit form',
)

// Replace icon buttons
AccessibleIconButton(
  icon: Icons.settings,
  semanticLabel: 'Settings',
  onPressed: () => _openSettings(),
)
```

### Adding Semantic Labels

```dart
Semantics(
  label: 'Submit button',
  hint: 'Submits the form',
  button: true,
  child: ElevatedButton(...),
)
```

## File Structure

```
lib/shared/accessibility/
├── accessibility_constants.dart      # WCAG constants
├── accessibility_helpers.dart         # Helper functions
├── accessibility_widgets.dart        # Accessible widgets
├── accessibility_test_helpers.dart   # Testing utilities
└── focus_announcer.dart              # Screen reader announcements

test/shared/accessibility/
└── accessibility_helpers_test.dart   # Unit tests
```

## Standards Compliance

- ✅ WCAG 2.1 Level AA
- ✅ Material Design Accessibility Guidelines
- ✅ Flutter Accessibility Best Practices
- ✅ Platform-specific guidelines (Android/iOS)

## Testing Checklist

Before releasing:

- [ ] All buttons have semantic labels
- [ ] All images have alt text
- [ ] All form fields have labels
- [ ] All headers are marked
- [ ] Touch targets are at least 48x48px
- [ ] Text contrast meets WCAG AA
- [ ] Keyboard navigation works
- [ ] Screen reader testing completed (TalkBack/VoiceOver)

## Resources

- [Flutter Accessibility Docs](https://docs.flutter.dev/accessibility-and-localization/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)

## Related Documentation

- [Common Tasks](../features/common-tasks.md) - Common development tasks
- [Internationalization Guide](../features/internationalization-guide.md) - i18n implementation
- [API Documentation](../../api/README.md) - Complete API reference

---

**Last Updated:** November 16, 2025

