/// Cohere Embeddings client + tiny in-memory vector store.
///
/// Used for RAG long-term memory: every utterance/observation is embedded
/// and stored; before generating the next agent turn we retrieve the
/// top-K by cosine similarity for the current stimulus and pass them as
/// `retrievedMemories`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

class EmbeddingsClient {
  EmbeddingsClient({String? apiKey})
      : _apiKey = apiKey ?? const String.fromEnvironment('COHERE_API_KEY');

  static const _endpoint = 'https://api.cohere.com/v1/embed';
  static const _model = 'embed-english-light-v3.0'; // small + fast
  final String _apiKey;
  bool get hasKey => _apiKey.isNotEmpty;

  /// Returns a list of vectors, one per input. Empty list on failure.
  Future<List<List<double>>> embedBatch(List<String> texts,
      {String inputType = 'search_document'}) async {
    if (!hasKey || texts.isEmpty) return const [];
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
              'texts': texts,
              'input_type': inputType,
              'embedding_types': ['float'],
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final embs = json['embeddings'];
      final List raw = embs is Map ? (embs['float'] as List? ?? const []) : (embs as List? ?? const []);
      return raw
          .map<List<double>>((v) => (v as List).map((e) => (e as num).toDouble()).toList())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<double>?> embedOne(String text,
      {String inputType = 'search_query'}) async {
    final batch = await embedBatch([text], inputType: inputType);
    return batch.isEmpty ? null : batch.first;
  }
}

/// Per-agent embedded memory store with cosine top-K retrieval.
class EmbeddingMemoryStore {
  final List<_EmbeddedItem> _items = [];
  int get length => _items.length;

  void add(String text, List<double> vec) {
    if (text.isEmpty || vec.isEmpty) return;
    _items.add(_EmbeddedItem(text, vec));
    // Cap memory; drop oldest when over 200.
    if (_items.length > 200) _items.removeAt(0);
  }

  List<String> topK(List<double> queryVec, int k) {
    if (_items.isEmpty || queryVec.isEmpty) return const [];
    final scored = _items
        .map((it) => MapEntry(it.text, _cosine(queryVec, it.vec)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.take(k).map((e) => e.key).toList();
  }

  static double _cosine(List<double> a, List<double> b) {
    final n = min(a.length, b.length);
    if (n == 0) return 0;
    double dot = 0, na = 0, nb = 0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }
}

class _EmbeddedItem {
  _EmbeddedItem(this.text, this.vec);
  final String text;
  final List<double> vec;
}
