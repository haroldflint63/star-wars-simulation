import 'package:flutter/material.dart';
import 'aaa_design_system.dart';

/// AAA Game HUD Components
/// Production-quality components for simulation dashboard

// ═══════════════════════════════════════════════════════════════
// HOLOGRAPHIC PANEL - Core UI Container
// ═══════════════════════════════════════════════════════════════

class HolographicPanel extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? accentColor;
  final bool showScanlines;
  final bool showBorder;
  final double opacity;

  const HolographicPanel({
    super.key,
    required this.child,
    this.padding,
    this.accentColor,
    this.showScanlines = true,
    this.showBorder = true,
    this.opacity = 0.15,
  });

  @override
  State<HolographicPanel> createState() => _HolographicPanelState();
}

class _HolographicPanelState extends State<HolographicPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    // Disabled for performance - shimmer causes constant rebuilds
    // ..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AAADesignSystem.accentCyan;

    return Container(
      padding: widget.padding ?? const EdgeInsets.all(AAADesignSystem.space16),
      decoration: BoxDecoration(
        color: AAADesignSystem.spaceDeep.withValues(alpha: widget.opacity),
        borderRadius: BorderRadius.circular(AAADesignSystem.radiusLarge),
        border:
            widget.showBorder
                ? Border.all(color: accent.withValues(alpha: 0.25), width: 1.5)
                : null,
        boxShadow: AAADesignSystem.glowSoft(accent),
      ),
      child: Stack(
        children: [
          // Scanline effect (optional)
          if (widget.showScanlines)
            Positioned.fill(
              child: CustomPaint(
                painter: ScanlinePainter(opacity: 0.02, lineSpacing: 6),
              ),
            ),
          // Content
          widget.child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GAME BUTTON - Interactive Control
// ═══════════════════════════════════════════════════════════════

class GameButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool isPrimary;
  final bool isDisabled;
  final double? width;

  const GameButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.color,
    this.isPrimary = false,
    this.isDisabled = false,
    this.width,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AAADesignSystem.accentCyan;
    final isActive = !widget.isDisabled;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:
            isActive
                ? (_) {
                  setState(() => _isPressed = true);
                }
                : null,
        onTapUp:
            isActive
                ? (_) {
                  setState(() => _isPressed = false);
                  widget.onPressed();
                }
                : null,
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: AAADesignSystem.durationFast,
          curve: AAADesignSystem.easeDefault,
          transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
          width: widget.width,
          padding: EdgeInsets.symmetric(
            horizontal: AAADesignSystem.space24,
            vertical:
                widget.label.isEmpty
                    ? AAADesignSystem.space12
                    : AAADesignSystem.space16,
          ),
          decoration: BoxDecoration(
            gradient:
                widget.isPrimary
                    ? LinearGradient(
                      colors: [
                        color.withValues(
                          alpha:
                              _isPressed
                                  ? 0.8
                                  : _isHovered
                                  ? 0.6
                                  : 0.5,
                        ),
                        color.withValues(
                          alpha:
                              _isPressed
                                  ? 0.6
                                  : _isHovered
                                  ? 0.4
                                  : 0.3,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color:
                !widget.isPrimary
                    ? AAADesignSystem.spaceDeep.withValues(
                      alpha:
                          _isPressed
                              ? 0.9
                              : _isHovered
                              ? 0.8
                              : 0.7,
                    )
                    : null,
            borderRadius: BorderRadius.circular(
              widget.isPrimary
                  ? AAADesignSystem.radiusLarge
                  : AAADesignSystem.radiusMedium,
            ),
            border: Border.all(
              color: color.withValues(
                alpha:
                    isActive
                        ? (_isPressed
                            ? 0.9
                            : _isHovered
                            ? 0.7
                            : 0.5)
                        : 0.2,
              ),
              width:
                  _isPressed
                      ? 2.5
                      : _isHovered
                      ? 2
                      : 1.5,
            ),
            boxShadow:
                isActive
                    ? [
                      // Inner glow
                      BoxShadow(
                        color: color.withValues(
                          alpha:
                              _isPressed
                                  ? 0.3
                                  : _isHovered
                                  ? 0.2
                                  : 0.1,
                        ),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                      // Outer glow
                      if (_isHovered || widget.isPrimary)
                        BoxShadow(
                          color: color.withValues(
                            alpha:
                                _isPressed
                                    ? 0.5
                                    : _isHovered
                                    ? 0.4
                                    : 0.3,
                          ),
                          blurRadius:
                              _isPressed
                                  ? 24
                                  : _isHovered
                                  ? 20
                                  : 16,
                          spreadRadius: _isPressed ? 2 : 0,
                        ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color:
                      isActive
                          ? (_isHovered ? color : color.withValues(alpha: 0.9))
                          : AAADesignSystem.textMuted,
                  size: 20,
                ),
                if (widget.label.isNotEmpty)
                  const SizedBox(width: AAADesignSystem.space8),
              ],
              if (widget.label.isNotEmpty)
                Text(
                  widget.label,
                  style: AAADesignSystem.labelLarge.copyWith(
                    color:
                        isActive
                            ? (_isHovered
                                ? color
                                : color.withValues(alpha: 0.9))
                            : AAADesignSystem.textMuted,
                    fontWeight: FontWeight.w700,
                    shadows:
                        _isHovered && isActive
                            ? [
                              Shadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 12,
                              ),
                            ]
                            : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TIMELINE CONTROL - Game-style Play/Pause
// ═══════════════════════════════════════════════════════════════

class TimelineControl extends StatelessWidget {
  final bool isRunning;
  final double speed;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final ValueChanged<double> onSpeedChange;

  const TimelineControl({
    super.key,
    required this.isRunning,
    required this.speed,
    required this.onPlay,
    required this.onPause,
    required this.onSpeedChange,
  });

  @override
  Widget build(BuildContext context) {
    return HolographicPanel(
      padding: const EdgeInsets.all(AAADesignSystem.space12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          _TimelineButton(
            icon: isRunning ? Icons.pause : Icons.play_arrow,
            onPressed: isRunning ? onPause : onPlay,
            isActive: isRunning,
            tooltip: isRunning ? 'Pause' : 'Play',
          ),
          const SizedBox(width: AAADesignSystem.space8),
          // Speed indicator
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AAADesignSystem.space12,
              vertical: AAADesignSystem.space8,
            ),
            decoration: BoxDecoration(
              color: AAADesignSystem.spaceVoid.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AAADesignSystem.radiusSmall),
              border: Border.all(
                color: AAADesignSystem.accentCyan.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.speed,
                  size: 14,
                  color: AAADesignSystem.accentCyanMuted,
                ),
                const SizedBox(width: AAADesignSystem.space8),
                Text(
                  '${speed.toStringAsFixed(1)}x',
                  style: AAADesignSystem.mono,
                ),
              ],
            ),
          ),
          const SizedBox(width: AAADesignSystem.space8),
          // Speed controls
          _TimelineButton(
            icon: Icons.remove,
            onPressed: speed > 0.5 ? () => onSpeedChange(speed - 0.5) : () {},
            tooltip: 'Slower',
            isSmall: true,
          ),
          const SizedBox(width: AAADesignSystem.space4),
          _TimelineButton(
            icon: Icons.add,
            onPressed: speed < 3.0 ? () => onSpeedChange(speed + 0.5) : () {},
            tooltip: 'Faster',
            isSmall: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final String? tooltip;
  final bool isSmall;

  const _TimelineButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.tooltip,
    this.isSmall = false,
  });

  @override
  State<_TimelineButton> createState() => _TimelineButtonState();
}

class _TimelineButtonState extends State<_TimelineButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.isSmall ? 32.0 : 44.0;
    final iconSize = widget.isSmall ? 16.0 : 20.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: AAADesignSystem.durationFast,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color:
                  widget.isActive
                      ? AAADesignSystem.accentCyan.withValues(alpha: 0.2)
                      : AAADesignSystem.spaceDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AAADesignSystem.radiusSmall),
              border: Border.all(
                color: AAADesignSystem.accentCyan.withValues(
                  alpha:
                      _isHovered
                          ? 0.6
                          : widget.isActive
                          ? 0.5
                          : 0.3,
                ),
                width: _isHovered ? 2 : 1,
              ),
              boxShadow:
                  _isHovered || widget.isActive
                      ? AAADesignSystem.glowSoft(AAADesignSystem.accentCyan)
                      : null,
            ),
            child: Icon(
              widget.icon,
              size: iconSize,
              color: AAADesignSystem.accentCyan,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STAT DISPLAY - Numeric Indicators
// ═══════════════════════════════════════════════════════════════

class StatDisplay extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  const StatDisplay({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? AAADesignSystem.accentCyan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: AAADesignSystem.textTertiary),
              const SizedBox(width: AAADesignSystem.space4),
            ],
            Text(label.toUpperCase(), style: AAADesignSystem.labelSmall),
          ],
        ),
        const SizedBox(height: AAADesignSystem.space4),
        Text(
          value,
          style: AAADesignSystem.headingMedium.copyWith(
            color: displayColor,
            shadows: [
              Shadow(color: displayColor.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PULSE INDICATOR - Event Visualization
// ═══════════════════════════════════════════════════════════════

class PulseIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const PulseIndicator({
    super.key,
    this.color = AAADesignSystem.accentCyan,
    this.size = 12,
  });

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: 0.6 * (1 - _controller.value),
                ),
                blurRadius: widget.size * _controller.value * 2,
                spreadRadius: widget.size * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// INFO TOOLTIP - Contextual Information
// ═══════════════════════════════════════════════════════════════

class GameTooltip extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget>? children;

  const GameTooltip({
    super.key,
    required this.title,
    this.description,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(AAADesignSystem.space16),
      decoration: BoxDecoration(
        color: AAADesignSystem.spaceVoid.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AAADesignSystem.radiusMedium),
        border: Border.all(
          color: AAADesignSystem.accentCyan.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: AAADesignSystem.glowMedium(AAADesignSystem.accentCyan),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AAADesignSystem.headingSmall),
          if (description != null) ...[
            const SizedBox(height: AAADesignSystem.space8),
            Text(description!, style: AAADesignSystem.bodySmall),
          ],
          if (children != null) ...[
            const SizedBox(height: AAADesignSystem.space12),
            ...children!,
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SCANLINE PAINTER - Holographic Effect
// ═══════════════════════════════════════════════════════════════

class ScanlinePainter extends CustomPainter {
  final double opacity;
  final double lineSpacing;

  ScanlinePainter({this.opacity = 0.05, this.lineSpacing = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(ScanlinePainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════
// GAME GRID - Background Effect
// ═══════════════════════════════════════════════════════════════

class GameGrid extends StatefulWidget {
  final Color gridColor;
  final double spacing;
  final double opacity;

  const GameGrid({
    super.key,
    this.gridColor = AAADesignSystem.accentCyan,
    this.spacing = 40,
    this.opacity = 0.1,
  });

  @override
  State<GameGrid> createState() => _GameGridState();
}

class _GameGridState extends State<GameGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 40),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: GridPainter(
            color: widget.gridColor,
            spacing: widget.spacing,
            opacity: widget.opacity,
            offset: _controller.value * widget.spacing,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double opacity;
  final double offset;

  GridPainter({
    required this.color,
    required this.spacing,
    required this.opacity,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..strokeWidth = 1;

    // Vertical lines
    for (double x = offset % spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = offset % spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => offset != oldDelegate.offset;
}
