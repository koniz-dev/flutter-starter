import 'package:cupertino_ui/cupertino_ui.dart' as ui;

/// Standalone Cupertino delegate for SDK-generated localization code.
///
/// The `l10n.yaml` header binds its generated `GlobalCupertinoLocalizations`
/// reference to this library prefix instead of the legacy SDK class. Keep this
/// adapter until the generator itself emits standalone design-library imports.
const ui.LocalizationsDelegate<ui.CupertinoLocalizations> delegate =
    ui.GlobalCupertinoLocalizations.delegate;
