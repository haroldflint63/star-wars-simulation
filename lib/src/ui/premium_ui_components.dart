import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../rendering/sci_fi_design_system.dart';
import '../rendering/premium_building_painter.dart';

/// Premium building marker with animation
class GalaxyBuildingMarker extends StatefulWidget {
  final String locationName;
  final BuildingStyle style;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const GalaxyBuildingMarker({
    super.key,
    required this.locationName,
    this.style = BuildingStyle.tower,
    this.accentColor = SciFiDesignSystem.accentPrimary,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<GalaxyBuildingMarker> createState() => _GalaxyBuildingMarkerState();
}

class _GalaxyBuildingMarkerState extends State<GalaxyBuildingMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    if (widget.isSelected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GalaxyBuildingMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : (widget.isSelected ? 1.05 : 1.0),
          duration: SciFiDesignSystem.animationFast,
          curve: SciFiDesignSystem.curveSnappy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Building visual
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(120, 180),
                      painter: PremiumBuildingPainter(
                        accentColor: widget.accentColor,
                        buildingHeight: 120,
                        style: widget.style,
                        animationValue:
                            widget.isSelected
                                ? _pulseController.value * 0.6
                                : 0.0,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: SciFiDesignSystem.space8),

              // Label pill
              NeonLabelPill(
                text: widget.locationName,
                isActive: widget.isSelected,
                accentColor: widget.accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clean sci-fi label with integrated neon effect
class NeonLabelPill extends StatelessWidget {
  final String text;
  final bool isActive;
  final Color accentColor;

  const NeonLabelPill({
    super.key,
    required this.text,
    this.isActive = false,
    this.accentColor = SciFiDesignSystem.accentPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SciFiDesignSystem.space12,
        vertical: SciFiDesignSystem.space4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isActive
                  ? [
                    accentColor.withValues(alpha: 0.3),
                    accentColor.withValues(alpha: 0.15),
                  ]
                  : [
                    SciFiDesignSystem.neutralDark.withValues(alpha: 0.8),
                    SciFiDesignSystem.neutralDark.withValues(alpha: 0.6),
                  ],
        ),
        borderRadius: BorderRadius.circular(SciFiDesignSystem.radiusMedium),
        border: Border.all(
          color:
              isActive
                  ? accentColor.withValues(alpha: 0.6)
                  : SciFiDesignSystem.neutralMid,
          width: 1.5,
        ),
        boxShadow:
            isActive
                ? SciFiDesignSystem.neonGlow(color: accentColor, intensity: 0.4)
                : null,
      ),
      child: Text(
        text.toUpperCase(),
        style: SciFiDesignSystem.labelSecondary.copyWith(
          color: isActive ? Colors.white : SciFiDesignSystem.neutralLight,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Animated mission callout bubble
class MissionCalloutBubble extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const MissionCalloutBubble({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.info_outline,
    this.accentColor = SciFiDesignSystem.accentPrimary,
  });

  @override
  State<MissionCalloutBubble> createState() => _MissionCalloutBubbleState();
}

class _MissionCalloutBubbleState extends State<MissionCalloutBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: SciFiDesignSystem.animationMedium,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: SciFiDesignSystem.curveElastic,
      ),
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _slideController,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(SciFiDesignSystem.space16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                SciFiDesignSystem.spaceDeep.withValues(alpha: 0.95),
                SciFiDesignSystem.spaceMid.withValues(alpha: 0.90),
              ],
            ),
            borderRadius: BorderRadius.circular(SciFiDesignSystem.radiusLarge),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              SciFiDesignSystem.ambientOcclusion(),
              ...SciFiDesignSystem.neonGlow(
                color: widget.accentColor,
                intensity: 0.3,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(SciFiDesignSystem.space8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                        SciFiDesignSystem.radiusSmall,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: SciFiDesignSystem.space12),
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: SciFiDesignSystem.labelPrimary.copyWith(
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: SciFiDesignSystem.space12),

              // Description
              Text(widget.description, style: SciFiDesignSystem.labelSecondary),

              const SizedBox(height: SciFiDesignSystem.space8),

              // Bottom accent line
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.accentColor,
                      widget.accentColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Performant starfield background
class StarfieldBackground extends StatefulWidget {
  final int starCount;

  const StarfieldBackground({super.key, this.starCount = 200});

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _driftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _driftController,
        builder: (context, child) {
          return CustomPaint(
            painter: _StarfieldPainter(
              starCount: widget.starCount,
              driftValue: _driftController.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final int starCount;
  final double driftValue;

  _StarfieldPainter({required this.starCount, required this.driftValue});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // Fixed seed
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < starCount; i++) {
      final x =
          (random.nextDouble() * size.width + driftValue * 20) % size.width;
      final y = random.nextDouble() * size.height;
      final brightness = 0.3 + random.nextDouble() * 0.7;
      final starSize = 1.0 + random.nextDouble() * 1.5;

      paint.color = Colors.white.withValues(alpha: brightness);
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter oldDelegate) {
    return oldDelegate.driftValue != driftValue;
  }
}
