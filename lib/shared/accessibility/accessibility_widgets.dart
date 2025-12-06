import 'package:flutter/material.dart';

import 'package:flutter_starter/shared/accessibility/accessibility_helpers.dart';

/// Accessible button widget with proper semantics and touch targets
///
/// Ensures minimum touch target size, proper semantic labels, and
/// accessibility features for screen readers.
class AccessibleButton extends StatelessWidget {
  /// Creates an [AccessibleButton] widget
  const AccessibleButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.semanticLabel,
    this.semanticHint,
    this.style,
    this.child,
  });

  /// Button label text
  final String label;

  /// Callback when button is pressed
  final VoidCallback? onPressed;

  /// Optional icon to display
  final IconData? icon;

  /// Whether the button is in loading state
  final bool isLoading;

  /// Whether the button is enabled
  final bool isEnabled;

  /// Custom semantic label for screen readers
  ///
  /// If not provided, uses [label] with state information.
  final String? semanticLabel;

  /// Semantic hint for screen readers
  ///
  /// Provides additional context about what the button does.
  final String? semanticHint;

  /// Button style
  final ButtonStyle? style;

  /// Custom child widget
  ///
  /// If provided, overrides the default button content.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel =
        semanticLabel ??
        AccessibilityHelpers.getButtonSemanticLabel(
          label,
          isEnabled: isEnabled,
          isLoading: isLoading,
        );

    final button = ElevatedButton(
      onPressed: (isEnabled && !isLoading) ? onPressed : null,
      style: style,
      child:
          child ??
          (isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : (icon != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon),
                          const SizedBox(width: 8),
                          Text(label),
                        ],
                      )
                    : Text(label))),
    );

    return Semantics(
      label: effectiveLabel,
      hint: semanticHint,
      button: true,
      enabled: isEnabled && !isLoading,
      child: AccessibilityHelpers.ensureMinTouchTarget(button),
    );
  }
}

/// Accessible icon button with proper semantics
///
/// Ensures minimum touch target size and proper semantic labels.
class AccessibleIconButton extends StatelessWidget {
  /// Creates an [AccessibleIconButton] widget
  const AccessibleIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.tooltip,
    this.isEnabled = true,
    this.semanticHint,
    this.iconSize,
    this.color,
  });

  /// Icon to display
  final IconData icon;

  /// Callback when button is pressed
  final VoidCallback? onPressed;

  /// Semantic label for screen readers (required)
  final String semanticLabel;

  /// Tooltip text (shown on long press)
  final String? tooltip;

  /// Whether the button is enabled
  final bool isEnabled;

  /// Semantic hint for screen readers
  final String? semanticHint;

  /// Icon size
  final double? iconSize;

  /// Icon color
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      icon: Icon(icon, size: iconSize, color: color),
      onPressed: isEnabled ? onPressed : null,
      tooltip: tooltip ?? semanticLabel,
    );

    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      enabled: isEnabled,
      child: AccessibilityHelpers.ensureMinTouchTarget(button),
    );
  }
}

/// Accessible text widget with proper semantics
///
/// Wraps text with semantic information for screen readers.
class AccessibleText extends StatelessWidget {
  /// Creates an [AccessibleText] widget
  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.semanticLabel,
    this.excludeSemantics = false,
  });

  /// Text to display
  final String text;

  /// Text style
  final TextStyle? style;

  /// Text alignment
  final TextAlign? textAlign;

  /// Maximum number of lines
  final int? maxLines;

  /// Text overflow behavior
  final TextOverflow? overflow;

  /// Custom semantic label for screen readers
  ///
  /// If not provided, uses [text].
  final String? semanticLabel;

  /// Whether to exclude this text from semantics
  ///
  /// Set to true for decorative text.
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final widget = Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );

    if (excludeSemantics) {
      return ExcludeSemantics(child: widget);
    }

    return Semantics(
      label: semanticLabel ?? text,
      child: widget,
    );
  }
}

/// Accessible image widget with proper alt text
///
/// Provides semantic labels for images to support screen readers.
class AccessibleImage extends StatelessWidget {
  /// Creates an [AccessibleImage] widget
  const AccessibleImage({
    required this.image,
    required this.semanticLabel,
    super.key,
    this.width,
    this.height,
    this.fit,
    this.isDecorative = false,
  });

  /// Image widget
  final Widget image;

  /// Semantic label (alt text) for screen readers
  ///
  /// Required unless [isDecorative] is true.
  final String semanticLabel;

  /// Image width
  final double? width;

  /// Image height
  final double? height;

  /// Image fit
  final BoxFit? fit;

  /// Whether the image is decorative
  ///
  /// If true, the image will be hidden from screen readers.
  final bool isDecorative;

  @override
  Widget build(BuildContext context) {
    final widget = SizedBox(
      width: width,
      height: height,
      child: image,
    );

    if (isDecorative) {
      return ExcludeSemantics(child: widget);
    }

    return Semantics(
      label: semanticLabel,
      image: true,
      child: widget,
    );
  }
}

/// Accessible progress indicator with semantic value
///
/// Provides proper semantic information for progress indicators.
class AccessibleProgressIndicator extends StatelessWidget {
  /// Creates an [AccessibleProgressIndicator] widget
  const AccessibleProgressIndicator({
    super.key,
    this.value,
    this.backgroundColor,
    this.valueColor,
    this.semanticLabel,
    this.semanticValue,
  });

  /// Progress value (0.0 to 1.0)
  final double? value;

  /// Background color
  final Color? backgroundColor;

  /// Value color
  final Color? valueColor;

  /// Semantic label for screen readers
  final String? semanticLabel;

  /// Semantic value for screen readers
  ///
  /// If not provided and [value] is set, generates from value.
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final effectiveValue =
        semanticValue ??
        (value != null
            ? AccessibilityHelpers.getProgressSemanticValue(value!)
            : null);

    return Semantics(
      label: semanticLabel ?? 'Progress indicator',
      value: effectiveValue,
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: backgroundColor,
        valueColor: valueColor != null
            ? AlwaysStoppedAnimation<Color>(valueColor!)
            : null,
      ),
    );
  }
}

/// Focus management widget
///
/// Helps manage focus for keyboard navigation and screen readers.
class FocusManager extends StatelessWidget {
  /// Creates a [FocusManager] widget
  const FocusManager({
    required this.child,
    super.key,
    this.autofocus = false,
    this.onFocusChange,
  });

  /// Child widget
  final Widget child;

  /// Whether to autofocus this widget
  final bool autofocus;

  /// Callback when focus changes
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      child: child,
    );
  }
}
