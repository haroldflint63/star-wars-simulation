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
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) {
        debugPrint('Cohere ${res.statusCode}: ${res.body}');
        return _fallback();
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final text = (json['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) return _fallback();
      return text.replaceAll('"', '').split('\n').first.trim();
    } catch (e) {
      debugPrint('Cohere error: $e');
      return _fallback();
    }
  }

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
