import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Dark Mode Palette (default) - deep navy, per the BooruWave mockup
  static const darkBackground = Color(0xFF080B17);
  static const darkSurface = Color(0xFF111629);
  static const darkCard = Color(0xFF171D35);
  static const darkCardElevated = Color(0xFF1D2440);
  static const darkBorder = Color(0xFF293452);
  static const darkDivider = Color(0xFF1C2338);

  // Primary Accent - Amethyst
  static const primary = Color(0xFFA180FF);
  static const primaryLight = Color(0xFFC1A8FF);
  static const primaryDark = Color(0xFF7B5CDB);
  static const primaryContainer = Color(0xFF241C4A);

  // Secondary - Amethyst-to-blue accent
  static const secondary = Color(0xFF66A9FF);
  static const secondaryContainer = Color(0xFF16233F);

  // Restrained pink highlight (favorites, "pro" accents)
  static const pinkHighlight = Color(0xFFE995D2);

  // Status Colors
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFFF5252);
  static const info = Color(0xFF2196F3);

  // Rating Colors
  static const ratingSafe = Color(0xFF4CAF50);
  static const ratingQuestionable = Color(0xFFFF9800);
  static const ratingExplicit = Color(0xFFFF5252);

  // Text
  static const textPrimary = Color(0xFFF5F3FF);
  static const textSecondary = Color(0xFFA1A8C4);
  static const textTertiary = Color(0xFF6F7897);
  static const textDisabled = Color(0xFF3A3A50);

  // Light Mode Palette
  static const lightBackground = Color(0xFFEEEFF9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFEAEBF7);
  static const lightBorder = Color(0xFFD5D7EB);
  static const lightTextPrimary = Color(0xFF24243B);
  static const lightTextSecondary = Color(0xFF6F7390);
}

class AppTextStyles {
  static const String _fontFamily = 'SF Pro Display';

  static const displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.15,
  );

  static const headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.25,
  );

  static const titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static const titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
  );

  static const bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.3,
  );

  static const labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.3,
  );

  static const caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.4,
  );

  static const mono = TextStyle(
    fontFamily: 'Courier New',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  );
}

class AppTheme {
  /// The amethyst-to-blue-to-pink accent gradient used for hero headings and
  /// other signature moments, matching the BooruWave mockup's brand gradient.
  static const accentGradient = LinearGradient(
    colors: [Color(0xFFAE98FF), Color(0xFF80B5FF), Color(0xFFEC9FD8)],
  );

  /// Lightens or darkens [color] by [amount] (-1..1) in HSL lightness space.
  static Color _adjustLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Builds a full [ThemeData] for the given [brightness] using [accent] as
  /// the primary color. This replaces the old static darkTheme/lightTheme
  /// getters so the accent color picked in Settings applies everywhere.
  static ThemeData build({required Brightness brightness, required Color accent}) {
    final isDark = brightness == Brightness.dark;
    final accentLight = _adjustLightness(accent, 0.14);
    final accentDark = _adjustLightness(accent, -0.18);
    final accentContainer = isDark
        ? Color.alphaBlend(accent.withOpacity(0.22), AppColors.darkBackground)
        : Color.alphaBlend(accent.withOpacity(0.12), Colors.white);

    return isDark
        ? _darkTheme(accent, accentLight, accentDark, accentContainer)
        : _lightTheme(accent, accentLight, accentDark, accentContainer);
  }

  static ThemeData _darkTheme(
    Color accent,
    Color accentLight,
    Color accentDark,
    Color accentContainer,
  ) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: accentContainer,
        onPrimaryContainer: accentLight,
        secondary: AppColors.secondary,
        onSecondary: Colors.black,
        secondaryContainer: AppColors.secondaryContainer,
        surface: AppColors.darkSurface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkDivider,
        surfaceContainerHighest: AppColors.darkCard,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      textTheme: _buildTextTheme(AppColors.textPrimary, AppColors.textSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.1,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface.withOpacity(0.95),
        elevation: 0,
        indicatorColor: accentContainer,
        labelTextStyle: WidgetStateProperty.all(
          AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent, size: 22);
          }
          return const IconThemeData(color: AppColors.textTertiary, size: 22);
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkCard,
        selectedColor: accentContainer,
        disabledColor: AppColors.darkCardElevated,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
        side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 0.5,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        modalBackgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.darkBorder,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCardElevated,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentContainer;
          return AppColors.darkCard;
        }),
      ),
      extensions: [
        AppThemeExtension(
          shimmerBase: const Color(0xFF171D35),
          shimmerHighlight: const Color(0xFF293452),
          // Matches the mockup's --glass: rgba(25,31,56,.82)
          glassBackground: const Color(0xD1191F38),
          // Fine lavender border, à la mockup's --line: #293452
          glassBorder: const Color(0x66565F8A),
          tagColors: {
            'general': const Color(0xFF7C8FFF),
            'artist': AppColors.pinkHighlight,
            'copyright': const Color(0xFFCC7CFF),
            'character': const Color(0xFF7CFFCC),
            'meta': const Color(0xFFFFCC7C),
          },
        ),
      ],
    );
  }

  static ThemeData _lightTheme(
    Color accent,
    Color accentLight,
    Color accentDark,
    Color accentContainer,
  ) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: accentContainer,
        onPrimaryContainer: accentDark,
        secondary: AppColors.secondary,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        outline: AppColors.lightBorder,
      ),
      textTheme: _buildTextTheme(
        AppColors.lightTextPrimary,
        AppColors.lightTextSecondary,
      ),
      extensions: [
        AppThemeExtension(
          shimmerBase: const Color(0xFFE8E8F0),
          shimmerHighlight: const Color(0xFFF5F5FA),
          glassBackground: const Color(0xD9F6F7FF),
          glassBorder: const Color(0x40D5D7EB),
          tagColors: {
            'general': const Color(0xFF5C6FDF),
            'artist': const Color(0xFFDF5C9B),
            'copyright': const Color(0xFFAC5CDF),
            'character': const Color(0xFF5CDFAC),
            'meta': const Color(0xFFDFAC5C),
          },
        ),
      ],
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: primary),
      displayMedium: AppTextStyles.displayMedium.copyWith(color: primary),
      headlineLarge: AppTextStyles.headlineLarge.copyWith(color: primary),
      headlineMedium: AppTextStyles.headlineMedium.copyWith(color: primary),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: primary),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: primary),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: primary),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: secondary),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: primary),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: secondary),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: secondary),
    );
  }
}

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color glassBackground;
  final Color glassBorder;
  final Map<String, Color> tagColors;

  const AppThemeExtension({
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.glassBackground,
    required this.glassBorder,
    required this.tagColors,
  });

  @override
  AppThemeExtension copyWith({
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? glassBackground,
    Color? glassBorder,
    Map<String, Color>? tagColors,
  }) {
    return AppThemeExtension(
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
      tagColors: tagColors ?? this.tagColors,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      tagColors: tagColors,
    );
  }
}
