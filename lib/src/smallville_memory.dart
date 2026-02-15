import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'memory.dart';
import 'ollama.dart';
import 'world.dart';

/// Enhanced memory with reflection capabilities inspired by Stanford Smallville.
///
/// Key features:
/// - Memory streams with observations
/// - Reflection mechanism to generate higher-level insights
/// - Importance-weighted retrieval
/// - Automatic reflection triggers
class SmallvilleMemory {
  /// Creates a Smallville-style memory system.
  SmallvilleMemory({
    required this.agentId,
    required this.llm,
    this.reflectionThreshold = 100.0,
  });

  /// Agent this memory belongs to.
  final String agentId;

  /// LLM for generating reflections.
  final OllamaPlannerModel llm;

  /// Cumulative importance threshold to trigger reflection.
  final double reflectionThreshold;

  final List<MemoryItem> _observations = <MemoryItem>[];
  final List<MemoryItem> _reflections = <MemoryItem>[];

  double _importanceSum = 0.0;
  int _lastReflectionTick = 0;

  /// All memories (observations + reflections).
  List<MemoryItem> get all {
    return [..._observations, ..._reflections];
  }

  /// Adds an observation to memory stream.
  void addObservation({
    required String text,
    required int tick,
    required double importance,
    List<String> tags = const <String>[],
  }) {
    final MemoryItem observation = MemoryItem(
      text: text,
      tick: tick,
      importance: importance,
      tags: [...tags, 'observation'],
    );

    _observations.add(observation);
    _importanceSum += importance;

    // Auto-trigger reflection if threshold exceeded
    if (_importanceSum >= reflectionThreshold) {
      debugPrint(
        '🧠 Agent $agentId ready for reflection (importance: $_importanceSum)',
      );
    }
  }

  /// Adds an event observation.
  void observeEvent(
    WorldEvent event, {
    required String observerId,
    required double socialAffinity,
  }) {
    final bool selfAuthored = event.actorId == observerId;
    final double socialBoost = selfAuthored ? 0.15 : socialAffinity * 0.2;
    final double baseImportance = selfAuthored ? 0.7 : 0.5;

    addObservation(
      text: event.description,
      tick: event.tick,
      importance: _clamp(baseImportance + socialBoost, 0.0, 1.0),
      tags: <String>[...event.tags, event.locationId, event.actorId],
    );
  }

  /// Performs reflection: generates higher-level insights from recent observations.
  Future<void> reflect({
    required int currentTick,
    required String agentName,
  }) async {
    if (_importanceSum < reflectionThreshold) {
      return; // Not ready to reflect yet
    }

    debugPrint('💭 Agent $agentName reflecting on recent experiences...');

    // Get top 100 most important recent observations
    final List<MemoryItem> recentMemories =
        _observations
            .where((MemoryItem m) => m.tick > _lastReflectionTick)
            .toList()
          ..sort(
            (MemoryItem a, MemoryItem b) =>
                b.importance.compareTo(a.importance),
          );

    final List<MemoryItem> topMemories = recentMemories.take(100).toList();

    if (topMemories.isEmpty) {
      return;
    }

    // Generate reflection questions
    final List<String> questions = await _generateReflectionQuestions(
      memories: topMemories,
      agentName: agentName,
    );

    // Generate insights for each question
    for (final String question in questions.take(3)) {
      final String insight = await _generateInsight(
        question: question,
        memories: topMemories,
        agentName: agentName,
      );

      if (insight.isNotEmpty) {
        final MemoryItem reflection = MemoryItem(
          text: insight,
          tick: currentTick,
          importance: 0.8, // Reflections are important
          tags: <String>['reflection', agentId],
        );
        _reflections.add(reflection);
        debugPrint('  💡 Reflection: $insight');
      }
    }

    _importanceSum = 0.0;
    _lastReflectionTick = currentTick;
  }

  /// Generates reflection questions from memories.
  Future<List<String>> _generateReflectionQuestions({
    required List<MemoryItem> memories,
    required String agentName,
  }) async {
    final String memoryContext = memories
        .take(20)
        .map((MemoryItem m) => '- ${m.text}')
        .join('\n');

    final String systemPrompt =
        'You are a thoughtful AI analyzing an agent\'s experiences.';
    final String userPrompt = '''
Agent: $agentName

Recent observations:
$memoryContext

Generate 3 high-level questions this agent should reflect on based on these observations.
Format: One question per line, no numbering.
Questions should be about patterns, relationships, or insights.

Examples:
- What does $agentName think about their recent social interactions?
- What is $agentName's current emotional state?
- What are $agentName's priorities right now?
''';

    try {
      final String response = await llm.complete(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      return response
          .split('\n')
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty && !line.startsWith('#'))
          .take(3)
          .toList();
    } catch (error) {
      debugPrint('⚠️  Reflection question generation failed: $error');
      return <String>[];
    }
  }

  /// Generates an insight answer for a reflection question.
  Future<String> _generateInsight({
    required String question,
    required List<MemoryItem> memories,
    required String agentName,
  }) async {
    final String memoryContext = memories
        .take(15)
        .map((MemoryItem m) => '- ${m.text}')
        .join('\n');

    final String systemPrompt =
        'You are $agentName reflecting on your experiences. Answer in first person, one sentence.';
    final String userPrompt = '''
Question: $question

Based on these recent observations:
$memoryContext

Answer:''';

    try {
      final String response = await llm.complete(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      return response.trim().split('\n').first; // Take first sentence
    } catch (error) {
      debugPrint('⚠️  Insight generation failed: $error');
      return '';
    }
  }

  /// Retrieves relevant memories using recency + relevance + importance.
  List<MemoryItem> recall({
    required String query,
    required int currentTick,
    int limit = 10,
  }) {
    final Set<String> queryTokens = _tokenize(query);
    final List<MemoryItem> allMemories = all;

    final List<_ScoredMemory> scored =
        allMemories.map((MemoryItem memory) {
          final int age = currentTick - memory.tick;
          final double recency = 1.0 / (1.0 + age * 0.01); // Decay factor
          final double relevance = _overlap(
            _tokenize(memory.text),
            queryTokens,
          );

          // Smallville scoring: importance (high) + recency (medium) + relevance (low)
          final double score =
              (0.5 * memory.importance) + (0.3 * recency) + (0.2 * relevance);

          return _ScoredMemory(memory: memory, score: score);
        }).toList();

    scored.sort(
      (_ScoredMemory a, _ScoredMemory b) => b.score.compareTo(a.score),
    );

    return scored
        .take(limit)
        .map((_ScoredMemory entry) => entry.memory)
        .toList();
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
    return intersection.length / math.max(a.length, b.length);
  }

  double _clamp(double value, double min, double max) {
    return value.clamp(min, max);
  }
}

class _ScoredMemory {
  const _ScoredMemory({required this.memory, required this.score});

  final MemoryItem memory;
  final double score;
}
