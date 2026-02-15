import 'package:my_dart_project/src/smallville_simulation.dart';

/// Quick test of Smallville simulation (3 ticks).
/// Run: dart run bin/smallville_test.dart
Future<void> main() async {
  print('🧪 Testing Smallville Simulation\n');

  try {
    final SmallvilleSimulation sim = SmallvilleSimulation.starWars();

    print('✅ Simulation created successfully');
    print('   - ${sim.agents.length} agents');
    print('   - ${sim.world.locations.length} locations\n');

    print('Running 3 simulation ticks...\n');

    for (int i = 0; i < 3; i++) {
      print('━━━ Tick $i ━━━');
      final events = await sim.tick();
      for (final event in events) {
        print('  📍 ${event.description}');
      }
      print('');
    }

    print('✅ Test completed successfully!\n');
    print('💡 Try the full demo:');
    print('   dart run bin/smallville_demo.dart --ticks 10');
  } catch (error, stackTrace) {
    print('❌ Test failed: $error');
    print('\nStack trace:');
    print(stackTrace);
    print('\n💡 Make sure Ollama is running:');
    print('   ollama serve');
    print('   ollama pull llama3.2:3b');
  }
}
