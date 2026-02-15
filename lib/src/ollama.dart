import 'dart:convert';
import 'dart:io';

import 'llm.dart';

/// Free local model adapter for Ollama.
class OllamaPlannerModel implements LlmPlannerModel {
  /// Creates model.
  OllamaPlannerModel({
    required this.baseUrl,
    required this.model,
    this.maxRetries = 0,
    this.timeout = const Duration(seconds: 4),
  });

  /// Builds from process environment.
  factory OllamaPlannerModel.fromEnvironment() {
    final String baseUrl =
        Platform.environment['OLLAMA_BASE_URL'] ?? 'http://localhost:11434';
    final String model = Platform.environment['OLLAMA_MODEL'] ?? 'llama3.2:3b';
    final int maxRetries =
        int.tryParse(Platform.environment['OLLAMA_MAX_RETRIES'] ?? '') ?? 0;
    final int timeoutMs =
        int.tryParse(Platform.environment['OLLAMA_TIMEOUT_MS'] ?? '') ?? 4000;
    return OllamaPlannerModel(
      baseUrl: baseUrl,
      model: model,
      maxRetries: maxRetries < 0 ? 0 : maxRetries,
      timeout: Duration(milliseconds: timeoutMs < 500 ? 500 : timeoutMs),
    );
  }

  /// Ollama base URL.
  final String baseUrl;

  /// Ollama model name.
  final String model;

  /// Number of retries after first failure.
  final int maxRetries;

  /// Request timeout.
  final Duration timeout;

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final Uri uri = Uri.parse('$baseUrl/api/generate');
    final String prompt = '$systemPrompt\n\n$userPrompt';

    Object? lastError;
    for (int attempt = 0; attempt <= maxRetries; attempt += 1) {
      try {
        final HttpClient client = HttpClient();
        final HttpClientRequest request = await client
            .postUrl(uri)
            .timeout(timeout);
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode(<String, Object>{
            'model': model,
            'prompt': prompt,
            'stream': false,
          }),
        );

        final HttpClientResponse response = await request.close().timeout(
          timeout,
        );
        final String raw = await utf8.decodeStream(response).timeout(timeout);
        client.close(force: true);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Ollama request failed with status ${response.statusCode}',
          );
        }

        final dynamic decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Unexpected Ollama response type');
        }

        final String? text = decoded['response'] as String?;
        if (text == null || text.trim().isEmpty) {
          throw const FormatException('Missing response field from Ollama');
        }

        return text.trim();
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError('Ollama completion failed: $lastError');
  }
}
