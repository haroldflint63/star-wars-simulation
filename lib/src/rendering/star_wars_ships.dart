import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;

/// Star Wars spacecraft renderer and animator
class StarWarsShips {
  static final Map<String, ShipState> _ships = {};
  static int _lastUpdate = 0;

  /// Initialize ships for each location
  static void initializeShips() {
    _ships['millennium_falcon'] = ShipState(
      type: ShipType.millenniumFalcon,
      position: vm.Vector3(-300, 150, -200),
      velocity: vm.Vector3(2, 0, 1),
      destination: vm.Vector3(200, 180, 150),
    );

    _ships['xwing_1'] = ShipState(
      type: ShipType.xWing,
      position: vm.Vector3(300, 200, 200),
      velocity: vm.Vector3(-1.5, 0, -1.5),
      destination: vm.Vector3(-200, 180, -150),
    );

    _ships['xwing_2'] = ShipState(
      type: ShipType.xWing,
      position: vm.Vector3(250, 190, 180),
      velocity: vm.Vector3(-1.5, 0, -1.5),
      destination: vm.Vector3(-220, 170, -170),
    );

    _ships['xwing_3'] = ShipState(
      type: ShipType.xWing,
      position: vm.Vector3(280, 210, 160),
      velocity: vm.Vector3(-1.5, 0, -1.5),
      destination: vm.Vector3(-250, 185, -130),
    );

    _ships['tie_fighter_1'] = ShipState(
      type: ShipType.tieFighter,
      position: vm.Vector3(-250, 170, 250),
      velocity: vm.Vector3(2, 0, -2),
      destination: vm.Vector3(200, 190, -200),
    );

    _ships['tie_fighter_2'] = ShipState(
      type: ShipType.tieFighter,
      position: vm.Vector3(-230, 160, 230),
      velocity: vm.Vector3(2, 0, -2),
      destination: vm.Vector3(220, 180, -220),
    );

    _ships['tie_fighter_3'] = ShipState(
      type: ShipType.tieFighter,
      position: vm.Vector3(-270, 175, 270),
      velocity: vm.Vector3(2, 0, -2),
      destination: vm.Vector3(240, 195, -240),
    );

    _ships['slave_1'] = ShipState(
      type: ShipType.slave1,
      position: vm.Vector3(0, 250, 0),
      velocity: vm.Vector3(0.5, -0.2, 0.5),
      destination: vm.Vector3(100, 200, 100),
    );

    _ships['star_destroyer'] = ShipState(
      type: ShipType.starDestroyer,
      position: vm.Vector3(400, 400, -300),
      velocity: vm.Vector3(-0.3, 0, 0.2),
      destination: vm.Vector3(-400, 400, 300),
      speed: 0.5,
    );

    _ships['ywing_1'] = ShipState(
      type: ShipType.yWing,
      position: vm.Vector3(-350, 160, -100),
      velocity: vm.Vector3(1.8, 0, 1.2),
      destination: vm.Vector3(300, 175, 200),
    );

    _ships['ywing_2'] = ShipState(
      type: ShipType.yWing,
      position: vm.Vector3(-370, 155, -120),
      velocity: vm.Vector3(1.8, 0, 1.2),
      destination: vm.Vector3(280, 170, 180),
    );

    _ships['awing_1'] = ShipState(
      type: ShipType.aWing,
      position: vm.Vector3(350, 180, -250),
      velocity: vm.Vector3(-2.5, 0, 2),
      destination: vm.Vector3(-300, 195, 200),
      speed: 3.0,
    );

    _ships['bwing'] = ShipState(
      type: ShipType.bWing,
      position: vm.Vector3(200, 165, 300),
      velocity: vm.Vector3(-1.2, 0, -1.5),
      destination: vm.Vector3(-250, 180, -250),
    );

    _ships['imperial_shuttle'] = ShipState(
      type: ShipType.imperialShuttle,
      position: vm.Vector3(-100, 220, 200),
      velocity: vm.Vector3(1, 0, -1),
      destination: vm.Vector3(150, 210, -150),
    );
  }

  /// Update ship positions
  static void updateShips(int tick) {
    if (_ships.isEmpty) initializeShips();

    if (tick == _lastUpdate) return;
    _lastUpdate = tick;

    for (final ship in _ships.values) {
      final toDestination = ship.destination - ship.position;
      final distance = toDestination.length;

      if (distance < 10) {
        // Reached destination, pick new random destination
        ship.destination = vm.Vector3(
          (math.Random().nextDouble() - 0.5) * 500,
          150 + math.Random().nextDouble() * 100,
          (math.Random().nextDouble() - 0.5) * 500,
        );
      } else {
        // Move towards destination
        final direction = toDestination.normalized();
        ship.velocity = direction * ship.speed;
        ship.position += ship.velocity;

        // Update rotation to face movement direction
        ship.rotation = math.atan2(ship.velocity.z, ship.velocity.x);
      }

      // Bob up and down slightly
      ship.bobPhase += 0.05;
      ship.bobOffset = math.sin(ship.bobPhase) * 3;
    }
  }

  /// Draw all ships
  static void drawShips(Canvas canvas, Function(vm.Vector3) worldToScreen) {
    if (_ships.isEmpty) initializeShips();

    for (final ship in _ships.values) {
      _drawShip(canvas, ship, worldToScreen);
    }
  }

  /// Draw individual ship
  static void _drawShip(
    Canvas canvas,
    ShipState ship,
    Function(vm.Vector3) w2s,
  ) {
    final pos = vm.Vector3(
      ship.position.x,
      ship.position.y + ship.bobOffset,
      ship.position.z,
    );

    switch (ship.type) {
      case ShipType.xWing:
        _drawXWing(canvas, pos, ship.rotation, w2s);
        break;
      case ShipType.tieFighter:
        _drawTIEFighter(canvas, pos, ship.rotation, w2s);
        break;
      case ShipType.millenniumFalcon:
        _drawMillenniumFalcon(canvas, pos, ship.rotation, w2s);
        break;
      case ShipType.slave1:
        _drawSlave1(canvas, pos, ship.rotation, w2s);
        break;
      case ShipType.starDestroyer:
        _drawStarDestroyer(canvas, pos, ship.rotation, w2s);
        break;
      case ShipType.yWing:
        _drawYWing(canvas, pos, ship.rotation, w2s);
        break;
      case ShipType.aWing:
        _drawAWing(canvas, pos, ship.rotation, w2s);
        break;
      case ShipType.bWing:
        _drawBWing(canvas, pos, ship.rotation, w2s);
        break;
      case ShipType.imperialShuttle:
        _drawImperialShuttle(canvas, pos, ship.rotation, w2s);
        break;
    }
  }

  /// Draw X-Wing fighter
  static void _drawXWing(
    Canvas canvas,
    vm.Vector3 pos,
    double rotation,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Main body
    final bodyPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.grey.shade300, Colors.grey.shade600],
          ).createShader(const Rect.fromLTWH(-15, -4, 30, 8));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -4, 30, 8),
        const Radius.circular(2),
      ),
      bodyPaint,
    );

    // X-shaped wings
    final wingPaint = Paint()..color = Colors.grey.shade400;

    // Top wings
    canvas.drawRect(const Rect.fromLTWH(-2, -18, 4, 14), wingPaint);
    canvas.drawRect(const Rect.fromLTWH(-2, 8, 4, 14), wingPaint);

    // Side wings
    canvas.drawRect(const Rect.fromLTWH(-20, -2, 8, 4), wingPaint);
    canvas.drawRect(const Rect.fromLTWH(16, -2, 8, 4), wingPaint);

    // Engine glow
    final enginePaint =
        Paint()
          ..color = Colors.cyan.shade400
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(-18, -12), 3, enginePaint);
    canvas.drawCircle(const Offset(-18, 12), 3, enginePaint);
    canvas.drawCircle(const Offset(-18, -6), 3, enginePaint);
    canvas.drawCircle(const Offset(-18, 6), 3, enginePaint);

    // Cockpit
    canvas.drawCircle(
      const Offset(5, 0),
      4,
      Paint()..color = Colors.lightBlue.shade200.withValues(alpha: 0.6),
    );

    // Red stripes
    final redPaint = Paint()..color = Colors.red.shade700;
    canvas.drawRect(const Rect.fromLTWH(0, -18, 2, 8), redPaint);
    canvas.drawRect(const Rect.fromLTWH(0, 12, 2, 8), redPaint);

    canvas.restore();
  }

  /// Draw TIE Fighter
  static void _drawTIEFighter(
    Canvas canvas,
    vm.Vector3 pos,
    double rotation,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Hexagonal wings
    final wingPaint = Paint()..color = Colors.grey.shade700;

    // Left wing
    final leftWing =
        Path()
          ..moveTo(-20, -15)
          ..lineTo(-20, 15)
          ..lineTo(-8, 18)
          ..lineTo(-8, -18)
          ..close();
    canvas.drawPath(leftWing, wingPaint);

    // Right wing
    final rightWing =
        Path()
          ..moveTo(20, -15)
          ..lineTo(20, 15)
          ..lineTo(8, 18)
          ..lineTo(8, -18)
          ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Wing panels
    final panelPaint =
        Paint()
          ..color = Colors.grey.shade600
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;

    for (int i = -15; i < 15; i += 5) {
      canvas.drawLine(
        Offset(-20, i.toDouble()),
        Offset(-8, i.toDouble()),
        panelPaint,
      );
      canvas.drawLine(
        Offset(20, i.toDouble()),
        Offset(8, i.toDouble()),
        panelPaint,
      );
    }

    // Central pod (cockpit)
    canvas.drawCircle(
      Offset.zero,
      8,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.grey.shade500, Colors.grey.shade800],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 8)),
    );

    // Viewport
    canvas.drawCircle(const Offset(2, 0), 3, Paint()..color = Colors.black87);

    // Engine glow (green for TIE fighters)
    final enginePaint =
        Paint()
          ..color = Colors.green.shade400
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(const Offset(-6, 0), 4, enginePaint);

    canvas.restore();
  }

  /// Draw Millennium Falcon
  static void _drawMillenniumFalcon(
    Canvas canvas,
    vm.Vector3 pos,
    double rotation,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Oval main hull
    final hullPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.grey.shade400, Colors.grey.shade700],
          ).createShader(const Rect.fromLTWH(-20, -15, 40, 30));

    canvas.drawOval(const Rect.fromLTWH(-20, -15, 40, 30), hullPaint);

    // Cockpit offset to side
    canvas.drawCircle(
      const Offset(12, -8),
      6,
      Paint()..color = Colors.lightBlue.shade100.withValues(alpha: 0.7),
    );

    // Cockpit frame
    canvas.drawCircle(
      const Offset(12, -8),
      6,
      Paint()
        ..color = Colors.grey.shade600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Sensor dish
    canvas.drawCircle(
      const Offset(-5, 5),
      4,
      Paint()..color = Colors.grey.shade500,
    );
    canvas.drawCircle(
      const Offset(-5, 5),
      3,
      Paint()..color = Colors.grey.shade700,
    );

    // Hull details
    final detailPaint =
        Paint()
          ..color = Colors.grey.shade800
          ..strokeWidth = 1;

    canvas.drawLine(const Offset(-15, -10), const Offset(15, -10), detailPaint);
    canvas.drawLine(const Offset(-15, 0), const Offset(15, 0), detailPaint);
    canvas.drawLine(const Offset(-15, 10), const Offset(15, 10), detailPaint);

    // Engine glow (blue)
    final enginePaint =
        Paint()
          ..color = Colors.blue.shade300
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(-18, -5), 4, enginePaint);
    canvas.drawCircle(const Offset(-18, 5), 4, enginePaint);

    canvas.restore();
  }

  /// Draw Slave I (Boba Fett's ship)
  static void _drawSlave1(
    Canvas canvas,
    vm.Vector3 pos,
    double rotation,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Vertical orientation ship
    final bodyPaint = Paint()..color = Colors.grey.shade600;

    // Main body (vertical)
    canvas.drawRect(const Rect.fromLTWH(-6, -20, 12, 40), bodyPaint);

    // Cockpit (front)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -22, 10, 8),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.blueGrey.shade700,
    );

    // Wings
    final wingPaint = Paint()..color = Colors.grey.shade500;
    canvas.drawRect(const Rect.fromLTWH(-18, -5, 12, 3), wingPaint);
    canvas.drawRect(const Rect.fromLTWH(6, -5, 12, 3), wingPaint);

    // Engine (bottom)
    final enginePaint =
        Paint()
          ..color = Colors.orange.shade400
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(const Offset(0, 22), 4, enginePaint);

    // Green accents (Mandalorian colors)
    final accentPaint = Paint()..color = Colors.green.shade700;
    canvas.drawRect(const Rect.fromLTWH(-4, -15, 8, 2), accentPaint);
    canvas.drawRect(const Rect.fromLTWH(-4, 0, 8, 2), accentPaint);

    canvas.restore();
  }

  /// Draw Star Destroyer (distant massive ship)
  static void _drawStarDestroyer(
    Canvas canvas,
    vm.Vector3 pos,
    double rotation,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(1.5); // Larger ship

    // Triangular hull
    final hullPath =
        Path()
          ..moveTo(40, 0)
          ..lineTo(-30, -25)
          ..lineTo(-30, 25)
          ..close();

    canvas.drawPath(
      hullPath,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.grey.shade500, Colors.grey.shade800],
        ).createShader(const Rect.fromLTWH(-30, -25, 70, 50)),
    );

    // Bridge tower
    canvas.drawRect(
      const Rect.fromLTWH(-10, -8, 15, 16),
      Paint()..color = Colors.grey.shade600,
    );

    // Engine glow
    final enginePaint =
        Paint()
          ..color = Colors.blue.shade200
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(-28, -15), 4, enginePaint);
    canvas.drawCircle(const Offset(-28, 0), 4, enginePaint);
    canvas.drawCircle(const Offset(-28, 15), 4, enginePaint);

    canvas.restore();
  }

  /// Draw Y-Wing bomber
  static void _drawYWing(
    Canvas canvas,
    vm.Vector3 pos,
    double rotation,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Main body
    canvas.drawRect(
      const Rect.fromLTWH(-12, -3, 24, 6),
      Paint()..color = Colors.grey.shade500,
    );

    // Cockpit
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, -4, 10, 8),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.lightBlue.shade100.withValues(alpha: 0.7),
    );

    // Engine nacelles
    canvas.drawRect(
      const Rect.fromLTWH(-20, -14, 6, 10),
      Paint()..color = Colors.grey.shade600,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-20, 4, 6, 10),
      Paint()..color = Colors.grey.shade600,
    );

    // Engine glow (yellow)
    final enginePaint =
        Paint()
          ..color = Colors.yellow.shade600
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(const Offset(-22, -9), 4, enginePaint);
    canvas.drawCircle(const Offset(-22, 9), 4, enginePaint);

    // Yellow rebel markings
    canvas.drawRect(
      const Rect.fromLTWH(0, -2, 4, 4),
      Paint()..color = Colors.yellow.shade700,
    );

    canvas.restore();
  }

  /// Draw A-Wing interceptor
  static void _drawAWing(
    Canvas canvas,
    vm.Vector3 pos,
    double rotation,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Sleek triangular body
    final bodyPath =
        Path()
          ..moveTo(15, 0)
          ..lineTo(-10, -8)
          ..lineTo(-10, 8)
          ..close();

    canvas.drawPath(bodyPath, Paint()..color = Colors.red.shade900);

    // Canopy
    canvas.drawCircle(
      const Offset(8, 0),
      3,
      Paint()..color = Colors.lightBlue.shade200.withValues(alpha: 0.6),
    );

    // Twin engines
    final enginePaint =
        Paint()
          ..color = Colors.red.shade400
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(-12, -6), 3, enginePaint);
    canvas.drawCircle(const Offset(-12, 6), 3, enginePaint);

    canvas.restore();
  }

  /// Draw B-Wing heavy assault fighter
  static void _drawBWing(
    Canvas canvas,
    vm.Vector3 pos,
    double rotation,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Main cross-shaped body
    canvas.drawRect(
      const Rect.fromLTWH(-2, -20, 4, 40),
      Paint()..color = Colors.grey.shade600,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-18, -2, 36, 4),
      Paint()..color = Colors.grey.shade600,
    );

    // Cockpit pod
    canvas.drawCircle(
      const Offset(0, 0),
      5,
      Paint()..color = Colors.grey.shade500,
    );
    canvas.drawCircle(
      const Offset(2, 0),
      3,
      Paint()..color = Colors.lightBlue.shade200.withValues(alpha: 0.6),
    );

    // Engine glow
    final enginePaint =
        Paint()
          ..color = Colors.blue.shade400
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(-18, 0), 3, enginePaint);

    canvas.restore();
  }

  /// Draw Imperial Shuttle
  static void _drawImperialShuttle(
    Canvas canvas,
    vm.Vector3 pos,
    double rotation,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Central body
    canvas.drawRect(
      const Rect.fromLTWH(-8, -15, 16, 30),
      Paint()..color = Colors.grey.shade700,
    );

    // Wings (folded up)
    final wingPath =
        Path()
          ..moveTo(-8, -15)
          ..lineTo(-18, -25)
          ..lineTo(-18, -12)
          ..close();
    canvas.drawPath(wingPath, Paint()..color = Colors.grey.shade600);

    final wingPath2 =
        Path()
          ..moveTo(8, -15)
          ..lineTo(18, -25)
          ..lineTo(18, -12)
          ..close();
    canvas.drawPath(wingPath2, Paint()..color = Colors.grey.shade600);

    // Cockpit
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-6, 10, 12, 8),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.blueGrey.shade800,
    );

    // Engine glow
    final enginePaint =
        Paint()
          ..color = Colors.blue.shade300
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(const Offset(-4, -18), 3, enginePaint);
    canvas.drawCircle(const Offset(4, -18), 3, enginePaint);

    canvas.restore();
  }
}

enum ShipType {
  xWing,
  tieFighter,
  millenniumFalcon,
  slave1,
  starDestroyer,
  yWing,
  aWing,
  bWing,
  imperialShuttle,
}

class ShipState {
  ShipType type;
  vm.Vector3 position;
  vm.Vector3 velocity;
  vm.Vector3 destination;
  double rotation;
  double bobPhase;
  double bobOffset;
  double speed;

  ShipState({
    required this.type,
    required this.position,
    required this.velocity,
    required this.destination,
    this.rotation = 0,
    this.bobPhase = 0,
    this.bobOffset = 0,
    this.speed = 2.0,
  });
}
