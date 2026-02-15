import 'package:flutter/material.dart';
import 'dart:async';
import '../agent.dart';
import '../engine.dart';
import '../world.dart';
import '../planner.dart';
import '../rendering/world_renderer_3d_interactive.dart';
import 'sims_control_panel.dart';
import 'galaxy_map_screen.dart';
import 'lego_ui_system.dart';
import 'premium_effects.dart';
import 'nasa_background.dart';
import '../audio/star_wars_sounds.dart';
import '../../simulation.dart';

/// Main 3D simulation view with Sims-like interface
class Simulation3DView extends StatefulWidget {
  const Simulation3DView({super.key});

  @override
  State<Simulation3DView> createState() => _Simulation3DViewState();
}

class _Simulation3DViewState extends State<Simulation3DView> {
  late SimulationEngine _engine;
  List<WorldEvent> _events = [];
  bool _isRunning = false;
  double _speed = 1.0;
  Timer? _simulationTimer;
  bool _showGalaxyMap = false;
  Agent? _selectedAgent;
  String _plannerStatus = 'LLM provider: local';

  @override
  void initState() {
    super.initState();
    _initializeSimulation();
    // Commented out to prevent audio errors on startup
    // _startCantinaMusic();
  }

  void _initializeSimulation() {
    // Use fast HeuristicPlanner for immediate action
    _engine = buildDefaultSimulation(planner: const HeuristicPlanner());
    _plannerStatus = 'Ready to simulate';
    debugPrint('🚀 Simulation initialized with HeuristicPlanner');
    _events = [];
    _selectedAgent = null;
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    StarWarsSounds.stopAll();
    super.dispose();
  }

  void _startSimulation() {
    if (_isRunning) return;

    debugPrint('▶️ Starting simulation at speed $_speed');
    setState(() {
      _isRunning = true;
    });

    final tickDuration = Duration(milliseconds: (1000 / _speed).round());
    debugPrint('⏱️ Tick duration: ${tickDuration.inMilliseconds}ms');
    _simulationTimer = Timer.periodic(tickDuration, (_) async {
      await _runTick();
    });
  }

  void _pauseSimulation() {
    debugPrint('⏸️ Pausing simulation');
    setState(() {
      _isRunning = false;
    });
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  Future<void> _runTick() async {
    try {
      debugPrint('🎬 Running simulation tick...');
      final newEvents = await _engine.tick();
      debugPrint('✅ Tick completed with ${newEvents.length} events');
      setState(() {
        _events.addAll(newEvents);
        // Keep only last 50 events for performance
        if (_events.length > 50) {
          _events = _events.sublist(_events.length - 50);
        }
      });
    } catch (e) {
      debugPrint('❌ Error during simulation tick: $e');
    }
  }

  void _changeSpeed(double newSpeed) {
    setState(() {
      _speed = newSpeed;
    });

    // Restart timer with new speed if running
    if (_isRunning) {
      _pauseSimulation();
      _startSimulation();
    }
  }

  void _onAgentSelected(Agent? agent) {
    setState(() {
      _selectedAgent = agent;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // NASA live space background
          const Positioned.fill(child: NasaSpaceBackground()),

          // Animated starfield overlay
          Positioned.fill(child: AnimatedStarfield(starCount: 200, speed: 0.3)),

          // Particle network effect
          Positioned.fill(
            child: ParticleBackground(
              particleCount: 30,
              particleColor: Color(0xFF00D9FF),
            ),
          ),
          // Toggle between Galaxy Map and 3D View with smooth transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child:
                _showGalaxyMap
                    ? GalaxyMapScreen(
                      key: const ValueKey('galaxy'),
                      locations: _engine.world.locations,
                      agents: _engine.agents,
                      onLocationSelected: (location) {
                        debugPrint('Selected location: ${location.label}');
                      },
                    )
                    : Column(
                      key: const ValueKey('3d'),
                      children: [
                        // 3D world view (main area)
                        Expanded(
                          flex: 7,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 2.0,
                                colors: [
                                  const Color(0xFF0a1929),
                                  const Color(0xFF051222),
                                  Colors.black,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                            child: WorldRenderer3DInteractive(
                              locations: _engine.world.locations,
                              agents: _engine.agents,
                              events: _events,
                              onAgentSelected: _onAgentSelected,
                            ),
                          ),
                        ),

                        // Sims-style control panel (bottom)
                        SizedBox(
                          height: 300,
                          child: SimsControlPanel(
                            selectedAgent: _selectedAgent,
                            recentEvents: _events,
                            isRunning: _isRunning,
                            speed: _speed,
                            onRunSimulation: _startSimulation,
                            onPauseSimulation: _pauseSimulation,
                            onSpeedChange: _changeSpeed,
                          ),
                        ),
                      ],
                    ),
          ),

          // LEGO-style status header with holographic effect
          Positioned(
            top: 40,
            left: 40,
            child: HolographicCard(
              accentColor: LegoUISystem.lightsaberGreen,
              child: LegoHeader(
                text: _plannerStatus,
                color: LegoUISystem.lightsaberGreen,
                icon: Icons.auto_awesome,
              ),
            ),
          ),

          // NASA APOD info panel
          const Positioned(
            bottom: 320,
            right: 20,
            child: SizedBox(width: 300, child: NasaApodDisplay()),
          ),

          // LEGO-style view toggle button
          Positioned(
            top: 40,
            right: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sound toggle
                LegoButton(
                  label: '',
                  icon: Icons.volume_up,
                  onPressed: () {
                    StarWarsSounds.toggleSound();
                    setState(() {});
                  },
                  color: LegoUISystem.legoYellow,
                  isLarge: false,
                ),
                const SizedBox(width: 16),
                // View toggle
                LegoButton(
                  label: _showGalaxyMap ? '3D VIEW' : 'GALAXY MAP',
                  icon: _showGalaxyMap ? Icons.view_in_ar : Icons.public,
                  onPressed: () {
                    setState(() {
                      _showGalaxyMap = !_showGalaxyMap;
                    });
                  },
                  color: LegoUISystem.legoBlue,
                  isLarge: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced view toggle button with hover effects
class _ViewToggleButton extends StatefulWidget {
  final bool showGalaxyMap;
  final VoidCallback onTap;

  const _ViewToggleButton({required this.showGalaxyMap, required this.onTap});

  @override
  State<_ViewToggleButton> createState() => _ViewToggleButtonState();
}

class _ViewToggleButtonState extends State<_ViewToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(
                    0xFF00FFFF,
                  ).withValues(alpha: _isHovered ? 0.4 : 0.3),
                  const Color(
                    0xFF0080FF,
                  ).withValues(alpha: _isHovered ? 0.3 : 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(
                  0xFF00FFFF,
                ).withValues(alpha: _isHovered ? 0.7 : 0.5),
                width: _isHovered ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF00FFFF,
                  ).withValues(alpha: _isHovered ? 0.5 : 0.3),
                  blurRadius: _isHovered ? 20 : 15,
                  spreadRadius: _isHovered ? 2 : 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.showGalaxyMap ? Icons.view_in_ar : Icons.public,
                  color: const Color(0xFF00FFFF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.showGalaxyMap ? '3D VIEW' : 'GALAXY MAP',
                  style: TextStyle(
                    color: const Color(0xFF00FFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    shadows:
                        _isHovered
                            ? [
                              const Shadow(
                                color: Color(0xFF00FFFF),
                                blurRadius: 8,
                              ),
                            ]
                            : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status badge with subtle pulse animation
class _StatusBadge extends StatefulWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(
                0xFF00FFFF,
              ).withValues(alpha: 0.5 + (_pulseController.value * 0.2)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF00FFFF,
                ).withValues(alpha: 0.15 + (_pulseController.value * 0.15)),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00FF88),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.status,
                style: const TextStyle(
                  color: Color(0xFF9EEBFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
