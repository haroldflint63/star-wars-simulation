import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;
import 'dart:async';
import '../agent.dart';
import '../world.dart';
import '../daily_tasks.dart';
import '../star_wars_api.dart'; // Added API import
import 'avatar_animator.dart';
import 'avatar_movement.dart';
import 'advanced_buildings.dart';
import 'star_wars_ships.dart';
import 'star_wars_avatars.dart';
import 'city_environment.dart';
import 'walking_animation.dart';
import '../audio/star_wars_sounds.dart';

/// Enhanced 3D isometric world renderer with click detection
class WorldRenderer3DInteractive extends StatefulWidget {
  const WorldRenderer3DInteractive({
    super.key,
    required this.locations,
    required this.agents,
    required this.events,
    this.onAgentSelected,
    this.cinematicMode = false,
  });

  final List<Location> locations;
  final List<Agent> agents;
  final List<WorldEvent> events;
  final ValueChanged<Agent?>? onAgentSelected;
  final bool cinematicMode;

  @override
  State<WorldRenderer3DInteractive> createState() =>
      _WorldRenderer3DInteractiveState();
}

class _WorldRenderer3DInteractiveState extends State<WorldRenderer3DInteractive>
    with TickerProviderStateMixin {
  double _cameraRotation = -math.pi / 6; // Better viewing angle
  double _cameraZoom = 1.15; // Slightly zoomed in for professional framing
  Offset _cameraPan = const Offset(0, -50); // Center view slightly up
  Agent? _selectedAgent;
  Offset? _lastPanPosition;

  // Cinematic camera movement
  late AnimationController _cinematicCameraController;
  Timer? _cameraMovementTimer;

  // Dynamic layout from API
  Map<String, vm.Vector3> _locationPositions = {};
  final Map<String, Map<String, dynamic>> _planetMetadata = {};
  final Map<String, Map<String, dynamic>> _characterAnimData = {};

  final Map<String, AnimationController> _agentAnimations = {};
  final Map<String, AnimationController> _agentHoverAnimations = {};

  @override
  void initState() {
    super.initState();
    _initializeLayout();
    _initializeCharacterAnimations();
    _initializeAgentAnimations();
    _startMovementUpdates();
  }

  Future<void> _initializeLayout() async {
    // Load Galactic Layout
    final layoutData = StarWarsAPI.getGalacticLayout();

    // Convert to Vector3 Map
    final positions = <String, vm.Vector3>{};
    layoutData.forEach((key, value) {
      final data = value as Map<String, dynamic>;
      positions[key] = vm.Vector3(data['x'], data['y'], data['z']);
    });

    setState(() {
      _locationPositions = positions;
    });

    // Optionally fetch extra details (async) simulating API usage
    // In a real app, we would await http calls here
    for (final locId in positions.keys) {
      final data = layoutData[locId] as Map<String, dynamic>;
      final planetId = data['planet_id'] as int;
      if (planetId > 0) {
        // Fetch in background
        StarWarsAPI.getPlanet(planetId).then((planetData) {
          if (mounted) {
            setState(() {
              _planetMetadata[locId] = planetData;
            });
          }
        });
      }
    }
  }

  Future<void> _initializeCharacterAnimations() async {
    // Load animation data for each agent from SWAPI
    for (final agent in widget.agents) {
      StarWarsAPI.getCharacterAnimationData(agent.profile.id).then((animData) {
        if (mounted) {
          setState(() {
            _characterAnimData[agent.profile.id] = animData;
          });
        }
      });
    }
  }

  void _startMovementUpdates() {
    // Update movement progress every frame
    _agentAnimations.values.first.addListener(() {
      for (final agent in widget.agents) {
        _WorldPainterInteractive._avatarMovement.updateProgress(
          agent.profile.id,
          0.016,
        );
      }
    });
  }

  void _initializeAgentAnimations() {
    for (final agent in widget.agents) {
      _agentAnimations[agent.profile.id] = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      )..repeat();

      _agentHoverAnimations[agent.profile.id] = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
    }

    // Cinematic camera controller for movie-like movements
    _cinematicCameraController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Automatic camera movements for dynamic movie set feel
    _startCinematicCameraMovements();
  }

  void _startCinematicCameraMovements() {
    _cameraMovementTimer?.cancel();
    _cameraMovementTimer = Timer.periodic(const Duration(milliseconds: 50), (
      _,
    ) {
      if (mounted && widget.cinematicMode) {
        final t = _cinematicCameraController.value;

        // Smooth camera orbit
        setState(() {
          _cameraRotation = -math.pi / 6 + math.sin(t * math.pi * 2) * 0.15;
          _cameraZoom = 1.15 + math.sin(t * math.pi * 4) * 0.05;

          // Gentle camera pan following action
          _cameraPan = Offset(
            math.cos(t * math.pi * 2) * 20,
            -50 + math.sin(t * math.pi * 2) * 15,
          );
        });
      }
    });
  }

  @override
  void didUpdateWidget(WorldRenderer3DInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset camera when cinematic mode is disabled
    if (!widget.cinematicMode && oldWidget.cinematicMode) {
      setState(() {
        _cameraRotation = -math.pi / 6;
        _cameraZoom = 1.15;
        _cameraPan = const Offset(0, -50);
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _agentAnimations.values) {
      controller.dispose();
    }
    for (final controller in _agentHoverAnimations.values) {
      controller.dispose();
    }
    _cinematicCameraController.dispose();
    _cameraMovementTimer?.cancel();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);

    // Check if tap hit an agent
    Agent? tappedAgent = _findAgentAtPosition(localPosition);

    setState(() {
      _selectedAgent = tappedAgent;
    });

    widget.onAgentSelected?.call(tappedAgent);

    // Animate selection
    if (tappedAgent != null) {
      _agentHoverAnimations[tappedAgent.profile.id]?.forward();
    }
  }

  Agent? _findAgentAtPosition(Offset position) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    for (final agent in widget.agents) {
      final locationId = _getAgentLocation(agent);
      final basePosition = _locationPositions[locationId] ?? vm.Vector3.zero();
      final agentOffset = _getAgentOffset(agent.profile.id);
      final worldPos = vm.Vector3(
        basePosition.x + agentOffset.dx,
        0,
        basePosition.z + agentOffset.dy,
      );

      final screenPos = _worldToScreen(worldPos, center);
      final transformedPos = Offset(
        screenPos.dx + _cameraPan.dx,
        screenPos.dy + _cameraPan.dy,
      );

      final distance = (transformedPos - position).distance;
      if (distance < 40 * _cameraZoom) {
        return agent;
      }
    }

    return null;
  }

  Offset _worldToScreen(vm.Vector3 worldPos, Offset center) {
    final isoX = (worldPos.x - worldPos.z) * math.cos(math.pi / 6);
    final isoY = (worldPos.x + worldPos.z) * math.sin(math.pi / 6) - worldPos.y;

    return Offset(
      center.dx + isoX * _cameraZoom,
      center.dy + isoY * _cameraZoom,
    );
  }

  String _getAgentLocation(Agent agent) {
    for (final event in widget.events.reversed) {
      if (event.actorId == agent.profile.id) {
        return event.locationId;
      }
    }
    return agent.profile.homeLocationId;
  }

  Offset _getAgentOffset(String agentId) {
    final hash = agentId.hashCode;
    final x = ((hash % 40) - 20).toDouble();
    final z = (((hash ~/ 40) % 40) - 20).toDouble();
    return Offset(x, z);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _lastPanPosition = details.focalPoint;
      },
      onScaleUpdate: (details) {
        if (details.scale != 1.0) {
          setState(() {
            _cameraZoom = (_cameraZoom * details.scale).clamp(0.5, 3.0);
          });
        } else if (_lastPanPosition != null) {
          setState(() {
            _cameraPan += details.focalPoint - _lastPanPosition!;
            _lastPanPosition = details.focalPoint;
          });
        }
      },
      onScaleEnd: (details) {
        _lastPanPosition = null;
      },
      onTapDown: _handleTapDown,
      child: CustomPaint(
        size: Size.infinite,
        painter: _WorldPainterInteractive(
          locations: widget.locations,
          locationPositions: _locationPositions,
          planetMetadata: _planetMetadata,
          characterAnimData: _characterAnimData,
          agents: widget.agents,
          events: widget.events,
          cameraRotation: _cameraRotation,
          cameraZoom: _cameraZoom,
          cameraPan: _cameraPan,
          selectedAgent: _selectedAgent,
          agentAnimations: _agentAnimations,
          agentHoverAnimations: _agentHoverAnimations,
        ),
      ),
    );
  }
}

class _WorldPainterInteractive extends CustomPainter {
  _WorldPainterInteractive({
    required this.locations,
    required this.locationPositions,
    required this.planetMetadata,
    required this.characterAnimData,
    required this.agents,
    required this.events,
    required this.cameraRotation,
    required this.cameraZoom,
    required this.cameraPan,
    required this.selectedAgent,
    required this.agentAnimations,
    required this.agentHoverAnimations,
  }) : super(
         repaint: Listenable.merge([
           ...agentAnimations.values,
           ...agentHoverAnimations.values,
         ]),
       );

  final List<Location> locations;
  final Map<String, vm.Vector3> locationPositions;
  final Map<String, Map<String, dynamic>> planetMetadata;
  final Map<String, Map<String, dynamic>> characterAnimData;
  final List<Agent> agents;
  final List<WorldEvent> events;
  final double cameraRotation;
  final double cameraZoom;
  final Offset cameraPan;
  final Agent? selectedAgent;
  final Map<String, AnimationController> agentAnimations;
  final Map<String, AnimationController> agentHoverAnimations;

  // Movement controller (static to persist between repaints)
  static final AvatarMovement _avatarMovement = AvatarMovement();
  static final WalkingAnimation _walkingAnimation = WalkingAnimation();
  static int _lastTick = 0;

  // Sound effect tracking
  static final Map<String, int> _lastFootstepFrame = {};
  static final Map<String, String> _lastLocationSound = {};
  static final Map<String, int> _lastActionSound = {};

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Save original canvas state
    canvas.save();

    canvas.translate(center.dx + cameraPan.dx, center.dy + cameraPan.dy);
    canvas.scale(cameraZoom);

    _drawGrid(canvas, size);

    // Draw terrain and streets
    CityEnvironment.drawTerrain(canvas, _worldToScreen);
    CityEnvironment.drawStreets(canvas, locationPositions, _worldToScreen);

    // Update and draw ships
    final currentTick = events.isNotEmpty ? events.last.tick : 0;
    StarWarsShips.updateShips(currentTick);

    for (final location in locations) {
      _drawLocation(canvas, location);
    }

    // Draw environmental decorations
    CityEnvironment.drawDecorations(canvas, locationPositions, _worldToScreen);
    CityEnvironment.drawLighting(canvas, locationPositions, _worldToScreen);

    // Draw ships in the sky
    StarWarsShips.drawShips(canvas, _worldToScreen);

    for (final agent in agents) {
      _drawAgent(canvas, agent);
    }

    // Draw atmospheric particles on top
    CityEnvironment.drawAtmosphere(canvas, currentTick, size);

    // Restore canvas before applying screen-space effects
    canvas.restore();

    // Apply professional post-processing effects (screen-space)
    _applyAtmosphericFog(canvas, size);
    _applyDepthOfField(canvas, size);
    _applyVignette(canvas, size);
    _applyColorGrading(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    // Professional Cinematic Star Wars Space Background

    // Base deep space gradient with enhanced color grading
    final bgRect = Rect.fromCenter(
      center: Offset.zero,
      width: 100000,
      height: 100000,
    );

    final bgGradient =
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.2, -0.3),
            radius: 2.8,
            colors: [
              const Color(0xFF0D1B2E), // Rich midnight blue
              const Color(0xFF050A15), // Deep space blue-black
              const Color(0xFF000205), // Near void
              const Color(0xFF000000), // Pure black
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ).createShader(bgRect);

    canvas.drawRect(bgRect, bgGradient);

    // Enhanced nebula clouds with better composition
    final random = math.Random(54321);
    for (int i = 0; i < 12; i++) {
      final x = (random.nextDouble() * 10000) - 5000;
      final y = (random.nextDouble() * 10000) - 5000;
      final size = random.nextDouble() * 1500 + 800;

      final nebulaColors = [
        const Color(0xFF4B0082).withValues(alpha: 0.12), // Indigo
        const Color(0xFF8B00FF).withValues(alpha: 0.10), // Purple
        const Color(0xFFFF1493).withValues(alpha: 0.08), // Deep pink
        const Color(0xFF00CED1).withValues(alpha: 0.09), // Cyan
        const Color(0xFF4169E1).withValues(alpha: 0.07), // Royal blue
        const Color(0xFFDA70D6).withValues(alpha: 0.06), // Orchid
      ];

      final nebulaPaint =
          Paint()
            ..shader = RadialGradient(
              colors: [
                nebulaColors[i % nebulaColors.length],
                nebulaColors[i % nebulaColors.length].withValues(alpha: 0.02),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ).createShader(Rect.fromCircle(center: Offset(x, y), radius: size))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.4);

      canvas.drawCircle(Offset(x, y), size, nebulaPaint);
    }

    // Layered starfield for depth

    // Distant stars (smallest, dimmest)
    final distantRandom = math.Random(11111);
    for (int i = 0; i < 1200; i++) {
      final x = (distantRandom.nextDouble() * 12000) - 6000;
      final y = (distantRandom.nextDouble() * 12000) - 6000;
      final starSize = distantRandom.nextDouble() * 0.8 + 0.2;
      final opacity = distantRandom.nextDouble() * 0.3 + 0.1;

      canvas.drawCircle(
        Offset(x, y),
        starSize,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }

    // Mid-distance stars (medium, twinkling)
    final midRandom = math.Random(22222);
    for (int i = 0; i < 600; i++) {
      final x = (midRandom.nextDouble() * 10000) - 5000;
      final y = (midRandom.nextDouble() * 10000) - 5000;
      final starSize = midRandom.nextDouble() * 1.2 + 0.5;

      // Twinkle effect
      final twinkle = 0.4 + 0.6 * math.sin((_lastTick * 0.03) + i * 0.2).abs();

      final starPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: twinkle * 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);

      canvas.drawCircle(Offset(x, y), starSize, starPaint);
    }

    // Close bright stars (largest, brightest with glow)
    final closeRandom = math.Random(33333);
    for (int i = 0; i < 200; i++) {
      final x = (closeRandom.nextDouble() * 8000) - 4000;
      final y = (closeRandom.nextDouble() * 8000) - 4000;
      final starSize = closeRandom.nextDouble() * 2.0 + 1.0;

      // Some stars have color tints
      final colorType = closeRandom.nextInt(10);
      Color starColor;
      if (colorType < 7) {
        starColor = Colors.white;
      } else if (colorType == 7) {
        starColor = const Color(0xFFFFE4B5); // Warm yellow
      } else if (colorType == 8) {
        starColor = const Color(0xFFB0E0E6); // Cool blue
      } else {
        starColor = const Color(0xFFFFDAB9); // Orange
      }

      // Glow
      final glowPaint =
          Paint()
            ..color = starColor.withValues(alpha: 0.3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, starSize * 2);
      canvas.drawCircle(Offset(x, y), starSize * 2, glowPaint);

      // Core
      canvas.drawCircle(
        Offset(x, y),
        starSize,
        Paint()..color = starColor.withValues(alpha: 0.95),
      );
    }

    // Distant galaxy spiral (optional cinematic element)
    final galaxyPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: 0.15),
              const Color(0xFF9370DB).withValues(alpha: 0.08),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(
            Rect.fromCircle(center: const Offset(-3000, -2500), radius: 800),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    canvas.drawCircle(const Offset(-3000, -2500), 800, galaxyPaint);

    // LEGO Baseplate Floor with studs
    _drawLegoFloor(canvas, size);
  }

  /// Draw surrounding buildings to add depth and variety
  void _drawSurroundingBuildings(
    Canvas canvas,
    Location location,
    vm.Vector3 centerPos,
  ) {
    final buildingOffsets = [
      vm.Vector3(150, 0, 100),
      vm.Vector3(-120, 0, 130),
      vm.Vector3(100, 0, -150),
      vm.Vector3(-140, 0, -110),
    ];

    for (int i = 0; i < buildingOffsets.length; i++) {
      final offset = buildingOffsets[i];
      final buildingPos = centerPos + offset;

      // Vary building types based on location
      final buildingType = _getBuildingType(location.id, i);
      _drawSmallBuilding(canvas, buildingPos, buildingType);
    }
  }

  /// Get building type based on location and index
  String _getBuildingType(String locationId, int index) {
    if (locationId == 'tatooine_cantina') {
      return ['hut', 'dome', 'tower', 'bunker'][index % 4];
    } else if (locationId == 'cloud_city') {
      return ['skyscraper', 'spire', 'platform', 'tower'][index % 4];
    } else if (locationId == 'jedi_temple') {
      return ['temple', 'spire', 'tower', 'monument'][index % 4];
    } else if (locationId == 'death_star') {
      return ['turret', 'hangar', 'tower', 'array'][index % 4];
    } else if (locationId == 'hoth_base') {
      return ['bunker', 'tower', 'shield', 'hangar'][index % 4];
    }
    return ['tower', 'cube', 'dome', 'spire'][index % 4];
  }

  /// Draw a small surrounding building
  void _drawSmallBuilding(Canvas canvas, vm.Vector3 position, String type) {
    final baseWidth = 40.0 + math.Random(position.x.toInt()).nextDouble() * 20;
    final height = 50.0 + math.Random(position.z.toInt()).nextDouble() * 40;

    // Get corners
    final corners = [
      _worldToScreen(
        vm.Vector3(
          position.x - baseWidth / 2,
          position.y,
          position.z - baseWidth / 2,
        ),
      ),
      _worldToScreen(
        vm.Vector3(
          position.x + baseWidth / 2,
          position.y,
          position.z - baseWidth / 2,
        ),
      ),
      _worldToScreen(
        vm.Vector3(
          position.x + baseWidth / 2,
          position.y,
          position.z + baseWidth / 2,
        ),
      ),
      _worldToScreen(
        vm.Vector3(
          position.x - baseWidth / 2,
          position.y,
          position.z + baseWidth / 2,
        ),
      ),
    ];

    final topCorners = [
      _worldToScreen(
        vm.Vector3(
          position.x - baseWidth / 2,
          position.y + height,
          position.z - baseWidth / 2,
        ),
      ),
      _worldToScreen(
        vm.Vector3(
          position.x + baseWidth / 2,
          position.y + height,
          position.z - baseWidth / 2,
        ),
      ),
      _worldToScreen(
        vm.Vector3(
          position.x + baseWidth / 2,
          position.y + height,
          position.z + baseWidth / 2,
        ),
      ),
      _worldToScreen(
        vm.Vector3(
          position.x - baseWidth / 2,
          position.y + height,
          position.z + baseWidth / 2,
        ),
      ),
    ];

    // Choose color based on type
    final Color baseColor = _getBuildingColor(type);

    // Draw building based on type
    switch (type) {
      case 'dome':
        _drawDomeBuilding(canvas, corners, topCorners, baseColor);
        break;
      case 'spire':
        _drawSpireBuilding(canvas, corners, topCorners, baseColor);
        break;
      case 'tower':
        _drawTowerBuilding(canvas, corners, topCorners, baseColor);
        break;
      default:
        _drawCubeBuilding(canvas, corners, topCorners, baseColor);
    }
  }

  Color _getBuildingColor(String type) {
    switch (type) {
      case 'dome':
        return const Color(0xFF4A5F7A);
      case 'spire':
        return const Color(0xFF5A6A8A);
      case 'tower':
        return const Color(0xFF3A4A6A);
      case 'bunker':
        return const Color(0xFF2A3A5A);
      case 'temple':
        return const Color(0xFF6A7A9A);
      case 'turret':
        return const Color(0xFF4A5A7A);
      default:
        return const Color(0xFF3A4A6A);
    }
  }

  void _drawCubeBuilding(
    Canvas canvas,
    List<Offset> corners,
    List<Offset> topCorners,
    Color color,
  ) {
    // Front face
    final frontPath =
        Path()
          ..moveTo(corners[0].dx, corners[0].dy)
          ..lineTo(corners[1].dx, corners[1].dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..lineTo(topCorners[0].dx, topCorners[0].dy)
          ..close();
    canvas.drawPath(frontPath, Paint()..color = color.withValues(alpha: 0.8));

    // Right face (darker)
    final rightPath =
        Path()
          ..moveTo(corners[1].dx, corners[1].dy)
          ..lineTo(corners[2].dx, corners[2].dy)
          ..lineTo(topCorners[2].dx, topCorners[2].dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..close();
    canvas.drawPath(rightPath, Paint()..color = color.withValues(alpha: 0.6));

    // Top face (lighter)
    final topPath =
        Path()
          ..moveTo(topCorners[0].dx, topCorners[0].dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..lineTo(topCorners[2].dx, topCorners[2].dy)
          ..lineTo(topCorners[3].dx, topCorners[3].dy)
          ..close();
    canvas.drawPath(topPath, Paint()..color = color.withValues(alpha: 0.9));
  }

  void _drawDomeBuilding(
    Canvas canvas,
    List<Offset> corners,
    List<Offset> topCorners,
    Color color,
  ) {
    // Base
    _drawCubeBuilding(canvas, corners, topCorners, color);

    // Dome on top
    final center = Offset(
      (topCorners[0].dx + topCorners[2].dx) / 2,
      (topCorners[0].dy + topCorners[2].dy) / 2,
    );
    final radius = (topCorners[1].dx - topCorners[0].dx) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
      radius * 0.3,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
  }

  void _drawSpireBuilding(
    Canvas canvas,
    List<Offset> corners,
    List<Offset> topCorners,
    Color color,
  ) {
    // Narrow base
    _drawCubeBuilding(canvas, corners, topCorners, color);

    // Pointed top
    final center = Offset(
      (topCorners[0].dx + topCorners[2].dx) / 2,
      (topCorners[0].dy + topCorners[2].dy) / 2 - 30,
    );

    final spirePath =
        Path()
          ..moveTo(topCorners[0].dx, topCorners[0].dy)
          ..lineTo(center.dx, center.dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..close();
    canvas.drawPath(spirePath, Paint()..color = color.withValues(alpha: 0.95));
  }

  void _drawTowerBuilding(
    Canvas canvas,
    List<Offset> corners,
    List<Offset> topCorners,
    Color color,
  ) {
    _drawCubeBuilding(canvas, corners, topCorners, color);

    // Add windows
    for (int i = 0; i < 3; i++) {
      final windowY =
          corners[0].dy - i * (corners[0].dy - topCorners[0].dy) / 4;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset((corners[0].dx + corners[1].dx) / 2, windowY),
          width: 6,
          height: 8,
        ),
        Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.6),
      );
    }
  }

  /// Draw enhanced procedural floor with textures (inspired by textures.com API)
  void _drawLegoFloor(Canvas canvas, Size size) {
    final tileSize = 80.0;
    final studSize = 20.0;

    // Draw procedural floor tiles with variation
    for (double x = -2000; x < 2000; x += tileSize) {
      for (double y = -2000; y < 2000; y += tileSize) {
        final screenPos = _worldToScreen(vm.Vector3(x, 0, y));

        // Only draw if visible on screen
        if (screenPos.dx > -200 &&
            screenPos.dx < size.width + 200 &&
            screenPos.dy > -200 &&
            screenPos.dy < size.height + 200) {
          // Procedural noise for tile variation (simulating texture API)
          final noise = (math.sin(x * 0.01) * math.cos(y * 0.01) * 0.5 + 0.5);
          final brightness = 0.15 + noise * 0.1;

          // Get tile corners
          final corners = [
            _worldToScreen(vm.Vector3(x, 0, y)),
            _worldToScreen(vm.Vector3(x + tileSize, 0, y)),
            _worldToScreen(vm.Vector3(x + tileSize, 0, y + tileSize)),
            _worldToScreen(vm.Vector3(x, 0, y + tileSize)),
          ];

          // Draw tile with gradient (simulating texture)
          final tilePath =
              Path()
                ..moveTo(corners[0].dx, corners[0].dy)
                ..lineTo(corners[1].dx, corners[1].dy)
                ..lineTo(corners[2].dx, corners[2].dy)
                ..lineTo(corners[3].dx, corners[3].dy)
                ..close();

          // Base tile color with variation
          final tileColor =
              Color.lerp(
                const Color(0xFF1A1A2E),
                const Color(0xFF2E2E4E),
                brightness,
              )!;

          canvas.drawPath(
            tilePath,
            Paint()..color = tileColor.withValues(alpha: 0.8),
          );

          // Tile outline
          canvas.drawPath(
            tilePath,
            Paint()
              ..color = const Color(0xFF3A3A5A).withValues(alpha: 0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );

          // Add LEGO studs within each tile
          for (double sx = 0; sx < tileSize; sx += studSize) {
            for (double sy = 0; sy < tileSize; sy += studSize) {
              final studPos = _worldToScreen(
                vm.Vector3(x + sx + studSize / 2, 0, y + sy + studSize / 2),
              );

              // Stud with 3D effect
              canvas.drawCircle(
                studPos,
                3.5,
                Paint()
                  ..color = Color.lerp(
                    const Color(0xFF3A4A6A),
                    const Color(0xFF4A5A7A),
                    brightness,
                  )!.withValues(alpha: 0.6),
              );

              // Stud highlight
              canvas.drawCircle(
                Offset(studPos.dx - 1, studPos.dy - 1),
                1.5,
                Paint()..color = const Color(0xFF6A7A9A).withValues(alpha: 0.5),
              );
            }
          }

          // Add weathering details (simulating PBR textures)
          if (noise > 0.7) {
            canvas.drawCircle(
              Offset(
                screenPos.dx + tileSize * 0.3,
                screenPos.dy + tileSize * 0.4,
              ),
              2,
              Paint()..color = const Color(0xFF0A0A1A).withValues(alpha: 0.3),
            );
          }
        }
      }
    }

    // Add subtle scan lines for holographic floor effect
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFF00FFFF).withValues(alpha: 0.02)
          ..strokeWidth = 1,
      );
    }
  }

  void _drawLocation(Canvas canvas, Location location) {
    final position = locationPositions[location.id] ?? vm.Vector3.zero();

    // Use advanced building renderer
    AdvancedBuildingRenderer.drawBuilding(
      canvas: canvas,
      position: position,
      locationId: location.id,
      worldToScreen: _worldToScreen,
    );

    // Add surrounding structures for more depth
    _drawSurroundingBuildings(canvas, location, position);

    final screenPos = _worldToScreen(position);

    // Location label with holographic panel background
    final textPainter = TextPainter(
      text: TextSpan(
        text: location.label,
        style: const TextStyle(
          color: Color(0xFF00FFFF),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          height: 1.3,
          shadows: [
            Shadow(
              offset: Offset(0, 0),
              blurRadius: 12,
              color: Color(0xFF00BFFF),
            ),
            Shadow(
              offset: Offset(0, 0),
              blurRadius: 6,
              color: Color(0xFF00FFFF),
            ),
            Shadow(
              offset: Offset(1, 2),
              blurRadius: 4,
              color: Color(0xFF000000),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Draw holographic panel background
    final labelX = screenPos.dx - textPainter.width / 2;
    final labelY = screenPos.dy - 150;
    final padding = 8.0;

    // Outer glow
    final glowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelX - padding - 2,
        labelY - padding - 2,
        textPainter.width + padding * 2 + 4,
        textPainter.height + padding * 2 + 4,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      glowRect,
      Paint()
        ..color = const Color(0xFF00BFFF).withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Panel background with gradient
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelX - padding,
        labelY - padding,
        textPainter.width + padding * 2,
        textPainter.height + padding * 2,
      ),
      const Radius.circular(4),
    );

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF0A1929).withValues(alpha: 0.95),
        const Color(0xFF051018).withValues(alpha: 0.95),
      ],
    );

    canvas.drawRRect(
      panelRect,
      Paint()..shader = gradient.createShader(panelRect.outerRect),
    );

    // Holographic border
    canvas.drawRRect(
      panelRect,
      Paint()
        ..color = const Color(0xFF00BFFF).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Corner accents
    final cornerPaint =
        Paint()
          ..color = const Color(0xFF00FFFF)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.square;

    final cornerLength = 6.0;
    // Top-left corner
    canvas.drawLine(
      Offset(labelX - padding, labelY - padding),
      Offset(labelX - padding + cornerLength, labelY - padding),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(labelX - padding, labelY - padding),
      Offset(labelX - padding, labelY - padding + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(labelX + textPainter.width + padding, labelY - padding),
      Offset(
        labelX + textPainter.width + padding - cornerLength,
        labelY - padding,
      ),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(labelX + textPainter.width + padding, labelY - padding),
      Offset(
        labelX + textPainter.width + padding,
        labelY - padding + cornerLength,
      ),
      cornerPaint,
    );

    textPainter.paint(canvas, Offset(labelX, labelY));

    // Planet metadata with holographic badge styling
    if (planetMetadata.containsKey(location.id)) {
      final meta = planetMetadata[location.id]!;
      final climate = meta['climate']?.toString() ?? '';
      final terrain = meta['terrain']?.toString().split(',').first ?? '';
      final info = "${climate.toUpperCase()} · ${terrain.toUpperCase()}";

      final subPainter = TextPainter(
        text: TextSpan(
          text: info,
          style: const TextStyle(
            color: Color(0xFF00BFFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            height: 1.2,
            shadows: [
              Shadow(
                offset: Offset(0, 0),
                blurRadius: 8,
                color: Color(0xFF00BFFF),
              ),
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Color(0xFF000000),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final metaX = screenPos.dx - subPainter.width / 2;
      final metaY = screenPos.dy - 128;
      final metaPadding = 6.0;

      // Metadata badge background
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          metaX - metaPadding,
          metaY - metaPadding,
          subPainter.width + metaPadding * 2,
          subPainter.height + metaPadding * 2,
        ),
        const Radius.circular(3),
      );

      // Semi-transparent background
      canvas.drawRRect(
        badgeRect,
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.7),
      );

      // Subtle border
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = const Color(0xFF00BFFF).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      subPainter.paint(canvas, Offset(metaX, metaY));
    }
  }

  // void _drawIsometricBuilding(
  //   Canvas canvas,
  //   vm.Vector3 position,
  //   Location location,
  // ) {
  //   final width = 90.0;
  //   final height = 110.0;
  //   final color = _getLocationColor(location.id);

  //   // Base corners
  //   final corners = [
  //     _worldToScreen(
  //       vm.Vector3(position.x - width / 2, position.y, position.z - width / 2),
  //     ),
  //     _worldToScreen(
  //       vm.Vector3(position.x + width / 2, position.y, position.z - width / 2),
  //     ),
  //     _worldToScreen(
  //       vm.Vector3(position.x + width / 2, position.y, position.z + width / 2),
  //     ),
  //     _worldToScreen(
  //       vm.Vector3(position.x - width / 2, position.y, position.z + width / 2),
  //     ),
  //   ];

  //   final topCorners = [
  //     _worldToScreen(
  //       vm.Vector3(
  //         position.x - width / 2,
  //         position.y + height,
  //         position.z - width / 2,
  //       ),
  //     ),
  //     _worldToScreen(
  //       vm.Vector3(
  //         position.x + width / 2,
  //         position.y + height,
  //         position.z - width / 2,
  //       ),
  //     ),
  //     _worldToScreen(
  //       vm.Vector3(
  //         position.x + width / 2,
  //         position.y + height,
  //         position.z + width / 2,
  //       ),
  //     ),
  //     _worldToScreen(
  //       vm.Vector3(
  //         position.x - width / 2,
  //         position.y + height,
  //         position.z + width / 2,
  //       ),
  //     ),
  //   ];

  //   // Front face
  //   final frontPath =
  //       Path()
  //         ..moveTo(corners[0].dx, corners[0].dy)
  //         ..lineTo(corners[1].dx, corners[1].dy)
  //         ..lineTo(topCorners[1].dx, topCorners[1].dy)
  //         ..lineTo(topCorners[0].dx, topCorners[0].dy)
  //         ..close();

  //   final frontPaint =
  //       Paint()
  //         ..shader = LinearGradient(
  //           begin: Alignment.topCenter,
  //           end: Alignment.bottomCenter,
  //           colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.7)],
  //         ).createShader(Rect.fromPoints(topCorners[0], corners[1]));
  //   canvas.drawPath(frontPath, frontPaint);

  //   // Right face
  //   final rightPath =
  //       Path()
  //         ..moveTo(corners[1].dx, corners[1].dy)
  //         ..lineTo(corners[2].dx, corners[2].dy)
  //         ..lineTo(topCorners[2].dx, topCorners[2].dy)
  //         ..lineTo(topCorners[1].dx, topCorners[1].dy)
  //         ..close();

  //   final rightPaint = Paint()..color = color.withValues(alpha: 0.5);
  //   canvas.drawPath(rightPath, rightPaint);

  //   // Top face
  //   final topPath =
  //       Path()
  //         ..moveTo(topCorners[0].dx, topCorners[0].dy)
  //         ..lineTo(topCorners[1].dx, topCorners[1].dy)
  //         ..lineTo(topCorners[2].dx, topCorners[2].dy)
  //         ..lineTo(topCorners[3].dx, topCorners[3].dy)
  //         ..close();

  //   final topPaint = Paint()..color = color;
  //   canvas.drawPath(topPath, topPaint);

  //   // Outlines
  //   final outlinePaint =
  //       Paint()
  //         ..color = Colors.black38
  //         ..style = PaintingStyle.stroke
  //         ..strokeWidth = 2;

  //   canvas.drawPath(frontPath, outlinePaint);
  //   canvas.drawPath(rightPath, outlinePaint);
  //   canvas.drawPath(topPath, outlinePaint);

  //   // Add windows
  //   _drawWindows(canvas, corners, topCorners, color);
  // }

  // void _drawWindows(
  //   Canvas canvas,
  //   List<Offset> corners,
  //   List<Offset> topCorners,
  //   Color buildingColor,
  // ) {
  //   final windowPaint =
  //       Paint()
  //         ..color = Colors.yellow.shade200.withValues(alpha: 0.6)
  //         ..style = PaintingStyle.fill;

  //   // Windows on front face
  //   for (int i = 0; i < 3; i++) {
  //     final t = (i + 1) / 4;
  //     final bottomLeft = Offset.lerp(corners[0], corners[1], t)!;
  //     final topLeft = Offset.lerp(topCorners[0], topCorners[1], t)!;
  //     final midPoint = Offset.lerp(bottomLeft, topLeft, 0.3)!;

  //     canvas.drawRect(
  //       Rect.fromCenter(center: midPoint, width: 8, height: 12),
  //       windowPaint,
  //     );
  //   }
  // }

  void _drawAgent(Canvas canvas, Agent agent) {
    final locationId = _getAgentLocation(agent);
    final targetPosition = locationPositions[locationId] ?? vm.Vector3.zero();

    // Get current tick from events
    final currentTick = events.isNotEmpty ? events.last.tick : 0;

    // Update movement target if location changed
    if (currentTick != _lastTick) {
      _avatarMovement.updateTarget(
        agent.profile.id,
        targetPosition,
        currentTick,
      );
      _lastTick = currentTick;

      // Play location arrival sound when agent reaches new location
      final lastLocation = _lastLocationSound[agent.profile.id];
      if (lastLocation != locationId) {
        _lastLocationSound[agent.profile.id] = locationId;
        StarWarsSounds.playLocationSound(locationId);
      }
    }

    // Get smoothly interpolated position
    final basePosition = _avatarMovement.getPosition(
      agent.profile.id,
      targetPosition,
    );
    final isMoving = _avatarMovement.isMoving(agent.profile.id);

    // Play footstep sounds when walking
    if (isMoving) {
      final frameCount = (currentTick * 2).toInt(); // Convert tick to frames
      final lastFrame = _lastFootstepFrame[agent.profile.id] ?? 0;

      // Play footstep every 12 frames (about 5 steps per second)
      if (frameCount - lastFrame >= 12) {
        _lastFootstepFrame[agent.profile.id] = frameCount;
        StarWarsSounds.footstep();
      }
    }

    // Update walking animation based on movement
    _walkingAnimation.update(agent.profile.id, basePosition, 0.016); // ~60fps

    final animController = agentAnimations[agent.profile.id];
    final animValue = animController?.value ?? 0.0;

    // Use walking animation if moving, otherwise use activity animation
    Map<String, double> animationValues;
    if (isMoving) {
      animationValues = _walkingAnimation.getAnimationValues(agent.profile.id);
    } else {
      final activity = _detectAgentActivity(agent, locationId);
      final activityAnimation = ActivityAnimator.getAnimationValues(
        activity,
        animValue,
      );

      // Apply API-based scaling and speed adjustments
      final animData = characterAnimData[agent.profile.id];
      final scale = animData?['scale'] ?? 1.0;
      final speedMultiplier = animData?['speed'] ?? 1.0;
      final bobIntensity = animData?['bobIntensity'] ?? 1.0;
      final limbSwing = animData?['limbSwing'] ?? 1.0;

      animationValues = {
        'bobOffset': (activityAnimation['bobOffset'] ?? 0.0) * bobIntensity,
        'bodyBob': (activityAnimation['bobOffset'] ?? 0.0) * bobIntensity,
        'leftArmAngle': (activityAnimation['leftArmAngle'] ?? 0.0) * limbSwing,
        'rightArmAngle':
            (activityAnimation['rightArmAngle'] ?? 0.0) * limbSwing,
        'leftLegAngle': (activityAnimation['leftLegAngle'] ?? 0.0) * limbSwing,
        'rightLegAngle':
            (activityAnimation['rightLegAngle'] ?? 0.0) * limbSwing,
        'scale': scale,
        'speed': speedMultiplier,
      };
    }

    final bobOffset =
        animationValues['bobOffset'] ?? animationValues['bodyBob'] ?? 0.0;

    final agentOffset = _getAgentOffset(agent.profile.id);
    final position = vm.Vector3(
      basePosition.x + agentOffset.dx,
      bobOffset,
      basePosition.z + agentOffset.dy,
    );

    final screenPos = _worldToScreen(position);

    // Shadow
    final shadowPaint =
        Paint()
          ..color = Colors.black38
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(screenPos.dx, screenPos.dy + 35),
        width: 45,
        height: 18,
      ),
      shadowPaint,
    );

    // Draw travel path if agent is moving
    if (isMoving) {
      _drawTravelPath(canvas, agent, basePosition, targetPosition);

      // Add motion blur trail for cinematic effect
      _drawMotionTrail(canvas, screenPos, isMoving);
    }

    final isSelected = selectedAgent?.profile.id == agent.profile.id;

    // Get current activity description for avatar
    final activityDescription = _getActivityDescription(
      agent,
      locationId,
      currentTick,
    );

    // Play activity-specific sounds
    final frameCount = (currentTick * 2).toInt();
    final lastActionFrame = _lastActionSound[agent.profile.id] ?? 0;

    // Trigger sounds for specific activities (throttled to avoid spam)
    if (frameCount - lastActionFrame >= 180) {
      // Every 3 seconds
      _lastActionSound[agent.profile.id] = frameCount;

      switch (activityDescription) {
        case 'training':
        case 'fighting':
          // Lightsaber sounds for Luke
          if (agent.profile.id == 'luke') {
            StarWarsSounds.lightsaberSwing();
          } else if (agent.profile.id == 'han') {
            StarWarsSounds.blasterFire();
          }
          break;
        case 'meditating':
          StarWarsSounds.forcePower();
          break;
        case 'piloting':
          StarWarsSounds.engineHum();
          break;
        case 'repairing':
          StarWarsSounds.r2d2Beep();
          break;
        case 'drinking':
          if (locationId == 'tatooine_cantina') {
            StarWarsSounds.playCantinaMusic();
          }
          break;
      }
    }

    // Draw Star Wars character avatar with activity
    StarWarsAvatars.drawCharacter(
      canvas: canvas,
      position: screenPos,
      characterId: agent.profile.id,
      animationValues: animationValues,
      isSelected: isSelected,
      activity: activityDescription,
    );

    if (isSelected) {
      // Professional selection indicator with glow
      final glowPaint =
          Paint()
            ..color = const Color(0xFF00FF88).withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(screenPos.dx, screenPos.dy + 20), 42, glowPaint);

      final selectionPaint =
          Paint()
            ..color = const Color(0xFF00FF88)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
      canvas.drawCircle(
        Offset(screenPos.dx, screenPos.dy + 20),
        40,
        selectionPaint,
      );

      _drawPlumbob(canvas, Offset(screenPos.dx, screenPos.dy - 85));
    }

    final namePainter = TextPainter(
      text: TextSpan(
        text: agent.profile.displayName,
        style: TextStyle(
          color: isSelected ? const Color(0xFF00FF88) : const Color(0xFFFFFFFF),
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          letterSpacing: 0.3,
          height: 1.2,
          shadows: [
            const Shadow(
              offset: Offset(0, 1),
              blurRadius: 3,
              color: Color(0xFF000000),
            ),
            if (isSelected)
              const Shadow(
                offset: Offset(0, 0),
                blurRadius: 8,
                color: Color(0xFF00FF88),
              ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    namePainter.paint(
      canvas,
      Offset(screenPos.dx - namePainter.width / 2, screenPos.dy + 40),
    );

    // Draw current task indicator
    _drawTaskIndicator(canvas, screenPos, agent, events);
  }

  void _drawTaskIndicator(
    Canvas canvas,
    Offset screenPos,
    Agent agent,
    List<WorldEvent> events,
  ) {
    // Get the most recent event for this agent to show current task
    String? currentDescription;
    for (final event in events.reversed) {
      if (event.actorId == agent.profile.id) {
        currentDescription = event.description;
        break;
      }
    }

    if (currentDescription == null) return;

    // Extract just the action part (after the colon)
    String displayText = currentDescription;
    if (displayText.contains(':')) {
      displayText = displayText.split(':').last.trim();
    }

    // Check if agent is moving
    final isMoving = _avatarMovement.isMoving(agent.profile.id);

    // Color coding based on activity
    Color indicatorColor = _getAgentColor(agent.profile.id);
    if (isMoving) {
      indicatorColor = Colors.orange; // Moving
    } else if (displayText.toLowerCase().contains('training') ||
        displayText.toLowerCase().contains('practicing')) {
      indicatorColor = Colors.blue; // Training
    } else if (displayText.toLowerCase().contains('meditating') ||
        displayText.toLowerCase().contains('studying')) {
      indicatorColor = Colors.purple; // Meditation/Study
    } else if (displayText.toLowerCase().contains('strategizing') ||
        displayText.toLowerCase().contains('coordinating')) {
      indicatorColor = Colors.green; // Leadership
    }

    // Draw task bubble above name
    final taskPainter = TextPainter(
      text: TextSpan(
        children: [
          if (isMoving)
            const TextSpan(
              text: '→ ',
              style: TextStyle(
                color: Color(0xFFFFA500),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          TextSpan(
            text: displayText,
            style: const TextStyle(
              color: Color(0xFFF0F0F0),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              height: 1.3,
            ),
          ),
        ],
        style: const TextStyle(
          shadows: [
            Shadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Color(0xFF000000),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 240);

    // Background bubble with gradient
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screenPos.dx, screenPos.dy + 55),
        width: taskPainter.width + 20,
        height: taskPainter.height + 10,
      ),
      const Radius.circular(12),
    );

    // Subtle gradient background
    final bubblePaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A1A).withValues(alpha: 0.92),
              const Color(0xFF0A0A0A).withValues(alpha: 0.95),
            ],
          ).createShader(bubbleRect.outerRect)
          ..style = PaintingStyle.fill;

    canvas.drawRRect(bubbleRect, bubblePaint);

    // Professional border styling
    if (isMoving) {
      final animValue = agentAnimations[agent.profile.id]?.value ?? 0.0;
      final borderPulse = 0.7 + 0.3 * math.sin(animValue * 4 * math.pi);

      // Outer glow for moving state
      final glowPaint =
          Paint()
            ..color = indicatorColor.withValues(alpha: borderPulse * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(bubbleRect, glowPaint);

      // Main border
      final borderPaint =
          Paint()
            ..color = indicatorColor.withValues(alpha: borderPulse * 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
      canvas.drawRRect(bubbleRect, borderPaint);
    } else {
      // Subtle static border
      final borderPaint =
          Paint()
            ..color = indicatorColor.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
      canvas.drawRRect(bubbleRect, borderPaint);
    }

    // Task text
    taskPainter.paint(
      canvas,
      Offset(
        screenPos.dx - taskPainter.width / 2,
        screenPos.dy + 55 - taskPainter.height / 2,
      ),
    );
  }

  AgentActivity _detectAgentActivity(Agent agent, String locationId) {
    // Get most recent event for this agent
    String? recentDescription;
    for (final event in events.reversed) {
      if (event.actorId == agent.profile.id) {
        recentDescription = event.description;
        break;
      }
    }

    return ActivityDetector.detectActivity(locationId, recentDescription);
  }

  String _getActivityDescription(Agent agent, String locationId, int tick) {
    final task = DailyTaskSchedule.getCurrentTask(agent.profile.id, tick);

    // Map task descriptions to activity keywords
    if (task.contains('Meditation') || task.contains('Force')) {
      return 'meditating';
    } else if (task.contains('training') || task.contains('practice')) {
      return 'training';
    } else if (task.contains('meeting') || task.contains('Cantina')) {
      return 'meeting';
    } else if (task.contains('Pilot') || task.contains('Falcon')) {
      return 'piloting';
    } else if (task.contains('Study') || task.contains('texts')) {
      return 'studying';
    } else if (task.contains('Command') || task.contains('briefing')) {
      return 'commanding';
    } else if (task.contains('Smuggling') ||
        task.contains('deal') ||
        task.contains('Negotiate')) {
      return 'negotiating';
    } else if (task.contains('maintenance') || task.contains('Repair')) {
      return 'repairing';
    }

    return 'idle';
  }

  void _drawPlumbob(Canvas canvas, Offset position) {
    final path =
        Path()
          ..moveTo(position.dx, position.dy - 18)
          ..lineTo(position.dx + 12, position.dy)
          ..lineTo(position.dx, position.dy + 18)
          ..lineTo(position.dx - 12, position.dy)
          ..close();

    final gradient =
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFF00FF88), const Color(0xFF00AA55)],
          ).createShader(Rect.fromCircle(center: position, radius: 18));

    canvas.drawPath(path, gradient);

    final glowPaint =
        Paint()
          ..color = const Color(0xFF00FF88).withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(path, glowPaint);
  }

  void _drawTravelPath(
    Canvas canvas,
    Agent agent,
    vm.Vector3 currentPos,
    vm.Vector3 targetPos,
  ) {
    final startScreen = _worldToScreen(currentPos);
    final endScreen = _worldToScreen(targetPos);

    // Animated dashed line with professional styling
    final animValue = agentAnimations[agent.profile.id]?.value ?? 0.0;
    final dashOffset = animValue * 20.0;

    final agentColor = _getAgentColor(agent.profile.id);

    // Subtle glow under the path
    final glowPaint =
        Paint()
          ..color = agentColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final glowPath =
        Path()
          ..moveTo(startScreen.dx, startScreen.dy)
          ..lineTo(endScreen.dx, endScreen.dy);
    canvas.drawPath(glowPath, glowPaint);

    // Main path with refined styling
    final pathPaint =
        Paint()
          ..color = agentColor.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;

    // Draw dashed line manually
    final path =
        Path()
          ..moveTo(startScreen.dx, startScreen.dy)
          ..lineTo(endScreen.dx, endScreen.dy);

    final pathMetrics = path.computeMetrics();
    final dashPath = Path();

    for (final metric in pathMetrics) {
      double distance = dashOffset % 20.0;
      while (distance < metric.length) {
        final start = distance;
        final end = math.min(distance + 12.0, metric.length);
        dashPath.addPath(metric.extractPath(start, end), Offset.zero);
        distance += 20.0;
      }
    }

    canvas.drawPath(dashPath, pathPaint);

    // Professional arrow at destination with glow
    final angle = math.atan2(
      endScreen.dy - startScreen.dy,
      endScreen.dx - startScreen.dx,
    );

    // Arrow glow
    final arrowGlowPaint =
        Paint()
          ..color = agentColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final arrowGlowPath =
        Path()
          ..moveTo(endScreen.dx, endScreen.dy)
          ..lineTo(
            endScreen.dx - 14 * math.cos(angle - 0.35),
            endScreen.dy - 14 * math.sin(angle - 0.35),
          )
          ..lineTo(
            endScreen.dx - 14 * math.cos(angle + 0.35),
            endScreen.dy - 14 * math.sin(angle + 0.35),
          )
          ..close();
    canvas.drawPath(arrowGlowPath, arrowGlowPaint);

    // Main arrow
    final arrowPaint =
        Paint()
          ..color = agentColor
          ..style = PaintingStyle.fill;

    final arrowPath =
        Path()
          ..moveTo(endScreen.dx, endScreen.dy)
          ..lineTo(
            endScreen.dx - 12 * math.cos(angle - 0.3),
            endScreen.dy - 12 * math.sin(angle - 0.3),
          )
          ..lineTo(
            endScreen.dx - 12 * math.cos(angle + 0.3),
            endScreen.dy - 12 * math.sin(angle + 0.3),
          )
          ..close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  /// Draw motion trail for moving avatars (cinematic effect)
  void _drawMotionTrail(Canvas canvas, Offset position, bool isMoving) {
    if (!isMoving) return;

    for (int i = 0; i < 3; i++) {
      final trailOffset = Offset(
        position.dx - (i + 1) * 8,
        position.dy + (i + 1) * 2,
      );

      canvas.drawCircle(
        trailOffset,
        8 - i * 2,
        Paint()
          ..color = const Color(0xFF00BFFF).withValues(alpha: 0.15 - i * 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  Offset _worldToScreen(vm.Vector3 worldPos) {
    final isoX = (worldPos.x - worldPos.z) * math.cos(math.pi / 6);
    final isoY = (worldPos.x + worldPos.z) * math.sin(math.pi / 6) - worldPos.y;
    return Offset(isoX, isoY);
  }

  String _getAgentLocation(Agent agent) {
    for (final event in events.reversed) {
      if (event.actorId == agent.profile.id) {
        return event.locationId;
      }
    }
    return agent.profile.homeLocationId;
  }

  Offset _getAgentOffset(String agentId) {
    final hash = agentId.hashCode;
    final x = ((hash % 40) - 20).toDouble();
    final z = (((hash ~/ 40) % 40) - 20).toDouble();
    return Offset(x, z);
  }

  // Color _getLocationColor(String locationId) {
  //   switch (locationId) {
  //     case 'tatooine_cantina':
  //       return const Color(0xFFD4A574); // Desert sand
  //     case 'jedi_temple':
  //       return const Color(0xFF4169E1); // Royal blue
  //     case 'cloud_city':
  //       return const Color(0xFFFFD700); // Gold
  //     case 'dagobah_swamp':
  //       return const Color(0xFF2E8B57); // Sea green
  //     case 'death_star':
  //       return const Color(0xFF708090); // Slate gray
  //     case 'endor_forest':
  //       return const Color(0xFF228B22); // Forest green
  //     case 'hoth_base':
  //       return const Color(0xFFADD8E6); // Light blue
  //     case 'naboo_palace':
  //       return const Color(0xFFDDA0DD); // Plum
  //     default:
  //       return Colors.blueGrey.shade600;
  //   }
  // }

  Color _getAgentColor(String agentId) {
    switch (agentId) {
      case 'luke':
        return const Color(0xFF87CEEB); // Sky blue (lightsaber)
      case 'leia':
        return const Color(0xFFFFFFFF); // White (princess)
      case 'han':
        return const Color(0xFFB8860B); // Dark goldenrod (smuggler)
      default:
        return Colors.teal.shade400;
    }
  }

  /// Apply atmospheric fog for depth perception
  void _applyAtmosphericFog(Canvas canvas, Size size) {
    final fogPaint =
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Colors.transparent,
              const Color(0xFF0A0E27).withValues(alpha: 0.15),
              const Color(0xFF000308).withValues(alpha: 0.25),
            ],
            stops: const [0.0, 0.7, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fogPaint);
  }

  /// Apply depth of field blur to edges for cinematic focus
  void _applyDepthOfField(Canvas canvas, Size size) {
    final dofPaint =
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [
              Colors.transparent,
              const Color(0xFF000000).withValues(alpha: 0.08),
            ],
            stops: const [0.6, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dofPaint);
  }

  /// Apply professional vignette effect
  void _applyVignette(Canvas canvas, Size size) {
    final vignettePaint =
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Colors.transparent,
              Colors.transparent,
              const Color(0xFF000000).withValues(alpha: 0.3),
              const Color(0xFF000000).withValues(alpha: 0.5),
            ],
            stops: const [0.0, 0.5, 0.85, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      vignettePaint,
    );
  }

  /// Apply cinematic color grading with Star Wars blue tint
  void _applyColorGrading(Canvas canvas, Size size) {
    // Subtle blue-cyan tint for Star Wars atmosphere
    final colorGradePaint =
        Paint()
          ..color = const Color(0xFF0A2540).withValues(alpha: 0.08)
          ..blendMode = BlendMode.overlay;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      colorGradePaint,
    );

    // Subtle contrast enhancement
    final contrastPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF000000).withValues(alpha: 0.05),
              Colors.transparent,
              const Color(0xFF000000).withValues(alpha: 0.03),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..blendMode = BlendMode.multiply;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      contrastPaint,
    );
  }

  @override
  bool shouldRepaint(_WorldPainterInteractive oldDelegate) => true;
}
