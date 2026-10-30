import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'auth_config.dart';
import 'auth_service.dart';
import 'auth_widgets.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, this.authService});

  final AuthService? authService;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreeToTerms = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng đồng ý với Điều khoản sử dụng và Chính sách bảo mật.',
          ),
        ),
      );
      return;
    }

    if (widget.authService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biểu mẫu hợp lệ. Đăng ký chưa kết nối máy chủ.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final service =
          widget.authService ??
          AuthService(
            baseUrl: AuthConfig.apiBaseUrl,
            client: IoAuthHttpClient(),
          );

      try {
        await service.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim().isNotEmpty
              ? _fullNameController.text.trim()
              : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký tài khoản thành công! Vui lòng đăng nhập.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      } on AuthServiceException catch (e) {
        if (!mounted) return;
        if (e.failure == AuthFailure.emailAlreadyRegistered) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email này đã được đăng ký trong hệ thống.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biểu mẫu hợp lệ. Đăng ký chưa kết nối máy chủ.'),
            ),
          );
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biểu mẫu hợp lệ. Đăng ký chưa kết nối máy chủ.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // SỬA LỖI: Tạo authTheme để đồng bộ màu sắc với LoginPage
    final baseTheme = Theme.of(context);
    final authTheme = AppTheme.auth(baseTheme);

    final compactHeight = isCompactAuthViewport(context);

    final smallGap = compactHeight ? AppSpacing.xSmall : AppSpacing.small;
    final mediumGap = compactHeight ? AppSpacing.small : AppSpacing.medium;
    final largeGap = compactHeight ? AppSpacing.medium : AppSpacing.large;

    // SỬA LỖI: Bọc Theme với authTheme ở ngoài cùng
    return Theme(
      data: authTheme,
      child: AuthPageScaffold(
        heritageBackground: true,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nút quay lại.
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filledTonal(
                  tooltip: 'Quay lại đăng nhập',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    foregroundColor: HeritagePalette.primaryNavy,
                    backgroundColor: Colors.white.withValues(alpha: 0.88),
                    side: const BorderSide(color: HeritagePalette.border),
                  ),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),

              SizedBox(height: smallGap),

              // Tiêu đề di sản.
              AuthBrandHeader(
                title: 'Tạo tài khoản',
                subtitle: 'Bắt đầu hành trình khám phá di sản',
                icon: Icons.account_balance_outlined,
                seamless: true,
              ),

              SizedBox(height: largeGap),

              Text(
                key: const Key('signup-title'),
                'Thông tin tài khoản',
                style: authTheme.textTheme.titleLarge?.copyWith(
                  // SỬA LỖI Ở DÒNG BÊN DƯỚI: Đổi primaryNavy thành authText (Trắng)
                  color: HeritagePalette.authText,
                  fontWeight: FontWeight.w700,
                ),
              ),

              SizedBox(height: mediumGap),

              TextFormField(
                key: const Key('signup-full-name'),
                controller: _fullNameController,
                textInputAction: TextInputAction.next,
                scrollPadding: const EdgeInsets.only(bottom: AppSpacing.xLarge),
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),

              SizedBox(height: mediumGap),

              AuthEmailField(
                fieldKey: const Key('signup-email'),
                controller: _emailController,
              ),

              SizedBox(height: mediumGap),

              AuthPasswordField(
                key: const Key('signup-password'),
                controller: _passwordController,
                label: 'Mật khẩu',
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu.';
                  }
                  if (value.length < 8) {
                    return 'Mật khẩu phải có ít nhất 8 ký tự.';
                  }
                  if (value.length > 128) {
                    return 'Mật khẩu không được vượt quá 128 ký tự.';
                  }
                  return null;
                },
              ),

              SizedBox(height: mediumGap),

              AuthPasswordField(
                key: const Key('signup-confirm-password'),
                controller: _confirmPasswordController,
                label: 'Xác nhận mật khẩu',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu.';
                  }
                  if (value != _passwordController.text) {
                    return 'Mật khẩu xác nhận không khớp.';
                  }
                  return null;
                },
              ),

              SizedBox(height: mediumGap),

              // Điều khoản sử dụng dạng Checkbox chuẩn mockup
              _buildTermsCheckbox(authTheme),

              SizedBox(height: largeGap),

              AuthSubmitButton(
                buttonKey: const Key('signup-submit'),
                label: 'Đăng ký',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),

              SizedBox(height: mediumGap),

              _buildLoginPrompt(authTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox(ThemeData theme) {
    return InkWell(
      key: const Key('signup-terms-agree'),
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          _agreeToTerms = !_agreeToTerms;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agreeToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreeToTerms = value ?? false;
                  });
                },
                activeColor: HeritagePalette.primaryNavy,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Tôi đồng ý với ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: HeritagePalette.secondaryText,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: 'Điều khoản sử dụng',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: HeritagePalette.primaryNavy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: ' và '),
                    TextSpan(
                      text: 'Chính sách bảo mật',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: HeritagePalette.primaryNavy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(ThemeData theme) {
    return Center(
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: AppSpacing.xSmall,
          ),
          child: Text.rich(
            TextSpan(
              text: 'Đã có tài khoản? ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: HeritagePalette.secondaryText,
              ),
              children: [
                TextSpan(
                  text: 'Đăng nhập',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: HeritagePalette.primaryNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
