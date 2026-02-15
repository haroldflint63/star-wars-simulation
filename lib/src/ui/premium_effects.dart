import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Premium glassmorphism effect
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Color? color;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.borderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withValues(alpha: opacity),
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: blur,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Animated starfield background
class AnimatedStarfield extends StatefulWidget {
  final int starCount;
  final Color starColor;
  final double speed;

  const AnimatedStarfield({
    super.key,
    this.starCount = 200,
    this.starColor = Colors.white,
    this.speed = 1.0,
  });

  @override
  State<AnimatedStarfield> createState() => _AnimatedStarfieldState();
}

class _AnimatedStarfieldState extends State<AnimatedStarfield>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    // Generate random stars
    final random = math.Random();
    for (int i = 0; i < widget.starCount; i++) {
      _stars.add(
        Star(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 2 + 0.5,
          speed: random.nextDouble() * widget.speed + 0.2,
          twinkleOffset: random.nextDouble() * 2 * math.pi,
        ),
      );
    }
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
          painter: StarfieldPainter(
            stars: _stars,
            animationValue: _controller.value,
            color: widget.starColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class Star {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double twinkleOffset;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.twinkleOffset,
  });
}

class StarfieldPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;
  final Color color;

  StarfieldPainter({
    required this.stars,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (final star in stars) {
      final x = star.x * size.width;
      final y = (star.y + animationValue * star.speed) % 1.0 * size.height;

      // Twinkling effect
      final twinkle =
          (math.sin(animationValue * 2 * math.pi + star.twinkleOffset) + 1) / 2;
      paint.color = color.withValues(alpha: 0.3 + twinkle * 0.7);

      canvas.drawCircle(Offset(x, y), star.size, paint);
    }
  }

  @override
  bool shouldRepaint(StarfieldPainter oldDelegate) => true;
}

/// Neon glow text effect
class NeonText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color glowColor;
  final double glowRadius;

  const NeonText({
    super.key,
    required this.text,
    this.style,
    this.glowColor = Colors.cyan,
    this.glowRadius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        shadows: [
          Shadow(color: glowColor, blurRadius: glowRadius),
          Shadow(
            color: glowColor.withValues(alpha: 0.5),
            blurRadius: glowRadius * 2,
          ),
          const Shadow(
            color: Colors.black87,
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// Holographic card effect
class HolographicCard extends StatefulWidget {
  final Widget child;
  final Color accentColor;

  const HolographicCard({
    super.key,
    required this.child,
    this.accentColor = Colors.cyan,
  });

  @override
  State<HolographicCard> createState() => _HolographicCardState();
}

class _HolographicCardState extends State<HolographicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _shimmerController.value * 4, -1.0),
              end: Alignment(1.0 + _shimmerController.value * 4, 1.0),
              colors: [
                Colors.transparent,
                widget.accentColor.withValues(alpha: 0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Particle effect background
class ParticleBackground extends StatefulWidget {
  final int particleCount;
  final Color particleColor;

  const ParticleBackground({
    super.key,
    this.particleCount = 50,
    this.particleColor = Colors.cyan,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    final random = math.Random();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(
        Particle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 4 + 1,
          speedX: (random.nextDouble() - 0.5) * 0.02,
          speedY: (random.nextDouble() - 0.5) * 0.02,
        ),
      );
    }
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
          painter: ParticlePainter(
            particles: _particles,
            animationValue: _controller.value,
            color: widget.particleColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  double x;
  double y;
  final double size;
  final double speedX;
  final double speedY;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;
  final Color color;

  ParticlePainter({
    required this.particles,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;

    for (final particle in particles) {
      final x =
          ((particle.x + animationValue * particle.speedX * 10) % 1.0) *
          size.width;
      final y =
          ((particle.y + animationValue * particle.speedY * 10) % 1.0) *
          size.height;

      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }

    // Draw connections between nearby particles
    paint.color = color.withValues(alpha: 0.1);
    paint.strokeWidth = 1;
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final x1 =
            ((particles[i].x + animationValue * particles[i].speedX * 10) %
                1.0) *
            size.width;
        final y1 =
            ((particles[i].y + animationValue * particles[i].speedY * 10) %
                1.0) *
            size.height;
        final x2 =
            ((particles[j].x + animationValue * particles[j].speedX * 10) %
                1.0) *
            size.width;
        final y2 =
            ((particles[j].y + animationValue * particles[j].speedY * 10) %
                1.0) *
            size.height;

        final distance = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
        if (distance < 100) {
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

/// Gradient shimmer effect
class GradientShimmer extends StatefulWidget {
  final Widget child;
  final List<Color> colors;

  const GradientShimmer({
    super.key,
    required this.child,
    this.colors = const [Colors.cyan, Colors.blue, Colors.purple],
  });

  @override
  State<GradientShimmer> createState() => _GradientShimmerState();
}

class _GradientShimmerState extends State<GradientShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
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
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + _controller.value * 2, 0),
              end: Alignment(1.0 + _controller.value * 2, 0),
              colors: widget.colors,
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
