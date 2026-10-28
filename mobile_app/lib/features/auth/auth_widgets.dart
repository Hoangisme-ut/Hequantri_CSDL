import 'dart:math' show cos, min, pi, sin;

import 'package:flutter/material.dart';

import '../../shared/widgets/heritage_widgets.dart';
import '../../theme/app_theme.dart';

export '../../shared/widgets/heritage_widgets.dart';

bool isCompactAuthViewport(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  return mediaQuery.size.height - mediaQuery.viewInsets.bottom <= 700;
}

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    required this.child,
    this.heritageBackground = false,
    super.key,
  });

  final Widget child;
  final bool heritageBackground;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.auth(Theme.of(context)),
      child: Scaffold(
        backgroundColor: HeritagePalette.background,
        body: Stack(
          children: [
            Positioned.fill(
              child: heritageBackground
                  ? const _LoginHeritageBackground()
                  : const ColoredBox(color: HeritagePalette.background),
            ),
            if (!heritageBackground) ...[
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
            ],
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;
                  final verticalPadding = constraints.maxHeight <= 700
                      ? AppSpacing.medium
                      : AppSpacing.large;
                  final minHeight = constraints.maxHeight > verticalPadding * 2
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
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Expanded(child: AuthHeritageAside()),
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
    );
  }
}

class _LoginHeritageBackground extends StatelessWidget {
  const _LoginHeritageBackground();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bannerWidth = constraints.maxWidth >= 900
            ? min(constraints.maxWidth, 980.0)
            : constraints.maxWidth;
        final bannerHeight = bannerWidth / 1.92;

        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, HeritagePalette.background],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: (constraints.maxWidth - bannerWidth) / 2,
              width: bannerWidth,
              height: bannerHeight,
              child: ExcludeSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 0.22,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF7895C4),
                          BlendMode.color,
                        ),
                        child: Image.asset(
                          'assets/images/van_mieu_welcome.jpg',
                          key: const Key('login-heritage-background-image'),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.58, 1],
                          colors: [
                            Color(0x1AFFFFFF),
                            Color(0x73FFFFFF),
                            Color(0xFFF1F5F9),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _LoginWatercolorPainter()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoginWatercolorPainter extends CustomPainter {
  const _LoginWatercolorPainter();

  static const _line = Color(0x4D5279B8);
  static const _softLine = Color(0x335D86C5);
  static const _wash = Color(0x167A9ED1);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width, 520.0) / 390;
    final stroke = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final softStroke = Paint()
      ..color = _softLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _paintGate(canvas, size, scale, stroke, softStroke);
    _paintBranch(canvas, scale, stroke);
    _paintBird(canvas, Offset(size.width * .84, size.height * .07), scale);
    _paintBird(
      canvas,
      Offset(size.width * .91, size.height * .105),
      scale * .64,
    );
    _paintBottomMotif(canvas, size, scale, stroke, softStroke);
  }

  void _paintGate(
    Canvas canvas,
    Size size,
    double scale,
    Paint stroke,
    Paint softStroke,
  ) {
    final center = size.width * .64;
    final top = size.height * .045;
    final gateWidth = min(size.width * .66, 300.0 * scale);
    final half = gateWidth / 2;
    final tierHeight = 25 * scale;
    final lowerRoofY = top + 58 * scale;

    void roof(double y, double roofHalf, double rise, Paint paint) {
      final path = Path()
        ..moveTo(center - roofHalf, y + 9 * scale)
        ..quadraticBezierTo(
          center - roofHalf * .73,
          y + 8 * scale,
          center - roofHalf * .47,
          y + rise,
        )
        ..quadraticBezierTo(
          center,
          y - 2 * scale,
          center + roofHalf * .47,
          y + rise,
        )
        ..quadraticBezierTo(
          center + roofHalf * .73,
          y + 8 * scale,
          center + roofHalf,
          y + 9 * scale,
        )
        ..quadraticBezierTo(
          center + roofHalf * .76,
          y + 10 * scale,
          center + roofHalf * .54,
          y + 14 * scale,
        )
        ..quadraticBezierTo(
          center,
          y + 5 * scale,
          center - roofHalf * .54,
          y + 14 * scale,
        )
        ..quadraticBezierTo(
          center - roofHalf * .76,
          y + 10 * scale,
          center - roofHalf,
          y + 9 * scale,
        );
      canvas.drawPath(path, paint);
      canvas.drawLine(
        Offset(center - roofHalf * .48, y + rise + 4 * scale),
        Offset(center + roofHalf * .48, y + rise + 4 * scale),
        paint,
      );
      for (var tile = -2; tile <= 2; tile++) {
        final x = center + tile * roofHalf * .16;
        canvas.drawLine(
          Offset(x, y + rise + 1 * scale),
          Offset(x, y + 12 * scale),
          paint,
        );
      }
    }

    roof(top + 8 * scale, half * .57, 16 * scale, softStroke);
    roof(lowerRoofY, half, 24 * scale, stroke);

    final upperBase = top + 36 * scale;
    final gateBase = top + 134 * scale;
    canvas.drawLine(
      Offset(center - half * .59, upperBase),
      Offset(center + half * .59, upperBase),
      softStroke,
    );
    canvas.drawLine(
      Offset(center - half * .92, gateBase),
      Offset(center + half * .92, gateBase),
      stroke,
    );
    canvas.drawLine(
      Offset(center - half * .78, gateBase + 5 * scale),
      Offset(center + half * .78, gateBase + 5 * scale),
      softStroke,
    );

    final facadeTop = lowerRoofY + tierHeight * .35;
    final facadeBottom = gateBase;
    for (final side in [-1.0, 1.0]) {
      final x = center + side * half * .77;
      canvas.drawLine(Offset(x, facadeTop), Offset(x, facadeBottom), stroke);
      final window = Rect.fromCenter(
        center: Offset(center + side * half * .57, facadeTop + 45 * scale),
        width: 17 * scale,
        height: 34 * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(window, Radius.circular(8 * scale)),
        softStroke,
      );
    }
    canvas.drawLine(
      Offset(center - half * .76, facadeTop),
      Offset(center + half * .76, facadeTop),
      stroke,
    );

    final arch = Path()
      ..moveTo(center - half * .28, facadeBottom)
      ..lineTo(center - half * .28, facadeTop + 47 * scale)
      ..cubicTo(
        center - half * .28,
        facadeTop + 16 * scale,
        center + half * .28,
        facadeTop + 16 * scale,
        center + half * .28,
        facadeTop + 47 * scale,
      )
      ..lineTo(center + half * .28, facadeBottom);
    canvas.drawPath(arch, softStroke);
    canvas.drawLine(
      Offset(center - half * .28, facadeTop + 47 * scale),
      Offset(center + half * .28, facadeTop + 47 * scale),
      softStroke,
    );
    for (final side in [-1.0, 1.0]) {
      final columnX = center + side * half * .38;
      canvas.drawLine(
        Offset(columnX, facadeTop + 49 * scale),
        Offset(columnX, facadeBottom),
        stroke,
      );
      canvas.drawLine(
        Offset(columnX - 4 * scale, facadeTop + 49 * scale),
        Offset(columnX + 4 * scale, facadeTop + 49 * scale),
        stroke,
      );
    }
    canvas.drawLine(
      Offset(center - half * .92, gateBase + 9 * scale),
      Offset(center + half * .92, gateBase + 9 * scale),
      softStroke,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center, top + 16 * scale),
        width: 4 * scale,
        height: 4 * scale,
      ),
      Paint()..color = _line,
    );

    final reflection = Paint()
      ..color = _wash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale;
    for (var row = 0; row < 3; row++) {
      final y = gateBase + (18 + row * 10) * scale;
      canvas.drawLine(
        Offset(center - half * (.6 - row * .06), y),
        Offset(center + half * (.6 - row * .06), y),
        reflection,
      );
    }
  }

  void _paintBranch(Canvas canvas, double scale, Paint stroke) {
    final branch = Path()
      ..moveTo(-8 * scale, 20 * scale)
      ..cubicTo(
        35 * scale,
        24 * scale,
        40 * scale,
        64 * scale,
        124 * scale,
        80 * scale,
      )
      ..cubicTo(
        156 * scale,
        86 * scale,
        170 * scale,
        105 * scale,
        194 * scale,
        126 * scale,
      );
    canvas.drawPath(branch, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(38 * scale, 39 * scale)
        ..quadraticBezierTo(28 * scale, 16 * scale, 15 * scale, 4 * scale)
        ..moveTo(72 * scale, 59 * scale)
        ..quadraticBezierTo(74 * scale, 30 * scale, 67 * scale, 14 * scale)
        ..moveTo(110 * scale, 75 * scale)
        ..quadraticBezierTo(119 * scale, 47 * scale, 118 * scale, 32 * scale)
        ..moveTo(145 * scale, 92 * scale)
        ..quadraticBezierTo(164 * scale, 72 * scale, 176 * scale, 67 * scale),
      stroke,
    );
    _leaf(canvas, Offset(20 * scale, 20 * scale), 15 * scale, -.9, stroke);
    _leaf(canvas, Offset(52 * scale, 47 * scale), 17 * scale, .45, stroke);
    _leaf(canvas, Offset(82 * scale, 38 * scale), 16 * scale, -.85, stroke);
    _leaf(canvas, Offset(112 * scale, 67 * scale), 18 * scale, .45, stroke);
    _leaf(canvas, Offset(143 * scale, 76 * scale), 14 * scale, -.7, stroke);
    _leaf(canvas, Offset(172 * scale, 104 * scale), 15 * scale, .55, stroke);
  }

  void _leaf(
    Canvas canvas,
    Offset center,
    double length,
    double angle,
    Paint stroke,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final leaf = Path()
      ..moveTo(-length * .58, 0)
      ..quadraticBezierTo(-length * .08, -length * .52, length * .58, 0)
      ..quadraticBezierTo(-length * .1, length * .48, -length * .58, 0);
    canvas.drawPath(leaf, stroke);
    canvas.drawLine(Offset(-length * .48, 0), Offset(length * .48, 0), stroke);
    canvas.restore();
  }

  void _paintBird(Canvas canvas, Offset origin, double scale) {
    final paint = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(origin.dx - 10 * scale, origin.dy)
      ..quadraticBezierTo(
        origin.dx - 4 * scale,
        origin.dy - 5 * scale,
        origin.dx,
        origin.dy,
      )
      ..quadraticBezierTo(
        origin.dx + 6 * scale,
        origin.dy - 7 * scale,
        origin.dx + 12 * scale,
        origin.dy - 1 * scale,
      );
    canvas.drawPath(path, paint);
  }

  void _paintBottomMotif(
    Canvas canvas,
    Size size,
    double scale,
    Paint stroke,
    Paint softStroke,
  ) {
    final lotusCenter = Offset(size.width * .13, size.height * .91);
    final petalPaint = Paint()
      ..color = _wash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * scale;
    for (var petal = -2; petal <= 2; petal++) {
      canvas.save();
      canvas.translate(lotusCenter.dx, lotusCenter.dy);
      canvas.rotate(petal * .34);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          -15 * scale,
          -18 * scale,
          -8 * scale,
          -44 * scale,
          0,
          -49 * scale,
        )
        ..cubicTo(8 * scale, -44 * scale, 15 * scale, -18 * scale, 0, 0);
      canvas.drawPath(path, petalPaint);
      canvas.restore();
    }
    canvas.drawLine(
      Offset(lotusCenter.dx - 24 * scale, lotusCenter.dy),
      Offset(lotusCenter.dx + 24 * scale, lotusCenter.dy),
      petalPaint,
    );

    for (var wave = 0; wave < 4; wave++) {
      final y = size.height * (.93 + wave * .022);
      final path = Path()
        ..moveTo(-10, y)
        ..cubicTo(
          size.width * .19,
          y - 35 * scale,
          size.width * .34,
          y + 28 * scale,
          size.width * .54,
          y + 2 * scale,
        )
        ..cubicTo(
          size.width * .76,
          y - 26 * scale,
          size.width * .84,
          y + 4 * scale,
          size.width + 12,
          y - 18 * scale,
        );
      canvas.drawPath(path, wave.isEven ? softStroke : stroke);
    }

    final cloud = Paint()
      ..color = _wash
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale;
    final cloudPath = Path()
      ..moveTo(size.width * .72, size.height * .91)
      ..cubicTo(
        size.width * .69,
        size.height * .89,
        size.width * .71,
        size.height * .87,
        size.width * .74,
        size.height * .88,
      )
      ..cubicTo(
        size.width * .76,
        size.height * .84,
        size.width * .81,
        size.height * .86,
        size.width * .81,
        size.height * .89,
      )
      ..cubicTo(
        size.width * .85,
        size.height * .87,
        size.width * .88,
        size.height * .9,
        size.width * .85,
        size.height * .92,
      );
    canvas.drawPath(cloudPath, cloud);
  }

  @override
  bool shouldRepaint(covariant _LoginWatercolorPainter oldDelegate) => false;
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({required this.child, this.isMobile = false});

  final Widget child;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
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
        color: HeritagePalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: HeritagePalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121E2A5A),
            blurRadius: 20,
            offset: Offset(0, 8),
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
              color: HeritagePalette.actionBlue,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Di sản sống\ntrong từng hành trình.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: HeritagePalette.primaryNavy,
              fontWeight: FontWeight.w700,
              height: 1.16,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Container(
            width: 72,
            height: 3,
            decoration: BoxDecoration(
              color: HeritagePalette.actionBlue,
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
    this.icon,
    this.showMark,
    this.seamless = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final bool? showMark;
  final bool seamless;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactHeight = isCompactAuthViewport(context);

    final shouldShowMark = showMark ?? (icon != null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : viewportWidth;

        final mobile = availableWidth < 440;
        final compact = availableWidth < 340 || compactHeight;

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: seamless
              ? const BoxDecoration()
              : BoxDecoration(
                  color: HeritagePalette.surface,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  border: Border.all(color: HeritagePalette.border),
                ),
          child: Stack(
            children: [
              if (!seamless)
                Positioned(
                  top: -18,
                  right: -14,
                  bottom: -18,
                  width: compact ? 96 : 144,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HeritageHeaderPainter(
                        color: HeritagePalette.lavender.withValues(
                          alpha: mobile ? 0.08 : 0.12,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.small : AppSpacing.medium,
                  vertical: mobile
                      ? (compact ? AppSpacing.xSmall : AppSpacing.medium)
                      : AppSpacing.medium,
                ),
                child: mobile
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (shouldShowMark && icon != null) ...[
                            HeritageMark(size: compact ? 42 : 52, icon: icon!),
                            SizedBox(
                              height: compact
                                  ? AppSpacing.xSmall
                                  : AppSpacing.small,
                            ),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: HeritagePalette.primaryNavy,
                                fontSize: compact ? 19 : 22,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 4 : AppSpacing.xSmall),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: HeritagePalette.bodyText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (shouldShowMark && icon != null) ...[
                            HeritageMark(size: 48, icon: icon!),
                            const SizedBox(width: AppSpacing.medium),
                          ],
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SMART HERITAGE',
                                  softWrap: true,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: HeritagePalette.actionBlue,
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  softWrap: true,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: HeritagePalette.primaryNavy,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  softWrap: true,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: HeritagePalette.bodyText,
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
      },
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
    this.label = 'Email hoặc số điện thoại',
    this.validator = validateEmail,
    super.key,
  });

  final TextEditingController controller;
  final Key fieldKey;
  final String label;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      scrollPadding: const EdgeInsets.only(bottom: AppSpacing.xLarge),
      autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.email_outlined),
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
    this.showPasswordTooltip = 'Hiện mật khẩu',
    this.hidePasswordTooltip = 'Ẩn mật khẩu',
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final TextInputAction textInputAction;
  final String showPasswordTooltip;
  final String hidePasswordTooltip;

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
          tooltip: _obscureText
              ? widget.showPasswordTooltip
              : widget.hidePasswordTooltip,
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

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.buttonKey,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        key: buttonKey,
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: HeritagePalette.authCta,
          foregroundColor: HeritagePalette.authNavy,
          disabledBackgroundColor: HeritagePalette.authCta.withValues(
            alpha: 0.5,
          ),
          disabledForegroundColor: HeritagePalette.authNavy.withValues(
            alpha: 0.5,
          ),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: HeritagePalette.authNavy,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label),
                  const SizedBox(width: AppSpacing.xSmall),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
      ),
    );
  }
}

String? validateEmail(
  String? value, {
  String requiredMessage = 'Vui lòng nhập email hoặc số điện thoại.',
  String invalidMessage = 'Email hoặc số điện thoại không hợp lệ.',
}) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) {
    return requiredMessage;
  }

  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final phonePattern = RegExp(r'^[0-9]{8,11}$');
  if (!emailPattern.hasMatch(input) && !phonePattern.hasMatch(input)) {
    return invalidMessage;
  }

  return null;
}
