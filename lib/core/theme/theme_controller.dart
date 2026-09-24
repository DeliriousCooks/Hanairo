import 'package:flutter/material.dart';
import '../../data/repositories/local_repository.dart';
import 'theme_settings.dart';

/// Owns all live theme state (dark/light, accent color, glass thickness,
/// preset) and persists changes via [LocalRepository]. Wrap the app in a
/// ChangeNotifierProvider<ThemeController> and rebuild MaterialApp.router
/// from its values so changes apply instantly, app-wide, with no restart.
class ThemeController extends ChangeNotifier {
  final LocalRepository _repo;

  bool _isDark;
  AccentColor _accent;
  GlassThickness _glass;
  ThemePreset _preset;

  ThemeController(this._repo)
      : _isDark = _repo.isDarkMode(),
        _accent = AccentColor.fromName(_repo.getAccentColorName()),
        _glass = GlassThickness.fromName(_repo.getGlassThicknessName()),
        _preset = ThemePreset.fromName(_repo.getThemePresetName());

  bool get isDark => _isDark;
  AccentColor get accent => _accent;
  GlassThickness get glass => _glass;
  ThemePreset get preset => _preset;
  bool get isOled => _isDark && _preset == ThemePreset.oled;
  Brightness get brightness => _isDark ? Brightness.dark : Brightness.light;

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    await _repo.setDarkMode(value);
    notifyListeners();
  }

  Future<void> setAccent(AccentColor value) async {
    if (_accent == value) return;
    _accent = value;
    await _repo.setAccentColorName(value.name);
    notifyListeners();
  }

  Future<void> setGlass(GlassThickness value) async {
    if (_glass == value) return;
    _glass = value;
    await _repo.setGlassThicknessName(value.name);
    notifyListeners();
  }

  /// Selecting a preset applies its background gradient and, since the user
  /// hasn't chosen an accent for this preset yet, also switches the accent
  /// to that preset's suggested color. The accent can still be changed
  /// independently afterward via [setAccent].
  Future<void> setPreset(ThemePreset value) async {
    if (_preset == value) return;
    _preset = value;
    if (value == ThemePreset.oled) {
      _isDark = true;
      await _repo.setDarkMode(true);
    }
    _accent = value.suggestedAccent;
    await _repo.setThemePresetName(value.name);
    await _repo.setAccentColorName(_accent.name);
    notifyListeners();
  }
}
