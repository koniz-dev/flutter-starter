# Adding a New Feature

Scaffold a feature slice, give it a data source, make its screen reachable,
and test it. The example feature is `notes` throughout; substitute your own
name (snake_case) everywhere it appears.

## Step 1: Scaffold the slice

```bash
./scripts/dev/create_feature.sh notes
```

`mason make feature_clean --feature_name notes --class_name Notes` produces the
same files if you use Mason. `class_name` is not derived from `feature_name`:
leave it out and the brick prompts for it, defaulting to `Profile`. Either way you get:

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

4. **Link it from home.** The home screen names no feature: it lists the
   `HomeDestination`s that `buildHomeDestinations` in `routes_registry.dart`
   returns. Declare one beside the route module, in `notes_routes.dart`:

   ```dart
   /// The home screen's entry to the notes screen.
   final HomeDestination notesHomeDestination = HomeDestination(
     id: 'notes',
     icon: Icons.note_outlined,
     label: (l10n) => l10n.notesTitle,
     location: AppRoutes.notes,
   );
   ```

   That needs `package:flutter/material.dart` and
   `core/routing/home_destination.dart` imported. Then add
   `notesHomeDestination,` to the list in `buildHomeDestinations`, next to the
   other features' entries (or to `_debugHomeDestinations` for a debug-only
   screen). Home renders it as a button keyed `UiKeys.homeDestination('notes')`
   that pushes the route. Elsewhere, navigate with the navigation extensions
   and the constant, never a hard-coded path:
   `context.pushRoute(AppRoutes.notes)`.

   Visible text goes through `AppLocalizations`: add `"notesTitle": "Notes"`
   to `lib/l10n/app_en.arb` and its translations to the other `app_*.arb`
   files (`flutter pub get` regenerates the localizations).
   `test/tooling/text_literal_guard_test.dart` fails on a bare
   `Text('Notes')` under `presentation/`.

The router's redirect already keeps every route except sign-in and
registration behind authentication, so `/notes` needs no guard of its own.

<!-- symbol: lib/core/routing/routes_registry.dart buildAppRoutes -->
<!-- symbol: lib/core/routing/routes_registry.dart buildHomeDestinations -->
<!-- symbol: lib/core/routing/home_destination.dart HomeDestination -->
<!-- symbol: lib/core/constants/ui_keys.dart UiKeys.homeDestination -->
<!-- symbol: lib/core/routing/navigation_extensions.dart NavigationExtensions -->

## Step 5: Test it

The scaffold's repository test already runs. Add a route test that signs a
user in, pumps the app's router (`pumpAppRouter` in
`test/helpers/pump_app.dart`) and follows the home entry, as
`test/features/notes/notes_route_test.dart`:

```dart
import 'package:flutter_starter/core/constants/ui_keys.dart';
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
    await tester.tap(find.byKey(UiKeys.homeDestination('notes')));
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
- [ ] `HomeDestination` beside the route module, listed in `buildHomeDestinations`, with localized text
- [ ] Route test; `flutter analyze` and `flutter test` pass

---

## Related APIs

- [Routing guide](../../guides/features/routing-guide.md) - Route constants, modules and navigation helpers
- [Common Patterns](common-patterns.md) - Common usage patterns
- [API Integration](api-integration.md) - API integration patterns
- [Auth - Repositories](../features/auth/repositories.md) - Example repository
