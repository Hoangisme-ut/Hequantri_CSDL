import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/l10n/app_strings.dart';
import 'package:flutter_application_1/features/artifacts/artifact.dart';

void main() {
  group('AppStrings VI/EN tests', () {
    const vi = AppStrings(Locale('vi'));
    const en = AppStrings(Locale('en'));

    test('isEnglish flag returns correct boolean', () {
      expect(vi.isEnglish, isFalse);
      expect(en.isEnglish, isTrue);
    });

    test('Feedback form labels and result states are localized', () {
      expect(vi.feedbackTitle, 'Đánh giá hiện vật');
      expect(en.feedbackTitle, 'Artifact feedback');
      expect(vi.feedbackCommentLabel, 'Nhận xét (không bắt buộc)');
      expect(en.feedbackCommentLabel, 'Comment (optional)');
      expect(vi.feedbackSubmittedPending, contains('chờ quản trị viên duyệt'));
      expect(en.feedbackSubmittedPending, contains('waiting for admin review'));
      expect(vi.feedbackAlreadySubmitted, contains('đã gửi đánh giá'));
      expect(en.feedbackAlreadySubmitted, contains('already submitted'));
    });

    test('welcome & onboarding strings differentiate VI and EN', () {
      expect(vi.welcomeStart, 'Bắt đầu khám phá');
      expect(en.welcomeStart, 'Get Started');

      expect(vi.welcomeSkip, 'Bỏ qua');
      expect(en.welcomeSkip, 'Skip');

      expect(vi.next, 'Tiếp tục');
      expect(en.next, 'Next');

      expect(vi.welcomePage(1, 3), 'Trang 1 trên 3');
      expect(en.welcomePage(1, 3), 'Page 1 of 3');

      expect(vi.languageTooltip, 'Đổi ngôn ngữ');
      expect(en.languageTooltip, 'Switch language');

      for (var i = 0; i < 3; i++) {
        expect(vi.welcomeTitle(i), isNot(equals(en.welcomeTitle(i))));
        expect(
          vi.welcomeDescription(i),
          isNot(equals(en.welcomeDescription(i))),
        );
      }
    });

    test('login strings and validation messages differentiate VI and EN', () {
      expect(vi.loginTitle, 'Đăng nhập tài khoản');
      expect(en.loginTitle, 'Sign In');

      expect(vi.loginEmailRequired, 'Vui lòng nhập email.');
      expect(en.loginEmailRequired, 'Please enter your email.');

      expect(vi.loginEmailInvalid, 'Email không hợp lệ.');
      expect(en.loginEmailInvalid, 'Invalid email address.');

      expect(vi.loginPasswordRequired, 'Vui lòng nhập mật khẩu.');
      expect(en.loginPasswordRequired, 'Please enter your password.');

      expect(vi.loginSubmit, 'Đăng nhập');
      expect(en.loginSubmit, 'Sign In');

      expect(vi.loginSignupPrompt, 'Chưa có tài khoản? Đăng ký');
      expect(en.loginSignupPrompt, "Don't have an account? Sign Up");

      expect(vi.loginForgotPassword, 'Quên mật khẩu?');
      expect(en.loginForgotPassword, 'Forgot password?');

      expect(
        vi.loginSubmitNotice,
        'Biểu mẫu hợp lệ. Đăng nhập chưa kết nối máy chủ.',
      );
      expect(en.loginSubmitNotice, 'Valid form. Login server not connected.');

      expect(vi.loginOrDivider, 'Hoặc đăng nhập bằng');
      expect(en.loginOrDivider, 'Or continue with');

      expect(vi.loginRejectedMessage, 'Email hoặc mật khẩu không chính xác.');
      expect(en.loginRejectedMessage, 'Incorrect email or password.');

      expect(vi.demoContinue, 'Trải nghiệm Demo');
      expect(en.demoContinue, 'Continue as Guest');
    });

    test('signup strings and validation messages differentiate VI and EN', () {
      expect(vi.signupTitle, 'Đăng ký tài khoản');
      expect(en.signupTitle, 'Create Account');

      expect(vi.signupAccountInfoTitle, 'Thông tin tài khoản');
      expect(en.signupAccountInfoTitle, 'Account Information');

      expect(vi.signupEmailRequired, 'Vui lòng nhập email.');
      expect(en.signupEmailRequired, 'Please enter your email.');

      expect(vi.signupPasswordMinLength, 'Mật khẩu phải có ít nhất 8 ký tự.');
      expect(
        en.signupPasswordMinLength,
        'Password must be at least 8 characters.',
      );

      expect(vi.signupConfirmPasswordRequired, 'Vui lòng xác nhận mật khẩu.');
      expect(en.signupConfirmPasswordRequired, 'Please confirm your password.');

      expect(vi.signupPasswordMismatch, 'Mật khẩu xác nhận không khớp.');
      expect(
        en.signupPasswordMismatch,
        'Password confirmation does not match.',
      );

      expect(vi.signupSubmit, 'Đăng ký');
      expect(en.signupSubmit, 'Register');

      expect(vi.signupLoginPrompt, 'Đã có tài khoản? Đăng nhập');
      expect(en.signupLoginPrompt, 'Already have an account? Sign In');

      expect(
        vi.signupTermsRequiredError,
        'Vui lòng đồng ý với Điều khoản sử dụng và Chính sách bảo mật.',
      );
      expect(
        en.signupTermsRequiredError,
        'Please agree to the Terms of Service and Privacy Policy.',
      );

      expect(
        vi.signupSuccess,
        'Đăng ký tài khoản thành công! Vui lòng đăng nhập.',
      );
      expect(
        en.signupSuccess,
        'Account registered successfully! Please sign in.',
      );
    });

    test(
      'forgot password strings and validation messages differentiate VI and EN',
      () {
        expect(vi.forgotPasswordTitle, 'Quên mật khẩu');
        expect(en.forgotPasswordTitle, 'Forgot Password');

        expect(vi.forgotPasswordBackToLogin, 'Quay lại đăng nhập');
        expect(en.forgotPasswordBackToLogin, 'Back to Sign In');

        expect(vi.forgotPasswordEmailRequired, 'Vui lòng nhập email.');
        expect(en.forgotPasswordEmailRequired, 'Please enter your email.');

        expect(
          vi.forgotPasswordSuccess,
          'Nếu email này đã đăng ký, hướng dẫn khôi phục sẽ được gửi đến bạn.',
        );
        expect(
          en.forgotPasswordSuccess,
          'If an account uses this email, recovery instructions will be sent.',
        );
      },
    );

    test('artifact categories translate accurately', () {
      expect(vi.categoryAll, 'Tất cả');
      expect(en.categoryAll, 'All');

      expect(vi.categoryCeramics, 'Đồ gốm');
      expect(en.categoryCeramics, 'Ceramics');

      expect(vi.categoryMetal, 'Kim loại');
      expect(en.categoryMetal, 'Metal');

      expect(vi.categoryCulture, 'Văn hóa');
      expect(en.categoryCulture, 'Culture');

      expect(vi.categorySculpture, 'Tượng điêu khắc');
      expect(en.categorySculpture, 'Sculptures');

      expect(en.artifactCategory('Đồ gốm'), 'Ceramics');
      expect(vi.artifactCategory('Đồ gốm'), 'Đồ gốm');
      expect(vi.artifactCategory('Artifacts'), 'Hiện vật');
      expect(vi.artifactCategory('Artifact'), 'Hiện vật');
      expect(en.artifactCategory('Artifacts'), 'Artifact');
      expect(en.artifactCategory('Artifact'), 'Artifact');
      expect(vi.artifactCategory('Favorites'), 'Yêu thích');
      expect(en.artifactCategory('Favorites'), 'Favorites');
      expect(vi.artifactCategory('Artifact details'), 'Chi tiết hiện vật');
      expect(en.artifactCategory('Artifact details'), 'Artifact details');
    });

    test('detail category follows locale while supplied name stays fixed', () {
      const officialName = 'Trống đồng Đông Sơn';
      const artifact = Artifact(
        id: 'test-artifact',
        titleVi: officialName,
        titleEn: officialName,
        period: 'Đông Sơn',
        category: 'Artifacts',
        location: 'Việt Nam',
        descriptionVi: '',
        descriptionEn: '',
        imageUrl: '',
      );

      expect(vi.artifactCategory(artifact.category), 'Hiện vật');
      expect(en.artifactCategory(artifact.category), 'Artifact');
      expect(artifact.getTitle('vi'), officialName);
      expect(artifact.getTitle('en'), officialName);
    });

    test('delegate supports and loads vi and en locales', () async {
      const delegate = AppStrings.delegate;
      expect(delegate.isSupported(const Locale('vi')), isTrue);
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('fr')), isFalse);

      final loadedVi = await delegate.load(const Locale('vi'));
      expect(loadedVi.isEnglish, isFalse);

      final loadedEn = await delegate.load(const Locale('en'));
      expect(loadedEn.isEnglish, isTrue);
    });
  });
}
