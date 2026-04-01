// Lightweight boundary contract file; repetitive per-member docs are omitted.
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

/// Semantic design tokens contract used by theme adapters.
abstract class AppDesignTokens {
  Color get primary;
  Color get secondary;
  Color get background;
  Color get surface;
  Color get error;

  Color get textPrimary;
  Color get textSecondary;
  Color get textOnPrimary;

  TextStyle get displayLarge;
  TextStyle get displayMedium;
  TextStyle get bodyLarge;
  TextStyle get bodyMedium;
  TextStyle get labelLarge;
}
