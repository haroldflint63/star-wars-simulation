import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Draws detailed avatar with clothing and accessories
class DetailedAvatarPainter {
  static void drawAvatar({
    required Canvas canvas,
    required Offset position,
    required Color primaryColor,
    required Map<String, double> animationValues,
    required bool isSelected,
  }) {
    final bobOffset = animationValues['bobOffset'] ?? 0.0;
    final leftArmAngle = animationValues['leftArmAngle'] ?? 0.0;
    final rightArmAngle = animationValues['rightArmAngle'] ?? 0.0;
    final leftLegAngle = animationValues['leftLegAngle'] ?? 0.0;
    final rightLegAngle = animationValues['rightLegAngle'] ?? 0.0;
    final headTilt = animationValues['headTilt'] ?? 0.0;
    final bodyRotation = animationValues['bodyRotation'] ?? 0.0;

    final avatarCenter = Offset(position.dx, position.dy + bobOffset);

    // Draw body with rotation
    canvas.save();
    canvas.translate(avatarCenter.dx, avatarCenter.dy);
    canvas.rotate(bodyRotation);
    canvas.translate(-avatarCenter.dx, -avatarCenter.dy);

    // Legs (behind body)
    _drawLegs(canvas, avatarCenter, primaryColor, leftLegAngle, rightLegAngle);

    // Body with shirt
    _drawBody(canvas, avatarCenter, primaryColor);

    // Arms
    _drawArms(canvas, avatarCenter, primaryColor, leftArmAngle, rightArmAngle);

    // Head with details
    _drawHead(canvas, avatarCenter, primaryColor, headTilt);

    canvas.restore();

    // Activity indicator (small icon above head)
    _drawActivityIndicator(
      canvas,
      Offset(position.dx, position.dy - 75),
      animationValues,
    );
  }

  static void _drawLegs(
    Canvas canvas,
    Offset center,
    Color color,
    double leftAngle,
    double rightAngle,
  ) {
    final pantsPaint =
        Paint()
          ..color = Colors.blueGrey.shade700
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round;

    // Left leg (darker pants)
    final leftLegStart = Offset(center.dx - 6, center.dy + 22);
    final leftLegEnd = Offset(
      center.dx - 10 + math.sin(leftAngle) * 15,
      center.dy + 38 + math.cos(leftAngle) * 8,
    );
    canvas.drawLine(leftLegStart, leftLegEnd, pantsPaint);

    // Right leg
    final rightLegStart = Offset(center.dx + 6, center.dy + 22);
    final rightLegEnd = Offset(
      center.dx + 10 + math.sin(rightAngle) * 15,
      center.dy + 38 + math.cos(rightAngle) * 8,
    );
    canvas.drawLine(rightLegStart, rightLegEnd, pantsPaint);

    // Shoes
    final shoePaint =
        Paint()
          ..color = Colors.grey.shade800
          ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: leftLegEnd, width: 12, height: 6),
      shoePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: rightLegEnd, width: 12, height: 6),
      shoePaint,
    );
  }

  static void _drawBody(Canvas canvas, Offset center, Color color) {
    // Main body (shirt)
    final bodyPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.9),
              color.withValues(alpha: 0.7),
            ],
          ).createShader(
            Rect.fromCenter(
              center: Offset(center.dx, center.dy + 5),
              width: 32,
              height: 42,
            ),
          );

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 5),
        width: 32,
        height: 42,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Body outline
    final outlinePaint =
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    canvas.drawRRect(bodyRect, outlinePaint);

    // Buttons on shirt
    final buttonPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(center.dx, center.dy - 5 + i * 12),
        2,
        buttonPaint,
      );
    }
  }

  static void _drawArms(
    Canvas canvas,
    Offset center,
    Color color,
    double leftAngle,
    double rightAngle,
  ) {
    final armPaint =
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;

    final handPaint =
        Paint()
          ..color = Color.lerp(color, Colors.brown.shade200, 0.3)!
          ..style = PaintingStyle.fill;

    // Left arm with sleeve
    final leftArmStart = Offset(center.dx - 16, center.dy);
    final leftArmEnd = Offset(
      center.dx - 16 + math.sin(leftAngle) * 20,
      center.dy + 18 + math.cos(leftAngle) * 15,
    );
    canvas.drawLine(leftArmStart, leftArmEnd, armPaint);

    // Left hand
    canvas.drawCircle(leftArmEnd, 4, handPaint);

    // Right arm
    final rightArmStart = Offset(center.dx + 16, center.dy);
    final rightArmEnd = Offset(
      center.dx + 16 + math.sin(rightAngle) * 20,
      center.dy + 18 + math.cos(rightAngle) * 15,
    );
    canvas.drawLine(rightArmStart, rightArmEnd, armPaint);

    // Right hand
    canvas.drawCircle(rightArmEnd, 4, handPaint);
  }

  static void _drawHead(
    Canvas canvas,
    Offset center,
    Color color,
    double tilt,
  ) {
    final headCenter = Offset(center.dx, center.dy - 20);

    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(tilt);
    canvas.translate(-headCenter.dx, -headCenter.dy);

    // Skin tone
    final skinColor = Color.lerp(color, const Color(0xFFFFDAB9), 0.5)!;

    // Head (circle)
    final headPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              skinColor.withValues(alpha: 1.0),
              skinColor.withValues(alpha: 0.85),
            ],
          ).createShader(Rect.fromCircle(center: headCenter, radius: 18));

    canvas.drawCircle(headCenter, 18, headPaint);

    // Head outline
    final headOutline =
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    canvas.drawCircle(headCenter, 18, headOutline);

    // Hair
    final hairPaint =
        Paint()
          ..color = Colors.brown.shade700
          ..style = PaintingStyle.fill;

    final hairPath =
        Path()..addOval(
          Rect.fromCircle(
            center: Offset(headCenter.dx, headCenter.dy - 8),
            radius: 18,
          ),
        );
    canvas.drawPath(hairPath, hairPaint);

    // Face details
    _drawFace(canvas, headCenter);

    canvas.restore();
  }

  static void _drawFace(Canvas canvas, Offset headCenter) {
    final eyePaint =
        Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.fill;

    // Eyes
    canvas.drawCircle(
      Offset(headCenter.dx - 6, headCenter.dy - 3),
      2.5,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + 6, headCenter.dy - 3),
      2.5,
      eyePaint,
    );

    // Eye highlights
    final highlightPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(headCenter.dx - 5, headCenter.dy - 4),
      1,
      highlightPaint,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + 7, headCenter.dy - 4),
      1,
      highlightPaint,
    );

    // Smile
    final smilePaint =
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;

    final smilePath =
        Path()
          ..moveTo(headCenter.dx - 6, headCenter.dy + 5)
          ..quadraticBezierTo(
            headCenter.dx,
            headCenter.dy + 8,
            headCenter.dx + 6,
            headCenter.dy + 5,
          );
    canvas.drawPath(smilePath, smilePaint);

    // Nose
    canvas.drawCircle(
      Offset(headCenter.dx, headCenter.dy + 2),
      1.5,
      Paint()..color = Colors.black26,
    );
  }

  static void _drawActivityIndicator(
    Canvas canvas,
    Offset position,
    Map<String, double> animationValues,
  ) {
    // Small floating icon indicating current activity
    final iconPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;

    final iconBgPaint =
        Paint()
          ..color = Colors.black45
          ..style = PaintingStyle.fill;

    // Background circle
    canvas.drawCircle(position, 10, iconBgPaint);

    // Activity-specific icon (simplified)
    if (animationValues['leftArmAngle']! < -0.5) {
      // Working - keyboard icon
      final rect = Rect.fromCenter(center: position, width: 10, height: 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        iconPaint,
      );
    } else if (animationValues['bobOffset']! < -5) {
      // Sitting - chair icon
      canvas.drawLine(
        Offset(position.dx - 4, position.dy + 2),
        Offset(position.dx + 4, position.dy + 2),
        iconPaint..strokeWidth = 2,
      );
    } else if (animationValues['bobOffset']!.abs() > 4) {
      // Walking - footsteps
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(position.dx - 2, position.dy),
          width: 4,
          height: 6,
        ),
        iconPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(position.dx + 2, position.dy + 2),
          width: 4,
          height: 6,
        ),
        iconPaint,
      );
    }
  }
}
