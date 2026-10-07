// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Flutter Starter';

  @override
  String get welcome =>
      'Chào mừng đến với Flutter Starter với Clean Architecture!';

  @override
  String get featureFlagsReady => 'Hệ thống Feature Flags đã sẵn sàng!';

  @override
  String get checkExamples =>
      'Xem các ví dụ trong feature_flags_example_screen.dart';

  @override
  String get login => 'Đăng nhập';

  @override
  String get register => 'Đăng ký';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mật khẩu';

  @override
  String get name => 'Tên';

  @override
  String get emailRequired => 'Vui lòng nhập email của bạn';

  @override
  String get emailInvalid => 'Vui lòng nhập địa chỉ email hợp lệ';

  @override
  String get passwordRequired => 'Vui lòng nhập mật khẩu';

  @override
  String passwordMinLength(int minLength) {
    return 'Mật khẩu phải có ít nhất $minLength ký tự';
  }

  @override
  String get nameRequired => 'Vui lòng nhập tên của bạn';

  @override
  String nameMinLength(int minLength) {
    return 'Tên phải có ít nhất $minLength ký tự';
  }

  @override
  String get dontHaveAccount => 'Chưa có tài khoản? Đăng ký';

  @override
  String get alreadyHaveAccount => 'Đã có tài khoản? Đăng nhập';

  @override
  String get retry => 'Thử lại';

  @override
  String get error => 'Lỗi';

  @override
  String get loading => 'Đang tải...';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get selectLanguage => 'Chọn ngôn ngữ';

  @override
  String get english => 'Tiếng Anh';

  @override
  String get spanish => 'Tiếng Tây Ban Nha';

  @override
  String get arabic => 'Tiếng Ả Rập';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get featureFlagsDebug => 'Gỡ lỗi Feature Flags';

  @override
  String get unexpectedError => 'Đã xảy ra lỗi không mong muốn';

  @override
  String get badRequest =>
      'Yêu cầu không hợp lệ. Vui lòng kiểm tra thông tin nhập vào.';

  @override
  String get unauthorized => 'Không được phép. Vui lòng đăng nhập lại.';

  @override
  String get forbidden => 'Bị cấm. Bạn không có quyền truy cập.';

  @override
  String get notFound => 'Không tìm thấy tài nguyên.';

  @override
  String get conflict => 'Xung đột. Tài nguyên đã tồn tại.';

  @override
  String get validationError =>
      'Lỗi xác thực. Vui lòng kiểm tra thông tin nhập vào.';

  @override
  String get tooManyRequests => 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';

  @override
  String get internalServerError => 'Lỗi máy chủ nội bộ. Vui lòng thử lại sau.';

  @override
  String get badGateway => 'Cổng kết nối không hợp lệ. Vui lòng thử lại sau.';

  @override
  String get serviceUnavailable =>
      'Dịch vụ không khả dụng. Vui lòng thử lại sau.';

  @override
  String get gatewayTimeout =>
      'Hết thời gian chờ cổng kết nối. Vui lòng thử lại sau.';

  @override
  String get clientError => 'Đã xảy ra lỗi phía máy khách.';

  @override
  String get serverError => 'Đã xảy ra lỗi máy chủ. Vui lòng thử lại sau.';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mục',
      one: '1 mục',
      zero: 'Không có mục nào',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phút trước',
      one: '1 phút trước',
      zero: 'Vừa xong',
    );
    return '$_temp0';
  }

  @override
  String get tasks => 'Nhiệm vụ';

  @override
  String get addTask => 'Thêm nhiệm vụ';

  @override
  String get editTask => 'Chỉnh sửa nhiệm vụ';

  @override
  String get taskTitle => 'Tiêu đề';

  @override
  String get taskDescription => 'Mô tả';

  @override
  String get taskTitleRequired => 'Vui lòng nhập tiêu đề nhiệm vụ';

  @override
  String get noTasks => 'Chưa có nhiệm vụ nào';

  @override
  String get addYourFirstTask => 'Nhấn nút + để thêm nhiệm vụ đầu tiên của bạn';

  @override
  String get incompleteTasks => 'Chưa hoàn thành';

  @override
  String get completedTasks => 'Đã hoàn thành';

  @override
  String get completed => 'Đã hoàn thành';

  @override
  String get incomplete => 'Chưa hoàn thành';

  @override
  String get edit => 'Chỉnh sửa';

  @override
  String get delete => 'Xóa';

  @override
  String get deleteTask => 'Xóa nhiệm vụ';

  @override
  String deleteTaskConfirmation(String taskTitle) {
    return 'Bạn có chắc chắn muốn xóa \"$taskTitle\"?';
  }

  @override
  String get save => 'Lưu';

  @override
  String get cancel => 'Hủy';

  @override
  String get add => 'Thêm';

  @override
  String get refresh => 'Làm mới';

  @override
  String get taskDetails => 'Chi tiết nhiệm vụ';

  @override
  String get taskStatus => 'Trạng thái';

  @override
  String get createdAt => 'Đã tạo';

  @override
  String get updatedAt => 'Đã cập nhật';

  @override
  String get pageNotFoundTitle => 'Không tìm thấy trang';

  @override
  String get pageNotFoundMessage => 'Trang bạn tìm không tồn tại.';

  @override
  String get backToHome => 'Về trang chủ';

  @override
  String get noItemsFound => 'Không tìm thấy mục nào';

  @override
  String get loadMore => 'Tải thêm';

  @override
  String get retryHint => 'Thử tải lại nội dung';

  @override
  String get selectLanguageHint => 'Mở hộp thoại chọn ngôn ngữ';

  @override
  String get progressIndicator => 'Chỉ báo tiến trình';

  @override
  String percentValue(int percent) {
    return '$percent phần trăm';
  }

  @override
  String get stateLoading => 'Đang tải';

  @override
  String get stateDisabled => 'Đã tắt';

  @override
  String focusedOn(String label) {
    return 'Đang chọn $label';
  }

  @override
  String navigatedTo(String page) {
    return 'Đã chuyển đến $page';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giờ trước',
      zero: 'Vừa xong',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ngày trước',
    );
    return '$_temp0';
  }

  @override
  String monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tháng trước',
    );
    return '$_temp0';
  }

  @override
  String yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count năm trước',
    );
    return '$_temp0';
  }

  @override
  String minutesFromNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phút nữa',
      zero: 'Vừa xong',
    );
    return '$_temp0';
  }

  @override
  String hoursFromNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giờ nữa',
      zero: 'Vừa xong',
    );
    return '$_temp0';
  }

  @override
  String daysFromNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ngày nữa',
    );
    return '$_temp0';
  }

  @override
  String monthsFromNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tháng nữa',
    );
    return '$_temp0';
  }

  @override
  String yearsFromNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count năm nữa',
    );
    return '$_temp0';
  }

  @override
  String get featureFlagsRefreshTooltip => 'Làm mới cờ';

  @override
  String get featureFlagsClearAllTooltip => 'Xóa tất cả ghi đè';

  @override
  String get featureFlagsClearAllTitle => 'Xóa tất cả ghi đè';

  @override
  String get featureFlagsClearAllMessage =>
      'Bạn có chắc muốn xóa tất cả ghi đè cục bộ?';

  @override
  String get featureFlagsClear => 'Xóa';

  @override
  String get featureFlagsAllOverridesCleared => 'Đã xóa tất cả ghi đè cục bộ';

  @override
  String featureFlagsErrorMessage(String error) {
    return 'Lỗi: $error';
  }

  @override
  String get featureFlagsEmpty => 'Không tìm thấy cờ tính năng nào';

  @override
  String get featureFlagsNoDescription => 'Không có mô tả';

  @override
  String get featureFlagsCategoryOther => 'Khác';

  @override
  String featureFlagsUpdatedAt(String time) {
    return 'Cập nhật: $time';
  }

  @override
  String featureFlagsFlagEnabled(String flagKey) {
    return 'Đã bật $flagKey';
  }

  @override
  String featureFlagsFlagDisabled(String flagKey) {
    return 'Đã tắt $flagKey';
  }

  @override
  String featureFlagsOverrideCleared(String flagKey) {
    return 'Đã xóa ghi đè cho $flagKey';
  }

  @override
  String get featureFlagsExamplesTitle => 'Ví dụ Feature Flags';

  @override
  String get featureFlagsOpenDebugMenu => 'Mở menu gỡ lỗi';

  @override
  String get featureFlagsExample1Title => 'Ví dụ 1: FeatureFlagBuilder';

  @override
  String get featureFlagsExample1Body =>
      'Ví dụ này cho thấy cách dùng FeatureFlagBuilder để hiển thị widget có điều kiện.';

  @override
  String get featureFlagsNewFeatureEnabled => 'Tính năng mới đang BẬT';

  @override
  String get featureFlagsNewFeatureDisabled => 'Tính năng mới đang TẮT';

  @override
  String get featureFlagsExample2Title => 'Ví dụ 2: FeatureFlagWidget';

  @override
  String get featureFlagsExample2Body =>
      'Ví dụ này cho thấy cách dùng FeatureFlagWidget cho các trường hợp ẩn/hiện đơn giản.';

  @override
  String get featureFlagsPremiumAvailable => 'Có tính năng cao cấp';

  @override
  String get featureFlagsExample3Title =>
      'Ví dụ 3: Truy cập provider trực tiếp';

  @override
  String get featureFlagsExample3Body =>
      'Ví dụ này cho thấy cách truy cập cờ tính năng trực tiếp từ provider cho logic phức tạp.';

  @override
  String get featureFlagsDarkMode => 'Chế độ tối';

  @override
  String get featureFlagsDarkModeIsEnabled => 'Chế độ tối đang bật';

  @override
  String get featureFlagsDarkModeIsDisabled => 'Chế độ tối đang tắt';

  @override
  String get featureFlagsDarkModeEnabled => 'Đã bật chế độ tối';

  @override
  String get featureFlagsDarkModeDisabled => 'Đã tắt chế độ tối';

  @override
  String get featureFlagsExample4Title => 'Ví dụ 4: Điều hướng có điều kiện';

  @override
  String get featureFlagsExample4Body =>
      'Ví dụ này cho thấy cách hiển thị tùy chọn điều hướng có điều kiện dựa trên cờ tính năng.';

  @override
  String get featureFlagsNavigatingToAnalytics =>
      'Đang chuyển đến Analytics...';

  @override
  String get featureFlagsViewAnalytics => 'Xem Analytics';

  @override
  String get featureFlagsAnalyticsUnavailable => 'Analytics không khả dụng';
}
