import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;

/// Environmental elements for realistic city atmosphere
class CityEnvironment {
  /// Draw pathways/streets between locations
  static void drawStreets(
    Canvas canvas,
    Map<String, vm.Vector3> locationPositions,
    Function(vm.Vector3) worldToScreen,
  ) {
    final connections = [
      ['tatooine_cantina', 'jedi_temple'],
      ['jedi_temple', 'cloud_city'],
      ['cloud_city', 'dagobah_swamp'],
      ['dagobah_swamp', 'death_star'],
      ['death_star', 'endor_forest'],
      ['endor_forest', 'hoth_base'],
      ['hoth_base', 'naboo_palace'],
      ['naboo_palace', 'tatooine_cantina'],
      ['tatooine_cantina', 'dagobah_swamp'],
      ['jedi_temple', 'naboo_palace'],
      ['cloud_city', 'hoth_base'],
      ['death_star', 'endor_forest'],
    ];

    for (final connection in connections) {
      final start = locationPositions[connection[0]];
      final end = locationPositions[connection[1]];

      if (start != null && end != null) {
        _drawPath(canvas, start, end, worldToScreen);
      }
    }
  }

  /// Draw a path between two points
  static void _drawPath(
    Canvas canvas,
    vm.Vector3 start,
    vm.Vector3 end,
    Function(vm.Vector3) w2s,
  ) {
    // Create curved path
    final steps = 30;

    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;

      // Bezier curve for natural looking path
      final mid = vm.Vector3((start.x + end.x) / 2, 0, (start.z + end.z) / 2);

      final x =
          math.pow(1 - t, 2) * start.x +
          2 * (1 - t) * t * mid.x +
          math.pow(t, 2) * end.x;
      final z =
          math.pow(1 - t, 2) * start.z +
          2 * (1 - t) * t * mid.z +
          math.pow(t, 2) * end.z;

      final point = w2s(vm.Vector3(x, 0, z));

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    // Outer glow
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue.shade900.withValues(alpha: 0.3)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Main path - darker base
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF1a2a4a).withValues(alpha: 0.7)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // Path center line - glowing effect
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.cyan.shade600.withValues(alpha: 0.4),
            Colors.blue.shade400.withValues(alpha: 0.3),
            Colors.cyan.shade600.withValues(alpha: 0.4),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 500))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Edge highlights for depth
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.cyan.shade300.withValues(alpha: 0.15)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Animated dashes for energy flow effect
    final dashPaint =
        Paint()
          ..color = Colors.cyan.shade200.withValues(alpha: 0.5)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= steps; i += 2) {
      final t = i / steps;
      final mid = vm.Vector3((start.x + end.x) / 2, 0, (start.z + end.z) / 2);

      final x =
          math.pow(1 - t, 2) * start.x +
          2 * (1 - t) * t * mid.x +
          math.pow(t, 2) * end.x;
      final z =
          math.pow(1 - t, 2) * start.z +
          2 * (1 - t) * t * mid.z +
          math.pow(t, 2) * end.z;

      final point = w2s(vm.Vector3(x, 0, z));

      canvas.drawCircle(point, 2, dashPaint);
    }
  }

  /// Draw ground terrain with texture - Holographic Map Style
  static void drawTerrain(Canvas canvas, Function(vm.Vector3) worldToScreen) {
    // Extended ground area - Limit to reasonable horizon, but large enough
    const mapSize = 3000.0;

    // We don't draw a solid ground anymore, just the grid floating in the void.
    // But we might want a semi-transparent base to ground the buildings.

    final groundPositions = [
      vm.Vector3(-mapSize, 0, -mapSize),
      vm.Vector3(mapSize, 0, -mapSize),
      vm.Vector3(mapSize, 0, mapSize),
      vm.Vector3(-mapSize, 0, mapSize),
    ];

    final groundCorners = groundPositions.map((p) => worldToScreen(p)).toList();

    // Base ground - Semi-transparent Holosurface
    // Allows stars to be slightly visible underneath but provides contrast
    final groundPath =
        Path()
          ..moveTo(groundCorners[0].dx, groundCorners[0].dy)
          ..lineTo(groundCorners[1].dx, groundCorners[1].dy)
          ..lineTo(groundCorners[2].dx, groundCorners[2].dy)
          ..lineTo(groundCorners[3].dx, groundCorners[3].dy)
          ..close();

    canvas.drawPath(
      groundPath,
      Paint()
        ..color = const Color(
          0xFF050A14,
        ).withValues(alpha: 0.92), // Very opaque navy/black
    );

    // Grid pattern - Tactical Holomap
    final gridSize = 50.0;
    final gridCount = (mapSize / gridSize).floor();

    final gridPaint =
        Paint()
          ..color = Colors.cyan.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    final glowPaint =
        Paint()
          ..color = Colors.cyan.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    // Draw grid
    for (int i = -gridCount; i <= gridCount; i += 1) {
      // Optimize: Only draw lines every 1 step, but maybe step is too small?
      // 3000 / 50 = 60 steps. -60 to 60 = 120 lines. Fine for Canvas.

      if (i.abs() > 40 && i % 2 != 0) {
        continue;
      } // Fade out density at edges? No, simple is better.

      // Horizontal lines (X-axis)
      final startX = vm.Vector3(-mapSize, 0, i * gridSize);
      final endX = vm.Vector3(mapSize, 0, i * gridSize);
      final p1 = worldToScreen(startX);
      final p2 = worldToScreen(endX);

      final isMajor = i % 5 == 0;
      canvas.drawLine(p1, p2, isMajor ? glowPaint : gridPaint);

      // Vertical lines (Z-axis)
      final startZ = vm.Vector3(i * gridSize, 0, -mapSize);
      final endZ = vm.Vector3(i * gridSize, 0, mapSize);
      final p3 = worldToScreen(startZ);
      final p4 = worldToScreen(endZ);

      canvas.drawLine(p3, p4, isMajor ? glowPaint : gridPaint);
    }

    // Radial Vignette to hide the hard edges of the map
    // We use a massive gradient on top
    final centerPos = worldToScreen(vm.Vector3(0, 0, 0));
    final screenRect = Rect.fromCircle(center: centerPos, radius: 2000);

    canvas.drawRect(
      screenRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.0), // Start transparent
            Colors.black.withValues(alpha: 1.0), // End solid black
          ],
          stops: const [0.5, 0.8, 1.0],
        ).createShader(screenRect),
    );
  }

  /// Draw ambient lighting effects - Holo-emitters
  static void drawLighting(
    Canvas canvas,
    Map<String, vm.Vector3> locationPositions,
    Function(vm.Vector3) worldToScreen,
  ) {
    // Street lights at each location
    for (final entry in locationPositions.entries) {
      _drawStreetLight(canvas, entry.value, entry.key, worldToScreen);
    }
  }

  /// Draw individual street light
  static void _drawStreetLight(
    Canvas canvas,
    vm.Vector3 position,
    String locationId,
    Function(vm.Vector3) w2s,
  ) {
    // Light poles around building
    final lightPositions = [
      vm.Vector3(position.x - 70, position.y, position.z - 70),
      vm.Vector3(position.x + 70, position.y, position.z - 70),
      vm.Vector3(position.x - 70, position.y, position.z + 70),
      vm.Vector3(position.x + 70, position.y, position.z + 70),
    ];

    for (final lightPos in lightPositions) {
      final base = w2s(lightPos);
      final top = w2s(vm.Vector3(lightPos.x, lightPos.y + 60, lightPos.z));

      // Pole
      canvas.drawLine(
        base,
        top,
        Paint()
          ..color = Colors.grey.shade700
          ..strokeWidth = 2,
      );

      // Light fixture
      canvas.drawCircle(top, 4, Paint()..color = Colors.grey.shade600);

      // Light glow
      final glowColor = _getLightColor(locationId);
      canvas.drawCircle(
        top,
        15,
        Paint()
          ..color = glowColor.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );

      canvas.drawCircle(
        top,
        6,
        Paint()..color = glowColor.withValues(alpha: 0.6),
      );
    }
  }

  /// Get light color based on location theme
  static Color _getLightColor(String locationId) {
    switch (locationId) {
      case 'tatooine_cantina':
        return Colors.orange.shade700;
      case 'jedi_temple':
        return Colors.blue.shade300;
      case 'cloud_city':
        return Colors.amber.shade200;
      case 'dagobah_swamp':
        return Colors.green.shade600;
      case 'death_star':
        return Colors.red.shade700;
      case 'endor_forest':
        return Colors.green.shade400;
      case 'hoth_base':
        return Colors.lightBlue.shade200;
      case 'naboo_palace':
        return Colors.purple.shade300;
      default:
        return Colors.white;
    }
  }

  /// Draw atmospheric particles (dust, snow, etc.)
  static void drawAtmosphere(Canvas canvas, int tick, Size size) {
    // Floating particles based on tick for animation
    final particleCount = 50;
    final random = math.Random(42); // Fixed seed for consistent particles

    for (int i = 0; i < particleCount; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.5 + random.nextDouble() * 0.5;
      final offset = (tick * speed) % size.height;

      final x = baseX + math.sin((tick + i) * 0.05) * 20;
      final y = (baseY + offset) % size.height;
      final particleSize = 1.0 + random.nextDouble() * 2;

      // Particle glow
      canvas.drawCircle(
        Offset(x, y),
        particleSize + 2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Particle core
      canvas.drawCircle(
        Offset(x, y),
        particleSize,
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
    }
  }

  /// Draw decorative elements around city
  static void drawDecorations(
    Canvas canvas,
    Map<String, vm.Vector3> locationPositions,
    Function(vm.Vector3) worldToScreen,
  ) {
    // Holographic billboards
    _drawHolographicSigns(canvas, locationPositions, worldToScreen);

    // Energy conduits connecting buildings
    _drawEnergyConduits(canvas, locationPositions, worldToScreen);

    // Cargo containers
    _drawCargoContainers(canvas, locationPositions, worldToScreen);
  }

  /// Draw holographic signs
  static void _drawHolographicSigns(
    Canvas canvas,
    Map<String, vm.Vector3> locations,
    Function(vm.Vector3) w2s,
  ) {
    for (final entry in locations.entries) {
      final signPos = w2s(
        vm.Vector3(entry.value.x - 50, entry.value.y + 130, entry.value.z),
      );

      // Sign glow
      canvas.drawRect(
        Rect.fromCenter(center: signPos, width: 35, height: 20),
        Paint()
          ..color = Colors.cyan.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      // Sign face
      canvas.drawRect(
        Rect.fromCenter(center: signPos, width: 30, height: 15),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.cyan.shade400.withValues(alpha: 0.6),
              Colors.blue.shade600.withValues(alpha: 0.4),
            ],
          ).createShader(
            Rect.fromCenter(center: signPos, width: 30, height: 15),
          ),
      );

      // Scanlines
      for (int i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(signPos.dx - 15, signPos.dy - 6 + i * 5),
          Offset(signPos.dx + 15, signPos.dy - 6 + i * 5),
          Paint()
            ..color = Colors.cyan.shade200.withValues(alpha: 0.3)
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  /// Draw energy conduits
  static void _drawEnergyConduits(
    Canvas canvas,
    Map<String, vm.Vector3> locations,
    Function(vm.Vector3) w2s,
  ) {
    final connections = [
      ['tatooine_cantina', 'jedi_temple'],
      ['cloud_city', 'naboo_palace'],
      ['hoth_base', 'death_star'],
    ];

    for (final conn in connections) {
      final start = locations[conn[0]];
      final end = locations[conn[1]];

      if (start != null && end != null) {
        final startPos = w2s(vm.Vector3(start.x, start.y + 80, start.z));
        final endPos = w2s(vm.Vector3(end.x, end.y + 80, end.z));

        // Energy beam
        canvas.drawLine(
          startPos,
          endPos,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withValues(alpha: 0.3),
                Colors.cyan.withValues(alpha: 0.3),
              ],
            ).createShader(Rect.fromPoints(startPos, endPos))
            ..strokeWidth = 2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  /// Draw cargo containers
  static void _drawCargoContainers(
    Canvas canvas,
    Map<String, vm.Vector3> locations,
    Function(vm.Vector3) w2s,
  ) {
    // Place containers near cantina and hoth base
    final containerLocations = [
      vm.Vector3(-280, 0, -200),
      vm.Vector3(-260, 0, -200),
      vm.Vector3(240, 0, 200),
      vm.Vector3(260, 0, 200),
    ];

    for (final pos in containerLocations) {
      final corners = [
        w2s(vm.Vector3(pos.x - 10, pos.y, pos.z - 10)),
        w2s(vm.Vector3(pos.x + 10, pos.y, pos.z - 10)),
        w2s(vm.Vector3(pos.x + 10, pos.y, pos.z + 10)),
        w2s(vm.Vector3(pos.x - 10, pos.y, pos.z + 10)),
      ];

      final topCorners = [
        w2s(vm.Vector3(pos.x - 10, pos.y + 20, pos.z - 10)),
        w2s(vm.Vector3(pos.x + 10, pos.y + 20, pos.z - 10)),
        w2s(vm.Vector3(pos.x + 10, pos.y + 20, pos.z + 10)),
        w2s(vm.Vector3(pos.x - 10, pos.y + 20, pos.z + 10)),
      ];

      // Container sides
      final frontPath =
          Path()
            ..moveTo(corners[0].dx, corners[0].dy)
            ..lineTo(corners[1].dx, corners[1].dy)
            ..lineTo(topCorners[1].dx, topCorners[1].dy)
            ..lineTo(topCorners[0].dx, topCorners[0].dy)
            ..close();

      canvas.drawPath(
        frontPath,
        Paint()..color = Colors.orange.shade900.withValues(alpha: 0.8),
      );

      // Container top
      final topPath =
          Path()
            ..moveTo(topCorners[0].dx, topCorners[0].dy)
            ..lineTo(topCorners[1].dx, topCorners[1].dy)
            ..lineTo(topCorners[2].dx, topCorners[2].dy)
            ..lineTo(topCorners[3].dx, topCorners[3].dy)
            ..close();

      canvas.drawPath(topPath, Paint()..color = Colors.orange.shade800);

      // Warning stripes
      canvas.drawLine(
        Offset((corners[0].dx + corners[1].dx) / 2, corners[0].dy + 5),
        Offset((topCorners[0].dx + topCorners[1].dx) / 2, topCorners[0].dy - 5),
        Paint()
          ..color = Colors.yellow.shade700
          ..strokeWidth = 3,
      );
    }
  }
}
