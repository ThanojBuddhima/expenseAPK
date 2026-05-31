import 'package:flutter/material.dart';

/// Soft fitness-style palette (light pastels + vibrant accents).
class AppColors {
  // Neutrals
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1A1A1A);
  static const cardDark = Color(0xFF262626);

  // Brand & actions — Material default orange
  static const primary = Color(0xFFFF9800);
  static const primaryDeep = Color(0xFFF57C00);
  static const accentLime = Color(0xFFC6E543);
  static const accentLimeSoft = Color(0xFFE8F5C8);

  // Text
  static const textPrimary = Color(0xFF1E293B);
  static const textPrimaryDark = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF6B7280);
  static const textSecondaryDark = Color(0xFF94A3B8);

  // UI chrome
  static const border = Color(0xFFF2F2F2);
  static const borderDark = Color(0xFF334155);
  static const inputBackground = Color(0xFFF2F2F2);
  static const inputBackgroundDark = Color(0xFF2D2D2D);
  static const navInactive = Color(0xFFF2F2F2);

  // Finance semantics
  static const cashTint = Color(0xFF64748B);
  static const incomeTint = Color(0xFF84CC16);
  static const incomeTintSoft = Color(0xFFD9F99D);
  static const expenseTint = Color(0xFFF26D6D);
  static const expenseTintSoft = Color(0xFFFBCFE8);

  // Pastel category accents
  static const pastelMint = Color(0xFFD9F99D);
  static const pastelPink = Color(0xFFFBCFE8);
  static const pastelYellow = Color(0xFFFEF08A);
  static const pastelOrange = Color(0xFFFFEDD5);
  static const pastelLavender = Color(0xFFDDD6FE);
  static const darkBanner = Color(0xFF334155);

  static const chartPalette = [
    Color(0xFFFBCFE8),
    Color(0xFFFFEDD5),
    Color(0xFFD9F99D),
    Color(0xFFFEF08A),
    Color(0xFFDDD6FE),
    Color(0xFFFDBA74),
    Color(0xFFF26D6D),
    Color(0xFF84CC16),
  ];

  /// Darkens light pastel accents for readable text and outlines.
  static Color readableAccent(Color color) {
    if (color.computeLuminance() <= 0.42) {
      return color;
    }
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * 0.45).clamp(0.28, 0.4))
        .withSaturation((hsl.saturation * 0.85 + 0.18).clamp(0.35, 1.0))
        .toColor();
  }
}

/// Theme-aware surface and text colors for widgets that cannot use const light tokens.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.card,
    required this.border,
    required this.input,
    required this.textPrimary,
    required this.textSecondary,
    required this.emptyIconBg,
    required this.emptyIconFg,
  });

  final Color card;
  final Color border;
  final Color input;
  final Color textPrimary;
  final Color textSecondary;
  final Color emptyIconBg;
  final Color emptyIconFg;

  static const light = AppPalette(
    card: AppColors.card,
    border: AppColors.border,
    input: AppColors.inputBackground,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    emptyIconBg: AppColors.pastelOrange,
    emptyIconFg: AppColors.primary,
  );

  static const dark = AppPalette(
    card: AppColors.cardDark,
    border: AppColors.borderDark,
    input: AppColors.inputBackgroundDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    emptyIconBg: Color(0xFF3D3118),
    emptyIconFg: Color(0xFFFFB74D),
  );

  @override
  AppPalette copyWith({
    Color? card,
    Color? border,
    Color? input,
    Color? textPrimary,
    Color? textSecondary,
    Color? emptyIconBg,
    Color? emptyIconFg,
  }) {
    return AppPalette(
      card: card ?? this.card,
      border: border ?? this.border,
      input: input ?? this.input,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      emptyIconBg: emptyIconBg ?? this.emptyIconBg,
      emptyIconFg: emptyIconFg ?? this.emptyIconFg,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      input: Color.lerp(input, other.input, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      emptyIconBg: Color.lerp(emptyIconBg, other.emptyIconBg, t)!,
      emptyIconFg: Color.lerp(emptyIconFg, other.emptyIconFg, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

class AppTheme {
  static const double cardRadius = 24;
  static const double buttonRadius = 28;
  static const double screenTopPadding = 24;

  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final onSurface =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accentLime,
      onSecondary: AppColors.textPrimary,
      surface: surface,
      onSurface: onSurface,
      error: AppColors.expenseTint,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [isDark ? AppPalette.dark : AppPalette.light],
      scaffoldBackgroundColor: surface,
      cardTheme: CardThemeData(
        color: isDark ? AppColors.cardDark : AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.06),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: kToolbarHeight + screenTopPadding,
        titleSpacing: 16,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.inputBackgroundDark : AppColors.inputBackground,
        hintStyle: TextStyle(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
        selectedColor: isDark ? AppColors.cardDark : AppColors.card,
        labelStyle: TextStyle(color: onSurface),
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerColor: isDark ? AppColors.borderDark : AppColors.border,
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyMedium: TextStyle(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),
    );
  }
}
