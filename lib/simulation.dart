import 'src/agent.dart';
import 'src/engine.dart';
import 'src/planner.dart';
import 'src/relationships.dart';
import 'src/world.dart';

/// Returns whether the application is initialized correctly.
bool isAppReady() {
  return true;
}

/// Builds a Star Wars Galaxy simulation.
SimulationEngine buildDefaultSimulation({Planner? planner}) {
  final WorldState world = WorldState(
    locations: const <Location>[
      Location(id: 'tatooine_cantina', label: 'Mos Eisley Cantina'),
      Location(id: 'jedi_temple', label: 'Jedi Temple'),
      Location(id: 'cloud_city', label: 'Cloud City'),
      Location(id: 'dagobah_swamp', label: 'Dagobah Swamp'),
      Location(id: 'death_star', label: 'Death Star'),
      Location(id: 'endor_forest', label: 'Endor Forest'),
      Location(id: 'hoth_base', label: 'Echo Base'),
      Location(id: 'naboo_palace', label: 'Naboo Palace'),
    ],
  );

  final RelationshipGraph relationships = RelationshipGraph();
  relationships.setBidirectional(
    a: 'luke',
    b: 'leia',
    affinity: 0.9,
    trust: 0.95,
    tick: 0,
  );
  relationships.setBidirectional(
    a: 'luke',
    b: 'han',
    affinity: 0.85,
    trust: 0.8,
    tick: 0,
  );
  relationships.setBidirectional(
    a: 'leia',
    b: 'han',
    affinity: 0.9,
    trust: 0.85,
    tick: 0,
  );

  // Use fast HeuristicPlanner by default for smooth simulation
  final Planner resolvedPlanner = planner ?? const HeuristicPlanner();

  final List<Agent> agents = <Agent>[
    Agent(
      profile: const AgentProfile(
        id: 'luke',
        displayName: 'Luke Skywalker',
        primaryGoal: 'Master the Force and restore balance to the galaxy',
        homeLocationId: 'jedi_temple',
      ),
      planner: resolvedPlanner,
      relationships: relationships,
    ),
    Agent(
      profile: const AgentProfile(
        id: 'leia',
        displayName: 'Princess Leia',
        primaryGoal: 'Lead the Rebellion and defeat the Empire',
        homeLocationId: 'naboo_palace',
      ),
      planner: resolvedPlanner,
      relationships: relationships,
    ),
    Agent(
      profile: const AgentProfile(
        id: 'han',
        displayName: 'Han Solo',
        primaryGoal: 'Complete the Kessel Run and earn credits',
        homeLocationId: 'tatooine_cantina',
      ),
      planner: resolvedPlanner,
      relationships: relationships,
    ),
  ];

  return SimulationEngine(
    world: world,
    agents: agents,
    relationships: relationships,
  );
}
