import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
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

    final strings = AppStrings.of(context);

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.signupTermsRequiredError),
        ),
      );
      return;
    }

    if (widget.authService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.signupSubmitNotice),
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
          SnackBar(
            content: Text(AppStrings.of(context).signupSuccess),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      } on AuthServiceException catch (e) {
        if (!mounted) return;
        if (e.failure == AuthFailure.emailAlreadyRegistered) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context).signupEmailAlreadyRegistered),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context).signupSubmitNotice),
            ),
          );
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).signupSubmitNotice),
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
    final strings = AppStrings.of(context);

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
                  tooltip: strings.signupBackToLoginTooltip,
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
                title: strings.signupHeaderTitle,
                subtitle: strings.signupHeaderSubtitle,
                icon: Icons.account_balance_outlined,
                seamless: true,
              ),

              SizedBox(height: largeGap),

              Text(
                key: const Key('signup-title'),
                strings.signupAccountInfoTitle,
                style: authTheme.textTheme.titleLarge?.copyWith(
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
                decoration: InputDecoration(
                  labelText: strings.signupFullNameLabel,
                  prefixIcon: const Icon(Icons.person_outline),
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
                label: strings.signupPasswordLabel,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return strings.signupPasswordRequired;
                  }
                  if (value.length < 8) {
                    return strings.signupPasswordMinLength;
                  }
                  if (value.length > 128) {
                    return strings.signupPasswordMaxLength;
                  }
                  return null;
                },
              ),

              SizedBox(height: mediumGap),

              AuthPasswordField(
                key: const Key('signup-confirm-password'),
                controller: _confirmPasswordController,
                label: strings.signupConfirmPasswordLabel,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return strings.signupConfirmPasswordRequired;
                  }
                  if (value != _passwordController.text) {
                    return strings.signupPasswordMismatch;
                  }
                  return null;
                },
              ),

              SizedBox(height: mediumGap),

              // Điều khoản sử dụng dạng Checkbox chuẩn mockup
              _buildTermsCheckbox(authTheme, strings),

              SizedBox(height: largeGap),

              AuthSubmitButton(
                buttonKey: const Key('signup-submit'),
                label: strings.signupSubmit,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),

              SizedBox(height: mediumGap),

              _buildLoginPrompt(authTheme, strings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox(ThemeData theme, AppStrings strings) {
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
                  text: strings.signupTermsAgreement,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: HeritagePalette.secondaryText,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: strings.signupTermsOfService,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: HeritagePalette.primaryNavy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: strings.signupAndWord),
                    TextSpan(
                      text: strings.signupPrivacyPolicy,
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

  Widget _buildLoginPrompt(ThemeData theme, AppStrings strings) {
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
              text: strings.signupPromptQuestion,
              style: theme.textTheme.bodySmall?.copyWith(
                color: HeritagePalette.secondaryText,
              ),
              children: [
                TextSpan(
                  text: strings.signupPromptAction,
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
