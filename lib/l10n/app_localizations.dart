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
    Locale('vi'),
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

  /// Title of the 404 screen shown for an unmatched route
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFoundTitle;

  /// Body text of the 404 screen shown for an unmatched route
  ///
  /// In en, this message translates to:
  /// **'The page you are looking for does not exist.'**
  String get pageNotFoundMessage;

  /// Action on the 404 screen that returns to the home route
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// Empty state message for a list with no items
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// Button label that loads the next page of a list
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMore;

  /// Screen reader hint for the retry button
  ///
  /// In en, this message translates to:
  /// **'Attempts to reload the content'**
  String get retryHint;

  /// Screen reader hint for the language switcher button
  ///
  /// In en, this message translates to:
  /// **'Opens language selection dialog'**
  String get selectLanguageHint;

  /// Default screen reader label for a progress indicator
  ///
  /// In en, this message translates to:
  /// **'Progress indicator'**
  String get progressIndicator;

  /// Screen reader value for a progress indicator
  ///
  /// In en, this message translates to:
  /// **'{percent} percent'**
  String percentValue(int percent);

  /// Screen reader state word for a control that is loading
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get stateLoading;

  /// Screen reader state word for a disabled control
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get stateDisabled;

  /// Screen reader announcement when focus moves
  ///
  /// In en, this message translates to:
  /// **'Focused on {label}'**
  String focusedOn(String label);

  /// Screen reader announcement when a new screen opens
  ///
  /// In en, this message translates to:
  /// **'Navigated to {page}'**
  String navigatedTo(String page);

  /// Pluralized hours ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Just now} =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// Pluralized days ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// Pluralized months ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String monthsAgo(int count);

  /// Pluralized years ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String yearsAgo(int count);

  /// Pluralized minutes from now (future relative time)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Just now} =1{in 1 minute} other{in {count} minutes}}'**
  String minutesFromNow(int count);

  /// Pluralized hours from now (future relative time)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Just now} =1{in 1 hour} other{in {count} hours}}'**
  String hoursFromNow(int count);

  /// Pluralized days from now (future relative time)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 day} other{in {count} days}}'**
  String daysFromNow(int count);

  /// Pluralized months from now (future relative time)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 month} other{in {count} months}}'**
  String monthsFromNow(int count);

  /// Pluralized years from now (future relative time)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 year} other{in {count} years}}'**
  String yearsFromNow(int count);

  /// Tooltip for the refresh action on the feature flags debug screen
  ///
  /// In en, this message translates to:
  /// **'Refresh flags'**
  String get featureFlagsRefreshTooltip;

  /// Tooltip for the clear-all-overrides action on the feature flags debug screen
  ///
  /// In en, this message translates to:
  /// **'Clear all overrides'**
  String get featureFlagsClearAllTooltip;

  /// Title of the dialog confirming that all local feature flag overrides will be cleared
  ///
  /// In en, this message translates to:
  /// **'Clear All Overrides'**
  String get featureFlagsClearAllTitle;

  /// Body of the dialog confirming that all local feature flag overrides will be cleared
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all local overrides?'**
  String get featureFlagsClearAllMessage;

  /// Confirm button of the clear-all-overrides dialog
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get featureFlagsClear;

  /// Snackbar shown after all local feature flag overrides were cleared
  ///
  /// In en, this message translates to:
  /// **'All local overrides cleared'**
  String get featureFlagsAllOverridesCleared;

  /// Error line on the feature flags screens; {error} is the raw error
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String featureFlagsErrorMessage(String error);

  /// Shown on the feature flags debug screen when no flags exist
  ///
  /// In en, this message translates to:
  /// **'No feature flags found'**
  String get featureFlagsEmpty;

  /// Fallback description for a feature flag without one
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get featureFlagsNoDescription;

  /// Category heading for feature flags without a category
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get featureFlagsCategoryOther;

  /// Last-updated time of a feature flag; {time} is HH:mm
  ///
  /// In en, this message translates to:
  /// **'Updated: {time}'**
  String featureFlagsUpdatedAt(String time);

  /// Snackbar after a flag override was switched on; {flagKey} is the flag key
  ///
  /// In en, this message translates to:
  /// **'{flagKey} enabled'**
  String featureFlagsFlagEnabled(String flagKey);

  /// Snackbar after a flag override was switched off; {flagKey} is the flag key
  ///
  /// In en, this message translates to:
  /// **'{flagKey} disabled'**
  String featureFlagsFlagDisabled(String flagKey);

  /// Snackbar after a single flag override was cleared; {flagKey} is the flag key
  ///
  /// In en, this message translates to:
  /// **'Override cleared for {flagKey}'**
  String featureFlagsOverrideCleared(String flagKey);

  /// App bar title of the feature flags example screen
  ///
  /// In en, this message translates to:
  /// **'Feature Flags Examples'**
  String get featureFlagsExamplesTitle;

  /// Tooltip for opening the feature flags debug screen
  ///
  /// In en, this message translates to:
  /// **'Open Debug Menu'**
  String get featureFlagsOpenDebugMenu;

  /// Section title; FeatureFlagBuilder is a class name and stays untranslated
  ///
  /// In en, this message translates to:
  /// **'Example 1: FeatureFlagBuilder'**
  String get featureFlagsExample1Title;

  /// Explanation for example 1
  ///
  /// In en, this message translates to:
  /// **'This example shows how to use FeatureFlagBuilder to conditionally render widgets.'**
  String get featureFlagsExample1Body;

  /// Shown when the new-feature flag is on
  ///
  /// In en, this message translates to:
  /// **'New Feature is ENABLED'**
  String get featureFlagsNewFeatureEnabled;

  /// Shown when the new-feature flag is off
  ///
  /// In en, this message translates to:
  /// **'New Feature is DISABLED'**
  String get featureFlagsNewFeatureDisabled;

  /// Section title; FeatureFlagWidget is a class name and stays untranslated
  ///
  /// In en, this message translates to:
  /// **'Example 2: FeatureFlagWidget'**
  String get featureFlagsExample2Title;

  /// Explanation for example 2
  ///
  /// In en, this message translates to:
  /// **'This example shows how to use FeatureFlagWidget for simple show/hide scenarios.'**
  String get featureFlagsExample2Body;

  /// Shown when the premium-features flag is on
  ///
  /// In en, this message translates to:
  /// **'Premium Features Available'**
  String get featureFlagsPremiumAvailable;

  /// Section title for example 3
  ///
  /// In en, this message translates to:
  /// **'Example 3: Direct Provider Access'**
  String get featureFlagsExample3Title;

  /// Explanation for example 3
  ///
  /// In en, this message translates to:
  /// **'This example shows how to access feature flags directly from providers for complex logic.'**
  String get featureFlagsExample3Body;

  /// Label of the dark mode switch in example 3
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get featureFlagsDarkMode;

  /// Subtitle when the dark mode flag is on
  ///
  /// In en, this message translates to:
  /// **'Dark mode is enabled'**
  String get featureFlagsDarkModeIsEnabled;

  /// Subtitle when the dark mode flag is off
  ///
  /// In en, this message translates to:
  /// **'Dark mode is disabled'**
  String get featureFlagsDarkModeIsDisabled;

  /// Snackbar after the dark mode switch was turned on
  ///
  /// In en, this message translates to:
  /// **'Dark mode enabled'**
  String get featureFlagsDarkModeEnabled;

  /// Snackbar after the dark mode switch was turned off
  ///
  /// In en, this message translates to:
  /// **'Dark mode disabled'**
  String get featureFlagsDarkModeDisabled;

  /// Section title for example 4
  ///
  /// In en, this message translates to:
  /// **'Example 4: Conditional Navigation'**
  String get featureFlagsExample4Title;

  /// Explanation for example 4
  ///
  /// In en, this message translates to:
  /// **'This example shows how to conditionally show navigation options based on feature flags.'**
  String get featureFlagsExample4Body;

  /// Snackbar shown when the analytics button is pressed
  ///
  /// In en, this message translates to:
  /// **'Navigating to Analytics...'**
  String get featureFlagsNavigatingToAnalytics;

  /// Button label shown when the analytics flag is on
  ///
  /// In en, this message translates to:
  /// **'View Analytics'**
  String get featureFlagsViewAnalytics;

  /// Disabled button label shown when the analytics flag is off
  ///
  /// In en, this message translates to:
  /// **'Analytics Unavailable'**
  String get featureFlagsAnalyticsUnavailable;
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
    'that was used.',
  );
}
