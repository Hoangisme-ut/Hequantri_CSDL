import 'package:flutter/material.dart';

abstract final class HeritagePalette {
  static const authNavy = Color(0xFF0B1F3A);
  static const authNavyRaised = Color(0xFF142D50);
  static const authGold = Color(0xFFD9B66F);
  static const authCta = Color(0xFFE7BD68);
  static const authText = Color(0xFFF7F2E8);
  static const navy = Color(0xFF17324D);
  static const deepNavy = Color(0xFF10263D);
  static const gold = Color(0xFFC6A15B);
  static const ivory = Color(0xFFF7F4EC);
  static const paper = Color(0xFFFFFEFA);
  static const ink = Color(0xFF202B36);
  static const mutedInk = Color(0xFF65717D);
  static const outline = Color(0xFFD9D3C7);
  static const darkCanvas = Color(0xFF101D2A);
  static const darkSurface = Color(0xFF192B3D);
  static const darkRaised = Color(0xFF22374B);
  static const darkText = Color(0xFFF5F1E8);
  static const error = Color(0xFFB3261E);
  static const darkError = Color(0xFFF2B8B5);
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
    final colorScheme = base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: HeritagePalette.authGold,
      onPrimary: HeritagePalette.authNavy,
      secondary: HeritagePalette.authCta,
      onSecondary: HeritagePalette.authNavy,
      surface: HeritagePalette.authNavy,
      onSurface: HeritagePalette.authText,
      surfaceContainerLowest: HeritagePalette.authNavyRaised,
      surfaceContainerLow: HeritagePalette.authNavyRaised,
      surfaceContainerHighest: HeritagePalette.authNavy,
      onSurfaceVariant: HeritagePalette.authText.withValues(alpha: 0.78),
      outline: HeritagePalette.authGold.withValues(alpha: 0.54),
      outlineVariant: HeritagePalette.authGold.withValues(alpha: 0.28),
      error: const Color(0xFFFFB4AB),
    );
    final textTheme = base.textTheme.apply(
      bodyColor: HeritagePalette.authText,
      displayColor: HeritagePalette.authText,
    );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: HeritagePalette.authNavy,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HeritagePalette.authNavyRaised,
        constraints: const BoxConstraints(minHeight: 56),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: HeritagePalette.authGold),
        errorMaxLines: 2,
        helperMaxLines: 2,
        errorStyle: TextStyle(
          color: colorScheme.error,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        prefixIconColor: HeritagePalette.authGold,
        suffixIconColor: HeritagePalette.authGold,
        border: _authInputBorder(
          color: HeritagePalette.authGold.withValues(alpha: 0.55),
        ),
        enabledBorder: _authInputBorder(
          color: HeritagePalette.authGold.withValues(alpha: 0.55),
        ),
        focusedBorder: _authInputBorder(
          color: HeritagePalette.authGold,
          width: 1.8,
        ),
        errorBorder: _authInputBorder(color: colorScheme.error),
        focusedErrorBorder: _authInputBorder(
          color: colorScheme.error,
          width: 1.8,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
          backgroundColor: HeritagePalette.authCta,
          foregroundColor: HeritagePalette.authNavy,
          disabledBackgroundColor: HeritagePalette.authCta,
          disabledForegroundColor: HeritagePalette.authNavy,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HeritagePalette.authGold,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: HeritagePalette.authGold),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HeritagePalette.authNavyRaised,
        contentTextStyle: const TextStyle(color: HeritagePalette.authText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          side: BorderSide(
            color: HeritagePalette.authGold.withValues(alpha: 0.28),
          ),
        ),
      ),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final seedScheme = ColorScheme.fromSeed(
      seedColor: HeritagePalette.navy,
      brightness: brightness,
    );
    final colorScheme = seedScheme.copyWith(
      primary: isLight ? HeritagePalette.navy : HeritagePalette.gold,
      onPrimary: isLight ? Colors.white : HeritagePalette.deepNavy,
      secondary: HeritagePalette.gold,
      onSecondary: HeritagePalette.deepNavy,
      tertiary: isLight ? HeritagePalette.deepNavy : HeritagePalette.gold,
      surface: isLight ? HeritagePalette.ivory : HeritagePalette.darkCanvas,
      onSurface: isLight ? HeritagePalette.ink : HeritagePalette.darkText,
      surfaceContainerLowest: isLight
          ? HeritagePalette.paper
          : HeritagePalette.darkSurface,
      surfaceContainerLow: isLight ? Colors.white : HeritagePalette.darkRaised,
      outline: isLight ? HeritagePalette.outline : Colors.blueGrey.shade600,
      error: isLight ? HeritagePalette.error : HeritagePalette.darkError,
    );
    final baseTextTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    ).textTheme;
    final textTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
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
      scaffoldBackgroundColor: colorScheme.surface,
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
        focusedBorder: _inputBorder(color: colorScheme.primary, width: 2),
        errorBorder: _inputBorder(color: colorScheme.error),
        focusedErrorBorder: _inputBorder(color: colorScheme.error, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
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
        color: colorScheme.surfaceContainerLowest,
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

  static OutlineInputBorder _authInputBorder({
    required Color color,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
