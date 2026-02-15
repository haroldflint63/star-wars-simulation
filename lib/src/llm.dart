import 'memory.dart';
import 'planner.dart';
import 'relationships.dart';
import 'world.dart';

/// Interface for an LLM completion provider.
abstract class LlmPlannerModel {
  /// Returns a compact single-line plan.
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
  });
}

/// Deterministic local model for offline development and tests.
class RuleBasedLlmPlannerModel implements LlmPlannerModel {
  /// Creates model.
  const RuleBasedLlmPlannerModel();

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final String goal =
        _extractTagValue(userPrompt, 'goal') ?? 'support the town';
    final String friend = _extractTagValue(userPrompt, 'top_friend') ?? 'team';
    final String fallbackLocation =
        _extractTagValue(userPrompt, 'fallback_location') ?? 'jedi_temple';
    final String knownLocations =
        _extractTagValue(userPrompt, 'known_locations') ?? fallbackLocation;
    final List<String> candidates =
        knownLocations
            .split(',')
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList();
    final String location =
        candidates.isNotEmpty ? candidates.first : fallbackLocation;
    return 'location=$location;action=Advance "$goal" with $friend';
  }

  String? _extractTagValue(String prompt, String tag) {
    final RegExp expression = RegExp('$tag=([^\\n]+)');
    final Match? match = expression.firstMatch(prompt);
    if (match == null) {
      return null;
    }
    return match.group(1)?.trim();
  }
}

/// Planner that delegates plan synthesis to an LLM model.
class LlmBackedPlanner implements Planner {
  /// Creates planner.
  LlmBackedPlanner({required this.model, required this.fallback});

  /// LLM completion provider.
  final LlmPlannerModel model;

  /// Fallback planner for invalid model output.
  final Planner fallback;

  bool _llmEnabled = true;

  @override
  Future<PlanAction> nextAction({
    required WorldSnapshot snapshot,
    required MemoryStore memory,
    required String agentId,
    required String primaryGoal,
    required String fallbackLocationId,
    required List<RelationshipSignal> socialSignals,
  }) async {
    final List<MemoryItem> recalled = memory.recall(
      query: primaryGoal,
      currentTick: snapshot.tick,
      limit: 2,
    );

    final String topFriend =
        socialSignals.isNotEmpty ? socialSignals.first.otherAgentId : 'none';
    final String topMemory = recalled.isNotEmpty ? recalled.first.text : 'none';

    final String systemPrompt =
        'You are a town-simulation planner. Return exactly: '
        'location=<id>;action=<text>';
    final String userPrompt =
        'tick=${snapshot.tick}\n'
        'agent=$agentId\n'
        'goal=$primaryGoal\n'
        'fallback_location=$fallbackLocationId\n'
        'known_locations=${_locationList(snapshot)}\n'
        'top_friend=$topFriend\n'
        'top_memory=$topMemory';

    if (_llmEnabled) {
      try {
        final String raw = await model.complete(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        );

        final PlanAction? parsed = _parsePlan(raw: raw, snapshot: snapshot);
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // Disable LLM after first hard failure to avoid repeated timeouts.
        _llmEnabled = false;
      }
    }

    return fallback.nextAction(
      snapshot: snapshot,
      memory: memory,
      agentId: agentId,
      primaryGoal: primaryGoal,
      fallbackLocationId: fallbackLocationId,
      socialSignals: socialSignals,
    );
  }

  PlanAction? _parsePlan({
    required String raw,
    required WorldSnapshot snapshot,
  }) {
    final Match? locationMatch = RegExp(r'location=([^;]+)').firstMatch(raw);
    final Match? actionMatch = RegExp(
      r'action=(.+)$',
      dotAll: true,
    ).firstMatch(raw);
    if (locationMatch == null || actionMatch == null) {
      return null;
    }

    final String locationId = locationMatch.group(1)!.trim();
    final bool exists = snapshot.locations.any((Location location) {
      return location.id == locationId;
    });
    if (!exists) {
      return null;
    }

    final String action = actionMatch.group(1)!.trim();
    return PlanAction(locationId: locationId, description: '[llm] $action');
  }

  String _locationList(WorldSnapshot snapshot) {
    return snapshot.locations.map((Location location) => location.id).join(',');
  }
}
