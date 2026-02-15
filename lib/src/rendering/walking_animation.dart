import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vm;

/// Manages walking animations for characters
class WalkingAnimation {
  final Map<String, double> _walkCycles = {};
  final Map<String, vm.Vector3> _lastPositions = {};
  final Map<String, vm.Vector3> _movementDirections = {};
  final Map<String, bool> _isWalking = {};

  /// Update walking animation state
  void update(String agentId, vm.Vector3 currentPosition, double deltaTime) {
    final lastPos = _lastPositions[agentId];

    if (lastPos == null) {
      _lastPositions[agentId] = currentPosition;
      _walkCycles[agentId] = 0.0;
      _isWalking[agentId] = false;
      return;
    }

    // Calculate movement distance
    final distance = (currentPosition - lastPos).length;

    if (distance > 0.1) {
      // Character is moving
      _isWalking[agentId] = true;

      // Calculate direction
      final direction = (currentPosition - lastPos).normalized();
      _movementDirections[agentId] = direction;

      // Update walk cycle based on movement speed
      final speed = distance / deltaTime;
      final cycleSpeed = speed * 0.05; // Adjust for visual speed
      _walkCycles[agentId] = (_walkCycles[agentId] ?? 0.0) + cycleSpeed;
    } else {
      // Character stopped
      _isWalking[agentId] = false;
      // Gradually stop animation
      final currentCycle = _walkCycles[agentId] ?? 0.0;
      _walkCycles[agentId] = currentCycle * 0.9;
    }

    _lastPositions[agentId] = currentPosition;
  }

  /// Get animation values for drawing
  Map<String, double> getAnimationValues(String agentId) {
    final cycle = _walkCycles[agentId] ?? 0.0;
    final isWalking = _isWalking[agentId] ?? false;

    if (!isWalking) {
      // Idle pose
      return {
        'leftLegAngle': 0.0,
        'rightLegAngle': 0.0,
        'leftArmAngle': 0.1,
        'rightArmAngle': -0.1,
        'bodyBob': 0.0,
        'headTurn': 0.0,
      };
    }

    // Walking cycle
    final walkPhase = cycle % (2 * math.pi);

    return {
      'leftLegAngle': math.sin(walkPhase) * 0.4,
      'rightLegAngle': -math.sin(walkPhase) * 0.4,
      'leftArmAngle': -math.sin(walkPhase) * 0.3,
      'rightArmAngle': math.sin(walkPhase) * 0.3,
      'bodyBob': math.sin(walkPhase * 2).abs() * 2.0,
      'headTurn': math.sin(walkPhase * 0.5) * 0.05,
    };
  }

  /// Get direction character is facing
  double getFacingAngle(String agentId) {
    final direction = _movementDirections[agentId];
    if (direction == null) return 0.0;

    return math.atan2(direction.z, direction.x);
  }

  /// Check if character is currently walking
  bool isWalking(String agentId) {
    return _isWalking[agentId] ?? false;
  }
}
