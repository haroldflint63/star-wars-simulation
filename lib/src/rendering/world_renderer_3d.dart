import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;
import '../agent.dart';
import '../world.dart';

/// 3D isometric world renderer similar to The Sims
class WorldRenderer3D extends StatefulWidget {
  const WorldRenderer3D({
    super.key,
    required this.locations,
    required this.agents,
    required this.events,
    this.onAgentSelected,
  });

  final List<Location> locations;
  final List<Agent> agents;
  final List<WorldEvent> events;
  final ValueChanged<Agent?>? onAgentSelected;

  @override
  State<WorldRenderer3D> createState() => _WorldRenderer3DState();
}

class _WorldRenderer3DState extends State<WorldRenderer3D>
    with TickerProviderStateMixin {
  final double _cameraRotation = -math.pi / 4; // Isometric angle
  double _cameraZoom = 1.0;
  Offset _cameraPan = Offset.zero;
  Agent? _selectedAgent;

  // Animation controllers for agents
  final Map<String, AnimationController> _agentAnimations = {};

  @override
  void initState() {
    super.initState();
    _initializeAgentAnimations();
  }

  void _initializeAgentAnimations() {
    for (final agent in widget.agents) {
      _agentAnimations[agent.profile.id] = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      )..repeat();
    }
  }

  @override
  void dispose() {
    for (final controller in _agentAnimations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {},
      onScaleUpdate: (details) {
        setState(() {
          _cameraZoom = (_cameraZoom * details.scale).clamp(0.5, 3.0);
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _cameraPan += details.delta;
        });
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _WorldPainter(
          locations: widget.locations,
          agents: widget.agents,
          events: widget.events,
          cameraRotation: _cameraRotation,
          cameraZoom: _cameraZoom,
          cameraPan: _cameraPan,
          selectedAgent: _selectedAgent,
          agentAnimations: _agentAnimations,
        ),
      ),
    );
  }

  // void _selectAgent(Agent? agent) {
  //   setState(() {
  //     _selectedAgent = agent;
  //   });
  //   widget.onAgentSelected?.call(agent);
  // }
}

class _WorldPainter extends CustomPainter {
  _WorldPainter({
    required this.locations,
    required this.agents,
    required this.events,
    required this.cameraRotation,
    required this.cameraZoom,
    required this.cameraPan,
    required this.selectedAgent,
    required this.agentAnimations,
  });

  final List<Location> locations;
  final List<Agent> agents;
  final List<WorldEvent> events;
  final double cameraRotation;
  final double cameraZoom;
  final Offset cameraPan;
  final Agent? selectedAgent;
  final Map<String, AnimationController> agentAnimations;

  // Location positions in world space
  static final Map<String, vm.Vector3> _locationPositions = {
    'town_square': vm.Vector3(0, 0, 0),
    'cafe': vm.Vector3(150, 0, 0),
    'office': vm.Vector3(-150, 0, 0),
    'park': vm.Vector3(0, 0, 150),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx + cameraPan.dx, center.dy + cameraPan.dy);
    canvas.scale(cameraZoom);

    // Draw grid floor (Sims-style)
    _drawGrid(canvas, size);

    // Draw locations (buildings)
    for (final location in locations) {
      _drawLocation(canvas, location);
    }

    // Draw agents
    for (final agent in agents) {
      _drawAgent(canvas, agent);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.green.shade100.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    // Draw isometric grid
    for (int x = -10; x <= 10; x++) {
      for (int z = -10; z <= 10; z++) {
        // final worldPos = vm.Vector3(x * 50.0, 0, z * 50.0);
        // final screenPos = _worldToScreen(worldPos);

        // Draw tile
        final path = Path();
        final tileSize = 50.0;

        final corners = [
          _worldToScreen(vm.Vector3(x * tileSize, 0, z * tileSize)),
          _worldToScreen(vm.Vector3((x + 1) * tileSize, 0, z * tileSize)),
          _worldToScreen(vm.Vector3((x + 1) * tileSize, 0, (z + 1) * tileSize)),
          _worldToScreen(vm.Vector3(x * tileSize, 0, (z + 1) * tileSize)),
        ];

        path.moveTo(corners[0].dx, corners[0].dy);
        for (int i = 1; i < corners.length; i++) {
          path.lineTo(corners[i].dx, corners[i].dy);
        }
        path.close();

        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawLocation(Canvas canvas, Location location) {
    final position = _locationPositions[location.id] ?? vm.Vector3.zero();
    final screenPos = _worldToScreen(position);

    // Draw building base (isometric cube)
    final buildingPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            colors: [
              _getLocationColor(location.id),
              _getLocationColor(location.id).withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(
            Rect.fromCenter(center: screenPos, width: 100, height: 120),
          );

    // Draw isometric building
    _drawIsometricCube(canvas, position, 80, 100, buildingPaint);

    // Draw location label
    final textPainter = TextPainter(
      text: TextSpan(
        text: location.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(screenPos.dx - textPainter.width / 2, screenPos.dy - 130),
    );
  }

  void _drawAgent(Canvas canvas, Agent agent) {
    // Get agent's current location
    final locationId = _getAgentLocation(agent);
    final basePosition = _locationPositions[locationId] ?? vm.Vector3.zero();

    // Add animation offset (bobbing effect)
    final animController = agentAnimations[agent.profile.id];
    final animValue = animController?.value ?? 0.0;
    final bobOffset = math.sin(animValue * 2 * math.pi) * 5;

    // Random offset within location for variety
    final agentOffset = _getAgentOffset(agent.profile.id);
    final position = vm.Vector3(
      basePosition.x + agentOffset.dx,
      bobOffset,
      basePosition.z + agentOffset.dy,
    );

    final screenPos = _worldToScreen(position);

    // Draw agent shadow
    final shadowPaint =
        Paint()
          ..color = Colors.black26
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(screenPos.dx, screenPos.dy + 30),
        width: 40,
        height: 15,
      ),
      shadowPaint,
    );

    // Draw agent body (animated)
    _drawAgentBody(canvas, screenPos, agent, animValue);

    // Draw selection indicator
    if (selectedAgent?.profile.id == agent.profile.id) {
      final selectionPaint =
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;

      canvas.drawCircle(
        Offset(screenPos.dx, screenPos.dy + 20),
        35,
        selectionPaint,
      );

      // Draw plumbob (green diamond above head like in Sims)
      _drawPlumbob(canvas, Offset(screenPos.dx, screenPos.dy - 60));
    }

    // Draw agent name
    final namePainter = TextPainter(
      text: TextSpan(
        text: agent.profile.displayName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    namePainter.paint(
      canvas,
      Offset(screenPos.dx - namePainter.width / 2, screenPos.dy + 35),
    );
  }

  void _drawAgentBody(
    Canvas canvas,
    Offset screenPos,
    Agent agent,
    double animValue,
  ) {
    // Head
    final headPaint =
        Paint()
          ..color = _getAgentColor(agent.profile.id)
          ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(screenPos.dx, screenPos.dy - 20), 15, headPaint);

    // Body
    final bodyPaint =
        Paint()
          ..color = _getAgentColor(agent.profile.id).withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screenPos.dx, screenPos.dy + 5),
        width: 25,
        height: 35,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Arms (animated swing)
    final armSwing = math.sin(animValue * 2 * math.pi) * 0.2;
    final armPaint =
        Paint()
          ..color = _getAgentColor(agent.profile.id).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;

    // Left arm
    canvas.drawLine(
      Offset(screenPos.dx - 12, screenPos.dy),
      Offset(screenPos.dx - 20, screenPos.dy + 15 + armSwing * 10),
      armPaint,
    );

    // Right arm
    canvas.drawLine(
      Offset(screenPos.dx + 12, screenPos.dy),
      Offset(screenPos.dx + 20, screenPos.dy + 15 - armSwing * 10),
      armPaint,
    );

    // Legs (animated walk)
    final legPaint =
        Paint()
          ..color = _getAgentColor(agent.profile.id).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;

    final legSwing = math.sin(animValue * 2 * math.pi) * 0.3;

    // Left leg
    canvas.drawLine(
      Offset(screenPos.dx - 5, screenPos.dy + 20),
      Offset(screenPos.dx - 8, screenPos.dy + 35 + legSwing * 5),
      legPaint,
    );

    // Right leg
    canvas.drawLine(
      Offset(screenPos.dx + 5, screenPos.dy + 20),
      Offset(screenPos.dx + 8, screenPos.dy + 35 - legSwing * 5),
      legPaint,
    );
  }

  void _drawPlumbob(Canvas canvas, Offset position) {
    final path = Path();
    path.moveTo(position.dx, position.dy - 15); // Top
    path.lineTo(position.dx + 10, position.dy); // Right
    path.lineTo(position.dx, position.dy + 15); // Bottom
    path.lineTo(position.dx - 10, position.dy); // Left
    path.close();

    final gradient =
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.lightGreenAccent, Colors.green.shade700],
          ).createShader(Rect.fromCircle(center: position, radius: 15));

    canvas.drawPath(path, gradient);

    // Glow effect
    final glowPaint =
        Paint()
          ..color = Colors.green.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);
  }

  void _drawIsometricCube(
    Canvas canvas,
    vm.Vector3 position,
    double width,
    double height,
    Paint paint,
  ) {
    // final base = _worldToScreen(position);

    // Define cube corners in isometric view
    final corners = [
      _worldToScreen(
        vm.Vector3(position.x - width / 2, position.y, position.z - width / 2),
      ),
      _worldToScreen(
        vm.Vector3(position.x + width / 2, position.y, position.z - width / 2),
      ),
      _worldToScreen(
        vm.Vector3(position.x + width / 2, position.y, position.z + width / 2),
      ),
      _worldToScreen(
        vm.Vector3(position.x - width / 2, position.y, position.z + width / 2),
      ),
    ];

    final topCorners = [
      _worldToScreen(
        vm.Vector3(
          position.x - width / 2,
          position.y + height,
          position.z - width / 2,
        ),
      ),
      _worldToScreen(
        vm.Vector3(
          position.x + width / 2,
          position.y + height,
          position.z - width / 2,
        ),
      ),
      _worldToScreen(
        vm.Vector3(
          position.x + width / 2,
          position.y + height,
          position.z + width / 2,
        ),
      ),
      _worldToScreen(
        vm.Vector3(
          position.x - width / 2,
          position.y + height,
          position.z + width / 2,
        ),
      ),
    ];

    // Draw front face
    final frontPath =
        Path()
          ..moveTo(corners[0].dx, corners[0].dy)
          ..lineTo(corners[1].dx, corners[1].dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..lineTo(topCorners[0].dx, topCorners[0].dy)
          ..close();
    canvas.drawPath(frontPath, paint);

    // Draw right face (darker)
    final rightPaint = Paint()..color = paint.color.withValues(alpha: 0.6);
    final rightPath =
        Path()
          ..moveTo(corners[1].dx, corners[1].dy)
          ..lineTo(corners[2].dx, corners[2].dy)
          ..lineTo(topCorners[2].dx, topCorners[2].dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..close();
    canvas.drawPath(rightPath, rightPaint);

    // Draw top face (lighter)
    final topPaint = Paint()..color = paint.color.withValues(alpha: 0.9);
    final topPath =
        Path()
          ..moveTo(topCorners[0].dx, topCorners[0].dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..lineTo(topCorners[2].dx, topCorners[2].dy)
          ..lineTo(topCorners[3].dx, topCorners[3].dy)
          ..close();
    canvas.drawPath(topPath, topPaint);

    // Draw outlines
    final outlinePaint =
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    canvas.drawPath(frontPath, outlinePaint);
    canvas.drawPath(rightPath, outlinePaint);
    canvas.drawPath(topPath, outlinePaint);
  }

  Offset _worldToScreen(vm.Vector3 worldPos) {
    // Isometric projection
    final isoX = (worldPos.x - worldPos.z) * math.cos(math.pi / 6);
    final isoY = (worldPos.x + worldPos.z) * math.sin(math.pi / 6) - worldPos.y;

    return Offset(isoX, isoY);
  }

  String _getAgentLocation(Agent agent) {
    // Find the most recent event for this agent
    for (final event in events.reversed) {
      if (event.actorId == agent.profile.id) {
        return event.locationId;
      }
    }
    return agent.profile.homeLocationId;
  }

  Offset _getAgentOffset(String agentId) {
    // Consistent but varied positioning for each agent
    final hash = agentId.hashCode;
    final x = ((hash % 40) - 20).toDouble();
    final z = (((hash ~/ 40) % 40) - 20).toDouble();
    return Offset(x, z);
  }

  Color _getLocationColor(String locationId) {
    switch (locationId) {
      case 'town_square':
        return Colors.blue.shade400;
      case 'cafe':
        return Colors.orange.shade400;
      case 'office':
        return Colors.grey.shade600;
      case 'park':
        return Colors.green.shade600;
      default:
        return Colors.purple.shade400;
    }
  }

  Color _getAgentColor(String agentId) {
    switch (agentId) {
      case 'ava':
        return Colors.pink.shade300;
      case 'noah':
        return Colors.blue.shade300;
      case 'liam':
        return Colors.amber.shade300;
      default:
        return Colors.teal.shade300;
    }
  }

  @override
  bool shouldRepaint(_WorldPainter oldDelegate) {
    return true; // Always repaint for animations
  }
}
