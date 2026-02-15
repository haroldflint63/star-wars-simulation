import 'dart:io';

import 'package:my_dart_project/simulation.dart';
import 'package:my_dart_project/src/planner_factory.dart';

/// Runs the demo simulation in the terminal.
Future<void> main() async {
  final bool ready = isAppReady();
  if (!ready) {
    throw StateError('Application failed readiness check.');
  }

  final String provider =
      Platform.environment['LLM_PROVIDER']?.toLowerCase() ?? 'local';
  final PlannerBootstrap bootstrap = buildPlannerForProvider(
    provider: provider,
  );
  // ignore: avoid_print
  print(bootstrap.statusMessage);

  final events = await buildDefaultSimulation(
    planner: bootstrap.planner,
  ).run(ticks: 4);
  for (final event in events) {
    // ignore: avoid_print
    print('[tick=${event.tick}] ${event.description}');
  }
}
