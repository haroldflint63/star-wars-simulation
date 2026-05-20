/// Autonomous galaxy event generator.
///
/// Periodically fabricates emergent world events (bounty hunts,
/// smuggling ops, Sith manipulation, rebellions, syndicate hits,
/// planetary disasters, ship malfunctions, …) and pushes them into
/// the simulation's `worldStateContext` so every agent reacts to a
/// living, breathing galaxy. Uses Groq when available for speed,
/// otherwise falls through to Cohere bulletins.
library;

import 'dart:async';
import 'dart:math';

import 'cohere_client.dart';
import 'groq_client.dart';

class EventGenerator {
  EventGenerator({CohereClient? cohere, GroqClient? groq})
      : _cohere = cohere ?? CohereClient(),
        _groq = groq ?? GroqClient();

  final CohereClient _cohere;
  final GroqClient _groq;
  final _rand = Random();

  static const _kinds = [
    'political conflict in the Galactic Senate',
    'new bounty posted by the Hutt Cartel',
    'smuggling operation through the Corellian Run',
    'Jedi investigation in the lower levels',
    'Sith manipulation of a Senator',
    'rebellion cell uprising on an Outer Rim world',
    'trade dispute between the Trade Federation and Bothans',
    'Crimson Dawn syndicate hit in CoCo Town',
    'planetary disaster (volcanic storm, hyperspace anomaly, plague)',
    'critical ship malfunction in Coruscant orbit',
    'underground social gathering of Outer Rim diplomats',
    'black-market deal in the Works manufacturing district',
  ];

  /// Returns a single ~1-2 sentence cinematic event headline.
  Future<String> nextEvent() async {
    final kind = _kinds[_rand.nextInt(_kinds.length)];
    final prompt =
        'Generate ONE cinematic, in-universe Star Wars event headline '
        '(1-2 sentences, max 200 chars). Subject: $kind. Include a '
        'specific location, faction or named character, and a stakes hook. '
        'No quotes, no preamble. Sound like a HoloNet breaking news ticker.';

    // Prefer Groq for speed.
    final fast = await _groq.completeText(
      _systemDirective,
      prompt,
      maxTokens: 120,
      temperature: 0.95,
    );
    if (fast != null && fast.isNotEmpty) {
      return _clip(fast);
    }
    // Fall back to Cohere bulletin (will fall back to canned if no key).
    final slow = await _cohere.coruscantBulletin();
    return _clip(slow);
  }

  static String _clip(String s) {
    final one = s.replaceAll('"', '').split('\n').first.trim();
    return one.length > 200 ? '${one.substring(0, 200)}…' : one;
  }

  static const _systemDirective =
      'You are the Star Wars galaxy event generator. Output ONE cinematic '
      'HoloNet headline, lore-accurate, no slang, no preamble, max 200 chars.';
}
