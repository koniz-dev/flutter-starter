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
| Logout | `POST /auth/logout` | none | ignored |

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

---

## Related APIs

- [Repositories](repositories.md) - Uses these models
- [Use Cases](usecases.md) - Returns User entities
- [Providers](providers.md) - Provides data sources that use models


