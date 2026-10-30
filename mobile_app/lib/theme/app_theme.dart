import 'package:flutter/material.dart';

abstract final class HeritagePalette {
  static const primaryNavy = Color(0xFF1E2A5A);
  static const actionBlue = Color(0xFF384CCA);
  static const lavender = Color(0xFF8B7CFF);
  static const secondaryText = Color(0xFF94A3B8);
  static const background = Color(0xFFF1F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const bodyText = Color(0xFF334155);
  static const error = Color(0xFFB42335);

  static const authNavy = primaryNavy;
  static const authNavyRaised = Color(0xFF2C3970);
  static const authGold = actionBlue;
  static const authCta = actionBlue;
  static const authText = surface; // Trắng
  static const navy = primaryNavy;
  static const deepNavy = primaryNavy;
  static const gold = actionBlue;
  static const ivory = background;
  static const paper = surface;
  static const ink = primaryNavy;
  static const mutedInk = secondaryText;
  static const outline = border;
  static const darkCanvas = Color(0xFF111827);
  static const darkSurface = Color(0xFF1E293B);
  static const darkRaised = Color(0xFF29364A);
  static const darkText = Color(0xFFF1F5F9);
  static const darkError = Color(0xFFFFB4AB);
}

abstract final class AppSpacing {
  static const xSmall = 8.0;
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const xLarge = 32.0;
}

abstract final class AppRadii {
  static const small = 12.0;
  static const medium = 18.0;
  static const large = 26.0;
  static const pill = 100.0;
}

abstract final class AppTheme {
  static ThemeData light() => _buildTheme(Brightness.light);

  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData auth(ThemeData base) {
    // Sửa lỗi test Dark Theme: Inherit độ sáng thay vì ép Brightness.light
    final colorScheme = base.colorScheme.copyWith(
      brightness: base.brightness,
      primary: HeritagePalette.authGold,
      onPrimary: HeritagePalette.surface,
      secondary: HeritagePalette.authCta,
      onSecondary: HeritagePalette.surface,
      tertiary: HeritagePalette.deepNavy,
      surface: HeritagePalette.surface,
      onSurface: HeritagePalette.primaryNavy,
      surfaceContainerLowest: HeritagePalette.surface,
      surfaceContainerLow: HeritagePalette.surface,
      surfaceContainerHighest: HeritagePalette.background,
      onSurfaceVariant: HeritagePalette.bodyText,
      outline: HeritagePalette.border,
      outlineVariant: HeritagePalette.border,
      error: HeritagePalette.error,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: HeritagePalette.bodyText,
      displayColor: HeritagePalette
          .authText, // Sửa lỗi tiêu đề Auth không hiển thị màu Trắng
    );

    return base.copyWith(
      brightness: base.brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: HeritagePalette.authNavy,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HeritagePalette.surface,
        constraints: const BoxConstraints(minHeight: 56),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: HeritagePalette.secondaryText),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: const TextStyle(color: HeritagePalette.primaryNavy),
        errorMaxLines: 2,
        helperMaxLines: 2,
        errorStyle: TextStyle(
          color: colorScheme.error,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        prefixIconColor: HeritagePalette.primaryNavy,
        suffixIconColor: HeritagePalette.secondaryText,
        border: _inputBorder(color: HeritagePalette.border),
        enabledBorder: _inputBorder(color: HeritagePalette.border),
        focusedBorder: _inputBorder(
          color: HeritagePalette.authGold,
          width: 1.8,
        ),
        errorBorder: _inputBorder(color: colorScheme.error),
        focusedErrorBorder: _inputBorder(color: colorScheme.error, width: 1.8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
          backgroundColor: HeritagePalette.actionBlue,
          foregroundColor: HeritagePalette.surface,
          disabledBackgroundColor: HeritagePalette.actionBlue,
          disabledForegroundColor: HeritagePalette.surface,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HeritagePalette.primaryNavy,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: HeritagePalette.primaryNavy,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HeritagePalette.primaryNavy,
        contentTextStyle: const TextStyle(color: HeritagePalette.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          side: const BorderSide(color: HeritagePalette.border),
        ),
      ),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: HeritagePalette.authGold,
      onPrimary: isLight
          ? HeritagePalette.surface
          : HeritagePalette.primaryNavy,
      secondary: HeritagePalette.gold,
      onSecondary: HeritagePalette.surface,
      tertiary: isLight ? HeritagePalette.deepNavy : HeritagePalette.gold,
      onTertiary: HeritagePalette.surface,
      error: isLight ? HeritagePalette.error : HeritagePalette.darkError,
      onError: HeritagePalette.surface,
      surface: isLight
          ? HeritagePalette.background
          : HeritagePalette.darkCanvas,
      onSurface: isLight
          ? HeritagePalette.primaryNavy
          : HeritagePalette.darkText,
      surfaceContainerLowest: isLight
          ? HeritagePalette.surface
          : HeritagePalette.darkSurface,
      surfaceContainerLow: isLight
          ? HeritagePalette.surface
          : HeritagePalette.darkRaised,
      surfaceContainerHighest: isLight
          ? HeritagePalette.background
          : HeritagePalette.darkCanvas,
      onSurfaceVariant: isLight
          ? HeritagePalette.bodyText
          : HeritagePalette.darkText,
      outline: isLight ? HeritagePalette.border : Colors.blueGrey.shade600,
    );

    final baseTextTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    ).textTheme;

    final textTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: isLight ? HeritagePalette.primaryNavy : HeritagePalette.darkText,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: isLight
          ? colorScheme.surface
          : HeritagePalette.darkCanvas,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: 13,
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        errorStyle: TextStyle(
          color: colorScheme.error,
          fontWeight: FontWeight.w500,
        ),
        border: _inputBorder(color: colorScheme.outline),
        enabledBorder: _inputBorder(color: colorScheme.outline),
        focusedBorder: _inputBorder(color: HeritagePalette.authGold, width: 2),
        errorBorder: _inputBorder(color: colorScheme.error),
        focusedErrorBorder: _inputBorder(color: colorScheme.error, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: HeritagePalette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? HeritagePalette.deepNavy
            : HeritagePalette.darkRaised,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.secondary,
      ),
    );
  }

  static OutlineInputBorder _inputBorder({
    required Color color,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.small),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
