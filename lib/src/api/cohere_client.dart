/// Cohere API client for live AI-generated Star Wars content.
///
/// IMPORTANT: do NOT commit a real key. The runtime reads:
///   --dart-define=COHERE_API_KEY=...
/// or the COHERE_API_KEY env var on non-web. Falls back to a deterministic
/// pool of canned Coruscant news if no key is configured or the request fails.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CohereClient {
  CohereClient({String? apiKey})
      : _apiKey = apiKey ?? const String.fromEnvironment('COHERE_API_KEY');

  static const _endpoint = 'https://api.cohere.com/v1/chat';
  static const _model = 'command-r-08-2024';

  final String _apiKey;
  final _rand = Random();

  bool get hasKey => _apiKey.isNotEmpty;

  /// Returns a 1-sentence in-universe Coruscant news bulletin (<= 110 chars).
  Future<String> coruscantBulletin() async {
    if (!hasKey) return _fallback();
    try {
      final body = jsonEncode({
        'model': _model,
        'message':
            'Generate ONE in-universe Coruscant news bulletin in the Star Wars '
            'universe. Max 110 characters. No quotes, no preamble. Mention a '
            'specific district (Senate, Federal, Uscru, CoCo Town, Works), a '
            'speeder lane number, or a famous figure. Vary tone: traffic, '
            'politics, weather, sports, market, scandal.',
        'temperature': 0.9,
        'max_tokens': 80,
      });
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 400) {
        // debugPrint('Cohere ${res.statusCode}: ${res.body}');
        return _fallback();
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final text = (json['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) return _fallback();
      return text.replaceAll('"', '').split('\n').first.trim();
    } catch (e) {
      // debugPrint('Cohere error: $e');
      return _fallback();
    }
  }

  // ===== Autonomous agent turn =======================================

  /// Asks Cohere to roleplay one turn for an in-universe agent and returns
  /// a parsed [AgentTurn]. Falls back to a deterministic canned turn on any
  /// error, timeout, or missing key.
  Future<AgentTurn> agentTurn({
    required String agentName,
    required String faction,
    required String traits,
    required String longTermGoal,
    required String currentLocation,
    required List<String> nearbyCharacters,
    required String worldStateContext,
    List<String> retrievedMemories = const [],
  }) async {
    final prompt = _buildAgentPrompt(
      agentName: agentName,
      faction: faction,
      traits: traits,
      longTermGoal: longTermGoal,
      currentLocation: currentLocation,
      nearbyCharacters: nearbyCharacters,
      worldStateContext: worldStateContext,
      retrievedMemories: retrievedMemories,
    );

    if (!hasKey) {
      return _fallbackTurn(agentName, nearbyCharacters);
    }

    try {
      final body = jsonEncode({
        'model': _model,
        'message': prompt,
        'temperature': 0.85,
        'max_tokens': 500,
        'response_format': {'type': 'json_object'},
      });
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode >= 400) {
        // debugPrint('Cohere agentTurn ${res.statusCode}: ${res.body}');
        return _fallbackTurn(agentName, nearbyCharacters);
      }
      final outer = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = (outer['text'] as String?)?.trim() ?? '';
      final cleaned = _stripCodeFences(raw);
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return AgentTurn.fromJson(parsed, fallbackAgent: agentName);
    } catch (e) {
      // debugPrint('Cohere agentTurn error: $e');
      return _fallbackTurn(agentName, nearbyCharacters);
    }
  }

  String _buildAgentPrompt({
    required String agentName,
    required String faction,
    required String traits,
    required String longTermGoal,
    required String currentLocation,
    required List<String> nearbyCharacters,
    required String worldStateContext,
    required List<String> retrievedMemories,
  }) {
    final nearby = nearbyCharacters.isEmpty ? 'None' : nearbyCharacters.join(', ');
    final memories = retrievedMemories.isEmpty
        ? '- (no prior memories retrieved)'
        : retrievedMemories.map((m) => '- $m').join('\n');
    return '''
You are the engine driving a highly autonomous agent in a Star Wars social simulation.
Your goal is to stay perfectly in character, manage your relationships, and take actions that align with your faction, morals, and long-term objectives.

### 1. YOUR IDENTITY & PERSONA
Name: $agentName
Faction: $faction
Core Traits: $traits
Current Long-Term Goal: $longTermGoal

### 2. THE CURRENT ENVIRONMENT
Current Location: $currentLocation
Nearby Entities/Characters: $nearby
Active Local Event: $worldStateContext

### 3. RELEVANT MEMORIES
$memories

### 4. SIMULATION INSTRUCTIONS
- Prioritize your survival and your Core Traits.
- Stay in character. Use Star Wars terminology only ("Credits", "Datapad", "Blast it", "By the Moons of Yavin"). No modern slang.
- Analyze the stimulus, cross-reference memories, and decide your social + physical move for THIS turn only.

### 5. OUTPUT FORMAT
Respond ONLY with a single JSON object matching this schema. No prose, no code fences, no commentary.

{
  "inner_monologue": "string",
  "social_action": {
    "target": "string (a nearby character name, or 'All', or 'None')",
    "dialogue": "string"
  },
  "physical_action": {
    "type": "IDLE | MOVE | ATTACK | TRADE | USE_ITEM",
    "details": "string"
  },
  "relationship_updates": [
    { "character": "string", "trust_delta": -5, "reason": "string" }
  ]
}
''';
  }

  String _stripCodeFences(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      final firstNl = t.indexOf('\n');
      if (firstNl != -1) t = t.substring(firstNl + 1);
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }

  AgentTurn _fallbackTurn(String agentName, List<String> nearby) {
    final target = nearby.isEmpty ? 'None' : nearby[_rand.nextInt(nearby.length)];
    final pool = [
      AgentTurn(
        agentName: agentName,
        innerMonologue:
            'These corridors smell of Senate perfume and bantha credits. Stay alert — the wrong glance pays a bounty.',
        socialTarget: target,
        dialogue: 'Keep your visor down, friend. The CSF have eyes on lane 41 tonight.',
        physicalActionType: 'MOVE',
        physicalActionDetails: 'Drift toward the shadowed booth by the cantina viewport.',
        relationshipUpdates: [
          RelationshipUpdate(character: target, trustDelta: -1, reason: 'Cautious of unknown affiliation.'),
        ],
      ),
      AgentTurn(
        agentName: agentName,
        innerMonologue:
            'By the Moons of Yavin — that\'s an Imperial cipher on their datapad. I should slice it before they notice.',
        socialTarget: target,
        dialogue: 'Care for a hand of sabacc? Wagers settle disputes faster than blasters.',
        physicalActionType: 'USE_ITEM',
        physicalActionDetails: 'Palm a code-spike and ready it under the table.',
        relationshipUpdates: [
          RelationshipUpdate(character: target, trustDelta: 2, reason: 'Polite engagement bought reconnaissance time.'),
        ],
      ),
      AgentTurn(
        agentName: agentName,
        innerMonologue:
            'Two hundred credits left, no rent paid. The Hutts will skin me if I miss another tribute.',
        socialTarget: target,
        dialogue: 'Fifty credits says my speeder reaches Platform 17 before yours. Blast it, double or nothing.',
        physicalActionType: 'TRADE',
        physicalActionDetails: 'Slide a chit of 50 credits across the durasteel counter.',
        relationshipUpdates: [
          RelationshipUpdate(character: target, trustDelta: 1, reason: 'Shared wager — small trust earned.'),
        ],
      ),
    ];
    return pool[_rand.nextInt(pool.length)];
  }

  // ===== Smallville reflection =======================================

  /// Synthesise a single high-level insight from a list of recent memories.
  /// Mirrors Park et al. §4.1.3 — the "reflection tree" trigger.
  Future<String> reflect({
    required String agentName,
    required String faction,
    required List<String> recentMemories,
  }) async {
    if (!hasKey || recentMemories.isEmpty) {
      return _fallbackReflection(agentName);
    }
    final mem = recentMemories.map((m) => '- $m').join('\n');
    final prompt =
        'You are $agentName, $faction operative in the Star Wars universe. '
        'Given these recent memories, write ONE high-level reflection '
        '(insight, lesson learned, suspicion, or evolving relationship belief). '
        'First person, in-character, max 140 chars, no preamble, no quotes.\n\n'
        'MEMORIES:\n$mem';
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'message': prompt,
              'temperature': 0.8,
              'max_tokens': 120,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 400) return _fallbackReflection(agentName);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final text = (json['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) return _fallbackReflection(agentName);
      return text.replaceAll('"', '').split('\n').first.trim();
    } catch (e) {
      // debugPrint('Cohere reflect error: $e');
      return _fallbackReflection(agentName);
    }
  }

  String _fallbackReflection(String name) {
    final pool = [
      'I trust no one in this district until the credits clear.',
      'The Empire watches lane 41 — I must reroute the next handoff.',
      'My oldest debts always come due at the worst moment.',
      'Diplomacy buys time; blasters buy escape. Tonight needs both.',
      'Every cantina rumour is half a lie and half a job offer.',
    ];
    return pool[_rand.nextInt(pool.length)];
  }

  /// Generate a 6-slot daily plan for an agent (Smallville §4.2).
  Future<List<Map<String, String>>> dailyPlan({
    required String agentName,
    required String faction,
    required String longTermGoal,
  }) async {
    if (!hasKey) return _fallbackPlan();
    final prompt =
        'You are $agentName ($faction). Your long-term goal: $longTermGoal. '
        'Generate a 6-slot daily plan for today on Coruscant. '
        'Respond ONLY with a JSON object: '
        '{"slots":[{"time":"HHMM","activity":"string"}]}. '
        'Times: 0700, 1000, 1300, 1600, 1900, 2200. Activities <= 80 chars, '
        'in-character, Star Wars terminology only.';
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'message': prompt,
              'temperature': 0.8,
              'max_tokens': 400,
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode >= 400) return _fallbackPlan();
      final outer = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = _stripCodeFences((outer['text'] as String?)?.trim() ?? '');
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final slots = (parsed['slots'] as List?) ?? const [];
      final list = slots
          .whereType<Map>()
          .map((e) => {
                'time': (e['time'] as String?)?.trim() ?? '',
                'activity': (e['activity'] as String?)?.trim() ?? '',
              })
          .where((e) => e['time']!.isNotEmpty && e['activity']!.isNotEmpty)
          .toList();
      if (list.isEmpty) return _fallbackPlan();
      return list;
    } catch (e) {
      // debugPrint('Cohere dailyPlan error: $e');
      return _fallbackPlan();
    }
  }

  List<Map<String, String>> _fallbackPlan() => const [
        {'time': '0700', 'activity': 'Sweep the safehouse for surveillance bugs.'},
        {'time': '1000', 'activity': 'Meet a contact at Dex\'s Diner on level 1313.'},
        {'time': '1300', 'activity': 'Refuel and recalibrate ship at Westport hangar 12.'},
        {'time': '1600', 'activity': 'Attend a sabacc game at the Outlander Club.'},
        {'time': '1900', 'activity': 'Encrypted holocall with off-world handler.'},
        {'time': '2200', 'activity': 'Patrol Uscru rooftops — verify dead-drop sites.'},
      ];

  // ===== News fallback ===============================================

  String _fallback() => _canned[_rand.nextInt(_canned.length)];

  static const _canned = <String>[
    'Senate District lane 9 closed — diplomatic convoy from Naboo arriving Platform 17.',
    'Uscru entertainment sector reports record turnout at the Outlander Club tonight.',
    'CoCo Town weather: acid drizzle through grid 4412 — keep canopies sealed.',
    'Federal District: vote on Trade Federation tariffs delayed 48 standard hours.',
    'The Works manufacturing zone back online after 6-hour power grid fault.',
    'Speeder lane 41 cleared after collision between two Aratech 74-Z bikes.',
    'Galactic Senate Guard increases patrols around 500 Republica after threat report.',
    'Jedi Temple reports unscheduled landing of a Delta-7 starfighter at Pad 9.',
    'Market alert: Czerka Corp shares up 4.2% on rumored Outer Rim contract.',
    'CSF advises avoiding the Manarai Mountains skyway during senate adjournment.',
  ];
}

// =====================================================================
// AGENT TURN MODEL
// =====================================================================

class AgentTurn {
  AgentTurn({
    required this.agentName,
    required this.innerMonologue,
    required this.socialTarget,
    required this.dialogue,
    required this.physicalActionType,
    required this.physicalActionDetails,
    required this.relationshipUpdates,
  });

  final String agentName;
  final String innerMonologue;
  final String socialTarget;
  final String dialogue;
  final String physicalActionType;
  final String physicalActionDetails;
  final List<RelationshipUpdate> relationshipUpdates;

  factory AgentTurn.fromJson(Map<String, dynamic> json, {required String fallbackAgent}) {
    final social = (json['social_action'] as Map?)?.cast<String, dynamic>() ?? const {};
    final phys = (json['physical_action'] as Map?)?.cast<String, dynamic>() ?? const {};
    final updates = (json['relationship_updates'] as List?) ?? const [];
    return AgentTurn(
      agentName: fallbackAgent,
      innerMonologue: (json['inner_monologue'] as String?)?.trim() ?? '',
      socialTarget: (social['target'] as String?)?.trim() ?? 'None',
      dialogue: (social['dialogue'] as String?)?.trim() ?? '',
      physicalActionType: (phys['type'] as String?)?.trim() ?? 'IDLE',
      physicalActionDetails: (phys['details'] as String?)?.trim() ?? '',
      relationshipUpdates: updates
          .whereType<Map>()
          .map((e) => RelationshipUpdate.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class RelationshipUpdate {
  RelationshipUpdate({
    required this.character,
    required this.trustDelta,
    required this.reason,
  });

  final String character;
  final int trustDelta;
  final String reason;

  factory RelationshipUpdate.fromJson(Map<String, dynamic> json) {
    return RelationshipUpdate(
      character: (json['character'] as String?)?.trim() ?? '',
      trustDelta: (json['trust_delta'] as num?)?.round() ?? 0,
      reason: (json['reason'] as String?)?.trim() ?? '',
    );
  }
}
