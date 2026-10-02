import 'package:flutter/material.dart';
import '../../../main.dart' show ThemeScope;

/// Paints the active theme preset's gradient as an opaque full-screen
/// background for a single screen.
///
/// Each tab screen owns its own opaque copy of the shared gradient so that
/// page transitions don't ghost/overlap (two transparent screens on top of
/// each other show both their content simultaneously mid-transition).
///
/// The child is expected to be a scrollable (CustomScrollView, ListView, etc.)
/// or Scaffold body. PageBackground itself just wraps with the gradient and
/// constrains to fill the available space — it does NOT add a Scaffold.
class PageBackground extends StatelessWidget {
  final Widget child;
  const PageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Container(
          // Fill the full screen including behind the system status bar
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: themeController.isOled
                  ? const [Colors.black, Colors.black]
                  : themeController.preset.gradient(themeController.brightness),
            ),
          ),
          child: child,
        );
      },
    );
  }
}
