import 'llm.dart';
import 'ollama_model_loader_stub.dart'
    if (dart.library.io) 'ollama_model_loader_io.dart'
    as ollama_loader;
import 'planner.dart';

/// Result of planner bootstrap.
class PlannerBootstrap {
  /// Creates bootstrap result.
  const PlannerBootstrap({
    required this.planner,
    required this.provider,
    required this.statusMessage,
  });

  /// Fully configured planner.
  final Planner planner;

  /// Active provider name.
  final String provider;

  /// Human-readable status for logs/UI.
  final String statusMessage;
}

/// Builds planner based on provider name.
PlannerBootstrap buildPlannerForProvider({required String provider}) {
  final String normalized = provider.toLowerCase().trim();
  final LlmBackedPlanner localLlm = LlmBackedPlanner(
    model: const RuleBasedLlmPlannerModel(),
    fallback: const HeuristicPlanner(),
  );

  if (normalized == 'ollama') {
    final LlmPlannerModel? ollamaModel =
        ollama_loader.createOllamaPlannerModelFromEnvironment();
    if (ollamaModel != null) {
      return PlannerBootstrap(
        planner: LlmBackedPlanner(
          model: ollamaModel,
          fallback: const HeuristicPlanner(),
        ),
        provider: 'ollama',
        statusMessage: 'LLM provider: ollama',
      );
    }
    return PlannerBootstrap(
      planner: localLlm,
      provider: 'local',
      statusMessage: 'LLM provider fallback: local (Ollama unavailable here)',
    );
  }

  return PlannerBootstrap(
    planner: localLlm,
    provider: 'local',
    statusMessage: 'LLM provider: local',
  );
}
