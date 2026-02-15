import 'memory.dart';
import 'planner.dart';
import 'relationships.dart';
import 'world.dart';

/// Immutable profile values for an agent.
class AgentProfile {
  /// Creates profile.
  const AgentProfile({
    required this.id,
    required this.displayName,
    required this.primaryGoal,
    required this.homeLocationId,
  });

  /// Stable id.
  final String id;

  /// Human-readable name.
  final String displayName;

  /// Top-priority goal.
  final String primaryGoal;

  /// Default location when no better action exists.
  final String homeLocationId;
}

/// Simulation agent with memory and planning.
class Agent {
  /// Creates an agent.
  Agent({
    required this.profile,
    required this.planner,
    required this.relationships,
  }) : memory = MemoryStore();

  /// Agent profile.
  final AgentProfile profile;

  /// Planner implementation.
  final Planner planner;

  /// Shared social graph.
  final RelationshipGraph relationships;

  /// Agent memory.
  final MemoryStore memory;

  /// Ingests world signals into memory.
  void perceive(WorldSnapshot snapshot) {
    for (final WorldEvent event in snapshot.recentEvents) {
      final double socialAffinity = relationships.affinity(
        profile.id,
        event.actorId,
      );
      memory.observeEvent(
        event,
        observerId: profile.id,
        socialAffinity: socialAffinity,
      );
    }
  }

  /// Produces this tick's event for the agent.
  Future<WorldEvent> act(WorldSnapshot snapshot) async {
    final PlanAction action = await planner.nextAction(
      snapshot: snapshot,
      memory: memory,
      agentId: profile.id,
      primaryGoal: profile.primaryGoal,
      fallbackLocationId: profile.homeLocationId,
      socialSignals: relationships.topSignals(agentId: profile.id),
    );

    final String description =
        '${profile.displayName} at ${action.locationId}: '
        '${action.description}';

    return WorldEvent(
      actorId: profile.id,
      locationId: action.locationId,
      description: description,
      tick: snapshot.tick,
      tags: <String>[profile.id, action.locationId, 'action'],
    );
  }
}
