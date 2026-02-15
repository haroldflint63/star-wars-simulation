import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// LEGO Star Wars UI Design System
/// Professional-grade component library inspired by LEGO Star Wars Nintendo Switch
/// Built with senior Roblox engineer quality standards
class LegoUISystem {
  // LEGO Brand Colors
  static const Color legoYellow = Color(0xFFFFC107);
  static const Color legoOrange = Color(0xFFFF9800);
  static const Color legoRed = Color(0xFFF44336);
  static const Color legoBlue = Color(0xFF2196F3);
  static const Color legoGreen = Color(0xFF4CAF50);
  static const Color legoDarkGray = Color(0xFF37474F);
  static const Color legoLightGray = Color(0xFFB0BEC5);

  // Star Wars themed colors
  static const Color lightsaberBlue = Color(0xFF00B4FF);
  static const Color lightsaberGreen = Color(0xFF00FF41);
  static const Color lightsaberRed = Color(0xFFFF1744);
  static const Color starWarsGold = Color(0xFFFFD700);
  static const Color spaceBlack = Color(0xFF0D1117);

  // Spacing
  static const double spaceTiny = 4.0;
  static const double spaceSmall = 8.0;
  static const double spaceMedium = 16.0;
  static const double spaceLarge = 24.0;
  static const double spaceXLarge = 32.0;

  // Border radius (chunky LEGO style)
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // Animations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 250);
  static const Duration animationSlow = Duration(milliseconds: 400);

  static const Curve curveSnappy = Curves.easeOutCubic;
  static const Curve curveBouncy = Curves.elasticOut;
}

/// LEGO-style chunky button with 3D effect
class LegoButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color color;
  final bool isLarge;
  final bool isEnabled;

  const LegoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = LegoUISystem.legoYellow,
    this.isLarge = false,
    this.isEnabled = true,
  });

  @override
  State<LegoButton> createState() => _LegoButtonState();
}

class _LegoButtonState extends State<LegoButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: LegoUISystem.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isEnabled) {
      setState(() => _isPressed = true);
      _bounceController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.isEnabled) {
      setState(() => _isPressed = false);
      _bounceController.reverse();
      widget.onPressed();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _bounceController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor =
        widget.isEnabled ? widget.color : LegoUISystem.legoLightGray;
    final shadowColor =
        widget.isEnabled
            ? buttonColor.withValues(alpha: 0.5)
            : Colors.grey.withValues(alpha: 0.3);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: LegoUISystem.animationFast,
              curve: LegoUISystem.curveSnappy,
              padding: EdgeInsets.symmetric(
                horizontal: widget.isLarge ? 32 : 24,
                vertical: widget.isLarge ? 18 : 14,
              ),
              decoration: BoxDecoration(
                // LEGO brick layered 3D effect
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _lighten(buttonColor, 0.15),
                    buttonColor,
                    _darken(buttonColor, 0.15),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(LegoUISystem.radiusMedium),
                border: Border.all(color: _darken(buttonColor, 0.3), width: 3),
                boxShadow:
                    _isPressed
                        ? [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: widget.isLarge ? 28 : 22,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    SizedBox(width: LegoUISystem.spaceSmall),
                  ],
                  Text(
                    widget.label,
                    style: GoogleFonts.poppins(
                      fontSize: widget.isLarge ? 20 : 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      height: 1.0,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// LEGO-style panel with studs (bumps) effect
class LegoPanel extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets? padding;
  final bool showStuds;

  const LegoPanel({
    super.key,
    required this.child,
    this.color = LegoUISystem.legoDarkGray,
    this.padding,
    this.showStuds = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(LegoUISystem.spaceLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(color, 0.1), color, _darken(color, 0.1)],
        ),
        borderRadius: BorderRadius.circular(LegoUISystem.radiusLarge),
        border: Border.all(color: _darken(color, 0.3), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // LEGO studs decoration
          if (showStuds)
            Positioned.fill(
              child: CustomPaint(
                painter: _LegoStudsPainter(color: _darken(color, 0.15)),
              ),
            ),
          child,
        ],
      ),
    );
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// Painter for LEGO brick studs pattern
class _LegoStudsPainter extends CustomPainter {
  final Color color;

  _LegoStudsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;

    const studRadius = 6.0;
    const spacing = 40.0;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), studRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// LEGO-style toggle switch (like in LEGO games)
class LegoToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const LegoToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: LegoUISystem.animationNormal,
            curve: LegoUISystem.curveSnappy,
            width: 60,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    value
                        ? [
                          LegoUISystem.legoGreen,
                          LegoUISystem.legoGreen.withValues(alpha: 0.8),
                        ]
                        : [
                          LegoUISystem.legoRed,
                          LegoUISystem.legoRed.withValues(alpha: 0.8),
                        ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (value ? LegoUISystem.legoGreen : LegoUISystem.legoRed)
                      .withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedAlign(
              duration: LegoUISystem.animationNormal,
              curve: LegoUISystem.curveBouncy,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// LEGO-style header with bold text
class LegoHeader extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const LegoHeader({
    super.key,
    required this.text,
    this.color = LegoUISystem.legoYellow,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LegoUISystem.spaceMedium,
        vertical: LegoUISystem.spaceSmall,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(LegoUISystem.radiusSmall),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: LegoUISystem.spaceSmall),
          ],
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2.0,
              shadows: const [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
