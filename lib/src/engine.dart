import 'agent.dart';
import 'relationships.dart';
import 'world.dart';

/// Drives the simulation loop.
class SimulationEngine {
  /// Creates engine.
  SimulationEngine({
    required this.world,
    required this.agents,
    required this.relationships,
  });

  /// World state.
  final WorldState world;

  /// Active agents.
  final List<Agent> agents;

  /// Shared social graph.
  final RelationshipGraph relationships;

  /// Runs the simulation for a fixed number of ticks.
  Future<List<WorldEvent>> run({required int ticks}) async {
    for (int i = 0; i < ticks; i += 1) {
      world.advanceTick();
      final WorldSnapshot snapshot = world.snapshot();

      for (final Agent agent in agents) {
        agent.perceive(snapshot);
      }

      final List<WorldEvent> currentTickEvents = <WorldEvent>[];
      for (final Agent agent in agents) {
        final WorldEvent event = await agent.act(snapshot);
        world.emit(event);
        currentTickEvents.add(event);
      }

      _updateRelationships(currentTickEvents, snapshot.tick);
    }

    return world.events;
  }

  /// Runs a single simulation tick and returns the new events.
  Future<List<WorldEvent>> tick() async {
    world.advanceTick();
    final WorldSnapshot snapshot = world.snapshot();

    for (final Agent agent in agents) {
      agent.perceive(snapshot);
    }

    final List<WorldEvent> currentTickEvents = <WorldEvent>[];
    for (final Agent agent in agents) {
      final WorldEvent event = await agent.act(snapshot);
      world.emit(event);
      currentTickEvents.add(event);
    }

    _updateRelationships(currentTickEvents, snapshot.tick);

    return currentTickEvents;
  }

  void _updateRelationships(List<WorldEvent> events, int tick) {
    for (int i = 0; i < events.length; i += 1) {
      for (int j = i + 1; j < events.length; j += 1) {
        final WorldEvent first = events[i];
        final WorldEvent second = events[j];
        if (first.locationId == second.locationId &&
            first.actorId != second.actorId) {
          relationships.observeCoLocation(
            a: first.actorId,
            b: second.actorId,
            tick: tick,
          );
        }
      }
    }
  }
}
