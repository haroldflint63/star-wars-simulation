import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'sci_fi_design_system.dart';

/// Premium isometric building with 3-layer structure
/// Designed for 60fps performance on mid-tier devices
class PremiumBuildingPainter extends CustomPainter {
  final Color accentColor;
  final double buildingHeight;
  final BuildingStyle style;
  final double animationValue; // 0.0 to 1.0 for pulse

  PremiumBuildingPainter({
    required this.accentColor,
    this.buildingHeight = 120.0,
    this.style = BuildingStyle.tower,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Layer 1: Ambient occlusion shadow
    _drawAmbientShadow(canvas, centerX, centerY + buildingHeight * 0.4);

    // Layer 2: Base platform
    _drawBasePlatform(canvas, centerX, centerY + buildingHeight * 0.3);

    // Layer 3: Main structure (varies by style)
    switch (style) {
      case BuildingStyle.tower:
        _drawTowerStructure(canvas, centerX, centerY);
        break;
      case BuildingStyle.dome:
        _drawDomeStructure(canvas, centerX, centerY);
        break;
      case BuildingStyle.cube:
        _drawCubeStructure(canvas, centerX, centerY);
        break;
      case BuildingStyle.spire:
        _drawSpireStructure(canvas, centerX, centerY);
        break;
    }

    // Layer 4: Top cap / antenna
    _drawTopCap(canvas, centerX, centerY - buildingHeight * 0.5);

    // Layer 5: Accent glow (pulsing)
    if (animationValue > 0) {
      _drawAccentGlow(canvas, centerX, centerY, animationValue);
    }
  }

  // ==========================================================================
  // LAYER 1: AMBIENT OCCLUSION SHADOW
  // ==========================================================================

  void _drawAmbientShadow(Canvas canvas, double x, double y) {
    final shadowPath =
        Path()..addOval(
          Rect.fromCenter(center: Offset(x, y), width: 80, height: 20),
        );

    final shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(shadowPath, shadowPaint);
  }

  // ==========================================================================
  // LAYER 2: BASE PLATFORM
  // ==========================================================================

  void _drawBasePlatform(Canvas canvas, double x, double y) {
    // Isometric base (parallelogram)
    final basePath =
        Path()
          ..moveTo(x, y)
          ..lineTo(x + 40, y - 20)
          ..lineTo(x, y - 40)
          ..lineTo(x - 40, y - 20)
          ..close();

    // Fill with gradient (top face)
    final basePaint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x - 40, y - 40),
            Offset(x + 40, y),
            [SciFiDesignSystem.buildingLight, SciFiDesignSystem.buildingBase],
          );
    canvas.drawPath(basePath, basePaint);

    // Left face (darker)
    final leftFacePath =
        Path()
          ..moveTo(x, y)
          ..lineTo(x - 40, y - 20)
          ..lineTo(x - 40, y - 10)
          ..lineTo(x, y + 10)
          ..close();

    final leftFacePaint = Paint()..color = SciFiDesignSystem.buildingDark;
    canvas.drawPath(leftFacePath, leftFacePaint);

    // Right face (mid tone)
    final rightFacePath =
        Path()
          ..moveTo(x, y)
          ..lineTo(x + 40, y - 20)
          ..lineTo(x + 40, y - 10)
          ..lineTo(x, y + 10)
          ..close();

    final rightFacePaint = Paint()..color = SciFiDesignSystem.buildingBase;
    canvas.drawPath(rightFacePath, rightFacePaint);

    // Rim light on top edge
    final rimPath =
        Path()
          ..moveTo(x - 40, y - 20)
          ..lineTo(x, y - 40)
          ..lineTo(x + 40, y - 20);

    SciFiDesignSystem.drawRimLight(canvas, rimPath, accentColor);
  }

  // ==========================================================================
  // LAYER 3: MAIN STRUCTURES
  // ==========================================================================

  void _drawTowerStructure(Canvas canvas, double x, double y) {
    // Tall rectangular tower with clear faces
    final height = buildingHeight * 0.6;

    // Front face
    final frontPath =
        Path()
          ..moveTo(x - 25, y)
          ..lineTo(x + 25, y - 12)
          ..lineTo(x + 25, y - 12 - height)
          ..lineTo(x - 25, y - height)
          ..close();

    final frontPaint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x - 25, y),
            Offset(x - 25, y - height),
            [SciFiDesignSystem.buildingBase, SciFiDesignSystem.buildingLight],
          );
    canvas.drawPath(frontPath, frontPaint);

    // Left face (darker)
    final leftPath =
        Path()
          ..moveTo(x - 25, y)
          ..lineTo(x - 25, y - height)
          ..lineTo(x, y - height - 15)
          ..lineTo(x, y - 15)
          ..close();

    final leftPaint = Paint()..color = SciFiDesignSystem.buildingDark;
    canvas.drawPath(leftPath, leftPaint);

    // Top face
    final topPath =
        Path()
          ..moveTo(x - 25, y - height)
          ..lineTo(x, y - height - 15)
          ..lineTo(x + 25, y - 12 - height)
          ..lineTo(x, y - height)
          ..close();

    final topPaint = Paint()..color = SciFiDesignSystem.buildingHighlight;
    canvas.drawPath(topPath, topPaint);

    // Windows (simple rectangles, purposeful placement)
    _drawWindows(canvas, x - 20, y - height * 0.3, 4, accentColor);
    _drawWindows(canvas, x - 20, y - height * 0.6, 4, accentColor);
  }

  void _drawDomeStructure(Canvas canvas, double x, double y) {
    // Hemisphere on cylinder base
    final baseHeight = buildingHeight * 0.3;

    // Cylinder base
    final cylinderPath =
        Path()
          ..moveTo(x - 30, y)
          ..lineTo(x + 30, y - 15)
          ..lineTo(x + 30, y - 15 - baseHeight)
          ..lineTo(x - 30, y - baseHeight)
          ..close();

    final cylinderPaint = Paint()..color = SciFiDesignSystem.buildingBase;
    canvas.drawPath(cylinderPath, cylinderPaint);

    // Dome (approximated with arcs)
    final domeRect = Rect.fromCenter(
      center: Offset(x, y - baseHeight - 25),
      width: 60,
      height: 50,
    );

    final domePaint =
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(x - 15, y - baseHeight - 35),
            30,
            [
              SciFiDesignSystem.buildingHighlight,
              SciFiDesignSystem.buildingLight,
            ],
          );
    canvas.drawArc(domeRect, math.pi, math.pi, false, domePaint);

    // Dome rim light
    final domeRimPaint =
        Paint()
          ..color = accentColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawArc(domeRect, math.pi, math.pi, false, domeRimPaint);
  }

  void _drawCubeStructure(Canvas canvas, double x, double y) {
    // Chunky cube with strong edges
    final size = buildingHeight * 0.5;

    // Top face
    final topPath =
        Path()
          ..moveTo(x, y - size)
          ..lineTo(x + 35, y - 20 - size)
          ..lineTo(x, y - 40 - size)
          ..lineTo(x - 35, y - 20 - size)
          ..close();

    final topPaint = Paint()..color = SciFiDesignSystem.buildingHighlight;
    canvas.drawPath(topPath, topPaint);

    // Left face
    final leftPath =
        Path()
          ..moveTo(x, y - size)
          ..lineTo(x - 35, y - 20 - size)
          ..lineTo(x - 35, y - 20)
          ..lineTo(x, y)
          ..close();

    final leftPaint = Paint()..color = SciFiDesignSystem.buildingDark;
    canvas.drawPath(leftPath, leftPaint);

    // Right face
    final rightPath =
        Path()
          ..moveTo(x, y - size)
          ..lineTo(x + 35, y - 20 - size)
          ..lineTo(x + 35, y - 20)
          ..lineTo(x, y)
          ..close();

    final rightPaint =
        Paint()
          ..shader = ui.Gradient.linear(Offset(x, y - size), Offset(x, y), [
            SciFiDesignSystem.buildingLight,
            SciFiDesignSystem.buildingBase,
          ]);
    canvas.drawPath(rightPath, rightPaint);
  }

  void _drawSpireStructure(Canvas canvas, double x, double y) {
    // Tapered spire with multiple tiers
    final height = buildingHeight * 0.7;

    for (int i = 0; i < 3; i++) {
      final tierY = y - (height * i / 3);
      final tierWidth = 30 - (i * 8);

      final tierPath =
          Path()
            ..moveTo(x - tierWidth, tierY)
            ..lineTo(x + tierWidth, tierY - 12)
            ..lineTo(x + tierWidth, tierY - 32)
            ..lineTo(x - tierWidth, tierY - 20)
            ..close();

      final tierPaint =
          Paint()
            ..color =
                Color.lerp(
                  SciFiDesignSystem.buildingBase,
                  SciFiDesignSystem.buildingLight,
                  i / 3,
                )!;
      canvas.drawPath(tierPath, tierPaint);

      // Tier rim
      final rimPaint =
          Paint()
            ..color = accentColor.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
      canvas.drawPath(tierPath, rimPaint);
    }
  }

  // ==========================================================================
  // LAYER 4: TOP CAP / ANTENNA
  // ==========================================================================

  void _drawTopCap(Canvas canvas, double x, double y) {
    // Small antenna with pulsing light
    final antennaPaint =
        Paint()
          ..color = SciFiDesignSystem.buildingLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawLine(Offset(x, y), Offset(x, y - 15), antennaPaint);

    // Tip light
    final tipPaint =
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y - 15), 3, tipPaint);

    // Tip glow
    final glowPaint =
        Paint()
          ..color = accentColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(x, y - 15), 6, glowPaint);
  }

  // ==========================================================================
  // LAYER 5: ACCENT GLOW
  // ==========================================================================

  void _drawAccentGlow(Canvas canvas, double x, double y, double intensity) {
    final glowPath =
        Path()..addOval(
          Rect.fromCenter(
            center: Offset(x, y - buildingHeight * 0.3),
            width: 100,
            height: 100,
          ),
        );

    SciFiDesignSystem.drawFakeGlow(
      canvas,
      glowPath,
      accentColor,
      intensity: intensity,
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  void _drawWindows(Canvas canvas, double x, double y, int count, Color color) {
    for (int i = 0; i < count; i++) {
      final windowX = x + (i * 8);
      final windowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(windowX, y, 4, 6),
        const Radius.circular(1),
      );

      final windowPaint = Paint()..color = color.withValues(alpha: 0.6);

      canvas.drawRRect(windowRect, windowPaint);
    }
  }

  @override
  bool shouldRepaint(PremiumBuildingPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

enum BuildingStyle { tower, dome, cube, spire }
