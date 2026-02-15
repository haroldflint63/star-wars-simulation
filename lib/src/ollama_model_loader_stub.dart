import 'llm.dart';

/// Returns null on platforms without `dart:io` support.
LlmPlannerModel? createOllamaPlannerModelFromEnvironment() {
  return null;
}
