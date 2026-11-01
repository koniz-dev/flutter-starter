import 'package:flutter/widgets.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// A screen the signed-in home screen links to.
///
/// A feature declares its own destination beside its routes, and
/// `routes_registry.dart` lists the destinations of the features it
/// registers. The home screen therefore names no feature, and removing a
/// feature's route module removes its entry with it.
@immutable
class HomeDestination {
  /// Creates a destination that opens [location].
  const HomeDestination({
    required this.id,
    required this.icon,
    required this.label,
    required this.location,
  });

  /// Stable id; `UiKeys.homeDestination(id)` keys the entry.
  final String id;

  /// Leading icon of the entry.
  final IconData icon;

  /// Localized label of the entry.
  final String Function(AppLocalizations l10n) label;

  /// Route pushed on top of home when the entry is tapped.
  final String location;
}
