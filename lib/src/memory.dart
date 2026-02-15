import 'world.dart';

/// Memory item stored by an agent.
class MemoryItem {
  /// Creates a memory.
  const MemoryItem({
    required this.text,
    required this.tick,
    required this.importance,
    this.tags = const <String>[],
  });

  /// Stored text.
  final String text;

  /// Tick when memory was created.
  final int tick;

  /// Relative importance in range [0, 1].
  final double importance;

  /// Tags used for retrieval.
  final List<String> tags;
}

/// Agent memory with recency + relevance + importance retrieval scoring.
class MemoryStore {
  /// Creates a memory store.
  MemoryStore();

  final List<MemoryItem> _items = <MemoryItem>[];

  /// Immutable view of all memories.
  List<MemoryItem> get all {
    return List<MemoryItem>.unmodifiable(_items);
  }

  /// Adds a generic memory item.
  void add(MemoryItem memory) {
    _items.add(memory);
  }

  /// Adds an observed world event as memory.
  void observeEvent(
    WorldEvent event, {
    required String observerId,
    required double socialAffinity,
  }) {
    final bool selfAuthored = event.actorId == observerId;
    final double socialBoost = selfAuthored ? 0.15 : socialAffinity * 0.2;
    final double baseImportance = selfAuthored ? 0.7 : 0.5;

    add(
      MemoryItem(
        text: event.description,
        tick: event.tick,
        importance: _clamp(baseImportance + socialBoost, 0.0, 1.0),
        tags: <String>[...event.tags, event.locationId, event.actorId],
      ),
    );
  }

  /// Returns top matching memories for a textual query.
  List<MemoryItem> recall({
    required String query,
    required int currentTick,
    int limit = 6,
  }) {
    final Set<String> queryTokens = _tokenize(query);
    final List<_ScoredMemory> scored =
        _items.map((MemoryItem memory) {
          final int age = currentTick - memory.tick;
          final double recency = 1.0 / (1.0 + age.toDouble());
          final double relevance = _overlap(
            _tokenize(memory.text),
            queryTokens,
          );
          final double score =
              (0.45 * memory.importance) +
              (0.35 * recency) +
              (0.20 * relevance);
          return _ScoredMemory(memory: memory, score: score);
        }).toList();

    scored.sort((_ScoredMemory a, _ScoredMemory b) {
      return b.score.compareTo(a.score);
    });

    return scored
        .take(limit)
        .map((_ScoredMemory entry) => entry.memory)
        .toList(growable: false);
  }

  Set<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toSet();
  }

  double _overlap(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) {
      return 0.0;
    }
    final Set<String> intersection = a.intersection(b);
    return intersection.length / a.length;
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

class _ScoredMemory {
  const _ScoredMemory({required this.memory, required this.score});

  final MemoryItem memory;
  final double score;
}
