/// Smallville-style agent memory architecture.
///
/// Inspired by "Generative Agents: Interactive Simulacra of Human Behavior"
/// (Park et al., Stanford 2023, arXiv:2304.03442).
///
/// Three components per agent:
///   1. MemoryStream — append-only timestamped observations + dialogue.
///   2. Reflection   — periodic high-level insights synthesised from memories.
///   3. DailyPlan    — 6-slot schedule generated at sim start.
library;

import 'package:flutter/foundation.dart';

enum MemoryKind { observation, dialogueSelf, dialogueHeard, reflection, plan }

@immutable
class Memory {
  const Memory({
    required this.kind,
    required this.content,
    required this.timestamp,
    required this.importance,
  });
  final MemoryKind kind;
  final String content;
  final DateTime timestamp;

  /// 1..10 — Smallville's "poignancy" score used for retrieval weighting.
  final int importance;

  String get kindLabel {
    switch (kind) {
      case MemoryKind.observation:
        return 'OBS';
      case MemoryKind.dialogueSelf:
        return 'SAID';
      case MemoryKind.dialogueHeard:
        return 'HEARD';
      case MemoryKind.reflection:
        return 'REFLECT';
      case MemoryKind.plan:
        return 'PLAN';
    }
  }
}

class MemoryStream {
  MemoryStream({this.maxSize = 80});
  final int maxSize;
  final List<Memory> _memories = [];

  List<Memory> get all => List.unmodifiable(_memories.reversed);
  int get length => _memories.length;

  void add(Memory m) {
    _memories.add(m);
    if (_memories.length > maxSize) {
      // Drop oldest low-importance first.
      final idx = _memories
          .asMap()
          .entries
          .where((e) => e.value.importance <= 4)
          .map((e) => e.key)
          .firstWhere((_) => true, orElse: () => 0);
      _memories.removeAt(idx);
    }
  }

  /// Retrieve top-N most relevant memories using a simple
  /// recency × importance × keyword-overlap score (Smallville §4.1.2).
  List<Memory> retrieve({required String query, int topN = 6}) {
    if (_memories.isEmpty) return const [];
    final now = DateTime.now();
    final qWords = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > 3)
        .toSet();

    double score(Memory m) {
      final ageHours = now.difference(m.timestamp).inMinutes / 60.0;
      final recency = 0.99 * (1.0 / (1.0 + ageHours)); // decay
      final importance = m.importance / 10.0;
      final mWords = m.content
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+'))
          .toSet();
      final overlap = qWords.isEmpty
          ? 0.0
          : qWords.intersection(mWords).length / qWords.length;
      return recency + importance + overlap;
    }

    final ranked = [..._memories]..sort((a, b) => score(b).compareTo(score(a)));
    return ranked.take(topN).toList();
  }

  /// Recent memories for reflection prompts.
  List<Memory> recent({int n = 12}) {
    if (_memories.length <= n) return List.unmodifiable(_memories);
    return List.unmodifiable(_memories.sublist(_memories.length - n));
  }
}

/// One slot of a Smallville daily plan.
@immutable
class PlanSlot {
  const PlanSlot({required this.time, required this.activity});
  final String time;     // e.g. "0800"
  final String activity; // e.g. "Meet with Rebel contact at Dex's Diner"
}

@immutable
class DailyPlan {
  const DailyPlan({required this.agentName, required this.slots});
  final String agentName;
  final List<PlanSlot> slots;

  static const DailyPlan empty = DailyPlan(agentName: '', slots: []);
}
