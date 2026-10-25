import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'auth_widgets.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Biểu mẫu hợp lệ. Đăng nhập chưa kết nối máy chủ.'),
      ),
    );
  }

  Future<void> _openSignup() {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const SignupPage()));
  }

  @override
  Widget build(BuildContext context) {
    final compactHeight = isCompactAuthViewport(context);

    return AuthPageScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthBrandHeader(
              title: 'Đăng nhập tài khoản',
              subtitle: 'Tiếp tục hành trình khám phá các di sản.',
              icon: Icons.account_balance_outlined,
            ),
            SizedBox(
              height: compactHeight ? AppSpacing.medium : AppSpacing.large,
            ),
            AuthEmailField(
              fieldKey: const Key('login-email'),
              controller: _emailController,
            ),
            SizedBox(
              height: compactHeight ? AppSpacing.small : AppSpacing.medium,
            ),
            AuthPasswordField(
              key: const Key('login-password'),
              controller: _passwordController,
              label: 'Mật khẩu',
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Vui lòng nhập mật khẩu.'
                  : null,
            ),
            SizedBox(
              height: compactHeight ? AppSpacing.medium : AppSpacing.large,
            ),
            AuthSubmitButton(label: 'Đăng nhập', onPressed: _submit),
            SizedBox(
              height: compactHeight ? AppSpacing.xSmall : AppSpacing.small,
            ),
            TextButton(
              onPressed: _openSignup,
              child: const Text('Chưa có tài khoản? Đăng ký'),
            ),
          ],
        ),
      ),
    );
  }
}
