import 'package:flutter/material.dart';
import 'dart:async';
import '../agent.dart';
import '../engine.dart';
import '../world.dart';
import '../planner.dart';
import '../rendering/world_renderer_3d_interactive.dart';
import 'galaxy_map_screen.dart';
import 'aaa_design_system.dart';
import 'game_hud_components.dart';
import 'premium_effects.dart';
import 'nasa_background.dart';
import '../audio/star_wars_sounds.dart';
import '../../simulation.dart';
import '../star_wars_api.dart';

/// AAA Game-Quality Simulation View
/// Inspired by EA Sports dashboards, Activision Blizzard live-ops, and Roblox Creator Hub
class AAASimulationView extends StatefulWidget {
  const AAASimulationView({super.key});

  @override
  State<AAASimulationView> createState() => _AAASimulationViewState();
}

class _AAASimulationViewState extends State<AAASimulationView>
    with TickerProviderStateMixin {
  late SimulationEngine _engine;
  List<WorldEvent> _events = [];
  bool _isRunning = false;
  double _speed = 1.0;
  Timer? _simulationTimer;
  bool _showGalaxyMap = false;
  Agent? _selectedAgent;
  bool _showAgentPanel = false;
  final bool _showEventFeed = true;

  // Star Wars API data
  Map<String, dynamic>? _currentCharacter;
  Map<String, dynamic>? _currentPlanet;
  String _selectedCharacterId = 'luke';
  int _selectedPlanetId = 1;
  bool _loadingData = false;

  late AnimationController _panelSlideController;
  late Animation<Offset> _panelSlideAnimation;
  late AnimationController _cameraShakeController;
  Timer? _cinematicCameraTimer;
  bool _cinematicMode = false;

  @override
  void initState() {
    super.initState();
    _initializeSimulation();
    _initializeAnimations();
  }

  void _initializeSimulation() {
    _engine = buildDefaultSimulation(planner: const HeuristicPlanner());
    debugPrint('🎮 AAA Simulation initialized');
    _events = [];
    _selectedAgent = null;
    _loadStarWarsData();

    // Auto-start simulation like a movie set - action always running!
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_isRunning) {
        debugPrint('🎬 Starting Star Wars movie set simulation...');
        _startSimulation();

        // Play iconic sound on start
        StarWarsSounds.playCantinaMusic();
      }
    });
  }

  Future<void> _loadStarWarsData() async {
    setState(() => _loadingData = true);
    try {
      final charData = await StarWarsAPI.getCharacterAnimationData(
        _selectedCharacterId,
      );
      final planetData = await StarWarsAPI.getPlanet(_selectedPlanetId);
      setState(() {
        _currentCharacter = charData;
        _currentPlanet = planetData;
        _loadingData = false;
      });
      debugPrint('📡 Loaded ${charData['name']} from ${planetData['name']}');
    } catch (e) {
      debugPrint('❌ Failed to load Star Wars data: $e');
      setState(() => _loadingData = false);
    }
  }

  void _changeCharacter(String characterId) {
    setState(() => _selectedCharacterId = characterId);
    _loadStarWarsData();
  }

  void _changePlanet(int planetId) {
    setState(() => _selectedPlanetId = planetId);
    _loadStarWarsData();
  }

  void _initializeAnimations() {
    _panelSlideController = AnimationController(
      duration: AAADesignSystem.durationSlow,
      vsync: this,
    );

    _panelSlideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _panelSlideController,
        curve: AAADesignSystem.easeDefault,
      ),
    );

    _cameraShakeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Start cinematic camera movements for movie set feel
    _startCinematicCamera();
  }

  void _startCinematicCamera() {
    _cinematicCameraTimer?.cancel();
    _cinematicCameraTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _isRunning) {
        // Subtle camera shake for dynamic feel
        _cameraShakeController.reset();
        _cameraShakeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _cinematicCameraTimer?.cancel();
    _panelSlideController.dispose();
    _cameraShakeController.dispose();
    StarWarsSounds.stopAll();
    super.dispose();
  }

  void _startSimulation() {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    final tickDuration = Duration(milliseconds: (1000 / _speed).round());
    _simulationTimer = Timer.periodic(tickDuration, (_) async {
      await _runTick();
    });
  }

  void _pauseSimulation() {
    setState(() => _isRunning = false);
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  Future<void> _runTick() async {
    try {
      final newEvents = await _engine.tick();
      setState(() {
        _events.addAll(newEvents);
        if (_events.length > 50) {
          _events = _events.sublist(_events.length - 50);
        }
      });
    } catch (e) {
      debugPrint('❌ Error during tick: $e');
    }
  }

  void _changeSpeed(double newSpeed) {
    setState(() => _speed = newSpeed);
    if (_isRunning) {
      _pauseSimulation();
      _startSimulation();
    }
  }

  void _onAgentSelected(Agent? agent) {
    setState(() {
      _selectedAgent = agent;
      _showAgentPanel = agent != null;
    });

    if (agent != null) {
      _panelSlideController.forward();
    } else {
      _panelSlideController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AAADesignSystem.spaceVoid,
      body: Stack(
        children: [
          // Background: NASA space imagery
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(child: NasaSpaceBackground()),
            ),
          ),

          // Subtle starfield overlay
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedStarfield(
                  starCount: 30,
                  speed: 0.05,
                  starColor: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),

          // Main Content: Galaxy Map or 3D World View
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: AAADesignSystem.durationSlower,
              switchInCurve: AAADesignSystem.easeDefault,
              switchOutCurve: AAADesignSystem.easeDefault,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: AAADesignSystem.easeSmooth,
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
                          debugPrint('Selected: ${location.label}');
                        },
                      )
                      : WorldRenderer3DInteractive(
                        key: const ValueKey('3d'),
                        locations: _engine.world.locations,
                        agents: _engine.agents,
                        events: _events,
                        onAgentSelected: _onAgentSelected,
                        cinematicMode: _cinematicMode,
                      ),
            ),
          ),

          // Top HUD: Status + Controls
          Positioned(
            top: AAADesignSystem.space24,
            left: AAADesignSystem.space24,
            right: AAADesignSystem.space24,
            child: _buildTopBar(),
          ),

          // Bottom HUD: Timeline + Stats
          Positioned(
            bottom: AAADesignSystem.space24,
            left: AAADesignSystem.space24,
            right: _showAgentPanel ? 420 : AAADesignSystem.space24,
            child: _buildBottomControls(),
          ),

          // Agent Detail Panel (slide in from right)
          if (_showAgentPanel && _selectedAgent != null)
            Positioned(
              top: AAADesignSystem.space24,
              right: AAADesignSystem.space24,
              bottom: AAADesignSystem.space24,
              child: SlideTransition(
                position: _panelSlideAnimation,
                child: _buildAgentDetailPanel(_selectedAgent!),
              ),
            ),

          // Event Feed (bottom-right)
          if (_showEventFeed && !_showAgentPanel && _events.isNotEmpty)
            Positioned(
              bottom: 100,
              right: AAADesignSystem.space24,
              child: _buildEventFeed(),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TOP BAR - Star Wars Character Selection
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Character Display
        HolographicPanel(
          padding: const EdgeInsets.all(AAADesignSystem.space16),
          child: Row(
            children: [
              PulseIndicator(color: AAADesignSystem.accentCyan, size: 12),
              const SizedBox(width: AAADesignSystem.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loadingData
                        ? 'LOADING...'
                        : _currentCharacter?['name']
                                ?.toString()
                                .toUpperCase() ??
                            'LUKE SKYWALKER',
                    style: AAADesignSystem.headingSmall.copyWith(
                      color: AAADesignSystem.accentCyan,
                    ),
                  ),
                  if (_currentPlanet != null)
                    Text(
                      'FROM ${_currentPlanet!['name']?.toString().toUpperCase()}',
                      style: AAADesignSystem.labelSmall.copyWith(
                        color: AAADesignSystem.accentAmber,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (_currentCharacter != null) ...[
                _buildStatChip('HEIGHT', '${_currentCharacter!['height']}cm'),
                const SizedBox(width: AAADesignSystem.space8),
                _buildStatChip('MASS', '${_currentCharacter!['mass']}kg'),
              ],
            ],
          ),
        ),

        const SizedBox(height: AAADesignSystem.space12),

        // Character Action Buttons
        Wrap(
          spacing: AAADesignSystem.space8,
          runSpacing: AAADesignSystem.space8,
          children: [
            GameButton(
              label: 'LUKE',
              icon: Icons.person,
              onPressed: () => _changeCharacter('luke'),
              color:
                  _selectedCharacterId == 'luke'
                      ? AAADesignSystem.accentCyan
                      : AAADesignSystem.textSecondary,
            ),
            GameButton(
              label: 'LEIA',
              icon: Icons.person_outline,
              onPressed: () => _changeCharacter('leia'),
              color:
                  _selectedCharacterId == 'leia'
                      ? AAADesignSystem.accentCyan
                      : AAADesignSystem.textSecondary,
            ),
            GameButton(
              label: 'HAN',
              icon: Icons.person_pin,
              onPressed: () => _changeCharacter('han'),
              color:
                  _selectedCharacterId == 'han'
                      ? AAADesignSystem.accentCyan
                      : AAADesignSystem.textSecondary,
            ),
            GameButton(
              label: 'VADER',
              icon: Icons.shield,
              onPressed: () => _changeCharacter('darth_vader'),
              color:
                  _selectedCharacterId == 'darth_vader'
                      ? Colors.red
                      : AAADesignSystem.textSecondary,
            ),
            GameButton(
              label: 'YODA',
              icon: Icons.psychology,
              onPressed: () => _changeCharacter('yoda'),
              color:
                  _selectedCharacterId == 'yoda'
                      ? AAADesignSystem.successGreen
                      : AAADesignSystem.textSecondary,
            ),
            GameButton(
              label: 'CHEWIE',
              icon: Icons.pets,
              onPressed: () => _changeCharacter('chewbacca'),
              color:
                  _selectedCharacterId == 'chewbacca'
                      ? AAADesignSystem.accentAmber
                      : AAADesignSystem.textSecondary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AAADesignSystem.space12,
        vertical: AAADesignSystem.space4,
      ),
      decoration: BoxDecoration(
        color: AAADesignSystem.spaceVoid.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AAADesignSystem.radiusMedium),
        border: Border.all(
          color: AAADesignSystem.accentCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: AAADesignSystem.labelSmall),
          Text(
            value,
            style: AAADesignSystem.labelSmall.copyWith(
              color: AAADesignSystem.accentCyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM CONTROLS - Planet Selection & Simulation Controls
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBottomControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Planet Selection
        HolographicPanel(
          padding: const EdgeInsets.all(AAADesignSystem.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GALACTIC LOCATIONS',
                style: AAADesignSystem.labelSmall.copyWith(
                  color: AAADesignSystem.accentAmber,
                ),
              ),
              const SizedBox(height: AAADesignSystem.space12),
              Wrap(
                spacing: AAADesignSystem.space8,
                runSpacing: AAADesignSystem.space8,
                children: [
                  GameButton(
                    label: 'TATOOINE',
                    icon: Icons.wb_sunny,
                    onPressed: () => _changePlanet(1),
                    color:
                        _selectedPlanetId == 1
                            ? AAADesignSystem.accentAmber
                            : AAADesignSystem.textSecondary,
                  ),
                  GameButton(
                    label: 'HOTH',
                    icon: Icons.ac_unit,
                    onPressed: () => _changePlanet(4),
                    color:
                        _selectedPlanetId == 4
                            ? Colors.lightBlue
                            : AAADesignSystem.textSecondary,
                  ),
                  GameButton(
                    label: 'DAGOBAH',
                    icon: Icons.water,
                    onPressed: () => _changePlanet(5),
                    color:
                        _selectedPlanetId == 5
                            ? AAADesignSystem.successGreen
                            : AAADesignSystem.textSecondary,
                  ),
                  GameButton(
                    label: 'ENDOR',
                    icon: Icons.forest,
                    onPressed: () => _changePlanet(7),
                    color:
                        _selectedPlanetId == 7
                            ? Colors.green.shade700
                            : AAADesignSystem.textSecondary,
                  ),
                  GameButton(
                    label: 'NABOO',
                    icon: Icons.landscape,
                    onPressed: () => _changePlanet(8),
                    color:
                        _selectedPlanetId == 8
                            ? Colors.purple.shade300
                            : AAADesignSystem.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AAADesignSystem.space12),

        // Simulation Controls
        Row(
          children: [
            TimelineControl(
              isRunning: _isRunning,
              speed: _speed,
              onPlay: _startSimulation,
              onPause: _pauseSimulation,
              onSpeedChange: _changeSpeed,
            ),
            const SizedBox(width: AAADesignSystem.space12),
            GameButton(
              label: _showGalaxyMap ? '3D VIEW' : 'GALAXY',
              icon: _showGalaxyMap ? Icons.view_in_ar : Icons.public,
              onPressed: () => setState(() => _showGalaxyMap = !_showGalaxyMap),
              color: AAADesignSystem.accentCyan,
            ),
            const SizedBox(width: AAADesignSystem.space8),
            GameButton(
              label: '',
              icon: Icons.volume_up,
              onPressed: () {
                StarWarsSounds.toggleSound();
                setState(() {});
              },
              color: AAADesignSystem.accentAmber,
            ),
            const SizedBox(width: AAADesignSystem.space8),
            GameButton(
              label: 'CINEMATIC',
              icon: Icons.movie,
              onPressed: () {
                setState(() {
                  _cinematicMode = !_cinematicMode;
                });
                if (_cinematicMode) {
                  StarWarsSounds.lightsaberIgnite();
                }
              },
              color:
                  _cinematicMode
                      ? Colors.purple
                      : AAADesignSystem.textSecondary,
            ),
            const Spacer(),
            HolographicPanel(
              padding: const EdgeInsets.symmetric(
                horizontal: AAADesignSystem.space16,
                vertical: AAADesignSystem.space12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatDisplay(
                    label: 'Agents',
                    value: '${_engine.agents.length}',
                    icon: Icons.people,
                    color: AAADesignSystem.accentCyan,
                  ),
                  const SizedBox(width: AAADesignSystem.space16),
                  StatDisplay(
                    label: 'Events',
                    value: '${_events.length}',
                    icon: Icons.offline_bolt,
                    color: AAADesignSystem.accentGreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AGENT DETAIL PANEL - Right Side
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAgentDetailPanel(Agent agent) {
    return SizedBox(
      width: 380,
      child: HolographicPanel(
        padding: const EdgeInsets.all(AAADesignSystem.space24),
        showBorder: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              children: [
                Expanded(
                  child: Text(
                    agent.profile.displayName.toUpperCase(),
                    style: AAADesignSystem.headingLarge.copyWith(
                      color: AAADesignSystem.accentCyan,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AAADesignSystem.textSecondary,
                  onPressed: () => _onAgentSelected(null),
                  iconSize: 20,
                ),
              ],
            ),

            const SizedBox(height: AAADesignSystem.space16),

            // Agent ID
            _buildPanelSection(
              'AGENT ID',
              Text(agent.profile.id, style: AAADesignSystem.mono),
            ),

            const SizedBox(height: AAADesignSystem.space16),

            // Primary Goal
            _buildPanelSection(
              'PRIMARY GOAL',
              Text(
                agent.profile.primaryGoal,
                style: AAADesignSystem.bodyMedium,
              ),
            ),

            const SizedBox(height: AAADesignSystem.space24),

            // Recent Activities
            Text('RECENT ACTIVITIES', style: AAADesignSystem.labelSmall),
            const SizedBox(height: AAADesignSystem.space12),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AAADesignSystem.space12),
                decoration: BoxDecoration(
                  color: AAADesignSystem.spaceVoid.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(
                    AAADesignSystem.radiusMedium,
                  ),
                  border: Border.all(
                    color: AAADesignSystem.accentCyan.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child:
                    _events
                            .where(
                              (e) =>
                                  e.description.contains(
                                    agent.profile.displayName,
                                  ) ||
                                  e.actorId == agent.profile.id,
                            )
                            .isEmpty
                        ? Center(
                          child: Text(
                            'No recent activity',
                            style: AAADesignSystem.bodySmall,
                          ),
                        )
                        : ListView.separated(
                          itemCount:
                              _events
                                  .where(
                                    (e) =>
                                        e.description.contains(
                                          agent.profile.displayName,
                                        ) ||
                                        e.actorId == agent.profile.id,
                                  )
                                  .length,
                          separatorBuilder:
                              (_, __) => const SizedBox(
                                height: AAADesignSystem.space8,
                              ),
                          itemBuilder: (context, index) {
                            final relevantEvents =
                                _events
                                    .where(
                                      (e) =>
                                          e.description.contains(
                                            agent.profile.displayName,
                                          ) ||
                                          e.actorId == agent.profile.id,
                                    )
                                    .toList();
                            final event = relevantEvents[index];

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PulseIndicator(
                                  color: AAADesignSystem.accentGreen,
                                  size: 6,
                                ),
                                const SizedBox(width: AAADesignSystem.space8),
                                Expanded(
                                  child: Text(
                                    event.description,
                                    style: AAADesignSystem.bodySmall,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelSection(String label, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AAADesignSystem.labelSmall),
        const SizedBox(height: AAADesignSystem.space8),
        content,
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EVENT FEED - Bottom Right
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEventFeed() {
    final recentEvents = _events.take(5).toList();

    return SizedBox(
      width: 320,
      child: HolographicPanel(
        padding: const EdgeInsets.all(AAADesignSystem.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                PulseIndicator(color: AAADesignSystem.accentGreen, size: 8),
                const SizedBox(width: AAADesignSystem.space8),
                Text('LIVE EVENTS', style: AAADesignSystem.labelSmall),
              ],
            ),
            const SizedBox(height: AAADesignSystem.space12),
            ...recentEvents.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: AAADesignSystem.space8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 2,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AAADesignSystem.accentCyan.withValues(alpha: 0.8),
                            AAADesignSystem.accentCyan.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AAADesignSystem.space12),
                    Expanded(
                      child: Text(
                        event.description,
                        style: AAADesignSystem.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
