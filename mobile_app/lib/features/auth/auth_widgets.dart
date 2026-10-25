import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../../shared/widgets/heritage_widgets.dart';
import '../../theme/app_theme.dart';

export '../../shared/widgets/heritage_widgets.dart';

bool isCompactAuthViewport(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  return mediaQuery.size.height - mediaQuery.viewInsets.bottom < 700;
}

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.auth(Theme.of(context)),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HeritagePalette.authNavyRaised,
                HeritagePalette.authNavy,
                HeritagePalette.authNavy,
              ],
              stops: [0, 0.34, 1],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: -116,
                left: -120,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: Size(280, 280),
                    painter: _DrumPatternPainter(),
                  ),
                ),
              ),
              const Positioned(
                right: -140,
                bottom: -146,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: Size(310, 310),
                    painter: _DrumPatternPainter(),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;
                    final verticalPadding = constraints.maxHeight < 700
                        ? AppSpacing.medium
                        : AppSpacing.large;
                    final minHeight =
                        constraints.maxHeight > verticalPadding * 2
                        ? constraints.maxHeight - verticalPadding * 2
                        : 0.0;

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth < 360
                            ? AppSpacing.medium
                            : AppSpacing.large,
                        vertical: verticalPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isDesktop ? 1120 : 520,
                            ),
                            child: isDesktop
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Expanded(
                                        child: AuthHeritageAside(),
                                      ),
                                      const SizedBox(width: AppSpacing.xLarge),
                                      SizedBox(
                                        width: 520,
                                        child: _AuthFormPanel(child: child),
                                      ),
                                    ],
                                  )
                                : _AuthFormPanel(isMobile: true, child: child),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({required this.child, this.isMobile = false});

  final Widget child;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 400;

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 0 : AppSpacing.small,
        ),
        child: child,
      );
    }

    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.medium : AppSpacing.large),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(
          color: HeritagePalette.authGold.withValues(alpha: 0.34),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D000000),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthHeritageAside extends StatelessWidget {
  const AuthHeritageAside({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xLarge,
        vertical: AppSpacing.large,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HeritageMark(size: 76),
          const SizedBox(height: AppSpacing.large),
          Text(
            'SMART HERITAGE',
            style: theme.textTheme.labelLarge?.copyWith(
              color: HeritagePalette.authGold,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Di sản sống\ntrong từng hành trình.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: HeritagePalette.authText,
              fontWeight: FontWeight.w700,
              height: 1.16,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Container(
            width: 72,
            height: 3,
            decoration: BoxDecoration(
              color: HeritagePalette.authGold,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Khám phá những câu chuyện văn hóa và kiến trúc được lưu giữ qua thời gian.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final mobile = viewportWidth < 600;
    final compact = viewportWidth < 400 || isCompactAuthViewport(context);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HeritagePalette.authNavyRaised, HeritagePalette.authNavy],
        ),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(
          color: HeritagePalette.authGold.withValues(alpha: 0.42),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -14,
            bottom: -18,
            width: compact ? 112 : 144,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HeritageHeaderPainter(
                  color: HeritagePalette.authGold.withValues(
                    alpha: mobile ? 0.08 : 0.12,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: mobile
                  ? (compact ? AppSpacing.small : AppSpacing.medium)
                  : AppSpacing.medium,
            ),
            child: mobile
                ? SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HeritageMark(size: compact ? 46 : 52, icon: icon),
                        SizedBox(
                          height: compact
                              ? AppSpacing.xSmall
                              : AppSpacing.small,
                        ),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: HeritagePalette.authGold,
                            fontSize: compact ? 20 : 22,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: compact ? 4 : AppSpacing.xSmall),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: HeritagePalette.authText.withValues(
                              alpha: 0.9,
                            ),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      HeritageMark(size: 48, icon: icon),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SMART HERITAGE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: HeritagePalette.authGold,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: HeritagePalette.authText,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: HeritagePalette.authText.withValues(
                                  alpha: 0.88,
                                ),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeritageHeaderPainter extends CustomPainter {
  const _HeritageHeaderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(size.width * 0.68, size.height * 0.52);
    for (var index = 0; index < 4; index++) {
      final inset = index * 9.0;
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * 1.15 - inset,
        height: size.height * 0.92 - inset,
      );
      canvas.drawArc(rect, -pi / 2, pi, false, paint);
    }

    final roof = Path()
      ..moveTo(size.width * 0.18, size.height * 0.66)
      ..lineTo(size.width * 0.56, size.height * 0.38)
      ..lineTo(size.width * 0.73, size.height * 0.46)
      ..lineTo(size.width * 0.91, size.height * 0.28)
      ..lineTo(size.width * 0.86, size.height * 0.49)
      ..lineTo(size.width * 0.98, size.height * 0.55);
    canvas.drawPath(roof, paint);
    canvas.drawLine(
      Offset(size.width * 0.45, size.height * 0.71),
      Offset(size.width * 0.96, size.height * 0.71),
      paint,
    );
    for (final x in [0.53, 0.68, 0.83, 0.95]) {
      canvas.drawLine(
        Offset(size.width * x, size.height * 0.72),
        Offset(size.width * x, size.height * 0.94),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeritageHeaderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DrumPatternPainter extends CustomPainter {
  const _DrumPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.46;
    final paint = Paint()
      ..color = HeritagePalette.authGold.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final scale in [1.0, 0.94, 0.74, 0.69, 0.42, 0.37, 0.16]) {
      canvas.drawCircle(center, radius * scale, paint);
    }
    for (var index = 0; index < 32; index++) {
      final angle = 2 * pi * index / 32;
      final innerRadius = radius * (index.isEven ? 0.72 : 0.78);
      final outerRadius = radius * 0.92;
      canvas.drawLine(
        center + Offset(innerRadius * cos(angle), innerRadius * sin(angle)),
        center + Offset(outerRadius * cos(angle), outerRadius * sin(angle)),
        paint,
      );
    }
    for (var index = 0; index < 12; index++) {
      final angle = 2 * pi * index / 12;
      final point =
          center +
          Offset(radius * 0.54 * cos(angle), radius * 0.54 * sin(angle));
      canvas.drawCircle(point, radius * 0.018, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrumPatternPainter oldDelegate) => false;
}

class AuthEmailField extends StatelessWidget {
  const AuthEmailField({
    required this.controller,
    required this.fieldKey,
    super.key,
  });

  final TextEditingController controller;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      scrollPadding: const EdgeInsets.only(bottom: AppSpacing.xLarge),
      autofillHints: const [AutofillHints.email],
      validator: validateEmail,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email_outlined),
      ),
    );
  }
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    required this.controller,
    required this.label,
    required this.validator,
    this.textInputAction = TextInputAction.done,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final TextInputAction textInputAction;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      textInputAction: widget.textInputAction,
      scrollPadding: const EdgeInsets.only(bottom: AppSpacing.xLarge),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Vui lòng nhập email.';
  }

  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailPattern.hasMatch(email)) {
    return 'Email không hợp lệ.';
  }

  return null;
}
