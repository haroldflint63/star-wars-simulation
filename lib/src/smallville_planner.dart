import 'package:flutter/foundation.dart';
import 'memory.dart';
import 'ollama.dart';
import 'planner.dart';
import 'relationships.dart';
import 'world.dart';

/// Stanford Smallville-inspired planner with LLM-powered planning.
///
/// Features:
/// - Daily plans with hourly schedules
/// - Context-aware action generation using Ollama
/// - Memory-informed decision making
/// - Social interaction prioritization
class SmallvillePlanner implements Planner {
  /// Creates a Smallville planner.
  SmallvillePlanner({
    required this.llm,
    this.planHorizon = 24, // Plan for next 24 ticks (hours)
  });

  /// LLM for generating plans.
  final OllamaPlannerModel llm;

  /// How many ticks ahead to plan.
  final int planHorizon;

  final Map<String, _AgentPlan> _agentPlans = <String, _AgentPlan>{};

  @override
  Future<PlanAction> nextAction({
    required WorldSnapshot snapshot,
    required MemoryStore memory,
    required String agentId,
    required String primaryGoal,
    required String fallbackLocationId,
    required List<RelationshipSignal> socialSignals,
  }) async {
    // Check if we have a current plan
    final _AgentPlan? existingPlan = _agentPlans[agentId];

    if (existingPlan == null ||
        existingPlan.shouldReplan(snapshot.tick) ||
        existingPlan.isComplete) {
      // Generate new plan
      await _generateNewPlan(
        snapshot: snapshot,
        memory: memory,
        agentId: agentId,
        primaryGoal: primaryGoal,
        fallbackLocationId: fallbackLocationId,
        socialSignals: socialSignals,
      );
    }

    // Execute current step from plan
    final _AgentPlan currentPlan = _agentPlans[agentId]!;
    return currentPlan.getCurrentAction(snapshot.tick) ??
        PlanAction(locationId: fallbackLocationId, description: 'Idle at home');
  }

  /// Generates a new daily plan for the agent.
  Future<void> _generateNewPlan({
    required WorldSnapshot snapshot,
    required MemoryStore memory,
    required String agentId,
    required String primaryGoal,
    required String fallbackLocationId,
    required List<RelationshipSignal> socialSignals,
  }) async {
    debugPrint('📋 Generating new plan for $agentId...');

    // Retrieve relevant memories
    final List<MemoryItem> relevantMemories = memory.recall(
      query: primaryGoal,
      currentTick: snapshot.tick,
      limit: 8,
    );

    // Get location options
    final List<String> locations =
        snapshot.locations
            .map((Location loc) => '${loc.id} (${loc.label})')
            .toList();

    // Build context
    final String memoryContext =
        relevantMemories.isEmpty
            ? 'No recent relevant memories.'
            : relevantMemories.map((MemoryItem m) => '- ${m.text}').join('\n');

    final String socialContext =
        socialSignals.isEmpty
            ? 'No current social connections.'
            : socialSignals
                .take(3)
                .map(
                  (RelationshipSignal s) =>
                      '- ${s.otherAgentId} (affinity: ${s.affinity.toStringAsFixed(2)}, trust: ${s.trust.toStringAsFixed(2)})',
                )
                .join('\n');

    // Generate plan using LLM
    final String systemPrompt =
        '''You are planning a day for a Star Wars character.
Generate a schedule of 6-8 hourly activities.
Each activity should specify a location and what they'll do there.''';

    final String userPrompt = '''
Character Goal: $primaryGoal
Current Time: Hour ${snapshot.tick % 24}

Available Locations:
${locations.join('\n')}

Recent Memories:
$memoryContext

Social Connections:
$socialContext

Generate a realistic daily schedule for this character.
Format: <location_id>|<activity description>
One activity per line.

Example:
tatooine_cantina|Have breakfast and listen to local gossip
jedi_temple|Morning meditation and lightsaber training
cloud_city|Meet with friends for lunch
hoth_base|Afternoon patrol duty

Schedule:''';

    try {
      final String response = await llm.complete(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      // Parse response into plan actions
      final List<_ScheduledAction> actions = _parsePlanResponse(
        response: response,
        startTick: snapshot.tick,
        fallbackLocationId: fallbackLocationId,
        availableLocations:
            snapshot.locations.map((Location l) => l.id).toSet(),
      );

      _agentPlans[agentId] = _AgentPlan(
        agentId: agentId,
        actions: actions,
        createdAt: snapshot.tick,
      );

      debugPrint('  ✅ Generated ${actions.length}-step plan for $agentId');
    } catch (error) {
      debugPrint('⚠️  Plan generation failed for $agentId: $error');

      // Fallback: simple default plan
      _agentPlans[agentId] = _AgentPlan(
        agentId: agentId,
        actions: <_ScheduledAction>[
          _ScheduledAction(
            tick: snapshot.tick,
            action: PlanAction(
              locationId: fallbackLocationId,
              description: 'Work on $primaryGoal',
            ),
          ),
        ],
        createdAt: snapshot.tick,
      );
    }
  }

  /// Parses LLM response into scheduled actions.
  List<_ScheduledAction> _parsePlanResponse({
    required String response,
    required int startTick,
    required String fallbackLocationId,
    required Set<String> availableLocations,
  }) {
    final List<_ScheduledAction> actions = <_ScheduledAction>[];
    final List<String> lines =
        response
            .split('\n')
            .map((String line) => line.trim())
            .where((String line) => line.isNotEmpty && line.contains('|'))
            .toList();

    for (int i = 0; i < lines.length; i++) {
      final List<String> parts = lines[i].split('|');
      if (parts.length < 2) continue;

      String locationId = parts[0].trim();
      final String description = parts[1].trim();

      // Validate location exists
      if (!availableLocations.contains(locationId)) {
        locationId = fallbackLocationId; // Use fallback if invalid
      }

      actions.add(
        _ScheduledAction(
          tick: startTick + (i * 3), // Each activity lasts ~3 ticks
          action: PlanAction(locationId: locationId, description: description),
        ),
      );
    }

    return actions;
  }
}

/// Internal class representing a planned schedule for an agent.
class _AgentPlan {
  _AgentPlan({
    required this.agentId,
    required this.actions,
    required this.createdAt,
  });

  final String agentId;
  final List<_ScheduledAction> actions;
  final int createdAt;

  int _currentIndex = 0;

  bool get isComplete => _currentIndex >= actions.length;

  /// Returns current action based on tick.
  PlanAction? getCurrentAction(int currentTick) {
    if (isComplete) return null;

    // Find the right action for current tick
    while (_currentIndex < actions.length &&
        currentTick >= actions[_currentIndex].tick) {
      if (_currentIndex == actions.length - 1 ||
          currentTick < actions[_currentIndex + 1].tick) {
        return actions[_currentIndex].action;
      }
      _currentIndex++;
    }

    return _currentIndex < actions.length
        ? actions[_currentIndex].action
        : null;
  }

  /// Should we generate a new plan?
  bool shouldReplan(int currentTick) {
    // Replan if plan is old (24+ ticks) or stuck
    return (currentTick - createdAt) > 24;
  }
}

class _ScheduledAction {
  const _ScheduledAction({required this.tick, required this.action});

  final int tick;
  final PlanAction action;
}
