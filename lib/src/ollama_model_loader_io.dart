import 'llm.dart';
import 'ollama.dart';

/// Creates the Ollama-backed model using environment variables.
LlmPlannerModel? createOllamaPlannerModelFromEnvironment() {
  return OllamaPlannerModel.fromEnvironment();
}
