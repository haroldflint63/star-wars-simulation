/// Represents a place in the simulated town.
class Location {
  /// Creates a location.
  const Location({required this.id, required this.label});

  /// Stable identifier.
  final String id;

  /// Human-readable name.
  final String label;
}

/// A world event emitted by agents or the environment.
class WorldEvent {
  /// Creates a world event.
  const WorldEvent({
    required this.actorId,
    required this.locationId,
    required this.description,
    required this.tick,
    this.tags = const <String>[],
  });

  /// Agent or system actor id.
  final String actorId;

  /// Location where the event happened.
  final String locationId;

  /// Event text.
  final String description;

  /// Simulation tick when event occurred.
  final int tick;

  /// Optional tags to support filtering and memory retrieval.
  final List<String> tags;
}

/// Snapshot of the world shared with agents each tick.
class WorldSnapshot {
  /// Creates a snapshot.
  const WorldSnapshot({
    required this.tick,
    required this.locations,
    required this.recentEvents,
  });

  /// Current simulation tick.
  final int tick;

  /// Known locations in the world.
  final List<Location> locations;

  /// Recently emitted events.
  final List<WorldEvent> recentEvents;
}

/// In-memory world state and append-only event log.
class WorldState {
  /// Creates world state.
  WorldState({required this.locations});

  /// World locations.
  final List<Location> locations;

  final List<WorldEvent> _events = <WorldEvent>[];

  int _tick = 0;

  /// Current tick.
  int get tick {
    return _tick;
  }

  /// Immutable copy of all events.
  List<WorldEvent> get events {
    return List<WorldEvent>.unmodifiable(_events);
  }

  /// Advances simulation by one tick.
  void advanceTick() {
    _tick += 1;
  }

  /// Adds an event to the world log.
  void emit(WorldEvent event) {
    _events.add(event);
  }

  /// Creates a snapshot with the latest `maxEvents` events.
  WorldSnapshot snapshot({int maxEvents = 20}) {
    final bool hasOverflow = _events.length > maxEvents;
    final int start = hasOverflow ? _events.length - maxEvents : 0;
    return WorldSnapshot(
      tick: _tick,
      locations: List<Location>.unmodifiable(locations),
      recentEvents: List<WorldEvent>.unmodifiable(_events.sublist(start)),
    );
  }
}
