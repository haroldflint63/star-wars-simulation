/// Pairwise social signal used by planners.
class RelationshipSignal {
  /// Creates a relationship signal.
  const RelationshipSignal({
    required this.otherAgentId,
    required this.affinity,
    required this.trust,
  });

  /// The other agent id.
  final String otherAgentId;

  /// Affinity in range [-1, 1].
  final double affinity;

  /// Trust in range [0, 1].
  final double trust;
}

/// Mutable relationship edge for one direction of a social tie.
class RelationshipEdge {
  /// Creates a relationship edge.
  const RelationshipEdge({
    required this.affinity,
    required this.trust,
    required this.lastUpdatedTick,
    required this.interactionCount,
  });

  /// Affinity in range [-1, 1].
  final double affinity;

  /// Trust in range [0, 1].
  final double trust;

  /// Tick when this edge was updated.
  final int lastUpdatedTick;

  /// Number of observed interactions.
  final int interactionCount;

  /// Returns a copy with provided values.
  RelationshipEdge copyWith({
    double? affinity,
    double? trust,
    int? lastUpdatedTick,
    int? interactionCount,
  }) {
    return RelationshipEdge(
      affinity: affinity ?? this.affinity,
      trust: trust ?? this.trust,
      lastUpdatedTick: lastUpdatedTick ?? this.lastUpdatedTick,
      interactionCount: interactionCount ?? this.interactionCount,
    );
  }
}

/// Relationship graph shared by all agents.
class RelationshipGraph {
  /// Creates a graph.
  RelationshipGraph();

  final Map<String, Map<String, RelationshipEdge>> _edges =
      <String, Map<String, RelationshipEdge>>{};

  /// Sets both directions to the same initial values.
  void setBidirectional({
    required String a,
    required String b,
    required double affinity,
    required double trust,
    required int tick,
  }) {
    _setOneWay(
      from: a,
      to: b,
      edge: RelationshipEdge(
        affinity: _clamp(affinity, -1.0, 1.0),
        trust: _clamp(trust, 0.0, 1.0),
        lastUpdatedTick: tick,
        interactionCount: 0,
      ),
    );
    _setOneWay(
      from: b,
      to: a,
      edge: RelationshipEdge(
        affinity: _clamp(affinity, -1.0, 1.0),
        trust: _clamp(trust, 0.0, 1.0),
        lastUpdatedTick: tick,
        interactionCount: 0,
      ),
    );
  }

  /// Returns directional edge if it exists.
  RelationshipEdge? edge(String from, String to) {
    return _edges[from]?[to];
  }

  /// Returns affinity from `from` to `to`.
  double affinity(String from, String to) {
    final RelationshipEdge? existing = edge(from, to);
    return existing?.affinity ?? 0.0;
  }

  /// Returns top social signals for one agent.
  List<RelationshipSignal> topSignals({
    required String agentId,
    int limit = 3,
  }) {
    final Map<String, RelationshipEdge>? outgoing = _edges[agentId];
    if (outgoing == null || outgoing.isEmpty) {
      return const <RelationshipSignal>[];
    }

    final List<MapEntry<String, RelationshipEdge>> entries =
        outgoing.entries.toList();
    entries.sort((
      MapEntry<String, RelationshipEdge> a,
      MapEntry<String, RelationshipEdge> b,
    ) {
      final double scoreA = (a.value.affinity * 0.6) + (a.value.trust * 0.4);
      final double scoreB = (b.value.affinity * 0.6) + (b.value.trust * 0.4);
      return scoreB.compareTo(scoreA);
    });

    return entries
        .take(limit)
        .map((MapEntry<String, RelationshipEdge> entry) {
          return RelationshipSignal(
            otherAgentId: entry.key,
            affinity: entry.value.affinity,
            trust: entry.value.trust,
          );
        })
        .toList(growable: false);
  }

  /// Rewards co-location interactions with small trust and affinity boosts.
  void observeCoLocation({
    required String a,
    required String b,
    required int tick,
  }) {
    _bumpOneWay(from: a, to: b, tick: tick);
    _bumpOneWay(from: b, to: a, tick: tick);
  }

  void _bumpOneWay({
    required String from,
    required String to,
    required int tick,
  }) {
    final RelationshipEdge current =
        edge(from, to) ??
        const RelationshipEdge(
          affinity: 0.0,
          trust: 0.2,
          lastUpdatedTick: 0,
          interactionCount: 0,
        );

    final RelationshipEdge updated = current.copyWith(
      affinity: _clamp(current.affinity + 0.03, -1.0, 1.0),
      trust: _clamp(current.trust + 0.02, 0.0, 1.0),
      lastUpdatedTick: tick,
      interactionCount: current.interactionCount + 1,
    );

    _setOneWay(from: from, to: to, edge: updated);
  }

  void _setOneWay({
    required String from,
    required String to,
    required RelationshipEdge edge,
  }) {
    _edges.putIfAbsent(from, () => <String, RelationshipEdge>{});
    _edges[from]![to] = edge;
  }

  double _clamp(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}
