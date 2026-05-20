/// Groq LLM client — OpenAI-compatible Chat Completions for ultra-fast
/// in-character dialogue. Reads --dart-define=GROQ_API_KEY=...
///
/// On success, returns an [AgentTurn] using the same schema as
/// CohereClient.agentTurn so it's a drop-in replacement. Falls back to
/// null on any error so the caller can use Cohere as backup.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cohere_client.dart' show AgentTurn, RelationshipUpdate;

class GroqClient {
  GroqClient({String? apiKey})
      : _apiKey = apiKey ?? const String.fromEnvironment('GROQ_API_KEY');

  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  final String _apiKey;
  bool get hasKey => _apiKey.isNotEmpty;

  Future<AgentTurn?> agentTurn({
    required String systemDirective,
    required String agentName,
    required String faction,
    required String traits,
    required String longTermGoal,
    required String currentLocation,
    required List<String> nearbyCharacters,
    required String worldStateContext,
    List<String> retrievedMemories = const [],
  }) async {
    if (!hasKey) return null;
    final nearby = nearbyCharacters.isEmpty ? 'None' : nearbyCharacters.join(', ');
    final mems = retrievedMemories.isEmpty
        ? '- (no prior memories retrieved)'
        : retrievedMemories.map((m) => '- $m').join('\n');
    final user = '''
You are $agentName ($faction). Traits: $traits. Long-term goal: $longTermGoal.
Location: $currentLocation. Nearby: $nearby. Local event: $worldStateContext.

Relevant memories:
$mems

Respond ONLY with a single JSON object matching:
{
  "inner_monologue": "string",
  "social_action": {"target":"string","dialogue":"string"},
  "physical_action": {"type":"IDLE|MOVE|ATTACK|TRADE|USE_ITEM","details":"string"},
  "relationship_updates": [{"character":"string","trust_delta":-5,"reason":"string"}]
}
''';
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
              'messages': [
                {'role': 'system', 'content': systemDirective},
                {'role': 'user', 'content': user},
              ],
              'temperature': 0.85,
              'max_tokens': 500,
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) return null;
      final outer = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = outer['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final content = (choices.first['message']?['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) return null;
      final parsed = jsonDecode(_strip(content)) as Map<String, dynamic>;
      return AgentTurn.fromJson(parsed, fallbackAgent: agentName);
    } catch (_) {
      return null;
    }
  }

  String _strip(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      final nl = t.indexOf('\n');
      if (nl != -1) t = t.substring(nl + 1);
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }

  /// Quick free-form text completion (used by the event generator).
  Future<String?> completeText(String systemDirective, String userPrompt,
      {int maxTokens = 200, double temperature = 0.9}) async {
    if (!hasKey) return null;
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
              'messages': [
                {'role': 'system', 'content': systemDirective},
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': temperature,
              'max_tokens': maxTokens,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 400) return null;
      final outer = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = outer['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final content = (choices.first['message']?['content'] as String?)?.trim();
      return (content == null || content.isEmpty) ? null : content;
    } catch (_) {
      return null;
    }
  }

  // Unused, kept for type completeness.
  // ignore: unused_element
  static RelationshipUpdate _r(String c, int d, String r) =>
      RelationshipUpdate(character: c, trustDelta: d, reason: r);
}
