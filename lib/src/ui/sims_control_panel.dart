import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../agent.dart';
import '../world.dart';
import '../daily_tasks.dart';
import 'lego_ui_system.dart';
import 'premium_effects.dart';

/// Sims-style control panel with agent info and controls
class SimsControlPanel extends StatelessWidget {
  const SimsControlPanel({
    super.key,
    required this.selectedAgent,
    required this.recentEvents,
    required this.isRunning,
    required this.onRunSimulation,
    required this.onPauseSimulation,
    required this.onSpeedChange,
    this.speed = 1.0,
  });

  final Agent? selectedAgent;
  final List<WorldEvent> recentEvents;
  final bool isRunning;
  final VoidCallback onRunSimulation;
  final VoidCallback onPauseSimulation;
  final ValueChanged<double> onSpeedChange;
  final double speed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            LegoUISystem.spaceBlack.withValues(alpha: 0.95),
            const Color(0xFF1a1a2e).withValues(alpha: 0.95),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: LegoUISystem.starWarsGold.withValues(alpha: 0.6),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: LegoUISystem.starWarsGold.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top control bar (similar to Sims)
          _buildTopControlBar(context),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left panel - Agent info
                if (selectedAgent != null)
                  SizedBox(width: 320, child: _buildAgentPanel(context)),

                // Center - Activity feed
                Expanded(child: _buildActivityFeed(context)),

                // Right panel - Speed and controls
                SizedBox(width: 280, child: _buildControlsPanel(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControlBar(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.4),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.cyan.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.cyan.withValues(alpha: 0.3),
                  Colors.cyan.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Icon(Icons.stars, color: Colors.cyan.shade200, size: 24),
          ),
          const SizedBox(width: 16),
          NeonText(
            text: 'STAR WARS GALAXY',
            glowColor: LegoUISystem.starWarsGold,
            glowRadius: 25,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: LegoUISystem.starWarsGold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          if (isRunning)
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'RUNNING',
                  style: GoogleFonts.orbitron(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAgentPanel(BuildContext context) {
    if (selectedAgent == null) return const SizedBox();

    return LegoPanel(
      color: LegoUISystem.legoDarkGray.withValues(alpha: 0.9),
      padding: const EdgeInsets.all(20),
      showStuds: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent avatar with glassmorphic effect
          Center(
            child: GlassmorphicContainer(
              blur: 15,
              opacity: 0.15,
              color: _getAgentColor(selectedAgent!.profile.id),
              borderRadius: BorderRadius.circular(60),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _getAgentColor(selectedAgent!.profile.id),
                      _getAgentColor(
                        selectedAgent!.profile.id,
                      ).withValues(alpha: 0.4),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.cyan.withValues(alpha: 0.6),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getAgentColor(
                        selectedAgent!.profile.id,
                      ).withValues(alpha: 0.6),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: Colors.cyan.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    selectedAgent!.profile.displayName[0].toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Agent name with shimmer effect
          Center(
            child: GradientShimmer(
              colors: [
                Colors.cyan,
                Colors.blue,
                LegoUISystem.starWarsGold,
                Colors.cyan,
              ],
              child: Text(
                selectedAgent!.profile.displayName,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          const Divider(color: Colors.tealAccent, thickness: 1),
          const SizedBox(height: 8),

          // Agent stats
          _buildStatRow('ID', selectedAgent!.profile.id),
          _buildStatRow('Goal', selectedAgent!.profile.primaryGoal),
          _buildStatRow('Home', selectedAgent!.profile.homeLocationId),

          const SizedBox(height: 16),

          // Daily Mission Log
          Text(
            'MISSION LOG',
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),

          Expanded(child: _buildDailyTasks()),
        ],
      ),
    );
  }

  Widget _buildDailyTasks() {
    if (selectedAgent == null) return const SizedBox();

    final tasks = DailyTaskSchedule.getTasksForAgent(selectedAgent!.profile.id);
    final currentTick = recentEvents.isNotEmpty ? recentEvents.last.tick : 0;
    final currentTaskIndex = currentTick % tasks.length;

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isCurrent = index == currentTaskIndex;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isCurrent
                    ? _getAgentColor(
                      selectedAgent!.profile.id,
                    ).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  isCurrent
                      ? _getAgentColor(selectedAgent!.profile.id)
                      : Colors.white.withValues(alpha: 0.1),
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (isCurrent)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Text(
                  task,
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    color: isCurrent ? Colors.white : Colors.white70,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              color: Colors.tealAccent.withValues(alpha: 0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildRelationships() {
  //   if (selectedAgent == null) return const SizedBox();

  //   final relationships = selectedAgent!.relationships.topSignals(
  //     agentId: selectedAgent!.profile.id,
  //   );

  //   return ListView.builder(
  //     itemCount: relationships.length,
  //     itemBuilder: (context, index) {
  //       final signal = relationships[index];
  //       return Container(
  //         margin: const EdgeInsets.only(bottom: 8),
  //         padding: const EdgeInsets.all(8),
  //         decoration: BoxDecoration(
  //           color: Colors.white.withValues(alpha: 0.05),
  //           borderRadius: BorderRadius.circular(6),
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               signal.otherAgentId.toUpperCase(),
  //               style: GoogleFonts.orbitron(
  //                 fontSize: 11,
  //                 color: Colors.white,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             const SizedBox(height: 4),
  //             _buildRelationshipBar('Affinity', signal.affinity, Colors.pink),
  //             _buildRelationshipBar('Trust', signal.trust, Colors.blue),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // Widget _buildRelationshipBar(String label, double value, Color color) {
  //   return Padding(
  //     padding: const EdgeInsets.only(top: 4),
  //     child: Row(
  //       children: [
  //         SizedBox(
  //           width: 50,
  //           child: Text(
  //             label,
  //             style: GoogleFonts.robotoMono(fontSize: 9, color: Colors.white70),
  //           ),
  //         ),
  //         Expanded(
  //           child: Stack(
  //             children: [
  //               Container(
  //                 height: 8,
  //                 decoration: BoxDecoration(
  //                   color: Colors.white.withValues(alpha: 0.1),
  //                   borderRadius: BorderRadius.circular(4),
  //                 ),
  //               ),
  //               FractionallySizedBox(
  //                 widthFactor: value,
  //                 child: Container(
  //                   height: 8,
  //                   decoration: BoxDecoration(
  //                     color: color,
  //                     borderRadius: BorderRadius.circular(4),
  //                     boxShadow: [
  //                       BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         const SizedBox(width: 8),
  //         Text(
  //           '${(value * 100).toInt()}%',
  //           style: GoogleFonts.robotoMono(fontSize: 9, color: Colors.white70),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildActivityFeed(BuildContext context) {
    return LegoPanel(
      color: LegoUISystem.spaceBlack.withValues(alpha: 0.85),
      padding: const EdgeInsets.all(20),
      showStuds: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.cyan.withValues(alpha: 0.4),
                      Colors.cyan.withValues(alpha: 0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withValues(alpha: 0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.cyan.shade100,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'GALAXY EVENTS',
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan.shade100,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(
                      color: Colors.cyan.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${recentEvents.length} EVENTS',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: Colors.cyan.shade200,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.cyan.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: recentEvents.length,
              itemBuilder: (context, index) {
                final event = recentEvents[recentEvents.length - 1 - index];
                return _buildEventItem(event);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(WorldEvent event) {
    final isCombat =
        event.description.toLowerCase().contains('fighting') ||
        event.description.toLowerCase().contains('combat') ||
        event.description.toLowerCase().contains('battling') ||
        event.description.toLowerCase().contains('dueling') ||
        event.description.toLowerCase().contains('sparring');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isCombat
                  ? [
                    Colors.red.withValues(alpha: 0.15),
                    Colors.orange.withValues(alpha: 0.08),
                  ]
                  : [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.04),
                  ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isCombat
                  ? Colors.red.withValues(alpha: 0.5)
                  : Colors.cyan.withValues(alpha: 0.3),
          width: isCombat ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isCombat
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.cyan.withValues(alpha: 0.1),
            blurRadius: isCombat ? 15 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isCombat)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flash_on,
                    color: Colors.red.shade200,
                    size: 14,
                  ),
                ),
              if (isCombat) const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.tealAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'TICK ${event.tick}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    color: Colors.tealAccent.shade200,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _getLocationColor(
                    event.locationId,
                  ).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getLocationColor(
                      event.locationId,
                    ).withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  event.locationId.toUpperCase(),
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel(BuildContext context) {
    return LegoPanel(
      color: LegoUISystem.legoDarkGray.withValues(alpha: 0.95),
      padding: const EdgeInsets.all(20),
      showStuds: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SIMULATION CONTROLS',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),

            // LEGO-style Play/Pause button
            LegoButton(
              label: isRunning ? 'PAUSE' : 'PLAY',
              icon: isRunning ? Icons.pause : Icons.play_arrow,
              onPressed: isRunning ? onPauseSimulation : onRunSimulation,
              color:
                  isRunning ? LegoUISystem.legoOrange : LegoUISystem.legoGreen,
              isLarge: true,
            ),

            const SizedBox(height: 16),

            // Speed control
            Text(
              'SPEED',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.cyan.withValues(alpha: 0.3),
                        Colors.cyan.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.speed,
                    color: Colors.cyan.shade200,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.cyan.shade400,
                      inactiveTrackColor: Colors.cyan.shade900.withValues(
                        alpha: 0.3,
                      ),
                      thumbColor: Colors.cyan.shade200,
                      overlayColor: Colors.cyan.withValues(alpha: 0.3),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: speed,
                      min: 0.5,
                      max: 3.0,
                      divisions: 5,
                      onChanged: onSpeedChange,
                    ),
                  ),
                ),
                Text(
                  '${speed.toStringAsFixed(1)}x',
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Camera controls hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.touch_app, color: Colors.lightBlue, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'CONTROLS',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildControlHint('Pan', 'Drag to move'),
                  _buildControlHint('Zoom', 'Pinch to zoom'),
                  _buildControlHint('Select', 'Tap agent'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildStatLine('Events', recentEvents.length.toString()),
                  const SizedBox(height: 6),
                  _buildStatLine(
                    'Selected',
                    selectedAgent?.profile.displayName ?? 'None',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlHint(String action, String description) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$action: ',
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              color: Colors.lightBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            description,
            style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStatLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.white70),
        ),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            fontSize: 11,
            color: Colors.tealAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getAgentColor(String agentId) {
    switch (agentId) {
      case 'luke':
        return const Color(0xFF87CEEB); // Sky blue
      case 'leia':
        return Colors.white;
      case 'han':
        return const Color(0xFFB8860B); // Dark goldenrod
      default:
        return Colors.teal.shade300;
    }
  }

  Color _getLocationColor(String locationId) {
    switch (locationId) {
      case 'tatooine_cantina':
        return const Color(0xFFD4A574); // Desert sand
      case 'jedi_temple':
        return const Color(0xFF4169E1); // Royal blue
      case 'cloud_city':
        return const Color(0xFFFFD700); // Gold
      case 'dagobah_swamp':
        return const Color(0xFF2E8B57); // Sea green
      case 'death_star':
        return const Color(0xFF708090); // Slate gray
      case 'endor_forest':
        return const Color(0xFF228B22); // Forest green
      case 'hoth_base':
        return const Color(0xFFADD8E6); // Light blue
      case 'naboo_palace':
        return const Color(0xFFDDA0DD); // Plum
      default:
        return Colors.purple;
    }
  }
}

/// Enhanced button with hover effects and animations
class EnhancedControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final Color? color;

  const EnhancedControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.color,
  });

  @override
  State<EnhancedControlButton> createState() => _EnhancedControlButtonState();
}

class _EnhancedControlButtonState extends State<EnhancedControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final buttonColor =
        widget.color ?? (widget.isPrimary ? Colors.cyan : Colors.blue);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    buttonColor.withValues(alpha: _isHovered ? 0.4 : 0.3),
                    buttonColor.withValues(alpha: _isHovered ? 0.25 : 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: buttonColor.withValues(alpha: _isHovered ? 0.8 : 0.5),
                  width: _isHovered ? 2 : 1.5,
                ),
                boxShadow:
                    _isHovered
                        ? [
                          BoxShadow(
                            color: buttonColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                        : [
                          BoxShadow(
                            color: buttonColor.withValues(alpha: 0.2),
                            blurRadius: 10,
                          ),
                        ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows:
                          _isHovered
                              ? [Shadow(color: buttonColor, blurRadius: 8)]
                              : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
