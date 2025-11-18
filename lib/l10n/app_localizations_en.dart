// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flutter Starter';

  @override
  String get welcome => 'Welcome to Flutter Starter with Clean Architecture!';

  @override
  String get featureFlagsReady => 'Feature Flags System is ready!';

  @override
  String get checkExamples =>
      'Check the examples in feature_flags_example_screen.dart';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get name => 'Name';

  @override
  String get emailRequired => 'Please enter your email';

  @override
  String get emailInvalid => 'Please enter a valid email address';

  @override
  String get passwordRequired => 'Please enter your password';

  @override
  String passwordMinLength(int minLength) {
    return 'Password must be at least $minLength characters';
  }

  @override
  String get nameRequired => 'Please enter your name';

  @override
  String nameMinLength(int minLength) {
    return 'Name must be at least $minLength characters';
  }

  @override
  String get dontHaveAccount => 'Don\'t have an account? Register';

  @override
  String get alreadyHaveAccount => 'Already have an account? Login';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Loading...';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';

  @override
  String get arabic => 'Arabic';

  @override
  String get featureFlagsDebug => 'Feature Flags Debug';

  @override
  String get unexpectedError => 'An unexpected error occurred';

  @override
  String get badRequest => 'Bad request. Please check your input.';

  @override
  String get unauthorized => 'Unauthorized. Please login again.';

  @override
  String get forbidden => 'Forbidden. You do not have permission.';

  @override
  String get notFound => 'Resource not found.';

  @override
  String get conflict => 'Conflict. The resource already exists.';

  @override
  String get validationError => 'Validation error. Please check your input.';

  @override
  String get tooManyRequests => 'Too many requests. Please try again later.';

  @override
  String get internalServerError =>
      'Internal server error. Please try again later.';

  @override
  String get badGateway => 'Bad gateway. Please try again later.';

  @override
  String get serviceUnavailable =>
      'Service unavailable. Please try again later.';

  @override
  String get gatewayTimeout => 'Gateway timeout. Please try again later.';

  @override
  String get clientError => 'Client error occurred.';

  @override
  String get serverError => 'Server error occurred. Please try again later.';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
      zero: 'Just now',
    );
    return '$_temp0';
  }

  @override
  String get tasks => 'Tasks';

  @override
  String get addTask => 'Add Task';

  @override
  String get editTask => 'Edit Task';

  @override
  String get taskTitle => 'Title';

  @override
  String get taskDescription => 'Description';

  @override
  String get taskTitleRequired => 'Please enter a task title';

  @override
  String get noTasks => 'No tasks yet';

  @override
  String get addYourFirstTask => 'Tap the + button to add your first task';

  @override
  String get incompleteTasks => 'Incomplete';

  @override
  String get completedTasks => 'Completed';

  @override
  String get completed => 'Completed';

  @override
  String get incomplete => 'Incomplete';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get deleteTask => 'Delete Task';

  @override
  String deleteTaskConfirmation(String taskTitle) {
    return 'Are you sure you want to delete \"$taskTitle\"?';
  }

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get refresh => 'Refresh';

  @override
  String get taskDetails => 'Task Details';

  @override
  String get taskStatus => 'Status';

  @override
  String get createdAt => 'Created';

  @override
  String get updatedAt => 'Updated';
}
