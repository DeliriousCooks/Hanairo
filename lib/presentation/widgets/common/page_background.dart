import 'package:flutter/material.dart';
import '../../../main.dart' show ThemeScope;

/// Paints the active theme preset's gradient as an *opaque* full-screen
/// background for a single screen.
///
/// Why this exists: making each tab screen's own Scaffold background
/// transparent (so MainShell's shared gradient shows through) seems like
/// the simple way to apply the gradient everywhere, but it breaks page
/// transitions - during a tab switch, both the outgoing and incoming
/// screens are transparent, so neither one visually covers the other and
/// their content overlaps/ghosts together mid-transition. Wrapping each
/// screen's content in its own opaque copy of the same gradient fixes
/// this: every screen is independently opaque, so transitions look
/// correct, while still all sharing the same visual background.
class PageBackground extends StatelessWidget {
  final Widget child;
  const PageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: themeController.preset.gradient(themeController.brightness),
            ),
          ),
          child: child,
        );
      },
    );
  }
}
