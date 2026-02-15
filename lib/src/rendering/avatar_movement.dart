import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;

/// Manages smooth avatar movement between locations
class AvatarMovement {
  final Map<String, vm.Vector3> _currentPositions = {};
  final Map<String, vm.Vector3> _targetPositions = {};
  final Map<String, vm.Vector3> _lastPositions = {};
  final Map<String, double> _movementProgress = {};
  final Map<String, int> _lastLocationChange = {};

  /// Update target position for an agent
  void updateTarget(
    String agentId,
    vm.Vector3 targetPosition,
    int currentTick,
  ) {
    final lastTick = _lastLocationChange[agentId] ?? 0;

    // Only update if location actually changed
    if (_targetPositions[agentId] != targetPosition && currentTick > lastTick) {
      _lastPositions[agentId] = _currentPositions[agentId] ?? targetPosition;
      _targetPositions[agentId] = targetPosition;
      _movementProgress[agentId] = 0.0;
      _lastLocationChange[agentId] = currentTick;
    }
  }

  /// Get interpolated position for smooth movement
  vm.Vector3 getPosition(String agentId, vm.Vector3 defaultPosition) {
    if (!_currentPositions.containsKey(agentId)) {
      _currentPositions[agentId] = defaultPosition;
      _targetPositions[agentId] = defaultPosition;
      _lastPositions[agentId] = defaultPosition;
      return defaultPosition;
    }

    final target = _targetPositions[agentId] ?? defaultPosition;
    final last = _lastPositions[agentId] ?? defaultPosition;
    final progress = _movementProgress[agentId] ?? 1.0;

    if (progress >= 1.0) {
      _currentPositions[agentId] = target;
      return target;
    }

    // Smooth ease-in-out interpolation
    final smoothProgress = _easeInOutCubic(progress);
    final interpolated = vm.Vector3(
      _lerp(last.x, target.x, smoothProgress),
      _lerp(last.y, target.y, smoothProgress),
      _lerp(last.z, target.z, smoothProgress),
    );

    _currentPositions[agentId] = interpolated;
    return interpolated;
  }

  /// Update movement progress (call every frame)
  void updateProgress(String agentId, double delta) {
    final progress = _movementProgress[agentId] ?? 1.0;
    if (progress < 1.0) {
      _movementProgress[agentId] = math.min(1.0, progress + delta * 0.5);
    }
  }

  /// Get movement direction for walking animation
  vm.Vector3 getMovementDirection(String agentId) {
    final current = _currentPositions[agentId];
    final target = _targetPositions[agentId];

    if (current == null || target == null) {
      return vm.Vector3.zero();
    }

    final diff = target - current;
    final distance = diff.length;

    if (distance < 1.0) {
      return vm.Vector3.zero();
    }

    return diff.normalized();
  }

  /// Check if agent is currently moving
  bool isMoving(String agentId) {
    final progress = _movementProgress[agentId] ?? 1.0;
    return progress < 0.95;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }
}
