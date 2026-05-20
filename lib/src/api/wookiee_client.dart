/// Wookieepedia (Fandom MediaWiki) retrieval client.
///
/// Pulls the opening lore paragraph for any Star Wars subject (character,
/// planet, ship, faction) directly from starwars.fandom.com via the public
/// MediaWiki API. No key required. Used as `retrievedMemories` ground
/// truth in agent prompts.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class WookieeClient {
  static const _endpoint = 'https://starwars.fandom.com/api.php';
  final Map<String, String> _cache = {};

  /// Returns up to ~600 chars of canonical lore about [subject], stripped
  /// of wiki markup. Empty string on any failure.
  Future<String> summary(String subject) async {
    final key = subject.trim().toLowerCase();
    if (key.isEmpty) return '';
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'action': 'query',
        'prop': 'extracts',
        'exintro': '1',
        'explaintext': '1',
        'redirects': '1',
        'format': 'json',
        'origin': '*',
        'titles': subject,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) return '';
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final pages = (json['query']?['pages']) as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return '';
      final first = pages.values.first as Map<String, dynamic>;
      var extract = (first['extract'] as String?)?.trim() ?? '';
      if (extract.isEmpty) return '';
      if (extract.length > 600) extract = '${extract.substring(0, 600)}…';
      _cache[key] = extract;
      return extract;
    } catch (_) {
      return '';
    }
  }
}
