import 'memory.dart';
import 'relationships.dart';
import 'world.dart';

/// A single concrete plan action for an agent.
class PlanAction {
  /// Creates an action.
  const PlanAction({required this.locationId, required this.description});

  /// Target location for this action.
  final String locationId;

  /// Human-readable action text.
  final String description;
}

/// Strategy interface to produce next-step plan actions.
abstract class Planner {
  /// Produces an action from current world snapshot and memories.
  Future<PlanAction> nextAction({
    required WorldSnapshot snapshot,
    required MemoryStore memory,
    required String agentId,
    required String primaryGoal,
    required String fallbackLocationId,
    required List<RelationshipSignal> socialSignals,
  });
}

/// Heuristic planner tuned for predictable sandbox behavior.
class HeuristicPlanner implements Planner {
  /// Creates planner.
  const HeuristicPlanner();

  @override
  Future<PlanAction> nextAction({
    required WorldSnapshot snapshot,
    required MemoryStore memory,
    required String agentId,
    required String primaryGoal,
    required String fallbackLocationId,
    required List<RelationshipSignal> socialSignals,
  }) async {
    final List<MemoryItem> recalled = memory.recall(
      query: primaryGoal,
      currentTick: snapshot.tick,
      limit: 3,
    );

    String selectedLocationId = fallbackLocationId;
    if (recalled.isNotEmpty) {
      final String? memoryLocation = _extractKnownLocation(
        tags: recalled.first.tags,
        snapshot: snapshot,
      );
      if (memoryLocation != null) {
        selectedLocationId = memoryLocation;
      }
    }

    final String socialHint =
        socialSignals.isNotEmpty
            ? 'with ${socialSignals.first.otherAgentId}'
            : 'solo';
    final String memoryHint =
        recalled.isNotEmpty
            ? 'informed by memory: "${recalled.first.text}"'
            : 'based on baseline routine';

    return PlanAction(
      locationId: selectedLocationId,
      description: 'Work on "$primaryGoal" $socialHint ($memoryHint)',
    );
  }

  String? _extractKnownLocation({
    required List<String> tags,
    required WorldSnapshot snapshot,
  }) {
    for (final String candidate in tags) {
      final bool exists = snapshot.locations.any((Location location) {
        return location.id == candidate;
      });
      if (exists) {
        return candidate;
      }
    }
    return null;
  }
}
