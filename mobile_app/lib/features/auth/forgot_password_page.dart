import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import 'auth_service.dart';
import 'auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({required this.authService, super.key});

  final AuthService authService;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _requestSubmitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    widget.authService.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final strings = AppStrings.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _requestSubmitted = false;
    });

    String? errorMessage;
    try {
      await widget.authService.requestPasswordRecovery(
        email: _emailController.text.trim(),
      );
    } on AuthServiceException catch (error) {
      errorMessage = switch (error.failure) {
        AuthFailure.network => strings.forgotPasswordNetworkError,
        AuthFailure.server => strings.forgotPasswordServerError,
        _ => strings.forgotPasswordGenericError,
      };
    } catch (_) {
      errorMessage = strings.forgotPasswordGenericError;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = errorMessage;
      _requestSubmitted = errorMessage == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final compact = isCompactAuthViewport(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 360
        ? AppSpacing.medium
        : AppSpacing.large;

    return Theme(
      data: AppTheme.auth(theme),
      child: Scaffold(
        backgroundColor: HeritagePalette.background,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7F9FE), Color(0xFFF1F5FB)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                compact ? AppSpacing.small : AppSpacing.medium,
                horizontalPadding,
                AppSpacing.xLarge,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('forgot-password-back'),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          label: Text(strings.forgotPasswordBackToLogin),
                          style: TextButton.styleFrom(
                            foregroundColor: HeritagePalette.primaryNavy,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.small,
                              vertical: AppSpacing.small,
                            ),
                            textStyle: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: compact ? AppSpacing.large : AppSpacing.xLarge,
                      ),
                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6EBFA),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: HeritagePalette.actionBlue.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 38,
                            color: HeritagePalette.primaryNavy,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.large),
                      Text(
                        strings.forgotPasswordTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: HeritagePalette.primaryNavy,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        strings.forgotPasswordSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: HeritagePalette.bodyText,
                          height: 1.55,
                        ),
                      ),
                      SizedBox(
                        height: compact ? AppSpacing.large : AppSpacing.xLarge,
                      ),
                      Container(
                        padding: EdgeInsets.all(
                          compact ? AppSpacing.medium : AppSpacing.large,
                        ),
                        decoration: BoxDecoration(
                          color: HeritagePalette.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFDDE4F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C1E2A5A),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                strings.forgotPasswordEmailLabel,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: HeritagePalette.primaryNavy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.small),
                              AuthEmailField(
                                fieldKey: const Key('forgot-password-email'),
                                controller: _emailController,
                                label: strings.forgotPasswordEmailLabel,
                                validator: (value) => validateEmail(
                                  value,
                                  requiredMessage:
                                      strings.forgotPasswordEmailRequired,
                                  invalidMessage:
                                      strings.forgotPasswordEmailInvalid,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.large),
                              AuthSubmitButton(
                                buttonKey: const Key('forgot-password-submit'),
                                label: strings.forgotPasswordSubmit,
                                onPressed: _submit,
                                isLoading: _isSubmitting,
                              ),
                              if (_requestSubmitted) ...[
                                const SizedBox(height: AppSpacing.medium),
                                _StatusMessage(
                                  message: strings.forgotPasswordSuccess,
                                  isSuccess: true,
                                ),
                              ],
                              if (_errorMessage != null) ...[
                                const SizedBox(height: AppSpacing.medium),
                                _StatusMessage(
                                  message: _errorMessage!,
                                  isSuccess: false,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.large),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: HeritagePalette.bodyText,
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Flexible(
                            child: Text(
                              'Thông tin tài khoản của bạn được bảo vệ an toàn.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: HeritagePalette.bodyText,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess
        ? const Color(0xFF176B4D)
        : Theme.of(context).colorScheme.error;
    final background = isSuccess
        ? const Color(0xFFEAF7F0)
        : const Color(0xFFFFF0F0);

    return Container(
      key: isSuccess
          ? const Key('forgot-password-success')
          : const Key('forgot-password-error'),
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: color, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
