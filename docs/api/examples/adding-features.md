# Adding a New Feature

Scaffold a feature slice, give it a data source, make its screen reachable,
and test it. The example feature is `notes` throughout; substitute your own
name (snake_case) everywhere it appears.

## Step 1: Scaffold the slice

```bash
./scripts/dev/create_feature.sh notes
```

`mason make feature_clean --feature_name notes` produces the same files if you
use Mason. Either way you get:

| File | What it is |
|---|---|
| `lib/features/notes/domain/entities/notes.dart` | The entity (`Notes`), with an `id` to start from |
| `lib/features/notes/domain/repositories/notes_repository.dart` | The repository contract the domain depends on |
| `lib/features/notes/domain/usecases/get_notes_by_id_usecase.dart` | One use case, `GetNotesByIdUseCase` |
| `lib/features/notes/data/models/notes_model.dart` | JSON model mapping to the entity |
| `lib/features/notes/data/datasources/notes_remote_datasource.dart` | `NotesRemoteDataSource`, an interface with `fetchById` |
| `lib/features/notes/data/repositories/notes_repository_impl.dart` | Repository over the data source, returning `Result` |
| `lib/features/notes/di/notes_providers.dart` | Riverpod providers for the data source, repository and use case |
| `lib/features/notes/presentation/providers/notes_provider.dart` | `notesStateProvider`, the screen's state |
| `lib/features/notes/presentation/screens/notes_screen.dart` | `NotesScreen`, which takes the `id` to load |
| `test/features/notes/notes_repository_impl_test.dart` | A repository test with a fake data source |

Check that the scaffold is sound before you change anything:

```bash
flutter analyze && flutter test test/features/<name>   # here: test/features/notes
```

The scaffold creates **no route and no data source implementation**. The next
two steps add them; until then the screen is unreachable and loading it
throws `UnimplementedError`.

## Step 2: Shape the domain and model

Add your fields to the `Notes` entity and to `NotesModel` (its `fromJson` /
`toJson` and its mapping to the entity), and add use cases next to
`GetNotesByIdUseCase` as you need them. The domain layer imports nothing from
`data/` or `presentation/`; `test/tooling/import_rules_test.dart` fails if it does.

## Step 3: Implement the remote data source

`notesRemoteDataSourceProvider` in `lib/features/notes/di/notes_providers.dart`
deliberately throws `UnimplementedError`. Implement the interface over
`ApiClient` in `notes_remote_datasource.dart`:

```dart
import 'package:flutter_starter/core/network/api_client.dart';

/// [NotesRemoteDataSource] over [ApiClient]: `GET /notes/<id>`.
final class NotesRemoteDataSourceImpl implements NotesRemoteDataSource {
  /// Creates a [NotesRemoteDataSourceImpl].
  const NotesRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> fetchById(String id) async {
    final response = await _apiClient.get('/notes/$id');
    return response.data as Map<String, dynamic>;
  }
}
```

Then make the provider build it, in place of the `throw`:

```dart
import 'package:flutter_starter/core/di/providers.dart';

final notesRemoteDataSourceProvider = Provider<NotesRemoteDataSource>((ref) {
  return NotesRemoteDataSourceImpl(ref.watch(apiClientProvider));
});
```

The path is relative to `BASE_URL` plus `/v1`, so this calls
`<BASE_URL>/v1/notes/<id>`; see
[Connecting Your Backend](../../guides/onboarding/getting-started.md#connecting-your-backend).
In a test, override `notesRemoteDataSourceProvider` in the `ProviderScope` (or
`ProviderContainer`) with a fake instead.

<!-- symbol: lib/core/di/providers.dart apiClientProvider -->
<!-- symbol: lib/core/network/api_client.dart ApiClient -->

## Step 4: Add a route and navigate to it

Four edits make the screen reachable once signed in. The
[routing guide](../../guides/features/routing-guide.md) explains the pieces.

1. **Route constants** in `lib/core/routing/app_routes.dart`, inside
   `AppRoutes`:

   ```dart
   static const String notes = '/notes';
   static const String notesName = 'notes';
   ```

2. **A route module**, in a new `routing/` directory,
   `lib/features/notes/routing/notes_routes.dart`:

   ```dart
   import 'package:flutter_riverpod/flutter_riverpod.dart';
   import 'package:flutter_starter/core/routing/app_routes.dart';
   import 'package:flutter_starter/features/notes/presentation/screens/notes_screen.dart';
   import 'package:go_router/go_router.dart';

   /// Builds the Notes route, reachable once signed in.
   GoRoute buildNotesRoute(Ref ref) {
     return GoRoute(
       path: AppRoutes.notes,
       name: AppRoutes.notesName,
       builder: (context, state) =>
           NotesScreen(id: state.uri.queryParameters['id'] ?? '1'),
     );
   }
   ```

3. **Register it** in `buildAppRoutes` in
   `lib/core/routing/routes_registry.dart`: import the module and add
   `buildNotesRoute(ref),` to the list, next to the other feature modules
   (before `buildHomeRoute(ref)`). A route that is not registered here is a
   404, whatever constants exist.

4. **Navigate to it** with the navigation extensions and the constant, never
   a hard-coded path. For example, a button on `HomeScreen`:

   ```dart
   FilledButton(
     onPressed: () => context.pushRoute(AppRoutes.notes),
     child: Text(context.l10n.notesTitle),
   ),
   ```

   That needs `core/routing/app_routes.dart`,
   `core/routing/navigation_extensions.dart` and
   `core/localization/localization_extensions.dart` imported. Visible text goes
   through `AppLocalizations`: add `"notesTitle": "Notes"`
   to `lib/l10n/app_en.arb` and its translations to the other `app_*.arb`
   files (`flutter pub get` regenerates the localizations).
   `test/tooling/text_literal_guard_test.dart` fails on a bare
   `Text('Notes')` under `presentation/`.

The router's redirect already keeps every route except sign-in and
registration behind authentication, so `/notes` needs no guard of its own.

<!-- symbol: lib/core/routing/routes_registry.dart buildAppRoutes -->
<!-- symbol: lib/core/routing/navigation_extensions.dart NavigationExtensions -->

## Step 5: Test it

The scaffold's repository test already runs. Add a route test that signs a
user in, pumps the app's router (`pumpAppRouter` in
`test/helpers/pump_app.dart`) and follows the button from home, as
`test/features/notes/notes_route_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/notes/presentation/screens/notes_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(id: 'u-1', email: 'user@example.com'),
  );
}

void main() {
  testWidgets('a signed-in user reaches the notes screen from home', (
    tester,
  ) async {
    await pumpAppRouter(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(_SignedIn.new),
        sessionRestorationProvider.overrideWith((ref) async {}),
      ],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);
  });
}
```

Then run everything:

```bash
flutter analyze && flutter test
```

## Checklist

- [ ] `./scripts/dev/create_feature.sh <name>`, then analyze and test the slice
- [ ] Entity, model and use cases hold your fields
- [ ] `<name>RemoteDataSourceProvider` builds a real implementation over `ApiClient`
- [ ] Route constants in `AppRoutes`
- [ ] `lib/features/<name>/routing/<name>_routes.dart` module
- [ ] Module registered in `buildAppRoutes`
- [ ] Navigation from an existing screen, with localized text
- [ ] Route test; `flutter analyze` and `flutter test` pass

---

## Related APIs

- [Routing guide](../../guides/features/routing-guide.md) - Route constants, modules and navigation helpers
- [Common Patterns](common-patterns.md) - Common usage patterns
- [API Integration](api-integration.md) - API integration patterns
- [Auth - Repositories](../features/auth/repositories.md) - Example repository
