// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Flutter Starter';

  @override
  String get welcome => 'مرحباً بك في Flutter Starter مع Clean Architecture!';

  @override
  String get featureFlagsReady => 'نظام Feature Flags جاهز!';

  @override
  String get checkExamples =>
      'تحقق من الأمثلة في feature_flags_example_screen.dart';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'التسجيل';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get name => 'الاسم';

  @override
  String get emailRequired => 'يرجى إدخال بريدك الإلكتروني';

  @override
  String get emailInvalid => 'يرجى إدخال عنوان بريد إلكتروني صحيح';

  @override
  String get passwordRequired => 'يرجى إدخال كلمة المرور';

  @override
  String passwordMinLength(int minLength) {
    return 'يجب أن تكون كلمة المرور على الأقل $minLength أحرف';
  }

  @override
  String get nameRequired => 'يرجى إدخال اسمك';

  @override
  String nameMinLength(int minLength) {
    return 'يجب أن يكون الاسم على الأقل $minLength أحرف';
  }

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟ سجل';

  @override
  String get alreadyHaveAccount => 'هل لديك حساب بالفعل؟ سجل الدخول';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get error => 'خطأ';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get language => 'اللغة';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get spanish => 'الإسبانية';

  @override
  String get arabic => 'العربية';

  @override
  String get vietnamese => 'الفيتنامية';

  @override
  String get featureFlagsDebug => 'تصحيح Feature Flags';

  @override
  String get unexpectedError => 'حدث خطأ غير متوقع';

  @override
  String get badRequest => 'طلب غير صحيح. يرجى التحقق من المدخلات.';

  @override
  String get unauthorized => 'غير مصرح. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get forbidden => 'ممنوع. ليس لديك إذن.';

  @override
  String get notFound => 'المورد غير موجود.';

  @override
  String get conflict => 'تعارض. المورد موجود بالفعل.';

  @override
  String get validationError => 'خطأ في التحقق. يرجى التحقق من المدخلات.';

  @override
  String get tooManyRequests => 'طلبات كثيرة جداً. يرجى المحاولة لاحقاً.';

  @override
  String get internalServerError =>
      'خطأ داخلي في الخادم. يرجى المحاولة لاحقاً.';

  @override
  String get badGateway => 'بوابة غير صحيحة. يرجى المحاولة لاحقاً.';

  @override
  String get serviceUnavailable => 'الخدمة غير متاحة. يرجى المحاولة لاحقاً.';

  @override
  String get gatewayTimeout => 'انتهت مهلة البوابة. يرجى المحاولة لاحقاً.';

  @override
  String get clientError => 'حدث خطأ في العميل.';

  @override
  String get serverError => 'حدث خطأ في الخادم. يرجى المحاولة لاحقاً.';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصرًا',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا توجد عناصر',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقيقة',
      many: 'منذ $count دقيقة',
      few: 'منذ $count دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة واحدة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String get tasks => 'المهام';

  @override
  String get addTask => 'إضافة مهمة';

  @override
  String get editTask => 'تعديل المهمة';

  @override
  String get taskTitle => 'العنوان';

  @override
  String get taskDescription => 'الوصف';

  @override
  String get taskTitleRequired => 'يرجى إدخال عنوان للمهمة';

  @override
  String get noTasks => 'لا توجد مهام بعد';

  @override
  String get addYourFirstTask => 'اضغط على زر + لإضافة مهمتك الأولى';

  @override
  String get incompleteTasks => 'غير مكتملة';

  @override
  String get completedTasks => 'مكتملة';

  @override
  String get completed => 'مكتملة';

  @override
  String get incomplete => 'غير مكتملة';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get deleteTask => 'حذف المهمة';

  @override
  String deleteTaskConfirmation(String taskTitle) {
    return 'هل أنت متأكد من أنك تريد حذف \"$taskTitle\"؟';
  }

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get add => 'إضافة';

  @override
  String get refresh => 'تحديث';

  @override
  String get taskDetails => 'تفاصيل المهمة';

  @override
  String get taskStatus => 'الحالة';

  @override
  String get createdAt => 'تم الإنشاء';

  @override
  String get updatedAt => 'تم التحديث';

  @override
  String get pageNotFoundTitle => 'الصفحة غير موجودة';

  @override
  String get pageNotFoundMessage => 'الصفحة التي تبحث عنها غير موجودة.';

  @override
  String get backToHome => 'العودة إلى الصفحة الرئيسية';

  @override
  String get noItemsFound => 'لا توجد عناصر';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get retryHint => 'يحاول إعادة تحميل المحتوى';

  @override
  String get selectLanguageHint => 'يفتح مربع حوار اختيار اللغة';

  @override
  String get progressIndicator => 'مؤشر التقدم';

  @override
  String percentValue(int percent) {
    return '$percent بالمئة';
  }

  @override
  String get stateLoading => 'جاري التحميل';

  @override
  String get stateDisabled => 'معطل';

  @override
  String focusedOn(String label) {
    return 'التركيز على $label';
  }

  @override
  String navigatedTo(String page) {
    return 'تم الانتقال إلى $page';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعة',
      many: 'منذ $count ساعة',
      few: 'منذ $count ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة واحدة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يوم',
      many: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم واحد',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count شهر',
      many: 'منذ $count شهرًا',
      few: 'منذ $count أشهر',
      two: 'منذ شهرين',
      one: 'منذ شهر واحد',
      zero: 'هذا الشهر',
    );
    return '$_temp0';
  }

  @override
  String yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count سنة',
      many: 'منذ $count سنة',
      few: 'منذ $count سنوات',
      two: 'منذ سنتين',
      one: 'منذ سنة واحدة',
      zero: 'هذا العام',
    );
    return '$_temp0';
  }
}
