import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import 'auth_config.dart';
import 'auth_service.dart';
import 'auth_widgets.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.onDemoContinue,
    this.onLoginSuccess,
    this.authService,
  });

  final VoidCallback? onDemoContinue;
  final VoidCallback? onLoginSuccess;
  final AuthService? authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    final strings = AppStrings.of(context);

    if (widget.authService == null &&
        widget.onLoginSuccess == null &&
        widget.onDemoContinue == null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.loginSubmitNotice)));
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final service =
          widget.authService ??
          AuthService(
            baseUrl: AuthConfig.apiBaseUrl,
            client: IoAuthHttpClient(),
          );

      // Thực hiện đăng nhập thật qua API backend:
      await service.login(email: email, password: password);

      if (!mounted) return;

      // Chỉ khi máy chủ xác thực thành công (nhận Token hợp lệ):
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else if (widget.onDemoContinue != null) {
        widget.onDemoContinue!();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.loginSubmitNotice)));
      }
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      final String message;
      if (e.failure == AuthFailure.loginRejected) {
        message = strings.isEnglish
            ? 'Incorrect email or password.'
            : 'Email hoặc mật khẩu không chính xác.';
      } else if (e.failure == AuthFailure.network) {
        message = strings.isEnglish
            ? 'Cannot connect to server. Check your network.'
            : 'Không thể kết nối tới máy chủ. Vui lòng thử lại sau.';
      } else {
        message = strings.isEnglish
            ? 'Login failed. Please try again.'
            : 'Đăng nhập thất bại. Vui lòng thử lại.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isEnglish
                ? 'Login failed. Please try again.'
                : 'Đăng nhập thất bại. Vui lòng thử lại.',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showGoogleNotConfigured() {
    final isEnglish = AppStrings.of(context).isEnglish;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEnglish
              ? 'Google sign-in has not been configured yet.'
              : 'Đăng nhập Google chưa được cấu hình.',
        ),
      ),
    );
  }

  Future<void> _openSignup() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SignupPage(authService: widget.authService),
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(
          authService: AuthService(
            baseUrl: AuthConfig.apiBaseUrl,
            client: IoAuthHttpClient(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactHeight = isCompactAuthViewport(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 360;
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final isEnglish = strings.isEnglish;

    final smallGap = compactHeight ? AppSpacing.xSmall : AppSpacing.small;
    final mediumGap = compactHeight ? AppSpacing.xSmall : AppSpacing.medium;
    final largeGap = compactHeight ? AppSpacing.small : AppSpacing.large;

    return AuthPageScaffold(
      heritageBackground: true,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthBrandHeader(
              title: strings.loginTitle,
              subtitle: strings.loginSubtitle,
              icon: Icons.account_balance_outlined,
              seamless: true,
            ),

            SizedBox(height: largeGap),

            AuthEmailField(
              fieldKey: const Key('login-email'),
              controller: _emailController,
              label: strings.loginEmailLabel,
              validator: (value) => validateEmail(
                value,
                requiredMessage: strings.loginEmailRequired,
                invalidMessage: strings.loginEmailInvalid,
              ),
            ),

            SizedBox(height: mediumGap),

            AuthPasswordField(
              key: const Key('login-password'),
              controller: _passwordController,
              label: strings.loginPasswordLabel,
              showPasswordTooltip: strings.showPassword,
              hidePasswordTooltip: strings.hidePassword,
              validator: (value) => value == null || value.isEmpty
                  ? strings.loginPasswordRequired
                  : null,
            ),

            SizedBox(height: smallGap),

            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRememberMe(theme, isEnglish),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildForgotPassword(theme, strings),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildRememberMe(theme, isEnglish)),
                    const SizedBox(width: AppSpacing.xSmall),
                    _buildForgotPassword(theme, strings),
                  ],
                );
              },
            ),

            SizedBox(height: largeGap),

            AuthSubmitButton(
              buttonKey: const Key('login-submit'),
              label: strings.loginSubmit,
              onPressed: _isLoading ? null : _submit,
            ),

            if (widget.onDemoContinue != null) ...[
              SizedBox(height: mediumGap),
              OutlinedButton.icon(
                key: const Key('login-demo-preview'),
                onPressed: _isLoading ? null : widget.onDemoContinue,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(
                  strings.demoContinue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: smallGap),
              Text(
                strings.demoSessionDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HeritagePalette.secondaryText,
                ),
              ),
            ],

            SizedBox(height: largeGap),

            LayoutBuilder(
              builder: (context, constraints) {
                final label = isEnglish
                    ? 'Or continue with'
                    : 'Hoặc đăng nhập bằng';

                return Row(
                  children: [
                    const Expanded(
                      child: Divider(
                        color: HeritagePalette.border,
                        thickness: 1,
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow
                              ? AppSpacing.xSmall
                              : AppSpacing.medium,
                        ),
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: HeritagePalette.secondaryText,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        color: HeritagePalette.border,
                        thickness: 1,
                      ),
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: mediumGap),

            OutlinedButton(
              key: const Key('login-google'),
              onPressed: _isLoading ? null : _showGoogleNotConfigured,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? AppSpacing.small : AppSpacing.medium,
                  vertical: AppSpacing.small,
                ),
                foregroundColor: HeritagePalette.primaryNavy,
                backgroundColor: Colors.white.withValues(alpha: 0.88),
                side: const BorderSide(color: HeritagePalette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleMark(),
                  const SizedBox(width: AppSpacing.small),
                  Flexible(
                    child: Text(
                      isEnglish
                          ? 'Continue with Google'
                          : 'Tiếp tục với Google',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: HeritagePalette.primaryNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: mediumGap),

            TextButton(
              onPressed: _isLoading ? null : _openSignup,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xSmall,
                  vertical: AppSpacing.xSmall,
                ),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                strings.loginSignupPrompt,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRememberMe(ThemeData theme, bool isEnglish) {
    return InkWell(
      key: const Key('login-remember-me'),
      borderRadius: BorderRadius.circular(8),
      onTap: _isLoading
          ? null
          : () {
              setState(() {
                _rememberMe = !_rememberMe;
              });
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
        child: Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
              activeColor: HeritagePalette.primaryNavy,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                isEnglish ? 'Remember me' : 'Ghi nhớ đăng nhập',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HeritagePalette.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForgotPassword(ThemeData theme, AppStrings strings) {
    return TextButton(
      key: const Key('login-forgot-password'),
      onPressed: _isLoading ? null : _openForgotPassword,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 36),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xSmall),
        foregroundColor: HeritagePalette.primaryNavy,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        strings.loginForgotPassword,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}
