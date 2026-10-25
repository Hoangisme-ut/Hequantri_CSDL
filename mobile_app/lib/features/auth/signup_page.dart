import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Biểu mẫu hợp lệ. Đăng ký chưa kết nối máy chủ.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactHeight = isCompactAuthViewport(context);

    return AuthPageScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton.filledTonal(
                tooltip: 'Quay lại đăng nhập',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  foregroundColor: HeritagePalette.authGold,
                  backgroundColor: HeritagePalette.authNavyRaised,
                  side: BorderSide(
                    color: HeritagePalette.authGold.withValues(alpha: 0.42),
                  ),
                ),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            SizedBox(
              height: compactHeight ? AppSpacing.xSmall : AppSpacing.small,
            ),
            AuthBrandHeader(
              title: 'Tạo tài khoản',
              subtitle:
                  'Bắt đầu hành trình khám phá di sản cùng Smart Heritage.',
              icon: Icons.account_balance_outlined,
            ),
            SizedBox(
              height: compactHeight ? AppSpacing.medium : AppSpacing.large,
            ),
            Text(
              key: const Key('signup-title'),
              'Thông tin tài khoản',
              style: theme.textTheme.titleLarge?.copyWith(
                color: HeritagePalette.authText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              height: compactHeight ? AppSpacing.small : AppSpacing.medium,
            ),
            TextFormField(
              key: const Key('signup-full-name'),
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              scrollPadding: const EdgeInsets.only(bottom: AppSpacing.xLarge),
              decoration: const InputDecoration(
                labelText: 'Họ tên (không bắt buộc)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            SizedBox(
              height: compactHeight ? AppSpacing.small : AppSpacing.medium,
            ),
            AuthEmailField(
              fieldKey: const Key('signup-email'),
              controller: _emailController,
            ),
            SizedBox(
              height: compactHeight ? AppSpacing.small : AppSpacing.medium,
            ),
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
            SizedBox(
              height: compactHeight ? AppSpacing.small : AppSpacing.medium,
            ),
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
            SizedBox(
              height: compactHeight ? AppSpacing.medium : AppSpacing.large,
            ),
            AuthSubmitButton(
              buttonKey: const Key('signup-submit'),
              label: 'Tạo tài khoản',
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.small),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã có tài khoản? Đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }
}
