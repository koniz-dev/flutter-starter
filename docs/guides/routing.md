# Routing Guide

This guide explains how to use the GoRouter-based routing system in the Flutter Starter project.

## Overview

The routing system uses [go_router](https://pub.dev/packages/go_router) for declarative routing with:
- ✅ Type-safe route definitions
- ✅ Deep linking support
- ✅ Authentication-based routing (protected routes)
- ✅ Riverpod integration with optimized performance
- ✅ Nested navigation support
- ✅ Efficient router instance management (no unnecessary recreations)

## Architecture

The routing system follows Clean Architecture principles:

```
lib/core/routing/
├── app_routes.dart          # Route constants and paths
├── app_router.dart          # Router configuration with Riverpod
└── navigation_extensions.dart # Navigation helper extensions
```

## Basic Navigation

### Using Navigation Extensions (Recommended)

The easiest way to navigate is using the provided extensions:

```dart
import 'package:flutter_starter/core/routing/navigation_extensions.dart';

// Navigate to home screen
context.goToHome();

// Navigate to login screen
context.goToLogin();

// Navigate to register screen
context.goToRegister();

// Navigate to feature flags debug screen
context.goToFeatureFlagsDebug();

// Pop current route
context.popRoute();
```

### Using GoRouter Directly

You can also use GoRouter methods directly:

```dart
import 'package:go_router/go_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';

// Navigate to a route (replaces current route)
context.go(AppRoutes.home);

// Push a new route (adds to navigation stack)
context.push(AppRoutes.login);

// Replace current route
context.replace(AppRoutes.register);

// Pop current route
context.pop();
```

## Navigation Patterns

### 1. Basic Navigation (Push, Pop, Replace)

#### Push Navigation
Adds a new route to the navigation stack:

```dart
// Using extension
context.pushRoute(AppRoutes.login);

// Using GoRouter directly
context.push(AppRoutes.login);
```

#### Pop Navigation
Removes the current route from the stack:

```dart
// Using extension
context.popRoute();

// Using GoRouter directly
context.pop();
```

#### Replace Navigation
Replaces the current route:

```dart
// Using extension
context.replaceRoute(AppRoutes.home);

// Using GoRouter directly
context.replace(AppRoutes.home);
```

### 2. Nested Navigation

Nested routes are defined under a parent route in `app_router.dart`:

```dart
GoRoute(
  path: AppRoutes.home,
  name: AppRoutes.homeName,
  builder: (context, state) => const HomeScreen(),
  routes: [
    // Nested route
    GoRoute(
      path: 'feature-flags-debug',
      name: AppRoutes.featureFlagsDebugName,
      builder: (context, state) => const FeatureFlagsDebugScreen(),
    ),
  ],
),
```

To navigate to a nested route, use the full path:

```dart
context.go(AppRoutes.featureFlagsDebug); // '/feature-flags-debug'
```

### 3. Passing Parameters

#### Path Parameters

Define a route with parameters:

```dart
// In app_routes.dart
static const String profile = '/profile/:userId';
static const String profileName = 'profile';

// In app_router.dart
GoRoute(
  path: AppRoutes.profile,
  name: AppRoutes.profileName,
  builder: (context, state) {
    final userId = state.pathParameters['userId']!;
    return ProfileScreen(userId: userId);
  },
),
```

Navigate with parameters:

```dart
// Using path
context.go('/profile/123');

// Using named route
context.pushNamed(
  AppRoutes.profileName,
  pathParameters: {'userId': '123'},
);
```

#### Query Parameters

```dart
// Navigate with query parameters
context.go('/products?category=electronics&sort=price');

// Or using named route
context.pushNamed(
  'products',
  queryParameters: {
    'category': 'electronics',
    'sort': 'price',
  },
);

// Extract query parameters in route builder
GoRoute(
  path: '/products',
  builder: (context, state) {
    final category = state.uri.queryParameters['category'];
    final sort = state.uri.queryParameters['sort'];
    return ProductsScreen(category: category, sort: sort);
  },
),
```

#### Extra Data (Complex Objects)

```dart
// Navigate with extra data
context.push(
  AppRoutes.productDetail,
  extra: Product(id: '123', name: 'Widget'),
);

// Extract extra data in route builder
GoRoute(
  path: '/product/:id',
  builder: (context, state) {
    final product = state.extra as Product?;
    return ProductDetailScreen(product: product);
  },
),
```

### 4. Handling Deep Links

Deep linking is automatically supported by GoRouter. Configure your app to handle deep links:

#### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme">
    <!-- Deep linking -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="yourapp.com" />
    </intent-filter>
</activity>
```

#### iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

#### Testing Deep Links

```bash
# Android
adb shell am start -a android.intent.action.VIEW -d "https://yourapp.com/profile/123"

# iOS (simulator)
xcrun simctl openurl booted "https://yourapp.com/profile/123"
```

## Authentication-Based Routing

The router automatically handles authentication-based routing with optimized performance:

### Protected Routes

Routes under the home route require authentication. Unauthenticated users are redirected to login:

```dart
// In app_router.dart
redirect: (BuildContext context, GoRouterState state) {
  // Read current auth state (safe because redirect is synchronous)
  final authState = ref.read(authNotifierProvider);
  final isAuthenticated = authState.user != null;
  final isAuthRoute = state.matchedLocation == AppRoutes.login ||
      state.matchedLocation == AppRoutes.register;

  // Redirect to login if not authenticated
  if (!isAuthenticated && !isAuthRoute) {
    return AppRoutes.login;
  }

  // Redirect to home if authenticated and on auth routes
  if (isAuthenticated && isAuthRoute) {
    return AppRoutes.home;
  }

  return null;
},
```

### Performance Optimization

The router implementation uses `refreshListenable` pattern for optimal performance:

- **Router instance is created once** - Not recreated on every auth state change
- **Smart notifications** - Only triggers redirects when authentication status actually changes
- **Efficient state reading** - Uses `ref.read()` in redirect function to avoid unnecessary rebuilds

The `_AuthStateNotifier` wrapper listens to auth state changes and only notifies the router when the authentication status (logged in/out) actually changes, preventing unnecessary redirect evaluations.

### Adding New Protected Routes

1. Add route constant to `app_routes.dart`:

```dart
static const String settings = '/settings';
static const String settingsName = 'settings';
```

2. Add route to `app_router.dart` under the home route:

```dart
GoRoute(
  path: AppRoutes.home,
  routes: [
    GoRoute(
      path: 'settings',
      name: AppRoutes.settingsName,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
),
```

3. Add navigation method to `navigation_extensions.dart`:

```dart
void goToSettings() => go(AppRoutes.settings);
```

## Examples

### Example 1: Login Flow

```dart
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              // Login logic
              await ref.read(authNotifierProvider.notifier).login(
                email,
                password,
              );
              // Router will automatically redirect to home on success
            },
            child: Text('Login'),
          ),
          TextButton(
            onPressed: () => context.goToRegister(),
            child: Text('Register'),
          ),
        ],
      ),
    );
  }
}
```

### Example 2: Product Detail with Parameters

```dart
// Define route
GoRoute(
  path: '/product/:productId',
  name: 'product-detail',
  builder: (context, state) {
    final productId = state.pathParameters['productId']!;
    return ProductDetailScreen(productId: productId);
  },
),

// Navigate
context.go('/product/123');

// Or with named route
context.pushNamed(
  'product-detail',
  pathParameters: {'productId': '123'},
);
```

### Example 3: Tab Navigation with Query Parameters

```dart
// Navigate to products with tab parameter
context.go('/products?tab=favorites');

// Extract in route builder
GoRoute(
  path: '/products',
  builder: (context, state) {
    final tab = state.uri.queryParameters['tab'] ?? 'all';
    return ProductsScreen(initialTab: tab);
  },
),
```

### Example 4: Conditional Navigation

```dart
void _handleAction() {
  final authState = ref.read(authNotifierProvider);
  
  if (authState.user != null) {
    context.goToHome();
  } else {
    context.goToLogin();
  }
}
```

## Best Practices

1. **Always use route constants** from `AppRoutes` instead of hardcoded strings
2. **Use navigation extensions** for common navigation patterns
3. **Keep route definitions centralized** in `app_router.dart`
4. **Use path parameters** for required data (e.g., IDs)
5. **Use query parameters** for optional filters/sorting
6. **Use extra data** for complex objects that don't fit in URLs
7. **Test deep links** during development
8. **Handle authentication state** properly in route builders

## Troubleshooting

### Router not updating on auth state change

The router uses `refreshListenable` with `_AuthStateNotifier` to reactively update when auth state changes. The notifier:
- Listens to `authNotifierProvider` using `ref.listen()`
- Only notifies the router when authentication status changes (logged in ↔ logged out)
- Automatically disposes when the provider is disposed

If the router isn't updating:
1. Verify `authNotifierProvider` is properly updating state
2. Check that `_AuthStateNotifier` is correctly created in `goRouterProvider`
3. Ensure `refreshListenable` is set in the `GoRouter` constructor

### Deep links not working

1. Check platform-specific configuration (AndroidManifest.xml, Info.plist)
2. Verify route paths match the deep link URLs
3. Test with `adb` (Android) or `xcrun simctl` (iOS)

### Navigation stack issues

- Use `go()` to replace the current route
- Use `push()` to add to the navigation stack
- Use `pop()` to remove the current route

## Implementation Details

This implementation follows go_router best practices:

### Key Features

- **Single Router Instance**: The router is created once and reused, preventing unnecessary recreations
- **Efficient State Management**: Uses `refreshListenable` pattern instead of recreating the router
- **Smart Redirects**: Only evaluates redirects when authentication status actually changes
- **Riverpod Integration**: Properly integrates with Riverpod's reactive system

## Additional Resources

- [GoRouter Documentation](https://pub.dev/documentation/go_router/latest/) - Official go_router docs
- [GoRouter Changelog](https://pub.dev/packages/go_router/changelog) - Latest changes and migration guides
- [Flutter Deep Linking Guide](https://docs.flutter.dev/ui/navigation/deep-linking) - Deep linking setup
- [Riverpod Documentation](https://riverpod.dev/) - Riverpod state management

