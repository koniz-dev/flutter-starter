# Accessibility Quick Reference

A quick reference guide for implementing accessibility in the Flutter Starter app.

## Quick Start

### 1. Use Accessible Widgets

Replace standard widgets with accessible versions:

```dart
// Instead of ElevatedButton
AccessibleButton(
  label: 'Submit',
  onPressed: () => _submit(),
)

// Instead of IconButton
AccessibleIconButton(
  icon: Icons.settings,
  semanticLabel: 'Settings',
  onPressed: () => _openSettings(),
)

// Instead of Text
AccessibleText(
  'Welcome',
  style: Theme.of(context).textTheme.headlineMedium,
)
```

### 2. Add Semantic Labels

Always provide semantic labels for interactive elements:

```dart
Semantics(
  label: 'Submit button',
  hint: 'Submits the form',
  button: true,
  child: ElevatedButton(...),
)
```

### 3. Mark Headers

Mark section headers:

```dart
Semantics(
  header: true,
  child: Text('Section Title'),
)
```

### 4. Ensure Minimum Touch Targets

All buttons automatically meet minimum size (48x48px) when using `AccessibleButton`.

## Common Patterns

### Buttons

```dart
AccessibleButton(
  label: 'Submit',
  onPressed: () => _submit(),
  isLoading: false,
  isEnabled: true,
  semanticLabel: 'Submit form',
  semanticHint: 'Submits the current form data',
)
```

### Icon Buttons

```dart
AccessibleIconButton(
  icon: Icons.delete,
  semanticLabel: 'Delete item',
  tooltip: 'Delete',
  onPressed: () => _delete(),
)
```

### Images

```dart
AccessibleImage(
  image: Image.asset('assets/logo.png'),
  semanticLabel: 'Company logo',
  isDecorative: false,
)
```

### Form Fields

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Email',
    hintText: 'Enter your email',
  ),
)
```

### Error Messages

```dart
Semantics(
  label: 'Error: Email is required',
  liveRegion: true,
  child: Text('Email is required'),
)
```

### Loading States

```dart
AccessibleButton(
  label: 'Submit',
  onPressed: () => _submit(),
  isLoading: true, // Automatically announces "Loading, Submit"
)
```

### Progress Indicators

```dart
AccessibleProgressIndicator(
  value: 0.5,
  semanticLabel: 'Upload progress',
)
```

## Testing

### Quick Test

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
    AccessibilityTestHelpers.hasSemanticLabel(
      tester,
      find.byType(AccessibleButton),
    ),
    isTrue,
  );
});
```

### Manual Testing

1. Enable screen reader (TalkBack/VoiceOver)
2. Navigate through the app
3. Verify all elements are announced
4. Check that labels are clear

## Checklist

Before releasing:

- [ ] All buttons have semantic labels
- [ ] All images have alt text
- [ ] All form fields have labels
- [ ] All headers are marked
- [ ] Touch targets are at least 48x48px
- [ ] Text contrast meets WCAG AA (4.5:1)
- [ ] Keyboard navigation works
- [ ] Screen reader testing completed

## Constants

```dart
// Minimum touch target size
AccessibilityConstants.minTouchTargetSize // 48.0

// Minimum contrast ratios
AccessibilityConstants.minContrastRatioNormal // 4.5
AccessibilityConstants.minContrastRatioLarge // 3.0
```

## Helpers

```dart
// Check contrast ratio
AccessibilityHelpers.getContrastRatio(foreground, background)

// Check if meets WCAG AA
AccessibilityHelpers.meetsContrastRatioAA(foreground, background)

// Get accessible text color
AccessibilityHelpers.getAccessibleTextColor(background)

// Announce to screen readers
FocusAnnouncer.announce(context, 'Message')
FocusAnnouncer.announcePageChange(context, 'Settings')
FocusAnnouncer.announceActionResult(context, 'Saved')
```

## Resources

- **Full Guide:** [guide.md](./guide.md)
- **Testing Procedures:** [testing-procedures.md](./testing-procedures.md)
- **Code:** `lib/shared/accessibility/`

## Common Mistakes

❌ **Don't:**
```dart
IconButton(icon: Icon(Icons.delete), onPressed: () {})
```

✅ **Do:**
```dart
AccessibleIconButton(
  icon: Icons.delete,
  semanticLabel: 'Delete',
  onPressed: () {},
)
```

❌ **Don't:**
```dart
Text('Submit', style: TextStyle(fontSize: 16))
```

✅ **Do:**
```dart
AccessibleText(
  'Submit',
  style: Theme.of(context).textTheme.bodyLarge,
)
```

❌ **Don't:**
```dart
Image.asset('assets/logo.png')
```

✅ **Do:**
```dart
AccessibleImage(
  image: Image.asset('assets/logo.png'),
  semanticLabel: 'Company logo',
)
```

