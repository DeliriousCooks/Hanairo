import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/theme_settings.dart';

/// A frosted "Liquid Glass" surface: a blurred, translucent backdrop with a
/// subtle border and highlight, matching the app's glassmorphism style.
///
/// Intensity is driven by [thickness] - typically the current
/// `ThemeController.glass` value - so every glass surface in the app stays
/// in sync with the user's chosen setting (Thin / Regular / Thick).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final GlassThickness thickness;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;

  const GlassContainer({
    super.key,
    required this.child,
    required this.thickness,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseTint = tint ?? theme.colorScheme.surface;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: thickness.sigma,
          sigmaY: thickness.sigma,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: baseTint.withOpacity(thickness.opacity * 0.6),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.0),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.14),
              width: 0.75,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
