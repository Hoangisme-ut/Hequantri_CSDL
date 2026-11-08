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

  String get welcomeStart => isEnglish ? 'Get Started' : 'Bắt đầu khám phá';
  String get welcomeSkip => isEnglish ? 'Skip' : 'Bỏ qua';
  String get skip => welcomeSkip;
  String get next => isEnglish ? 'Next' : 'Tiếp tục';
  String get start => welcomeStart;
  String get languageTooltip => isEnglish ? 'Switch language' : 'Đổi ngôn ngữ';
  String get siteTranslationFallback => isEnglish
      ? 'English translation is not available; showing Vietnamese content.'
      : 'Chưa có bản dịch tiếng Anh; đang hiển thị tiếng Việt.';

  String welcomePage(int current, int total) =>
      isEnglish ? 'Page $current of $total' : 'Trang $current trên $total';

  // ==================== LOGIN PAGE ====================
  String get loginTitle => isEnglish ? 'Sign In' : 'Đăng nhập tài khoản';
  String get loginSubtitle => isEnglish
      ? 'Continue your journey exploring heritage.'
      : 'Tiếp tục hành trình khám phá các di sản.';
  String get loginEmailLabel => isEnglish ? 'Email' : 'Email';
  String get loginEmailRequired =>
      isEnglish ? 'Please enter your email.' : 'Vui lòng nhập email.';
  String get loginEmailInvalid =>
      isEnglish ? 'Invalid email address.' : 'Email không hợp lệ.';
  String get loginPasswordLabel => isEnglish ? 'Password' : 'Mật khẩu';
  String get loginPasswordRequired =>
      isEnglish ? 'Please enter your password.' : 'Vui lòng nhập mật khẩu.';
  String get loginSubmit => isEnglish ? 'Sign In' : 'Đăng nhập';
  String get loginSignupPrompt => isEnglish
      ? "Don't have an account? Sign Up"
      : 'Chưa có tài khoản? Đăng ký';
  String get loginPromptQuestion =>
      isEnglish ? "Don't have an account? " : 'Chưa có tài khoản? ';
  String get loginPromptAction => isEnglish ? 'Sign Up' : 'Đăng ký';
  String get loginForgotPassword =>
      isEnglish ? 'Forgot password?' : 'Quên mật khẩu?';
  String get loginSubmitNotice => isEnglish
      ? 'Valid form. Login server not connected.'
      : 'Biểu mẫu hợp lệ. Đăng nhập chưa kết nối máy chủ.';
  String get loginOrDivider =>
      isEnglish ? 'Or continue with' : 'Hoặc đăng nhập bằng';
  String get loginGoogleNotConfigured => isEnglish
      ? 'Google sign-in has not been configured yet.'
      : 'Đăng nhập Google chưa được cấu hình.';
  String get loginRejectedMessage => isEnglish
      ? 'Incorrect email or password.'
      : 'Email hoặc mật khẩu không chính xác.';
  String get loginNetworkErrorMessage => isEnglish
      ? 'Cannot connect to server. Check your network.'
      : 'Không thể kết nối tới máy chủ. Vui lòng thử lại sau.';
  String get loginGenericErrorMessage => isEnglish
      ? 'Login failed. Please try again.'
      : 'Đăng nhập thất bại. Vui lòng thử lại.';
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
  String get signupHeaderTitle =>
      isEnglish ? 'Create Account' : 'Tạo tài khoản';
  String get signupHeaderSubtitle => isEnglish
      ? 'Begin your journey to explore heritage'
      : 'Bắt đầu hành trình khám phá di sản';
  String get signupAccountInfoTitle =>
      isEnglish ? 'Account Information' : 'Thông tin tài khoản';
  String get signupNameLabel =>
      isEnglish ? 'Full Name (Optional)' : 'Họ và tên (Không bắt buộc)';
  String get signupFullNameLabel => isEnglish ? 'Full Name' : 'Họ và tên';
  String get signupEmailLabel => isEnglish ? 'Email' : 'Email';
  String get signupEmailRequired =>
      isEnglish ? 'Please enter your email.' : 'Vui lòng nhập email.';
  String get signupEmailInvalid =>
      isEnglish ? 'Invalid email address.' : 'Email không hợp lệ.';
  String get signupPasswordLabel => isEnglish ? 'Password' : 'Mật khẩu';
  String get signupPasswordRequired =>
      isEnglish ? 'Please enter your password.' : 'Vui lòng nhập mật khẩu.';
  String get signupPasswordMinLength => isEnglish
      ? 'Password must be at least 8 characters.'
      : 'Mật khẩu phải có ít nhất 8 ký tự.';
  String get signupPasswordMaxLength => isEnglish
      ? 'Password cannot exceed 128 characters.'
      : 'Mật khẩu không được vượt quá 128 ký tự.';
  String get signupConfirmPasswordLabel =>
      isEnglish ? 'Confirm Password' : 'Xác nhận mật khẩu';
  String get signupConfirmPasswordRequired => isEnglish
      ? 'Please confirm your password.'
      : 'Vui lòng xác nhận mật khẩu.';
  String get signupPasswordMismatch => isEnglish
      ? 'Password confirmation does not match.'
      : 'Mật khẩu xác nhận không khớp.';
  String get signupTermsAgreement =>
      isEnglish ? 'I agree to the ' : 'Tôi đồng ý với ';
  String get signupTermsOfService =>
      isEnglish ? 'Terms of Service' : 'Điều khoản sử dụng';
  String get signupAndWord => isEnglish ? ' and ' : ' và ';
  String get signupPrivacyPolicy =>
      isEnglish ? 'Privacy Policy' : 'Chính sách bảo mật';
  String get signupTermsRequiredError => isEnglish
      ? 'Please agree to the Terms of Service and Privacy Policy.'
      : 'Vui lòng đồng ý với Điều khoản sử dụng và Chính sách bảo mật.';
  String get signupSubmit => isEnglish ? 'Register' : 'Đăng ký';
  String get signupSubmitNotice => isEnglish
      ? 'Valid form. Registration server not connected.'
      : 'Biểu mẫu hợp lệ. Đăng ký chưa kết nối máy chủ.';
  String get signupSuccess => isEnglish
      ? 'Account registered successfully! Please sign in.'
      : 'Đăng ký tài khoản thành công! Vui lòng đăng nhập.';
  String get signupEmailAlreadyRegistered => isEnglish
      ? 'This email is already registered.'
      : 'Email này đã được đăng ký trong hệ thống.';
  String get signupLoginPrompt => isEnglish
      ? 'Already have an account? Sign In'
      : 'Đã có tài khoản? Đăng nhập';
  String get signupPromptQuestion =>
      isEnglish ? 'Already have an account? ' : 'Đã có tài khoản? ';
  String get signupPromptAction => isEnglish ? 'Sign In' : 'Đăng nhập';
  String get signupBackToLoginTooltip =>
      isEnglish ? 'Back to sign in' : 'Quay lại đăng nhập';

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
      isEnglish ? 'Back to Sign In' : 'Quay lại đăng nhập';
  String get forgotPasswordEmailRequired =>
      isEnglish ? 'Please enter your email.' : 'Vui lòng nhập email.';
  String get forgotPasswordEmailInvalid =>
      isEnglish ? 'Invalid email address.' : 'Email không hợp lệ.';
  String get forgotPasswordNetworkError =>
      isEnglish ? 'Network connection error.' : 'Lỗi kết nối mạng.';
  String get forgotPasswordServerError =>
      isEnglish ? 'Server error occurred.' : 'Lỗi từ phía máy chủ.';
  String get forgotPasswordGenericError => isEnglish
      ? 'An error occurred. Try again.'
      : 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  // ==================== ARTIFACT CATEGORIES ====================
  String get categoryAll => isEnglish ? 'All' : 'Tất cả';
  String get categoryCeramics => isEnglish ? 'Ceramics' : 'Đồ gốm';
  String get categoryMetal => isEnglish ? 'Metal' : 'Kim loại';
  String get categoryCulture => isEnglish ? 'Culture' : 'Văn hóa';
  String get categorySculpture => isEnglish ? 'Sculptures' : 'Tượng điêu khắc';

  String artifactCategory(String category) {
    switch (category) {
      case 'Artifacts':
      case 'Artifact':
        return isEnglish ? 'Artifact' : 'Hiện vật';
      case 'Favorites':
        return navFavorites;
      case 'Artifact details':
        return isEnglish ? 'Artifact details' : 'Chi tiết hiện vật';
      case 'Tất cả':
        return categoryAll;
      case 'Đồ gốm':
        return categoryCeramics;
      case 'Kim loại':
        return categoryMetal;
      case 'Văn hóa':
        return categoryCulture;
      case 'Tượng điêu khắc':
        return categorySculpture;
      default:
        return category;
    }
  }

  String get apiConfigurationMissing => isEnglish
      ? 'Configure API_BASE_URL to connect to the backend.'
      : 'Chưa cấu hình địa chỉ API để kết nối máy chủ.';

  String get favoritesSignInRequired => isEnglish
      ? 'Sign in to load your favorites.'
      : 'Vui lòng đăng nhập để tải danh sách yêu thích.';

  String get historySignInRequired => isEnglish
      ? 'Sign in to load your visit history.'
      : 'Vui lòng đăng nhập để tải lịch sử tham quan.';

  String get favoritesLoadError => isEnglish
      ? 'Could not load favorites. Please retry.'
      : 'Không tải được danh sách yêu thích. Vui lòng thử lại.';

  String get historyLoadError => isEnglish
      ? 'Could not load visit history. Please retry.'
      : 'Không tải được lịch sử tham quan. Vui lòng thử lại.';

  String get artifactLoadError => isEnglish
      ? 'Could not load artifacts. Please retry.'
      : 'Không tải được hiện vật. Vui lòng thử lại.';

  String get artifactDetailsLoadError => isEnglish
      ? 'Could not load artifact details.'
      : 'Không tải được chi tiết hiện vật.';

  String get favoriteStatusLoadError => isEnglish
      ? 'Could not load favorite status.'
      : 'Không tải được trạng thái yêu thích.';

  String get favoriteUpdateError => isEnglish
      ? 'Could not update favorite. Please retry.'
      : 'Không cập nhật được trạng thái yêu thích. Vui lòng thử lại.';

  String get feedbackTitle =>
      isEnglish ? 'Artifact feedback' : 'Đánh giá hiện vật';

  String get feedbackPrompt => isEnglish
      ? 'Share your rating for this artifact.'
      : 'Chia sẻ đánh giá của bạn về hiện vật này.';

  String get feedbackRatingLabel =>
      isEnglish ? 'Your rating' : 'Đánh giá của bạn';

  String get feedbackCommentLabel =>
      isEnglish ? 'Comment (optional)' : 'Nhận xét (không bắt buộc)';

  String get feedbackCommentHint =>
      isEnglish ? 'Write up to 2000 characters' : 'Viết tối đa 2000 ký tự';

  String get feedbackSubmit => isEnglish ? 'Submit feedback' : 'Gửi đánh giá';

  String get feedbackSubmitting => isEnglish ? 'Submitting…' : 'Đang gửi…';

  String get feedbackSubmittedPending => isEnglish
      ? 'Your feedback was submitted and is waiting for admin review.'
      : 'Đã gửi đánh giá. Nội dung đang chờ quản trị viên duyệt.';

  String get feedbackSignInRequired => isEnglish
      ? 'Sign in to submit feedback.'
      : 'Vui lòng đăng nhập để gửi đánh giá.';

  String get feedbackApiUnavailable => isEnglish
      ? 'Feedback service is unavailable. Please try again later.'
      : 'Dịch vụ đánh giá chưa khả dụng. Vui lòng thử lại sau.';

  String get feedbackRatingRequired => isEnglish
      ? 'Select a rating from 1 to 5 stars.'
      : 'Hãy chọn mức đánh giá từ 1 đến 5 sao.';

  String get feedbackAlreadySubmitted => isEnglish
      ? 'You have already submitted feedback for this artifact.'
      : 'Bạn đã gửi đánh giá cho hiện vật này.';

  String get feedbackPermissionError => isEnglish
      ? 'Your account is not allowed to submit feedback.'
      : 'Tài khoản không được phép gửi đánh giá.';

  String get feedbackArtifactMissing => isEnglish
      ? 'This artifact is unavailable for feedback.'
      : 'Không thể gửi đánh giá cho hiện vật này.';

  String get feedbackValidationError => isEnglish
      ? 'Check the rating and comment, then try again.'
      : 'Hãy kiểm tra đánh giá và nhận xét rồi thử lại.';

  String get feedbackNetworkError => isEnglish
      ? 'Could not connect to the server. Check your connection and retry.'
      : 'Không kết nối được máy chủ. Hãy kiểm tra mạng và thử lại.';

  String get feedbackServerError => isEnglish
      ? 'The server could not save your feedback. Please retry later.'
      : 'Máy chủ chưa lưu được đánh giá. Vui lòng thử lại sau.';

  String get feedbackUnexpectedError => isEnglish
      ? 'Could not submit feedback. Please retry.'
      : 'Không gửi được đánh giá. Vui lòng thử lại.';

  String get beaconContentLoadError => isEnglish
      ? 'Could not load beacon content. Please retry.'
      : 'Không tải được nội dung beacon. Vui lòng thử lại.';

  String get beaconSignInRequired => isEnglish
      ? 'Sign in to load beacon content.'
      : 'Cần đăng nhập để tải nội dung beacon.';

  String visitorApiError(int? statusCode) {
    if (statusCode == 401) {
      return isEnglish
          ? 'Your session has expired. Please sign in again.'
          : 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (statusCode == 403) {
      return isEnglish
          ? 'Your account cannot access this data.'
          : 'Tài khoản của bạn không được phép truy cập dữ liệu này.';
    }
    if (statusCode == 404) {
      return isEnglish
          ? 'The requested heritage record was not found.'
          : 'Không tìm thấy dữ liệu di sản được yêu cầu.';
    }
    if (statusCode != null && statusCode >= 500) {
      return isEnglish
          ? 'The server is unavailable. Please try again.'
          : 'Máy chủ hiện không khả dụng. Vui lòng thử lại.';
    }
    if (statusCode == null) {
      return isEnglish
          ? 'Could not connect to the server. Please retry.'
          : 'Không thể kết nối máy chủ. Vui lòng thử lại.';
    }
    return isEnglish
        ? 'The request failed ($statusCode).'
        : 'Yêu cầu thất bại ($statusCode).';
  }

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
