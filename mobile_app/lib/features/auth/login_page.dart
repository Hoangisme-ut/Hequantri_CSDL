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
    this.onLoginSuccess,
    this.onAuthenticated,
    this.authService,
  });

  final VoidCallback? onLoginSuccess;

  /// Receives the token after successful backend authentication.
  /// The caller owns session storage and navigation.
  final ValueChanged<AuthToken>? onAuthenticated;

  final AuthService? authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _accentColor = HeritagePalette.actionBlue;

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
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    final strings = AppStrings.of(context);
    AuthService? ownedService;

    try {
      if (widget.authService == null &&
          widget.onAuthenticated == null &&
          widget.onLoginSuccess == null) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.loginSubmitNotice)));
        return;
      }

      final service =
          widget.authService ??
          AuthService(
            baseUrl: AuthConfig.apiBaseUrl,
            client: IoAuthHttpClient(),
          );

      if (widget.authService == null) {
        ownedService = service;
      }

      final token = await service.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (token.accessToken.trim().isEmpty ||
          token.tokenType.trim().toLowerCase() != 'bearer') {
        throw const AuthServiceException(AuthFailure.invalidResponse);
      }

      final onAuthenticated = widget.onAuthenticated;

      if (onAuthenticated != null) {
        onAuthenticated(token);
      } else if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.isEnglish
                  ? 'Signed in successfully.'
                  : 'Đăng nhập thành công.',
            ),
          ),
        );
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;

      final message = switch (error.failure) {
        AuthFailure.loginRejected =>
          strings.isEnglish
              ? 'Incorrect email or password.'
              : 'Email hoặc mật khẩu không chính xác.',
        AuthFailure.network =>
          strings.isEnglish
              ? 'Cannot connect to server. Check your network.'
              : 'Không thể kết nối tới máy chủ. Vui lòng thử lại sau.',
        AuthFailure.invalidResponse =>
          strings.isEnglish
              ? 'The server returned an invalid sign-in response.'
              : 'Máy chủ trả về thông tin đăng nhập không hợp lệ.',
        _ =>
          strings.isEnglish
              ? 'Login failed. Please try again.'
              : 'Đăng nhập thất bại. Vui lòng thử lại.',
      };

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
      ownedService?.close();

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
      accentColor: _accentColor,
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
              isLoading: _isLoading,
              backgroundColor: _accentColor,
              onPressed: _isLoading ? null : _submit,
            ),

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
                disabledForegroundColor: HeritagePalette.secondaryText,
                backgroundColor: Colors.white,
                disabledBackgroundColor: Colors.white,
                overlayColor: HeritagePalette.primaryNavy.withValues(
                  alpha: 0.08,
                ),
                side: const BorderSide(color: Color(0xFF747775)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/google/g-logo.png',
                    key: const Key('login-google-mark'),
                    width: 20,
                    height: 20,
                  ),
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
              key: const Key('login-signup'),
              onPressed: _isLoading ? null : _openSignup,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xSmall,
                  vertical: AppSpacing.xSmall,
                ),
                foregroundColor: _accentColor,
                disabledForegroundColor: _accentColor.withValues(alpha: 0.45),
                overlayColor: _accentColor.withValues(alpha: 0.08),
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
              activeColor: _accentColor,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.focused)) {
                  return _accentColor.withValues(alpha: 0.12);
                }
                return null;
              }),
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
        foregroundColor: _accentColor,
        disabledForegroundColor: _accentColor.withValues(alpha: 0.45),
        overlayColor: _accentColor.withValues(alpha: 0.08),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        strings.loginForgotPassword,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: _accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
