import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Studio-quality sci-fi design system for galaxy map
/// Inspired by Roblox, PlayStation, and Microsoft Flight Simulator UI
class SciFiDesignSystem {
  // ============================================================================
  // VISUAL DIAGNOSIS OF OLD SYSTEM
  // ============================================================================
  //
  // PROBLEMS IDENTIFIED:
  // 1. Flat polygons with no depth cues
  // 2. Random line weights create visual noise
  // 3. No consistent light direction (confusing shadows)
  // 4. Weak contrast between background and buildings
  // 5. Labels use generic styles (not integrated with sci-fi theme)
  // 6. Too many small details fighting for attention
  // 7. No visual hierarchy (everything same importance)
  // 8. Harsh colors without proper blending
  //
  // ============================================================================

  // ============================================================================
  // COLOR PALETTE - Space Command Theme
  // ============================================================================

  /// Deep space background gradient
  static const Color spaceDeep = Color(0xFF0a0e27);
  static const Color spaceMid = Color(0xFF1a1f3a);
  static const Color spaceLight = Color(0xFF2a2f4a);

  /// Primary accent - Cyan hologram
  static const Color accentPrimary = Color(0xFF00d9ff);
  static const Color accentPrimaryDim = Color(0xFF0088aa);
  static const Color accentPrimaryBright = Color(0xFF5fefff);

  /// Secondary accent - Purple energy
  static const Color accentSecondary = Color(0xFF9d4edd);
  static const Color accentSecondaryDim = Color(0xFF6c2eb0);

  /// Danger / Alert
  static const Color danger = Color(0xFFff006e);
  static const Color dangerDim = Color(0xFFaa0048);

  /// Success / Active
  static const Color success = Color(0xFF00ff88);
  static const Color successDim = Color(0xFF00aa55);

  /// Neutral grays
  static const Color neutralDark = Color(0xFF1a1f2e);
  static const Color neutralMid = Color(0xFF3a4458);
  static const Color neutralLight = Color(0xFF6a7489);
  static const Color neutralBright = Color(0xFFa0aabe);

  /// Building materials
  static const Color buildingBase = Color(0xFF2d3748);
  static const Color buildingLight = Color(0xFF4a5568);
  static const Color buildingDark = Color(0xFF1a202c);
  static const Color buildingHighlight = Color(0xFF718096);

  // ============================================================================
  // TYPOGRAPHY SCALE
  // ============================================================================

  /// Hero title (galaxy name, mission title)
  static const TextStyle titleHero = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
    height: 1.2,
    color: accentPrimaryBright,
  );

  /// Section header
  static const TextStyle titleSection = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.3,
    color: neutralBright,
  );

  /// Label / button
  static const TextStyle labelPrimary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    height: 1.4,
    color: Colors.white,
  );

  /// Label small
  static const TextStyle labelSecondary = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    height: 1.4,
    color: neutralLight,
  );

  /// Micro text (stats, timestamps)
  static const TextStyle labelMicro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    height: 1.3,
    color: neutralMid,
  );

  // ============================================================================
  // SPACING & SIZING
  // ============================================================================

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  /// Corner radii
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;

  // ============================================================================
  // LIGHTING & SHADOW SYSTEM
  // ============================================================================

  /// Global light direction (top-left, 45°)
  static const Offset lightDirection = Offset(-0.707, -0.707);

  /// Rim light intensity (edge highlight)
  static const double rimLightIntensity = 0.3;

  /// Ambient occlusion shadow
  static BoxShadow ambientOcclusion({double intensity = 0.6}) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.4 * intensity),
      blurRadius: 16,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    );
  }

  /// Glow effect (no heavy blur, layered strokes)
  static List<BoxShadow> neonGlow({
    required Color color,
    double intensity = 1.0,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.6 * intensity),
        blurRadius: 8,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.3 * intensity),
        blurRadius: 16,
        spreadRadius: 4,
      ),
    ];
  }

  /// Subtle inner shadow for depth
  static List<BoxShadow> innerShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 4,
        offset: const Offset(2, 2),
      ),
    ];
  }

  // ============================================================================
  // ANIMATION CURVES & DURATIONS
  // ============================================================================

  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  static const Curve curveSnappy = Curves.easeOutCubic;
  static const Curve curveSmooth = Curves.easeInOutCubic;
  static const Curve curveElastic = Curves.easeOutBack;

  // ============================================================================
  // GLOW PAINT HELPERS
  // ============================================================================

  /// Create multi-stroke glow effect (cheaper than blur)
  static void drawFakeGlow(
    Canvas canvas,
    Path path,
    Color color, {
    double intensity = 1.0,
  }) {
    // Outer glow
    final outerPaint =
        Paint()
          ..color = color.withValues(alpha: 0.15 * intensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path, outerPaint);

    // Mid glow
    final midPaint =
        Paint()
          ..color = color.withValues(alpha: 0.3 * intensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    canvas.drawPath(path, midPaint);

    // Inner bright
    final innerPaint =
        Paint()
          ..color = color.withValues(alpha: 0.6 * intensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawPath(path, innerPaint);
  }

  /// Draw rim light on polygon edge
  static void drawRimLight(Canvas canvas, Path path, Color baseColor) {
    final rimPaint =
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 0),
            const Offset(100, 100),
            [
              baseColor.withValues(alpha: 0.6),
              baseColor.withValues(alpha: 0.0),
            ],
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawPath(path, rimPaint);
  }
}
