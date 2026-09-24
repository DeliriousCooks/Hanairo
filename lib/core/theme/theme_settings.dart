import 'package:flutter/material.dart';

/// The 8 selectable accent colors shown as swatches in Settings.
enum AccentColor {
  violet(Color(0xFFA180FF), 'Amethyst'),
  magenta(Color(0xFFB56FFF), 'Magenta'),
  blue(Color(0xFF66A9FF), 'Blue'),
  teal(Color(0xFF4ECDC4), 'Teal'),
  green(Color(0xFF6FCF7A), 'Green'),
  orange(Color(0xFFFF9D4F), 'Orange'),
  red(Color(0xFFFF6F6F), 'Red'),
  pink(Color(0xFFE995D2), 'Pink');

  final Color color;
  final String label;
  const AccentColor(this.color, this.label);

  static AccentColor fromName(String? name) {
    return AccentColor.values.firstWhere(
      (a) => a.name == name,
      orElse: () => AccentColor.violet,
    );
  }
}

/// Controls how strong the frosted-glass ("Liquid Glass") blur/translucency
/// effect is on cards, nav bars, and sheets.
enum GlassThickness {
  thin(sigma: 8, opacity: 0.55, label: 'Thin'),
  regular(sigma: 18, opacity: 0.72, label: 'Regular'),
  thick(sigma: 32, opacity: 0.88, label: 'Thick');

  final double sigma;
  final double opacity;
  final String label;
  const GlassThickness({required this.sigma, required this.opacity, required this.label});

  static GlassThickness fromName(String? name) {
    return GlassThickness.values.firstWhere(
      (g) => g.name == name,
      orElse: () => GlassThickness.regular,
    );
  }
}

/// Named wallpaper/background presets. Each preset defines a background
/// gradient (seen behind glass surfaces) and a suggested accent color,
/// which is applied when the preset is selected but can be overridden
/// afterward by picking a different accent swatch.
enum ThemePreset {
  defaultPreset(
    label: 'Default',
    suggestedAccent: AccentColor.violet,
    gradientDark: [Color(0xFF130E29), Color(0xFF080B17)],
    gradientLight: [Color(0xFFF5F5FA), Color(0xFFECEAF7)],
  ),
  amethyst(
    label: 'Amethyst',
    suggestedAccent: AccentColor.magenta,
    gradientDark: [Color(0xFF1B1033), Color(0xFF0D0820)],
    gradientLight: [Color(0xFFF6EEFB), Color(0xFFE9D9F5)],
  ),
  ocean(
    label: 'Ocean',
    suggestedAccent: AccentColor.blue,
    gradientDark: [Color(0xFF081C33), Color(0xFF06111F)],
    gradientLight: [Color(0xFFEAF5FC), Color(0xFFD6EAF7)],
  ),
  sunset(
    label: 'Sunset',
    suggestedAccent: AccentColor.orange,
    gradientDark: [Color(0xFF1F0F0A), Color(0xFF351610)],
    gradientLight: [Color(0xFFFDF0E8), Color(0xFFFAD9C4)],
  ),
  forest(
    label: 'Forest',
    suggestedAccent: AccentColor.green,
    gradientDark: [Color(0xFF0A1A0F), Color(0xFF122B18)],
    gradientLight: [Color(0xFFEDF7EF), Color(0xFFD8EEDC)],
  ),
  noir(
    label: 'Noir',
    suggestedAccent: AccentColor.teal,
    gradientDark: [Color(0xFF000000), Color(0xFF0D0D0D)],
    gradientLight: [Color(0xFFFAFAFA), Color(0xFFE8E8E8)],
  );

  final String label;
  final AccentColor suggestedAccent;
  final List<Color> gradientDark;
  final List<Color> gradientLight;

  const ThemePreset({
    required this.label,
    required this.suggestedAccent,
    required this.gradientDark,
    required this.gradientLight,
  });

  List<Color> gradient(Brightness brightness) =>
      brightness == Brightness.dark ? gradientDark : gradientLight;

  static ThemePreset fromName(String? name) {
    return ThemePreset.values.firstWhere(
      (p) => p.name == name,
      orElse: () => ThemePreset.defaultPreset,
    );
  }
}
