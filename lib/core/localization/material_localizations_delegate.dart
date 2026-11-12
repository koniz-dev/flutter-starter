import 'package:material_ui/material_ui.dart' as ui;

/// Standalone Material delegate for the SDK localization generator's namespace.
///
/// The `l10n.yaml` header binds its generated `GlobalMaterialLocalizations`
/// reference to this library prefix instead of the legacy SDK class. Keep this
/// adapter until the generator itself emits standalone design-library imports.
const ui.LocalizationsDelegate<ui.MaterialLocalizations> delegate =
    ui.GlobalMaterialLocalizations.delegate;
