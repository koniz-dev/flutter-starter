# Monitoring & Analytics Setup

Complete guide for setting up monitoring, crash reporting, and analytics in Flutter Starter.

## Table of Contents

1. [Firebase Crashlytics](#firebase-crashlytics)
2. [Firebase Analytics](#firebase-analytics)
3. [Firebase Performance](#firebase-performance)
4. [Custom Analytics](#custom-analytics)
5. [Error Tracking](#error-tracking)
6. [Logging](#logging)

---

## Firebase Crashlytics

### Setup

#### 1. Add Dependencies

Update `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_crashlytics: ^4.0.0
```

#### 2. Initialize Firebase

Create `lib/core/firebase/firebase_config.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    
    // Only enable Crashlytics in staging and production
    if (AppConfig.enableCrashReporting) {
      _setupCrashlytics();
    }
  }

  static void _setupCrashlytics() {
    // Pass all uncaught errors to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
}
```

#### 3. Update main.dart

```dart
import 'package:flutter_starter/core/firebase/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseConfig.initialize();
  
  // ... rest of initialization
}
```

#### 4. Configure Firebase Projects

**Android**:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create projects for each environment:
   - `your-app-dev`
   - `your-app-staging`
   - `your-app-prod`
3. Add Android apps to each project
4. Download `google-services.json` for each environment
5. Place in flavor directories:
   - `android/app/src/development/google-services.json`
   - `android/app/src/staging/google-services.json`
   - `android/app/src/production/google-services.json`

**iOS**:

1. Add iOS apps to Firebase projects
2. Download `GoogleService-Info.plist` for each environment
3. Place in scheme-specific directories or use build phases to copy

#### 5. Manual Crash Reporting

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Record non-fatal errors
try {
  // Your code
} catch (e, stack) {
  FirebaseCrashlytics.instance.recordError(e, stack);
}

// Log custom messages
FirebaseCrashlytics.instance.log('User clicked button');

// Set user identifier
FirebaseCrashlytics.instance.setUserIdentifier('user123');

// Set custom keys
FirebaseCrashlytics.instance.setCustomKey('screen', 'home');
FirebaseCrashlytics.instance.setCustomKey('user_type', 'premium');
```

---

## Firebase Analytics

### Setup

#### 1. Add Dependencies

```yaml
dependencies:
  firebase_analytics: ^11.0.0
```

#### 2. Create Analytics Service

Create `lib/core/analytics/analytics_service.dart`:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_starter/core/config/app_config.dart';

class AnalyticsService {
  AnalyticsService._();
  
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  // Only track if analytics is enabled
  static bool get _isEnabled => AppConfig.enableAnalytics;
  
  /// Log screen view
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isEnabled) return;
    
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }
  
  /// Log custom event
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_isEnabled) return;
    
    await _analytics.logEvent(
      name: name,
      parameters: parameters,
    );
  }
  
  /// Set user property
  static Future<void> setUserProperty({
    required String name,
    String? value,
  }) async {
    if (!_isEnabled) return;
    
    await _analytics.setUserProperty(name: name, value: value);
  }
  
  /// Set user ID
  static Future<void> setUserId(String? userId) async {
    if (!_isEnabled) return;
    
    await _analytics.setUserId(userId);
  }
  
  // Common events
  static Future<void> logLogin({String? method}) async {
    await logEvent(
      name: 'login',
      parameters: {'method': method ?? 'unknown'},
    );
  }
  
  static Future<void> logSignUp({String? method}) async {
    await logEvent(
      name: 'sign_up',
      parameters: {'method': method ?? 'unknown'},
    );
  }
  
  static Future<void> logPurchase({
    required String currency,
    required double value,
    String? transactionId,
  }) async {
    await logEvent(
      name: 'purchase',
      parameters: {
        'currency': currency,
        'value': value,
        'transaction_id': transactionId,
      },
    );
  }
  
  static Future<void> logButtonClick({
    required String buttonName,
    String? screen,
  }) async {
    await logEvent(
      name: 'button_click',
      parameters: {
        'button_name': buttonName,
        'screen': screen,
      },
    );
  }
}
```

#### 3. Usage Examples

```dart
import 'package:flutter_starter/core/analytics/analytics_service.dart';

// Track screen views
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    AnalyticsService.logScreenView(screenName: 'home');
    // ...
  }
}

// Track button clicks
ElevatedButton(
  onPressed: () {
    AnalyticsService.logButtonClick(
      buttonName: 'submit',
      screen: 'form',
    );
    // Handle button press
  },
  child: Text('Submit'),
)

// Track user actions
AnalyticsService.logLogin(method: 'email');
AnalyticsService.setUserId('user123');
AnalyticsService.setUserProperty(name: 'subscription', value: 'premium');
```

---

## Firebase Performance

### Setup

#### 1. Add Dependencies

```yaml
dependencies:
  firebase_performance: ^0.9.0
```

#### 2. Create Performance Service

Create `lib/core/performance/performance_service.dart`:

```dart
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_starter/core/config/app_config.dart';

class PerformanceService {
  PerformanceService._();
  
  static final FirebasePerformance _performance = 
      FirebasePerformance.instance;
  
  static bool get _isEnabled => AppConfig.enablePerformanceMonitoring;
  
  /// Start a trace
  static Trace? startTrace(String name) {
    if (!_isEnabled) return null;
    return _performance.newTrace(name);
  }
  
  /// Measure API call performance
  static Future<T> measureApiCall<T>({
    required String name,
    required Future<T> Function() call,
  }) async {
    if (!_isEnabled) return await call();
    
    final trace = _performance.newTrace('api_$name');
    await trace.start();
    
    try {
      final result = await call();
      trace.putMetric('success', 1);
      return result;
    } catch (e) {
      trace.putMetric('error', 1);
      rethrow;
    } finally {
      await trace.stop();
    }
  }
  
  /// Measure screen load time
  static Future<void> measureScreenLoad({
    required String screenName,
    required Future<void> Function() load,
  }) async {
    if (!_isEnabled) {
      await load();
      return;
    }
    
    final trace = _performance.newTrace('screen_$screenName');
    await trace.start();
    
    try {
      await load();
      trace.putMetric('success', 1);
    } catch (e) {
      trace.putMetric('error', 1);
      rethrow;
    } finally {
      await trace.stop();
    }
  }
}
```

#### 3. Usage Examples

```dart
import 'package:flutter_starter/core/performance/performance_service.dart';

// Measure API calls
final data = await PerformanceService.measureApiCall(
  name: 'fetch_user_data',
  call: () => apiService.getUserData(),
);

// Measure screen loads
await PerformanceService.measureScreenLoad(
  screenName: 'home',
  load: () async {
    // Load screen data
    await loadHomeData();
  },
);

// Custom traces
final trace = PerformanceService.startTrace('custom_operation');
if (trace != null) {
  // Your operation
  trace.putMetric('items_processed', 10);
  await trace.stop();
}
```

---

## Custom Analytics

### Create Custom Analytics Service

Create `lib/core/analytics/custom_analytics.dart`:

```dart
import 'package:flutter_starter/core/config/app_config.dart';

abstract class AnalyticsProvider {
  Future<void> trackEvent(String name, Map<String, dynamic>? parameters);
  Future<void> setUserProperty(String name, String value);
  Future<void> setUserId(String userId);
}

class CustomAnalytics {
  CustomAnalytics._();
  
  static final List<AnalyticsProvider> _providers = [];
  static bool get _isEnabled => AppConfig.enableAnalytics;
  
  static void registerProvider(AnalyticsProvider provider) {
    _providers.add(provider);
  }
  
  static Future<void> trackEvent(
    String name, {
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isEnabled) return;
    
    for (final provider in _providers) {
      try {
        await provider.trackEvent(name, parameters);
      } catch (e) {
        // Log error but don't break app
        debugPrint('Analytics error: $e');
      }
    }
  }
  
  static Future<void> setUserProperty(String name, String value) async {
    if (!_isEnabled) return;
    
    for (final provider in _providers) {
      try {
        await provider.setUserProperty(name, value);
      } catch (e) {
        debugPrint('Analytics error: $e');
      }
    }
  }
  
  static Future<void> setUserId(String userId) async {
    if (!_isEnabled) return;
    
    for (final provider in _providers) {
      try {
        await provider.setUserId(userId);
      } catch (e) {
        debugPrint('Analytics error: $e');
      }
    }
  }
}
```

### Example: Mixpanel Integration

```dart
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class MixpanelProvider implements AnalyticsProvider {
  final Mixpanel _mixpanel;
  
  MixpanelProvider(this._mixpanel);
  
  @override
  Future<void> trackEvent(String name, Map<String, dynamic>? parameters) {
    return _mixpanel.track(name, properties: parameters);
  }
  
  @override
  Future<void> setUserProperty(String name, String value) {
    _mixpanel.getPeople().set(name, value);
    return Future.value();
  }
  
  @override
  Future<void> setUserId(String userId) {
    _mixpanel.identify(userId);
    return Future.value();
  }
}

// Initialize
final mixpanel = await Mixpanel.init('YOUR_TOKEN');
CustomAnalytics.registerProvider(MixpanelProvider(mixpanel));
```

---

## Error Tracking

### Sentry Integration

#### 1. Add Dependencies

```yaml
dependencies:
  sentry_flutter: ^7.0.0
```

#### 2. Initialize Sentry

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN';
      options.environment = AppConfig.environment;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(MyApp()),
  );
}
```

#### 3. Usage

```dart
// Capture exceptions
try {
  // Your code
} catch (e, stack) {
  await Sentry.captureException(e, stackTrace: stack);
}

// Capture messages
await Sentry.captureMessage('Something went wrong');

// Add breadcrumbs
Sentry.addBreadcrumb(
  Breadcrumb(
    message: 'User clicked button',
    category: 'user_action',
  ),
);
```

---

## Logging

### Structured Logging

Create `lib/core/logging/logger.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class Logger {
  Logger._();
  
  static bool get _isEnabled => AppConfig.enableLogging;
  
  static void debug(String message, [Object? error, StackTrace? stack]) {
    if (!_isEnabled) return;
    _log(LogLevel.debug, message, error, stack);
  }
  
  static void info(String message, [Object? error, StackTrace? stack]) {
    if (!_isEnabled) return;
    _log(LogLevel.info, message, error, stack);
  }
  
  static void warning(String message, [Object? error, StackTrace? stack]) {
    if (!_isEnabled) return;
    _log(LogLevel.warning, message, error, stack);
  }
  
  static void error(String message, [Object? error, StackTrace? stack]) {
    _log(LogLevel.error, message, error, stack);
    
    // Always log errors to Crashlytics if enabled
    if (AppConfig.enableCrashReporting && error != null) {
      // FirebaseCrashlytics.instance.recordError(error, stack);
    }
  }
  
  static void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stack,
  ) {
    final prefix = '[${level.name.toUpperCase()}]';
    final timestamp = DateTime.now().toIso8601String();
    
    if (kDebugMode) {
      debugPrint('$timestamp $prefix $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stack != null) {
        debugPrint('Stack: $stack');
      }
    }
  }
}
```

### Usage

```dart
import 'package:flutter_starter/core/logging/logger.dart';

Logger.debug('Debug message');
Logger.info('Info message');
Logger.warning('Warning message');
Logger.error('Error message', error, stackTrace);
```

---

## Best Practices

1. **Respect User Privacy**: Only enable analytics in staging/production
2. **Don't Track PII**: Never track personally identifiable information
3. **Use Feature Flags**: Control analytics via environment configuration
4. **Handle Errors Gracefully**: Analytics failures shouldn't break the app
5. **Test Analytics**: Verify events are tracked correctly
6. **Monitor Performance**: Don't let analytics slow down the app
7. **Comply with Regulations**: Follow GDPR, CCPA, etc.

---

## Resources

- [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics)
- [Firebase Analytics](https://firebase.google.com/docs/analytics)
- [Firebase Performance](https://firebase.google.com/docs/perf-mon)
- [Sentry Flutter](https://docs.sentry.io/platforms/flutter/)

