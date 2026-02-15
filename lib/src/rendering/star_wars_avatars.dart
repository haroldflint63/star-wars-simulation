import 'package:flutter/material.dart';
import 'dart:math';
import '../audio/star_wars_sounds.dart';

/// Star Wars character avatar renderer with activity-specific poses
class StarWarsAvatars {
  /// Draw character-specific avatar with activity
  static void drawCharacter({
    required Canvas canvas,
    required Offset position,
    required String characterId,
    required Map<String, double> animationValues,
    required bool isSelected,
    String activity = 'idle',
  }) {
    // Check if character is walking based on leg animation
    final isWalking =
        (animationValues['leftLegAngle']?.abs() ?? 0.0) > 0.1 ||
        (animationValues['rightLegAngle']?.abs() ?? 0.0) > 0.1;

    // Add energy aura when moving or active
    if (isWalking || activity != 'idle') {
      _drawEnergyAura(canvas, position, characterId, animationValues);
    }

    // Trigger character-specific sounds for special activities
    _triggerActivitySound(characterId, activity, animationValues);

    // Apply scale from API data if available
    final scale = animationValues['scale'] ?? 1.0;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.scale(scale);
    canvas.translate(-position.dx, -position.dy);

    // shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(position.dx, position.dy - 2),
        width: 24 * scale,
        height: 8,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Draw activity-specific props/effects first (background layer)
    _drawActivityBackground(canvas, position, activity, animationValues);

    switch (characterId) {
      case 'luke':
        _drawLukeSkywalker(
          canvas,
          position,
          animationValues,
          isSelected,
          activity,
          isWalking,
        );
        break;
      case 'leia':
        _drawPrincessLeia(
          canvas,
          position,
          animationValues,
          isSelected,
          activity,
          isWalking,
        );
        break;
      case 'han':
        _drawHanSolo(
          canvas,
          position,
          animationValues,
          isSelected,
          activity,
          isWalking,
        );
        break;
      default:
        _drawGenericJedi(canvas, position, animationValues, isSelected);
    }

    // Draw activity-specific props/effects on top (foreground layer)
    _drawActivityForeground(canvas, position, activity, animationValues);

    canvas.restore();
  }

  // Sound trigger tracking
  static final Map<String, int> _lastSoundTrigger = {};

  /// Draw energy aura around active characters for movie-like effect
  static void _drawEnergyAura(
    Canvas canvas,
    Offset position,
    String characterId,
    Map<String, double> animationValues,
  ) {
    final t = animationValues['bobOffset'] ?? 0.0;
    final pulse = (sin(t * 0.5) + 1) / 2; // 0 to 1 pulse

    Color auraColor;
    switch (characterId) {
      case 'luke':
        auraColor = const Color(0xFF00BFFF); // Blue (Jedi)
        break;
      case 'leia':
        auraColor = const Color(0xFFFFB6C1); // Pink (Princess)
        break;
      case 'han':
        auraColor = const Color(0xFFFF8C00); // Orange (Smuggler)
        break;
      default:
        auraColor = const Color(0xFF00FFFF); // Cyan (default)
    }

    // Outer glow
    canvas.drawCircle(
      Offset(position.dx, position.dy - 15),
      40 + pulse * 5,
      Paint()
        ..color = auraColor.withValues(alpha: 0.08 + pulse * 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );

    // Inner glow
    canvas.drawCircle(
      Offset(position.dx, position.dy - 15),
      25 + pulse * 3,
      Paint()
        ..color = auraColor.withValues(alpha: 0.12 + pulse * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Energy particles
    for (int i = 0; i < 4; i++) {
      final angle = (t + i * 90) * 0.01;
      final radius = 35 + sin(angle * 2) * 5;
      final particlePos = Offset(
        position.dx + cos(angle) * radius,
        position.dy - 15 + sin(angle) * radius * 0.5,
      );

      canvas.drawCircle(
        particlePos,
        2 + pulse,
        Paint()
          ..color = auraColor.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  /// Trigger activity-specific sounds with proper timing
  static void _triggerActivitySound(
    String characterId,
    String activity,
    Map<String, double> anim,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTrigger = _lastSoundTrigger[characterId] ?? 0;
    final timeSinceLastSound = now - lastTrigger;

    // Throttle sounds to prevent spam (minimum 2 seconds between triggers)
    if (timeSinceLastSound < 2000) return;

    bool shouldTrigger = false;

    switch (activity) {
      case 'training':
      case 'fighting':
        if (characterId == 'luke') {
          // Lightsaber swing during combat
          final armAngle = (anim['rightArmAngle'] ?? 0.0).abs();
          if (armAngle > 0.3) {
            StarWarsSounds.lightsaberSwing();
            shouldTrigger = true;
          }
        } else if (characterId == 'han') {
          // Blaster fire
          final armAngle = (anim['rightArmAngle'] ?? 0.0).abs();
          if (armAngle > 0.2) {
            StarWarsSounds.blasterFire();
            shouldTrigger = true;
          }
        }
        break;

      case 'meditating':
        // Force power sound
        if (timeSinceLastSound > 5000) {
          // Every 5 seconds for meditation
          StarWarsSounds.forcePower();
          shouldTrigger = true;
        }
        break;

      case 'repairing':
        // R2-D2 beeps
        if (timeSinceLastSound > 3000) {
          StarWarsSounds.r2d2Beep();
          shouldTrigger = true;
        }
        break;
    }

    if (shouldTrigger) {
      _lastSoundTrigger[characterId] = now;
    }
  }

  /// Draw activity background effects
  static void _drawActivityBackground(
    Canvas canvas,
    Offset pos,
    String activity,
    Map<String, double> anim,
  ) {
    final t = anim['bobOffset'] ?? 0.0;

    switch (activity) {
      case 'meditating':
        // Force energy swirls
        for (int i = 0; i < 3; i++) {
          final angle = (t + i * 120) * 0.02;
          final radius = 40 + i * 8;
          // Use angle for a gentle sway
          final sway = sin(angle) * 10;

          canvas.drawCircle(
            Offset(
              pos.dx + sway + radius * 0.3 * (i % 2 == 0 ? 1 : -1),
              pos.dy - 15 + (i * 5),
            ),
            6 - i * 1.5,
            Paint()
              ..color = Colors.cyan.withValues(alpha: 0.3 - i * 0.08)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
        }
        break;

      case 'training':
        // Energy field around avatar
        canvas.drawCircle(
          Offset(pos.dx, pos.dy - 15),
          35,
          Paint()
            ..color = Colors.blue.withValues(alpha: 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
        );
        break;

      case 'piloting':
        // Control panel
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(pos.dx, pos.dy + 5),
            width: 40,
            height: 20,
          ),
          Paint()..color = Colors.grey.shade800,
        );
        // Blinking lights
        for (int i = 0; i < 4; i++) {
          canvas.drawCircle(
            Offset(pos.dx - 15 + i * 10, pos.dy + 5),
            2,
            Paint()..color = (i % 2 == 0) ? Colors.red : Colors.green,
          );
        }
        break;

      case 'studying':
        // Holographic book/datapad
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(pos.dx, pos.dy + 5),
            width: 20,
            height: 28,
          ),
          Paint()
            ..color = Colors.cyan.shade700.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        break;
    }
  }

  /// Draw activity foreground effects
  static void _drawActivityForeground(
    Canvas canvas,
    Offset pos,
    String activity,
    Map<String, double> anim,
  ) {
    // final t = anim['bobOffset'] ?? 0.0; // Unused for now

    switch (activity) {
      case 'meeting':
        // Speech bubble
        canvas.drawCircle(
          Offset(pos.dx + 25, pos.dy - 35),
          12,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(pos.dx + 25, pos.dy - 35),
          12,
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        // Speech marks
        final textPainter = TextPainter(
          text: TextSpan(
            text: '...',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(pos.dx + 17, pos.dy - 42));
        break;

      case 'commanding':
        // Hologram projection
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(pos.dx + 30, pos.dy - 10),
            width: 20,
            height: 25,
          ),
          Paint()
            ..color = Colors.blue.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
        // Hologram lines
        for (int i = 0; i < 5; i++) {
          canvas.drawLine(
            Offset(pos.dx + 20, pos.dy - 20 + i * 5),
            Offset(pos.dx + 40, pos.dy - 20 + i * 5),
            Paint()
              ..color = Colors.cyan.withValues(alpha: 0.6)
              ..strokeWidth = 0.8,
          );
        }
        break;

      case 'negotiating':
        // Credits/currency floating
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(pos.dx + 20 + i * 8, pos.dy - 20 - i * 3),
            3,
            Paint()..color = Colors.amber.shade600,
          );
        }
        break;

      case 'repairing':
        // Tools
        canvas.drawRect(
          Rect.fromLTRB(pos.dx + 15, pos.dy - 5, pos.dx + 25, pos.dy + 15),
          Paint()..color = Colors.grey.shade600,
        );
        // Sparks
        for (int i = 0; i < 2; i++) {
          canvas.drawCircle(
            Offset(pos.dx + 20 + i * 5, pos.dy + 8),
            1.5,
            Paint()
              ..color = Colors.orange.shade400
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
        break;
    }
  }

  /// Draw Luke Skywalker - LEGO Style
  static void _drawLukeSkywalker(
    Canvas canvas,
    Offset pos,
    Map<String, double> anim,
    bool selected,
    String activity,
    bool isWalking,
  ) {
    var leftArmAngle = anim['leftArmAngle'] ?? 0.0;
    var rightArmAngle = anim['rightArmAngle'] ?? 0.0;
    final leftLegAngle = anim['leftLegAngle'] ?? 0.0;
    final rightLegAngle = anim['rightLegAngle'] ?? 0.0;
    final bodyBob = anim['bodyBob'] ?? 0.0;

    // Adjust arm angles based on activity (only when not walking)
    if (!isWalking) {
      if (activity == 'meditating' || activity == 'training') {
        leftArmAngle = -0.8; // Arms crossed in meditation
        rightArmAngle = 0.8;
      } else if (activity == 'studying') {
        leftArmAngle = 0.3; // Arms down reading
        rightArmAngle = 0.3;
      } else if (activity == 'piloting') {
        leftArmAngle = 0.5; // Hands on controls
        rightArmAngle = -0.5;
      }
    }

    final bobPos = Offset(pos.dx, pos.dy - bodyBob);

    // LEGO Legs - Blocky rectangles
    _drawLegoLeg(canvas, pos, -5, leftLegAngle, const Color(0xFF0055AA));
    _drawLegoLeg(canvas, pos, 5, rightLegAngle, const Color(0xFF0055AA));

    // LEGO Torso - Blocky white body
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(bobPos.dx, bobPos.dy - 10),
        width: 18,
        height: 20,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(torsoRect, Paint()..color = Colors.white);

    // LEGO torso print (simple tunic design)
    final printPaint =
        Paint()
          ..color = Colors.grey.shade400
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(bobPos.dx, bobPos.dy - 18),
      Offset(bobPos.dx, bobPos.dy - 2),
      printPaint,
    );

    // Belt print
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(bobPos.dx, bobPos.dy - 3),
        width: 16,
        height: 3,
      ),
      Paint()..color = const Color(0xFF8B4513),
    );

    // LEGO Arms - Cylindrical blocky arms
    _drawLegoArm(canvas, bobPos, -11, leftArmAngle, Colors.white);
    _drawLegoArm(canvas, bobPos, 11, rightArmAngle, Colors.white);

    // Lightsaber
    if (activity == 'training' ||
        activity == 'meditating' ||
        rightArmAngle.abs() > 0.6) {
      _drawLightsaber(canvas, bobPos, 11, rightArmAngle, Colors.blue);
    }

    // LEGO Head - Yellow cylindrical
    _drawLegoHead(canvas, bobPos, const Color(0xFFFFD700), true);

    // Selection glow
    if (selected) {
      _drawSelectionGlow(canvas, bobPos, Colors.blue);
    }
  }

  /// Draw Princess Leia - LEGO Style
  static void _drawPrincessLeia(
    Canvas canvas,
    Offset pos,
    Map<String, double> anim,
    bool selected,
    String activity,
    bool isWalking,
  ) {
    var leftArmAngle = anim['leftArmAngle'] ?? 0.0;
    var rightArmAngle = anim['rightArmAngle'] ?? 0.0;
    final leftLegAngle = anim['leftLegAngle'] ?? 0.0;
    final rightLegAngle = anim['rightLegAngle'] ?? 0.0;
    final bodyBob = anim['bodyBob'] ?? 0.0;

    // Adjust arm angles based on activity (only when not walking)
    if (!isWalking) {
      if (activity == 'commanding') {
        leftArmAngle = -0.6; // Gesturing
        rightArmAngle = 0.4;
      } else if (activity == 'meeting') {
        leftArmAngle = 0.3; // Diplomatic pose
        rightArmAngle = 0.3;
      }
    }

    final bobPos = Offset(pos.dx, pos.dy - bodyBob);

    // LEGO Legs
    _drawLegoLeg(canvas, pos, -5, leftLegAngle, Colors.white);
    _drawLegoLeg(canvas, pos, 5, rightLegAngle, Colors.white);

    // LEGO Torso - White robe
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(bobPos.dx, bobPos.dy - 10),
        width: 18,
        height: 20,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(torsoRect, Paint()..color = Colors.white);

    // Belt print
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(bobPos.dx, bobPos.dy - 4),
        width: 16,
        height: 4,
      ),
      Paint()..color = Colors.grey.shade400,
    );

    // LEGO Arms
    _drawLegoArm(canvas, bobPos, -11, leftArmAngle, Colors.white);
    _drawLegoArm(canvas, bobPos, 11, rightArmAngle, Colors.white);

    // Blaster
    if (activity == 'commanding' || leftArmAngle.abs() > 0.4) {
      _drawBlaster(canvas, bobPos, -11, leftArmAngle);
    }

    // LEGO Head with hair buns
    _drawLegoHead(canvas, bobPos, const Color(0xFFFFD700), false);

    // LEGO Hair Buns - Simplified circular studs
    final hairColor = const Color(0xFF4A2511);
    // Left bun
    canvas.drawCircle(
      Offset(bobPos.dx - 10, bobPos.dy - 28),
      5,
      Paint()..color = hairColor,
    );
    // Right bun
    canvas.drawCircle(
      Offset(bobPos.dx + 10, bobPos.dy - 28),
      5,
      Paint()..color = hairColor,
    );

    // Selection glow
    if (selected) {
      _drawSelectionGlow(canvas, bobPos, Colors.pink);
    }
  }

  /// Draw Han Solo - LEGO Style
  static void _drawHanSolo(
    Canvas canvas,
    Offset pos,
    Map<String, double> anim,
    bool selected,
    String activity,
    bool isWalking,
  ) {
    var leftArmAngle = anim['leftArmAngle'] ?? 0.0;
    var rightArmAngle = anim['rightArmAngle'] ?? 0.0;
    final leftLegAngle = anim['leftLegAngle'] ?? 0.0;
    final rightLegAngle = anim['rightLegAngle'] ?? 0.0;
    final bodyBob = anim['bodyBob'] ?? 0.0;

    // Adjust arm angles based on activity (only when not walking)
    if (!isWalking) {
      if (activity == 'repairing' || activity == 'piloting') {
        leftArmAngle = 0.6; // Working on machinery
        rightArmAngle = -0.4;
      } else if (activity == 'negotiating') {
        leftArmAngle = -0.3;
        rightArmAngle = 0.5;
      }
    }

    final bobPos = Offset(pos.dx, pos.dy - bodyBob);

    // LEGO Legs - Dark blue
    _drawLegoLeg(canvas, pos, -5, leftLegAngle, const Color(0xFF1a1a4d));
    _drawLegoLeg(canvas, pos, 5, rightLegAngle, const Color(0xFF1a1a4d));

    // LEGO Torso - Cream with black vest print
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(bobPos.dx, bobPos.dy - 10),
        width: 18,
        height: 20,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(torsoRect, Paint()..color = const Color(0xFFF5F5DC));

    // Vest print
    canvas.drawRect(
      Rect.fromLTWH(bobPos.dx - 8, bobPos.dy - 18, 5, 16),
      Paint()..color = const Color(0xFF222222),
    );
    canvas.drawRect(
      Rect.fromLTWH(bobPos.dx + 3, bobPos.dy - 18, 5, 16),
      Paint()..color = const Color(0xFF222222),
    );

    // Belt print
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(bobPos.dx, bobPos.dy - 2),
        width: 16,
        height: 3,
      ),
      Paint()..color = const Color(0xFF5D4037),
    );

    // LEGO Arms
    _drawLegoArm(canvas, bobPos, -11, leftArmAngle, const Color(0xFFF5F5DC));
    _drawLegoArm(canvas, bobPos, 11, rightArmAngle, const Color(0xFFF5F5DC));

    // Blaster DL-44
    _drawBlaster(canvas, bobPos, 11, rightArmAngle);

    // LEGO Head
    _drawLegoHead(canvas, bobPos, const Color(0xFFFFD700), false);

    // LEGO Hair piece - Brown
    final hairRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(bobPos.dx, bobPos.dy - 32),
        width: 14,
        height: 8,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(hairRect, Paint()..color = const Color(0xFF3E2723));

    // Selection glow
    if (selected) {
      _drawSelectionGlow(canvas, bobPos, Colors.amber);
    }
  }

  /// LEGO-style blocky leg
  static void _drawLegoLeg(
    Canvas canvas,
    Offset pos,
    double offsetX,
    double angle,
    Color color,
  ) {
    canvas.save();
    canvas.translate(pos.dx + offsetX, pos.dy);
    canvas.rotate(angle);

    // LEGO leg - simple rectangle
    final legRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-3.5, 0, 7, 18),
      const Radius.circular(1),
    );
    canvas.drawRRect(legRect, Paint()..color = color);

    // Leg joint line
    canvas.drawLine(
      const Offset(-3.5, 9),
      const Offset(3.5, 9),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1,
    );

    canvas.restore();
  }

  // static void _drawDetailedLeg(
  //   Canvas canvas,
  //   Offset pos,
  //   double offsetX,
  //   double angle,
  //   Color color,
  //   Color bootColor,
  // ) {
  //   _drawLegoLeg(canvas, pos, offsetX, angle, color);
  // }

  /// LEGO-style cylindrical arm
  static void _drawLegoArm(
    Canvas canvas,
    Offset pos,
    double offsetX,
    double angle,
    Color color,
  ) {
    canvas.save();
    canvas.translate(pos.dx + offsetX, pos.dy - 16);
    canvas.rotate(angle);

    // LEGO arm - cylindrical
    final armRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-2.5, 0, 5, 12),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(armRect, Paint()..color = color);

    // LEGO hand - yellow claw
    final handRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-3, 11, 6, 5),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(handRect, Paint()..color = const Color(0xFFFFD700));

    canvas.restore();
  }

  // static void _drawDetailedArm(
  //   Canvas canvas,
  //   Offset pos,
  //   double offsetX,
  //   double angle,
  //   Color color,
  // ) {
  //   _drawLegoArm(canvas, pos, offsetX, angle, color);
  // }

  /// LEGO-style cylindrical head
  static void _drawLegoHead(
    Canvas canvas,
    Offset pos,
    Color color,
    bool isLuke,
  ) {
    // LEGO head - cylindrical
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy - 26),
        width: 12,
        height: 14,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(headRect, Paint()..color = color);

    // Stud on top
    canvas.drawCircle(
      Offset(pos.dx, pos.dy - 32),
      2.5,
      Paint()..color = color.withValues(alpha: color.a * 0.9),
    );

    // Simple eyes - printed dots
    canvas.drawCircle(
      Offset(pos.dx - 3, pos.dy - 27),
      1.2,
      Paint()..color = Colors.black,
    );
    canvas.drawCircle(
      Offset(pos.dx + 3, pos.dy - 27),
      1.2,
      Paint()..color = Colors.black,
    );

    // Simple smile
    canvas.drawArc(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy - 24), width: 6, height: 3),
      0,
      3.14,
      false,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  // static void _drawHead(
  //   Canvas canvas,
  //   Offset pos,
  //   Color skinColor,
  //   bool isLuke,
  // ) {
  //   _drawLegoHead(canvas, pos, const Color(0xFFFFD700), isLuke);
  // }

  static void _drawSelectionGlow(Canvas canvas, Offset pos, Color color) {
    canvas.drawCircle(
      Offset(pos.dx, pos.dy - 15),
      30,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
    canvas.drawCircle(
      Offset(pos.dx, pos.dy - 15),
      30,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  /// Draw lightsaber
  static void _drawLightsaber(
    Canvas canvas,
    Offset pos,
    double offsetX,
    double angle,
    Color bladeColor,
  ) {
    canvas.save();
    canvas.translate(pos.dx + offsetX, pos.dy - 12);
    canvas.rotate(angle);

    // Hilt
    canvas.drawRect(
      const Rect.fromLTWH(-2, 14, 4, 12),
      Paint()..color = Colors.grey.shade700,
    );

    // Blade glow
    canvas.drawRect(
      const Rect.fromLTWH(-3, -20, 6, 34),
      Paint()
        ..color = bladeColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Blade core
    canvas.drawRect(
      const Rect.fromLTWH(-1.5, -20, 3, 34),
      Paint()..color = bladeColor,
    );

    canvas.restore();
  }

  /// Draw blaster
  static void _drawBlaster(
    Canvas canvas,
    Offset pos,
    double offsetX,
    double angle,
  ) {
    canvas.save();
    canvas.translate(pos.dx + offsetX, pos.dy - 12);
    canvas.rotate(angle);

    // Blaster body
    canvas.drawRect(
      const Rect.fromLTWH(-2, 12, 4, 10),
      Paint()..color = Colors.grey.shade800,
    );

    // Barrel
    canvas.drawRect(
      const Rect.fromLTWH(-1, 8, 2, 4),
      Paint()..color = Colors.grey.shade600,
    );

    // Grip
    canvas.drawRect(
      const Rect.fromLTWH(-2, 18, 4, 4),
      Paint()..color = Colors.brown.shade700,
    );

    canvas.restore();
  }

  /// Generic Jedi
  static void _drawGenericJedi(
    Canvas canvas,
    Offset pos,
    Map<String, double> anim,
    bool selected,
  ) {
    _drawLukeSkywalker(canvas, pos, anim, selected, 'idle', false);
  }
}
