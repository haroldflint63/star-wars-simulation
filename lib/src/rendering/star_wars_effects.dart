import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;
import '../audio/star_wars_sounds.dart';

/// Star Wars movie set cinematic effects
class StarWarsEffects {
  // Sound trigger tracking
  static final Map<String, int> _lastHologramSound = {};

  /// Holographic tech panels on building surfaces
  static void drawHolographicPanels(
    Canvas canvas,
    vm.Vector3 pos,
    double width,
    double height,
    double depth,
    Function(vm.Vector3) w2s,
  ) {
    // Trigger hologram activation sound occasionally
    final locationKey = '${pos.x.toInt()}_${pos.z.toInt()}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastSound = _lastHologramSound[locationKey] ?? 0;

    if (now - lastSound > 30000) {
      // Every 30 seconds (reduced from 15)
      _lastHologramSound[locationKey] = now;
      StarWarsSounds.hologramActivate();
    }

    final random = math.Random(999);

    // Holographic displays on building facade
    for (int i = 0; i < 4; i++) {
      final panelX = pos.x + (random.nextDouble() * width - width / 2) * 0.8;
      final panelY = pos.y + 20 + random.nextDouble() * (height - 40);
      final panelZ = pos.z + depth / 2 + 1;

      final panelPos = w2s(vm.Vector3(panelX, panelY, panelZ));

      // Holographic panel glow
      canvas.drawRect(
        Rect.fromCenter(center: panelPos, width: 15, height: 12),
        Paint()
          ..color = const Color(0xFF00BFFF).withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Panel screen
      canvas.drawRect(
        Rect.fromCenter(center: panelPos, width: 12, height: 10),
        Paint()..color = const Color(0xFF0088CC).withValues(alpha: 0.6),
      );

      // Scan lines
      for (int j = 0; j < 3; j++) {
        canvas.drawLine(
          Offset(panelPos.dx - 6, panelPos.dy - 4 + j * 3),
          Offset(panelPos.dx + 6, panelPos.dy - 4 + j * 3),
          Paint()
            ..color = const Color(0xFF00FFFF).withValues(alpha: 0.5)
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  /// Energy shield shimmer effect
  static void drawEnergyShield(
    Canvas canvas,
    vm.Vector3 pos,
    double width,
    double height,
    Function(vm.Vector3) w2s,
  ) {
    final shieldCenter = w2s(vm.Vector3(pos.x, pos.y + height / 2, pos.z));

    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final shimmer = (math.sin(time * 2) * 0.5 + 0.5) * 0.15;

    // Shield bubble
    canvas.drawCircle(
      shieldCenter,
      width * 0.6,
      Paint()
        ..color = const Color(0xFF00FFFF).withValues(alpha: shimmer)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Energy pulses
    final pulseSize = (time % 2) * 20;
    canvas.drawCircle(
      shieldCenter,
      pulseSize,
      Paint()
        ..color = const Color(
          0xFF00FFFF,
        ).withValues(alpha: 0.3 * (1 - pulseSize / 40))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  /// Holographic Jedi symbols floating
  static void drawHolographicJediSymbols(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final float = math.sin(time) * 10;

    for (int i = 0; i < 3; i++) {
      final angle = i * 2 * math.pi / 3;
      final symbolPos = w2s(
        vm.Vector3(
          pos.x + math.cos(angle) * 60,
          pos.y + 180 + float + i * 15,
          pos.z + math.sin(angle) * 60,
        ),
      );

      // Holographic glow
      canvas.drawCircle(
        symbolPos,
        20,
        Paint()
          ..color = const Color(0xFF00BFFF).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );

      // Jedi symbol (simplified star)
      final path = Path();
      path.moveTo(symbolPos.dx, symbolPos.dy - 10);
      path.lineTo(symbolPos.dx + 6, symbolPos.dy + 10);
      path.lineTo(symbolPos.dx - 6, symbolPos.dy + 10);
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF00FFFF).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// Death Star superlaser charging
  static void drawSuperlaserCharge(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // Pulsing green energy
    final pulse = (math.sin(time * 3) * 0.5 + 0.5);

    // Energy core
    canvas.drawCircle(
      center,
      12 + pulse * 5,
      Paint()
        ..color = const Color(0xFF00FF00).withValues(alpha: 0.6 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );

    // Energy rings
    for (int i = 0; i < 3; i++) {
      final ringSize = 15 + i * 10 + pulse * 5;
      canvas.drawCircle(
        center,
        ringSize,
        Paint()
          ..color = const Color(
            0xFF00FF00,
          ).withValues(alpha: 0.3 * (1 - i * 0.2))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// Metallic greebling details
  static void drawMetallicGreebling(
    Canvas canvas,
    vm.Vector3 pos,
    double width,
    double height,
    double depth,
    Function(vm.Vector3) w2s,
  ) {
    final random = math.Random(777);

    // Metallic vents
    for (int i = 0; i < 8; i++) {
      final ventX = pos.x + (random.nextDouble() * width - width / 2) * 0.7;
      final ventY = pos.y + random.nextDouble() * height;
      final ventZ = pos.z + (i % 2 == 0 ? depth / 2 : -depth / 2);

      final ventPos = w2s(vm.Vector3(ventX, ventY, ventZ));

      // Vent panel
      canvas.drawRect(
        Rect.fromCenter(center: ventPos, width: 10, height: 8),
        Paint()..color = Colors.grey.shade800,
      );

      // Vent grille
      for (int j = 0; j < 4; j++) {
        canvas.drawLine(
          Offset(ventPos.dx - 4, ventPos.dy - 3 + j * 2),
          Offset(ventPos.dx + 4, ventPos.dy - 3 + j * 2),
          Paint()
            ..color = Colors.grey.shade900
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  /// Animated landing lights
  static void drawLandingLights(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final blink = ((time * 2) % 1) > 0.5;

    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final lightPos = w2s(
        vm.Vector3(
          pos.x + math.cos(angle) * 55,
          pos.y + 5,
          pos.z + math.sin(angle) * 55,
        ),
      );

      if (blink || i % 2 == 0) {
        // Light glow
        canvas.drawCircle(
          lightPos,
          8,
          Paint()
            ..color = (i % 2 == 0 ? Colors.blue : Colors.red).withValues(
              alpha: 0.4,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );

        // Light core
        canvas.drawCircle(
          lightPos,
          3,
          Paint()..color = i % 2 == 0 ? Colors.cyan : Colors.orange,
        );
      }
    }
  }
}
