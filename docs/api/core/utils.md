# Utility APIs

Utility classes for common operations.

## Overview

The utilities layer provides:
- `Result<T>` - Type-safe success/failure handling
- `JsonHelper` - Safe JSON operations
- `DateFormatter` - Date formatting utilities
- `Validators` - Input validation utilities

---

## Result<T>

Sealed class for handling success and failure states with type-safe pattern matching.

**Location:** `lib/core/utils/result.dart`

### Types

- `Success<T>` - Success result containing data of type T
- `ResultFailure<T>` - Failure result containing typed failure information

### Success

```dart
final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}
```

### ResultFailure

```dart
final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);
  final Failure failure;
  String get message => failure.message;
  String? get code => failure.code;
}
```

### Extension Methods

#### Properties

```dart
/// Check if result is success
bool get isSuccess;

/// Check if result is failure
bool get isFailure;

/// Get data if success, null otherwise
T? get dataOrNull;

/// Get error message if failure, null otherwise
String? get errorOrNull;

/// Get typed failure if failure, null otherwise
Failure? get failureOrNull;
```

#### Methods

```dart
/// Map the data if success
Result<R> map<R>(R Function(T data) mapper);

/// Map the error if failure
Result<T> mapError(String Function(String message) mapper);

/// Pattern matching helper using Dart 3.0 switch expressions
R when<R>({
  required R Function(T data) success,
  required R Function(Failure failure) failureCallback,
});
```

### Usage Examples

#### Basic Usage

```dart
final result = await loginUseCase('user@example.com', 'password');

// Check result type
if (result.isSuccess) {
  final user = result.dataOrNull;
  print('Logged in: ${user?.email}');
} else {
  final error = result.errorOrNull;
  print('Error: $error');
}
```

#### Pattern Matching

```dart
final result = await loginUseCase('user@example.com', 'password');
result.when(
  success: (user) {
    print('Logged in: ${user.email}');
    navigateToHome();
  },
  failureCallback: (failure) {
    if (failure is AuthFailure) {
      showError('Authentication failed: ${failure.message}');
    } else if (failure is NetworkFailure) {
      showError('Network error: ${failure.message}');
    } else {
      showError('Error: ${failure.message}');
    }
  },
);
```

#### Mapping Results

```dart
// Map success data
final userResult = await getUserUseCase();
final emailResult = userResult.map((user) => user.email);

// Map error message
final result = await someOperation();
final friendlyResult = result.mapError((msg) => 'User-friendly: $msg');
```

---

## JsonHelper

JSON helper utilities for safe JSON operations.

**Location:** `lib/core/utils/json_helper.dart`

### Decoding Methods

```dart
/// Safely decode a JSON string to a Map or List
/// Returns null if decoding fails
static dynamic decode(String? jsonString);

/// Safely decode a JSON string to a Map<String, dynamic>
/// Returns null if decoding fails or result is not a Map
static Map<String, dynamic>? decodeMap(String? jsonString);

/// Safely decode a JSON string to a List
/// Returns null if decoding fails or result is not a List
static List<dynamic>? decodeList(String? jsonString);
```

### Encoding Methods

```dart
/// Encode an object to a JSON string
/// Returns null if encoding fails
static String? encode(dynamic object);

/// Encode an object to a pretty-printed JSON string
/// Returns null if encoding fails
static String? encodePretty(dynamic object);
```

### Value Extraction Methods

```dart
/// Safely get a value from a Map by key
static T? getValue<T>(Map<String, dynamic>? map, String key);

/// Safely get a String value from a Map by key
static String? getString(Map<String, dynamic>? map, String key);

/// Safely get an int value from a Map by key
static int? getInt(Map<String, dynamic>? map, String key);

/// Safely get a double value from a Map by key
static double? getDouble(Map<String, dynamic>? map, String key);

/// Safely get a bool value from a Map by key
static bool? getBool(Map<String, dynamic>? map, String key);

/// Safely get a Map from a Map by key
static Map<String, dynamic>? getMap(Map<String, dynamic>? map, String key);

/// Safely get a List from a Map by key
static List<dynamic>? getList(Map<String, dynamic>? map, String key);

/// Safely get a List of a specific type from a Map by key
static List<T>? getListOf<T>(
  Map<String, dynamic>? map,
  String key,
  T Function(dynamic) converter,
);
```

### Utility Methods

```dart
/// Check if a JSON string is valid
static bool isValidJson(String? jsonString);

/// Merge two JSON maps, with the second map taking precedence
static Map<String, dynamic> merge(
  Map<String, dynamic>? map1,
  Map<String, dynamic>? map2,
);

/// Deep merge two JSON maps
static Map<String, dynamic> deepMerge(
  Map<String, dynamic>? map1,
  Map<String, dynamic>? map2,
);

/// Remove null values from a Map
static Map<String, dynamic> removeNulls(Map<String, dynamic>? map);

/// Convert a Map to a query string format
static String toQueryString(Map<String, dynamic>? map);
```

### Usage Examples

#### Decoding JSON

```dart
final jsonString = '{"name": "John", "age": 30}';
final map = JsonHelper.decodeMap(jsonString);
if (map != null) {
  final name = JsonHelper.getString(map, 'name'); // "John"
  final age = JsonHelper.getInt(map, 'age'); // 30
}
```

#### Encoding JSON

```dart
final data = {'name': 'John', 'age': 30};
final jsonString = JsonHelper.encode(data); // '{"name":"John","age":30}'
final prettyJson = JsonHelper.encodePretty(data); // Formatted JSON
```

#### Safe Value Extraction

```dart
final map = {'name': 'John', 'age': 30, 'active': true};
final name = JsonHelper.getString(map, 'name'); // "John"
final age = JsonHelper.getInt(map, 'age'); // 30
final active = JsonHelper.getBool(map, 'active'); // true
final email = JsonHelper.getString(map, 'email'); // null (key doesn't exist)
```

#### Working with Lists

```dart
final map = {'users': [{'name': 'John'}, {'name': 'Jane'}]};
final users = JsonHelper.getListOf<User>(
  map,
  'users',
  (json) => User.fromJson(json as Map<String, dynamic>),
);
```

---

## DateFormatter

Date formatting utilities using intl package.

**Location:** `lib/core/utils/date_formatter.dart`

### Methods

```dart
/// Format date to string (yyyy-MM-dd)
static String formatDate(DateTime date);

/// Format date and time to string (yyyy-MM-dd HH:mm:ss)
static String formatDateTime(DateTime dateTime);

/// Format time to string (HH:mm:ss)
static String formatTime(DateTime dateTime);

/// Parse string to date
static DateTime? parseDate(String dateString);

/// Parse string to date and time
static DateTime? parseDateTime(String dateTimeString);
```

### Usage Examples

```dart
final now = DateTime.now();

// Format dates
final dateStr = DateFormatter.formatDate(now); // "2024-01-15"
final dateTimeStr = DateFormatter.formatDateTime(now); // "2024-01-15 10:30:45"
final timeStr = DateFormatter.formatTime(now); // "10:30:45"

// Parse dates
final date = DateFormatter.parseDate("2024-01-15");
final dateTime = DateFormatter.parseDateTime("2024-01-15 10:30:45");
```

---

## Validators

Validation utilities for common input validation.

**Location:** `lib/core/utils/validators.dart`

### Methods

```dart
/// Validate email
static bool isValidEmail(String email);

/// Validate phone number (basic validation)
static bool isValidPhone(String phone);

/// Validate password (at least 8 characters)
static bool isValidPassword(String password);

/// Validate URL
static bool isValidUrl(String url);

/// Check if string is empty or null
static bool isEmpty(String? value);
```

### Usage Examples

```dart
// Email validation
if (Validators.isValidEmail(email)) {
  // Email is valid
} else {
  showError('Invalid email address');
}

// Phone validation
if (Validators.isValidPhone(phone)) {
  // Phone is valid
}

// Password validation
if (Validators.isValidPassword(password)) {
  // Password is valid (at least 8 characters)
}

// URL validation
if (Validators.isValidUrl(url)) {
  // URL is valid
}

// Empty check
if (Validators.isEmpty(value)) {
  // Value is empty or null
}
```

---

## Related APIs

- [Errors](errors.md) - Failure types used in Result
- [Storage](storage.md) - Uses JsonHelper for caching
- [Network](network.md) - Uses Result for error handling

