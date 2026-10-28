import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  bool get isEnglish => locale.languageCode == 'en';

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        const AppStrings(Locale('vi'));
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  // ==================== WELCOME & ONBOARDING ====================
  String welcomeTitle(int index) {
    switch (index) {
      case 0:
        return isEnglish
            ? 'Preserving the essence of Vietnamese studiousness'
            : 'Nơi lưu giữ tinh hoa hiếu học Việt Nam';
      case 1:
        return isEnglish
            ? 'Discover unique architecture through time'
            : 'Dấu ấn giao thoa của những nền văn hóa';
      case 2:
      default:
        return isEnglish
            ? 'Experience smart interactive heritage'
            : 'Khám phá vẻ đẹp kinh thành xưa';
    }
  }

  String welcomeDescription(int index) {
    switch (index) {
      case 0:
        return isEnglish
            ? 'Temple of Literature, the first university of Vietnam.'
            : 'Văn Miếu – Quốc Tử Giám là di tích lịch sử gắn với truyền thống hiếu học và giáo dục Việt Nam.';
      case 1:
        return isEnglish
            ? 'Hoi An Ancient Town, a well-preserved trading port.'
            : 'Những ngôi nhà truyền thống và kiến trúc phố cổ lưu giữ dấu ấn lịch sử của thương cảng Hội An.';
      case 2:
      default:
        return isEnglish
            ? 'Thien Mu Pagoda, iconic cultural symbol of Hue.'
            : 'Khám phá kiến trúc cung đình và giá trị lịch sử của quần thể di tích Cố đô Huế.';
    }
  }

  String get welcomeTagline => isEnglish
      ? 'Living heritage in every journey'
      : 'Di sản sống trong từng hành trình';

  String get welcomeStory0 => welcomeTitle(0);
  String get welcomeStory1 => welcomeTitle(1);
  String get welcomeStory2 => welcomeTitle(2);

  String get welcomeStart =>
      isEnglish ? 'Bắt đầu khám phá' : 'Bắt đầu khám phá';
  String get welcomeSkip => isEnglish ? 'Bỏ qua' : 'Bỏ qua';
  String get skip => welcomeSkip;
  String get next => isEnglish ? 'Tiếp tục' : 'Tiếp tục';
  String get start => welcomeStart;
  String get languageTooltip => isEnglish ? 'Switch language' : 'Đổi ngôn ngữ';

  String welcomePage(int current, int total) =>
      isEnglish ? 'Trang $current trên $total' : 'Trang $current trên $total';

  // ==================== LOGIN PAGE ====================
  String get loginTitle => isEnglish ? 'Sign In' : 'Đăng nhập tài khoản';
  String get loginSubtitle => isEnglish
      ? 'Continue your journey exploring heritage.'
      : 'Tiếp tục hành trình khám phá các di sản.';
  String get loginEmailLabel => isEnglish ? 'Email' : 'Email';
  String get loginEmailRequired => 'Vui lòng nhập email.';
  String get loginEmailInvalid => 'Email không hợp lệ.';
  String get loginPasswordLabel => isEnglish ? 'Password' : 'Mật khẩu';
  String get loginPasswordRequired => 'Vui lòng nhập mật khẩu.';
  String get loginSubmit => isEnglish ? 'Sign In' : 'Đăng nhập';
  String get loginSignupPrompt =>
      isEnglish ? 'Chưa có tài khoản? Đăng ký' : 'Chưa có tài khoản? Đăng ký';
  String get loginForgotPassword =>
      isEnglish ? 'Forgot password?' : 'Quên mật khẩu?';
  String get loginSubmitNotice => isEnglish
      ? 'Biểu mẫu hợp lệ. Đăng nhập chưa kết nối máy chủ.'
      : 'Biểu mẫu hợp lệ. Đăng nhập chưa kết nối máy chủ.';
  String get showPassword => isEnglish ? 'Show password' : 'Hiện mật khẩu';
  String get hidePassword => isEnglish ? 'Hide password' : 'Ẩn mật khẩu';
  String get demoContinue =>
      isEnglish ? 'Continue as Guest' : 'Trải nghiệm Demo';
  String get demoSessionDescription => isEnglish
      ? 'Explore full features without an account'
      : 'Khám phá đầy đủ tính năng không cần đăng nhập';

  // ==================== SIGNUP PAGE ====================
  String get signupTitle => isEnglish ? 'Create Account' : 'Đăng ký tài khoản';
  String get signupSubtitle => isEnglish
      ? 'Join us to preserve and explore heritage values.'
      : 'Tham gia cùng chúng tôi để lưu giữ di sản.';
  String get signupNameLabel =>
      isEnglish ? 'Full Name (Optional)' : 'Họ và tên (Không bắt buộc)';
  String get signupEmailLabel => isEnglish ? 'Email' : 'Email';
  String get signupEmailRequired => 'Vui lòng nhập email.';
  String get signupEmailInvalid => 'Email không hợp lệ.';
  String get signupPasswordLabel => isEnglish ? 'Password' : 'Mật khẩu';
  String get signupPasswordRequired => 'Vui lòng nhập mật khẩu.';
  String get signupPasswordMinLength => 'Mật khẩu phải có ít nhất 8 ký tự.';
  String get signupConfirmPasswordLabel =>
      isEnglish ? 'Confirm Password' : 'Xác nhận mật khẩu';
  String get signupConfirmPasswordRequired =>
      isEnglish ? 'Vui lòng xác nhận mật khẩu.' : 'Vui lòng xác nhận mật khẩu.';
  String get signupPasswordMismatch => 'Mật khẩu xác nhận không khớp.';
  String get signupSubmit => isEnglish ? 'Register' : 'Đăng ký';
  String get signupSubmitNotice => isEnglish
      ? 'Biểu mẫu hợp lệ. Đăng ký chưa kết nối máy chủ.'
      : 'Biểu mẫu hợp lệ. Đăng ký chưa kết nối máy chủ.';
  String get signupLoginPrompt =>
      isEnglish ? 'Đã có tài khoản? Đăng nhập' : 'Đã có tài khoản? Đăng nhập';

  // ==================== FORGOT PASSWORD ====================
  String get forgotPasswordTitle =>
      isEnglish ? 'Forgot Password' : 'Quên mật khẩu';
  String get forgotPasswordSubtitle => isEnglish
      ? 'Enter your registered email to receive reset instructions.'
      : 'Nhập email đã đăng ký để nhận hướng dẫn khôi phục.';
  String get forgotPasswordEmailLabel => 'Email';
  String get forgotPasswordSubmit =>
      isEnglish ? 'Send Instructions' : 'Gửi yêu cầu';
  String get forgotPasswordSuccess => isEnglish
      ? 'Reset link sent. Check your inbox.'
      : 'Đã gửi hướng dẫn khôi phục. Vui lòng kiểm tra hộp thư.';
  String get forgotPasswordBackToLogin =>
      isEnglish ? 'Quay lại đăng nhập' : 'Quay lại đăng nhập';
  String get forgotPasswordEmailRequired => 'Vui lòng nhập email.';
  String get forgotPasswordEmailInvalid => 'Email không hợp lệ.';
  String get forgotPasswordNetworkError =>
      isEnglish ? 'Network connection error.' : 'Lỗi kết nối mạng.';
  String get forgotPasswordServerError =>
      isEnglish ? 'Server error occurred.' : 'Lỗi từ phía máy chủ.';
  String get forgotPasswordGenericError => isEnglish
      ? 'An error occurred. Try again.'
      : 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  // ==================== NAVIGATION & SHELL ====================
  String get demoSessionLabel =>
      isEnglish ? 'Demo Session' : 'Phiên trải nghiệm';
  String get openBeaconScanner =>
      isEnglish ? 'Open iBeacon Scanner' : 'Quét iBeacon';
  String get openSimulation => isEnglish ? 'Open Simulation' : 'Chế độ giả lập';

  String get navHome => isEnglish ? 'Home' : 'Trang chủ';
  String get homePreviewBody => isEnglish
      ? 'Explore featured heritage locations around you.'
      : 'Khám phá các điểm di sản nổi bật xung quanh bạn.';
  String get navMap => isEnglish ? 'Map' : 'Bản đồ';
  String get mapPreviewBody => isEnglish
      ? 'Interactive heritage navigation map.'
      : 'Bản đồ chỉ đường di sản tương tác.';
  String get navArtifacts => isEnglish ? 'Artifacts' : 'Hiện vật';
  String get artifactsPreviewBody => isEnglish
      ? 'Discover historical artifacts collection.'
      : 'Bộ sưu tập hiện vật lịch sử đặc sắc.';
  String get navFavorites => isEnglish ? 'Favorites' : 'Yêu thích';
  String get favoritesPreviewBody => isEnglish
      ? 'Your saved favorite heritage spots.'
      : 'Danh sách các di sản bạn đã lưu yêu thích.';
  String get navProfile => isEnglish ? 'Profile' : 'Cá nhân';
  String get profilePreviewBody => isEnglish
      ? 'Manage personal profile and settings.'
      : 'Quản lý thông tin cá nhân và cài đặt.';
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => ['vi', 'en'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
