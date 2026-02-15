import 'agent.dart';
import 'memory.dart';
import 'ollama.dart';
import 'planner.dart';
import 'relationships.dart';
import 'smallville_memory.dart';
import 'smallville_planner.dart';
import 'world.dart';

/// Smallville-style agent with enhanced memory and planning.
class SmallvilleAgent {
  /// Creates a Smallville agent.
  SmallvilleAgent({
    required this.profile,
    required this.planner,
    required this.relationships,
    required OllamaPlannerModel llm,
    double reflectionThreshold = 150.0,
  }) : memory = SmallvilleMemory(
         agentId: profile.id,
         llm: llm,
         reflectionThreshold: reflectionThreshold,
       );

  /// Agent profile.
  final AgentProfile profile;

  /// Smallville-style planner.
  final SmallvillePlanner planner;

  /// Shared social graph.
  final RelationshipGraph relationships;

  /// Enhanced memory with reflection.
  final SmallvilleMemory memory;

  int _ticksSinceLastReflection = 0;

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

    _ticksSinceLastReflection++;
  }

  /// Performs reflection if needed.
  Future<void> maybeReflect({required int currentTick}) async {
    // Reflect every 10 ticks or when threshold is met
    if (_ticksSinceLastReflection >= 10) {
      await memory.reflect(
        currentTick: currentTick,
        agentName: profile.displayName,
      );
      _ticksSinceLastReflection = 0;
    }
  }

  /// Produces this tick's event for the agent.
  Future<WorldEvent> act(WorldSnapshot snapshot) async {
    // Use old MemoryStore interface for planner compatibility
    final MemoryStore legacyMemory = _convertToLegacyMemory();

    final PlanAction action = await planner.nextAction(
      snapshot: snapshot,
      memory: legacyMemory,
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

  /// Converts SmallvilleMemory to legacy MemoryStore for compatibility.
  MemoryStore _convertToLegacyMemory() {
    final MemoryStore legacy = MemoryStore();
    for (final MemoryItem item in memory.all) {
      legacy.add(item);
    }
    return legacy;
  }
}

/// Factory for creating Smallville agents with shared LLM.
class SmallvilleAgentFactory {
  /// Creates factory.
  SmallvilleAgentFactory({required this.llm, required this.relationships});

  /// Shared LLM instance.
  final OllamaPlannerModel llm;

  /// Shared relationship graph.
  final RelationshipGraph relationships;

  /// Creates a Smallville agent.
  SmallvilleAgent createAgent({
    required AgentProfile profile,
    double reflectionThreshold = 150.0,
  }) {
    return SmallvilleAgent(
      profile: profile,
      planner: SmallvillePlanner(llm: llm),
      relationships: relationships,
      llm: llm,
      reflectionThreshold: reflectionThreshold,
    );
  }

  /// Creates multiple agents from profiles.
  List<SmallvilleAgent> createAgents({
    required List<AgentProfile> profiles,
    double reflectionThreshold = 150.0,
  }) {
    return profiles
        .map(
          (AgentProfile profile) => createAgent(
            profile: profile,
            reflectionThreshold: reflectionThreshold,
          ),
        )
        .toList();
  }
}
