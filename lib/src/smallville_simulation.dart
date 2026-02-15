import 'package:flutter/foundation.dart';
import 'agent.dart';
import 'ollama.dart';
import 'relationships.dart';
import 'smallville_agent.dart';
import 'world.dart';

/// Simulation engine using Smallville-style agents with Ollama.
class SmallvilleSimulation {
  /// Creates a Smallville simulation.
  SmallvilleSimulation({required this.world, required this.agents});

  /// Builds a Star Wars Smallville simulation from scratch.
  factory SmallvilleSimulation.starWars() {
    // Initialize Ollama LLM
    final OllamaPlannerModel llm = OllamaPlannerModel.fromEnvironment();

    // Create world
    final WorldState world = WorldState(
      locations: <Location>[
        const Location(
          id: 'tatooine_cantina',
          label: 'Mos Eisley Cantina - a wretched hive of scum and villainy',
        ),
        const Location(
          id: 'jedi_temple',
          label: 'Jedi Temple on Coruscant - center of Force wisdom',
        ),
        const Location(
          id: 'hoth_base',
          label: 'Echo Base on Hoth - ice planet rebel hideout',
        ),
        const Location(
          id: 'cloud_city',
          label: 'Cloud City on Bespin - floating mining colony',
        ),
        const Location(
          id: 'dagobah_swamp',
          label: 'Dagobah swamp - mysterious Force-rich planet',
        ),
        const Location(
          id: 'death_star',
          label: 'Death Star - Imperial superweapon',
        ),
        const Location(
          id: 'naboo_palace',
          label: 'Royal Palace on Naboo - elegant seat of government',
        ),
        const Location(
          id: 'endor_forest',
          label: 'Forest moon of Endor - home of the Ewoks',
        ),
      ],
    );

    // Create relationship graph
    final RelationshipGraph relationships = RelationshipGraph();

    // Create agent factory
    final SmallvilleAgentFactory factory = SmallvilleAgentFactory(
      llm: llm,
      relationships: relationships,
    );

    // Create Star Wars agent profiles
    final List<AgentProfile> profiles = <AgentProfile>[
      const AgentProfile(
        id: 'luke',
        displayName: 'Luke Skywalker',
        primaryGoal: 'Become a Jedi Knight and bring balance to the Force',
        homeLocationId: 'tatooine_cantina',
      ),
      const AgentProfile(
        id: 'leia',
        displayName: 'Princess Leia',
        primaryGoal: 'Lead the Rebellion against the Empire',
        homeLocationId: 'hoth_base',
      ),
      const AgentProfile(
        id: 'han',
        displayName: 'Han Solo',
        primaryGoal: 'Pay off debt to Jabba and help friends',
        homeLocationId: 'tatooine_cantina',
      ),
      const AgentProfile(
        id: 'vader',
        displayName: 'Darth Vader',
        primaryGoal: 'Hunt down rebels and serve the Emperor',
        homeLocationId: 'death_star',
      ),
      const AgentProfile(
        id: 'yoda',
        displayName: 'Master Yoda',
        primaryGoal: 'Train young Jedi and preserve the Force',
        homeLocationId: 'dagobah_swamp',
      ),
      const AgentProfile(
        id: 'padme',
        displayName: 'Padmé Amidala',
        primaryGoal: 'Maintain peace and democracy in the galaxy',
        homeLocationId: 'naboo_palace',
      ),
    ];

    // Initialize relationships
    relationships.setBidirectional(
      a: 'luke',
      b: 'leia',
      affinity: 0.9,
      trust: 0.95,
      tick: 0,
    ); // Siblings
    relationships.setBidirectional(
      a: 'luke',
      b: 'han',
      affinity: 0.85,
      trust: 0.9,
      tick: 0,
    ); // Best friends
    relationships.setBidirectional(
      a: 'luke',
      b: 'yoda',
      affinity: 0.95,
      trust: 1.0,
      tick: 0,
    ); // Master-apprentice
    relationships.setBidirectional(
      a: 'luke',
      b: 'vader',
      affinity: -0.7,
      trust: 0.2,
      tick: 0,
    ); // Enemy (but family)

    relationships.setBidirectional(
      a: 'leia',
      b: 'han',
      affinity: 0.9,
      trust: 0.85,
      tick: 0,
    ); // Romance
    relationships.setBidirectional(
      a: 'leia',
      b: 'padme',
      affinity: 0.7,
      trust: 0.8,
      tick: 0,
    ); // Mother

    relationships.setBidirectional(
      a: 'vader',
      b: 'padme',
      affinity: 0.6,
      trust: 0.3,
      tick: 0,
    ); // Complex past
    relationships.setBidirectional(
      a: 'vader',
      b: 'yoda',
      affinity: -0.8,
      trust: 0.1,
      tick: 0,
    ); // Opposing sides

    relationships.setBidirectional(
      a: 'han',
      b: 'vader',
      affinity: -0.9,
      trust: 0.1,
      tick: 0,
    ); // Strong enemies

    // Create agents
    final List<SmallvilleAgent> agents = factory.createAgents(
      profiles: profiles,
      reflectionThreshold: 100.0, // Reflect after 100 importance
    );

    return SmallvilleSimulation(world: world, agents: agents);
  }

  /// World state.
  final WorldState world;

  /// Smallville agents.
  final List<SmallvilleAgent> agents;

  /// Current simulation tick.
  int get currentTick => world.tick;

  /// Advances simulation by one tick.
  Future<List<WorldEvent>> tick() async {
    final WorldSnapshot snapshot = world.snapshot();
    final List<WorldEvent> events = <WorldEvent>[];

    // Phase 1: All agents perceive
    for (final SmallvilleAgent agent in agents) {
      agent.perceive(snapshot);
    }

    // Phase 2: Some agents reflect (async)
    for (final SmallvilleAgent agent in agents) {
      await agent.maybeReflect(currentTick: snapshot.tick);
    }

    // Phase 3: All agents act
    for (final SmallvilleAgent agent in agents) {
      try {
        final WorldEvent event = await agent.act(snapshot);
        events.add(event);
      } catch (error) {
        debugPrint('⚠️  ${agent.profile.displayName} action failed: $error');

        // Fallback action
        events.add(
          WorldEvent(
            actorId: agent.profile.id,
            locationId: agent.profile.homeLocationId,
            description: '${agent.profile.displayName} pauses to think',
            tick: snapshot.tick,
            tags: <String>[agent.profile.id, agent.profile.homeLocationId],
          ),
        );
      }
    }

    // Phase 4: Update world
    for (final WorldEvent event in events) {
      world.emit(event);
    }
    world.advanceTick();

    return events;
  }

  /// Runs simulation for N ticks.
  Future<void> run({required int ticks, bool verbose = true}) async {
    debugPrint('\n🌟 Starting Smallville-style Star Wars Simulation');
    debugPrint('📊 Agents: ${agents.length}');
    debugPrint('🗺️  Locations: ${world.locations.length}');
    debugPrint('⏱️  Ticks to simulate: $ticks\n');

    for (int i = 0; i < ticks; i++) {
      if (verbose) {
        debugPrint('━━━ Tick $currentTick ━━━');
      }

      final List<WorldEvent> events = await tick();

      if (verbose) {
        for (final WorldEvent event in events) {
          debugPrint('  📍 ${event.description}');
        }
        debugPrint('');
      }

      // Small delay to avoid overwhelming the LLM
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    debugPrint('\n✅ Simulation complete!');
    _printSummary();
  }

  /// Prints simulation summary.
  void _printSummary() {
    debugPrint('\n📈 Simulation Summary:');
    debugPrint('Total ticks: $currentTick');
    debugPrint('Total events: ${world.snapshot().recentEvents.length}');

    debugPrint('\n🧠 Agent Memory Stats:');
    for (final SmallvilleAgent agent in agents) {
      final int memoryCount = agent.memory.all.length;
      final int reflections =
          agent.memory.all
              .where((item) => item.tags.contains('reflection'))
              .length;
      debugPrint(
        '  ${agent.profile.displayName}: '
        '$memoryCount memories ($reflections reflections)',
      );
    }
  }

  /// Gets agent by ID.
  SmallvilleAgent? getAgent(String id) {
    return agents.where((SmallvilleAgent a) => a.profile.id == id).firstOrNull;
  }

  /// Gets all agent profiles.
  List<AgentProfile> get profiles {
    return agents.map((SmallvilleAgent a) => a.profile).toList();
  }
}
