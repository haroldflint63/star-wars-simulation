import 'package:flutter/material.dart';

/// AAA Game Design System
/// Inspired by EA Sports, Activision Blizzard, and Roblox Creator Hub
///
/// This system provides:
/// - Professional color palette
/// - Spacing tokens
/// - Motion/animation curves
/// - Typography scale
/// - Shadow/glow effects
class AAADesignSystem {
  // ═══════════════════════════════════════════════════════════════
  // COLOR PALETTE - Dark Sci-Fi Base
  // ═══════════════════════════════════════════════════════════════

  // Base colors (backgrounds)
  static const Color spaceVoid = Color(0xFF0B0F14);
  static const Color spaceDark = Color(0xFF0E1621);
  static const Color spaceDeep = Color(0xFF111827);
  static const Color spaceMid = Color(0xFF1F2937);

  // Accent colors (never pure neon - soft glows)
  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color accentCyanMuted = Color(0xFF67E8F9);
  static const Color accentAmber = Color(0xFFFBBF24);
  static const Color accentAmberMuted = Color(0xFFFCD34D);
  static const Color accentGreen = Color(0xFF34D399);
  static const Color accentGreenMuted = Color(0xFF6EE7B7);

  // UI states
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF97316);
  static const Color successGreen = Color(0xFF10B981);

  // Semantic colors
  static const Color hologramBlue = Color(0xFF60A5FA);
  static const Color energyPurple = Color(0xFFA78BFA);
  static const Color scanlineGreen = Color(0xFF4ADE80);

  // Text colors
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFFD1D5DB);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // ═══════════════════════════════════════════════════════════════
  // SPACING SYSTEM - 8px Grid
  // ═══════════════════════════════════════════════════════════════

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // ═══════════════════════════════════════════════════════════════
  // BORDER RADIUS - Consistent Roundness
  // ═══════════════════════════════════════════════════════════════

  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  static const double radiusFull = 9999.0;

  // ═══════════════════════════════════════════════════════════════
  // MOTION SYSTEM - Easing Curves
  // ═══════════════════════════════════════════════════════════════

  static const Curve easeDefault = Curves.easeInOutCubic;
  static const Curve easeSnappy = Curves.easeOutExpo;
  static const Curve easeSmooth = Curves.easeInOutQuart;
  static const Curve easeSpring = Curves.elasticOut;

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationSlower = Duration(milliseconds: 600);

  // ═══════════════════════════════════════════════════════════════
  // SHADOWS & GLOWS - Depth & Light Bloom
  // ═══════════════════════════════════════════════════════════════

  static List<BoxShadow> shadowSmall(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.15),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMedium(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowLarge(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> glowSoft(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.3),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> glowMedium(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.4),
      blurRadius: 30,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> glowStrong(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.5),
      blurRadius: 40,
      spreadRadius: 4,
    ),
  ];

  // Inner glow effect
  static BoxDecoration innerGlow({
    required Color color,
    double blur = 16,
    double opacity = 0.1,
  }) {
    return BoxDecoration(
      border: Border.all(color: color.withValues(alpha: opacity * 2), width: 1),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: -4,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TYPOGRAPHY - Game UI Text Styles
  // ═══════════════════════════════════════════════════════════════

  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.1,
    color: textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
    color: textPrimary,
  );

  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: textPrimary,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
    height: 1.4,
    color: textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    height: 1.4,
    color: textSecondary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
    color: textSecondary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
    color: textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
    color: textTertiary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
    color: textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.75,
    height: 1.2,
    color: textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    height: 1.2,
    color: textTertiary,
  );

  // Monospace for data/stats
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: accentCyanMuted,
  );
}
