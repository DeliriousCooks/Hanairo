import 'dart:ui';

import 'package:flutter/material.dart';

/// A restrained, adaptive glass surface for high-level controls such as
/// navigation and search. Flutter's BackdropFilter provides a cross-platform
/// Liquid Glass-inspired treatment; it isn't Apple's native refractive
/// UIGlassEffect, so keep it to controls rather than content cards.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;
  final EdgeInsetsGeometry? padding;
  final bool highContrast;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.sigma = 18,
    this.padding,
    this.highContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOled = theme.scaffoldBackgroundColor == Colors.black;
    final fill = isDark
        ? (isOled ? const Color(0xFF08080A) : const Color(0xFF17151E))
        : const Color(0xFFFDFBFF);
    final fillOpacity = highContrast
        ? (isDark ? (isOled ? 0.96 : 0.90) : 0.9)
        : (isDark ? (isOled ? 0.82 : 0.60) : 0.62);
    final edge = isDark
        ? Colors.white.withOpacity(isOled ? 0.20 : 0.24)
        : Colors.white.withOpacity(0.78);
    final safeSigma = sigma.clamp(10.0, 24.0).toDouble();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: safeSigma, sigmaY: safeSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill.withOpacity(fillOpacity),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(highContrast ? 0.035 : 0.10),
                        Colors.white.withOpacity(highContrast ? 0.008 : 0.015),
                      ]
                    : [
                        Colors.white.withOpacity(highContrast ? 0.22 : 0.70),
                        Colors.white.withOpacity(highContrast ? 0.08 : 0.22),
                      ],
              ),
              border: Border.all(color: edge, width: 0.8),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
