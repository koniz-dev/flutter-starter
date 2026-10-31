# Auth Models

Data models for authentication.

## Overview

Models represent data structures used in the authentication flow, including user data and authentication responses.

---

## User Entity

Domain entity representing a user.

**Location:** `lib/features/auth/domain/entities/user.dart`

### Properties

```dart
/// Unique user identifier
final String id;

/// User's email address
final String email;

/// User's display name
final String? name;

/// URL to user's avatar image
final String? avatarUrl;
```

### Constructor

```dart
/// Creates a [User] with the given [id], [email], optional [name], and
/// optional [avatarUrl]
const User({
  required this.id,
  required this.email,
  this.name,
  this.avatarUrl,
});
```

### Usage

```dart
const user = User(
  id: '123',
  email: 'user@example.com',
  name: 'John Doe',
  avatarUrl: 'https://example.com/avatar.jpg',
);
```

---

## UserModel

Data model for user, extends User entity.

**Location:** `lib/features/auth/data/models/user_model.dart`

### Methods

```dart
/// Create UserModel from JSON
factory UserModel.fromJson(Map<String, dynamic> json);

/// Convert UserModel to JSON
Map<String, dynamic> toJson();
```

There is no `toEntity()`: `UserModel` *extends* `User`, so a `UserModel` already
is a `User` and is passed to the domain layer as one, with no conversion.

<!-- strip:tasks start -->
(`TaskModel`, which does not extend its entity, is the model with a
`toEntity()`.)
<!-- strip:tasks end -->

### Usage

```dart
// From JSON
final json = {'id': '123', 'email': 'user@example.com', 'name': 'John'};
final userModel = UserModel.fromJson(json);

// To JSON
final json = userModel.toJson();

// As the entity - no conversion: a UserModel is a User
final User user = userModel;
```

---

## AuthResponseModel

Data model for authentication response from API.

**Location:** `lib/features/auth/data/models/auth_response_model.dart`

### Properties

```dart
/// User data
final UserModel user;

/// Access token
final String token;

/// Refresh token (optional)
final String? refreshToken;
```

### Methods

```dart
/// Create AuthResponseModel from JSON
factory AuthResponseModel.fromJson(Map<String, dynamic> json);

/// Convert AuthResponseModel to JSON
Map<String, dynamic> toJson();
```

### Usage

```dart
// From API response
final response = await apiClient.post('/login', data: {...});
final authResponse = AuthResponseModel.fromJson(response.data);

// Access data
final user = authResponse.user;
final token = authResponse.token;
final refreshToken = authResponse.refreshToken;
```

---

## Wire format

The auth slice speaks **snake_case** on the wire, in both directions. Your
backend must send and accept exactly these keys.
Paths are relative to `BASE_URL` plus the
`/v1` API version (`ApiEndpoints.apiVersion`; set it to `''` for an unversioned
API), so login is `<BASE_URL>/v1/auth/login`:

| Call | Endpoint | Request body | Response body |
|---|---|---|---|
| Login | `POST /auth/login` | `email`, `password` | `user`, `token`, `refresh_token` |
| Register | `POST /auth/register` | `email`, `password`, `name` | `user`, `token`, `refresh_token` |
| Refresh | `POST /auth/refresh` | `refresh_token` | `user`, `token`, `refresh_token` |
| Logout | `POST /auth/logout` | `refresh_token` (the stored one, so the server can revoke it; no body when none is stored) | ignored |

The `user` object is `id`, `email`, and the optional `name` and `avatar_url`.
`refresh_token` is optional in a response. When it is missing, no refresh token
is stored and the first access-token expiry ends the session.

```json
{
  "user": {
    "id": "u-1",
    "email": "user@example.com",
    "name": "Jane",
    "avatar_url": "https://example.com/jane.png"
  },
  "token": "<access token>",
  "refresh_token": "<refresh token>"
}
```

A backend that uses another convention (for example camelCase `refreshToken`)
must be adapted in the models' `@JsonKey` names or in
`AuthRemoteDataSourceImpl`. Otherwise its refresh token parses as `null` and is
never stored. `test/features/auth/data/auth_wire_format_test.dart` pins every
key above.

<!-- symbol: lib/features/auth/data/models/auth_response_model.dart AuthResponseModel -->
<!-- symbol: lib/features/auth/data/models/user_model.dart UserModel -->
<!-- symbol: lib/features/auth/data/datasources/auth_remote_datasource.dart AuthRemoteDataSourceImpl -->

## Adapting the auth slice to an existing API

When your API does not speak the [wire format](#wire-format) above, change
the data layer, not the domain or the screens. What to touch, by difference:

| Your API differs in | Change |
|---|---|
| The response envelope (a flat body, no `user` object) or the token keys (`accessToken`, `refreshToken`) | Reshape the body in `AuthRemoteDataSourceImpl` (`lib/features/auth/data/datasources/auth_remote_datasource.dart`) before `AuthResponseModel.fromJson`, as in the worked example below; or, when only key names differ, change the `@JsonKey(name: ...)` annotations in `lib/features/auth/data/models/auth_response_model.dart` |
| The user fields or the id type | The same reshaping, or `lib/features/auth/data/models/user_model.dart`. `User.id` is a `String`: an integer id must be converted (`'${json['id']}'`), or parsing fails with `type 'int' is not a subtype of type 'String'` |
| The login (or register) request keys | The request maps in `AuthRemoteDataSourceImpl.login` / `register` |
| The refresh request or response | `AuthRemoteDataSourceImpl.refreshToken`: its body key, and the reshaping of its response. `AuthRepositoryImpl.refreshToken` reads only the token and refresh token from it, but `AuthResponseModel` requires a `user`; when your refresh endpoint returns tokens only, reshape it with a placeholder user (`{'id': '', 'email': ''}`), which is discarded |
| Sign-in by username instead of email | The request key in `AuthRemoteDataSourceImpl.login`, and the login form in `lib/features/auth/presentation/screens/login_screen.dart`: its `Validators.isValidEmail` check, `TextInputType.emailAddress` and the `l10n.email` / `l10n.emailInvalid` strings (`lib/l10n/app_*.arb`). The domain keeps calling the value `email`; rename it there too if that reads wrong |

Two follow-ups whichever row applies:

- **Regenerate** after editing an annotated model (`@JsonSerializable`,
  `@JsonKey`): `flutter pub run build_runner build --delete-conflicting-outputs`.
  Reshaping in the data source needs no regeneration.
- **Update `test/features/auth/data/auth_wire_format_test.dart`** in the same
  change. It pins every request and response key above, so it fails until it
  describes your API instead.

### Worked example: a flat response with an integer id

A login endpoint such as `POST /auth/login` on dummyjson.com takes
`username` and `password` and answers with one flat object:

```json
{
  "id": 1,
  "username": "emilys",
  "email": "emily.johnson@x.dummyjson.com",
  "firstName": "Emily",
  "lastName": "Johnson",
  "image": "https://dummyjson.com/icon/emilys/128",
  "accessToken": "<access token>",
  "refreshToken": "<refresh token>"
}
```

Reshape it into the envelope the models read, in `AuthRemoteDataSourceImpl`:

```dart
@override
Future<AuthResponseModel> login(String email, String password) async {
  final response = await _post(ApiEndpoints.login, <String, dynamic>{
    'username': email, // the value the login form collects
    'password': password,
  });
  return AuthResponseModel.fromJson(
    _fromFlat(response.data as Map<String, dynamic>),
  );
}

/// Reshapes a flat `{id, email, ..., accessToken, refreshToken}` body into
/// the `{user, token, refresh_token}` envelope the models read.
Map<String, dynamic> _fromFlat(Map<String, dynamic> json) => {
  'user': {
    'id': '${json['id']}', // an int on this API; User.id is a String
    'email': json['email'],
    'name': '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
    'avatar_url': json['image'],
  },
  'token': json['accessToken'],
  'refresh_token': json['refreshToken'],
};
```

Here this API's endpoints have no `/v1`, so set `ApiEndpoints.apiVersion` to
`''` as well (see [Connecting Your Backend](../../../guides/onboarding/getting-started.md#connecting-your-backend)).

<!-- symbol: lib/features/auth/data/repositories/auth_repository_impl.dart AuthRepositoryImpl -->

---

## Related APIs

- [Repositories](repositories.md) - Uses these models
- [Use Cases](usecases.md) - Returns User entities
- [Providers](providers.md) - Provides data sources that use models


