import 'package:flutter_test/flutter_test.dart';
import 'package:my_dart_project/simulation.dart';

void main() {
  group('Application Tests', () {
    test('App readiness is true', () {
      expect(isAppReady(), isTrue);
    });

    test('Default simulation emits events for each tick and agent', () async {
      final simulation = buildDefaultSimulation();
      final events = await simulation.run(ticks: 3);

      expect(events.length, equals(9));
      expect(events.first.description.contains('[llm]'), isTrue);
      expect(events.last.tick, equals(3));
    });

    test('LLM planner marks actions and relationship graph evolves', () async {
      final simulation = buildDefaultSimulation();
      final events = await simulation.run(ticks: 2);

      expect(events.first.description.contains('[llm]'), isTrue);
      expect(
        simulation.relationships.affinity('luke', 'leia'),
        greaterThan(0.6),
      );
    });
  });
}
