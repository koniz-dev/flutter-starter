import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('vi')
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Flutter Starter'**
  String get appTitle;

  /// Welcome message on home screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to Flutter Starter with Clean Architecture!'**
  String get welcome;

  /// Message indicating feature flags are ready
  ///
  /// In en, this message translates to:
  /// **'Feature Flags System is ready!'**
  String get featureFlagsReady;

  /// Hint to check examples
  ///
  /// In en, this message translates to:
  /// **'Check the examples in feature_flags_example_screen.dart'**
  String get checkExamples;

  /// Login button and screen title
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Register button and screen title
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Email validation error message
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailRequired;

  /// Invalid email validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get emailInvalid;

  /// Password validation error message
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordRequired;

  /// Password minimum length validation error
  ///
  /// In en, this message translates to:
  /// **'Password must be at least {minLength} characters'**
  String passwordMinLength(int minLength);

  /// Name validation error message
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get nameRequired;

  /// Name minimum length validation error
  ///
  /// In en, this message translates to:
  /// **'Name must be at least {minLength} characters'**
  String nameMinLength(int minLength);

  /// Link to registration screen
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get dontHaveAccount;

  /// Link to login screen
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get alreadyHaveAccount;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Error title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Language selection label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Spanish language name
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// Arabic language name
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// Vietnamese language name
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// Feature flags debug tooltip
  ///
  /// In en, this message translates to:
  /// **'Feature Flags Debug'**
  String get featureFlagsDebug;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get unexpectedError;

  /// HTTP 400 error message
  ///
  /// In en, this message translates to:
  /// **'Bad request. Please check your input.'**
  String get badRequest;

  /// HTTP 401 error message
  ///
  /// In en, this message translates to:
  /// **'Unauthorized. Please login again.'**
  String get unauthorized;

  /// HTTP 403 error message
  ///
  /// In en, this message translates to:
  /// **'Forbidden. You do not have permission.'**
  String get forbidden;

  /// HTTP 404 error message
  ///
  /// In en, this message translates to:
  /// **'Resource not found.'**
  String get notFound;

  /// HTTP 409 error message
  ///
  /// In en, this message translates to:
  /// **'Conflict. The resource already exists.'**
  String get conflict;

  /// HTTP 422 error message
  ///
  /// In en, this message translates to:
  /// **'Validation error. Please check your input.'**
  String get validationError;

  /// HTTP 429 error message
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get tooManyRequests;

  /// HTTP 500 error message
  ///
  /// In en, this message translates to:
  /// **'Internal server error. Please try again later.'**
  String get internalServerError;

  /// HTTP 502 error message
  ///
  /// In en, this message translates to:
  /// **'Bad gateway. Please try again later.'**
  String get badGateway;

  /// HTTP 503 error message
  ///
  /// In en, this message translates to:
  /// **'Service unavailable. Please try again later.'**
  String get serviceUnavailable;

  /// HTTP 504 error message
  ///
  /// In en, this message translates to:
  /// **'Gateway timeout. Please try again later.'**
  String get gatewayTimeout;

  /// Generic 4xx error message
  ///
  /// In en, this message translates to:
  /// **'Client error occurred.'**
  String get clientError;

  /// Generic 5xx error message
  ///
  /// In en, this message translates to:
  /// **'Server error occurred. Please try again later.'**
  String get serverError;

  /// Pluralized item count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// Pluralized minutes ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Just now} =1{1 minute ago} other{{count} minutes ago}}'**
  String minutesAgo(int count);

  /// Tasks screen title
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// Add task button and dialog title
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTask;

  /// Edit task screen title
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// Task title field label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taskTitle;

  /// Task description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskDescription;

  /// Task title validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a task title'**
  String get taskTitleRequired;

  /// Empty tasks list message
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get noTasks;

  /// Hint to add first task
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add your first task'**
  String get addYourFirstTask;

  /// Incomplete tasks section header
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get incompleteTasks;

  /// Completed tasks section header
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedTasks;

  /// Task status: completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Task status: incomplete
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get incomplete;

  /// Edit button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Delete task dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get deleteTask;

  /// Delete task confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{taskTitle}\"?'**
  String deleteTaskConfirmation(String taskTitle);

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Refresh button label
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Task details section title
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get taskDetails;

  /// Task status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get taskStatus;

  /// Created at label
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get createdAt;

  /// Updated at label
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updatedAt;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'es', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
