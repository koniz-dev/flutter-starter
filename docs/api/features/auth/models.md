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

/// Convert UserModel to User entity
User toEntity();
```

### Usage

```dart
// From JSON
final json = {'id': '123', 'email': 'user@example.com', 'name': 'John'};
final userModel = UserModel.fromJson(json);

// To JSON
final json = userModel.toJson();

// To entity
final user = userModel.toEntity();
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

## Related APIs

- [Repositories](repositories.md) - Uses these models
- [Use Cases](usecases.md) - Returns User entities
- [Providers](providers.md) - Provides data sources that use models

