import 'package:my_dart_project/src/smallville_agent.dart';
import 'package:my_dart_project/src/smallville_simulation.dart';

/// Runs a Smallville-style simulation with Ollama.
///
/// Usage:
///   dart run bin/smallville_demo.dart
///
/// Make sure Ollama is running:
///   ollama serve
///   ollama pull llama3.2:3b
Future<void> main(List<String> arguments) async {
  print('🚀 Smallville-style Multi-Agent Simulation');
  print('   Using Ollama for AI-powered agents\n');

  // Check for help flag
  if (arguments.contains('--help') || arguments.contains('-h')) {
    print('''
Usage: dart run bin/smallville_demo.dart [options]

Options:
  --ticks <n>     Number of simulation ticks (default: 5)
  --quiet         Minimal output
  --help, -h      Show this help

Environment Variables:
  OLLAMA_BASE_URL    Ollama server URL (default: http://localhost:11434)
  OLLAMA_MODEL       Model to use (default: llama3.2:3b)

Example:
  dart run bin/smallville_demo.dart --ticks 10
''');
    return;
  }

  // Parse arguments
  int ticks = 5;
  bool verbose = true;

  for (int i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--ticks' && i + 1 < arguments.length) {
      ticks = int.tryParse(arguments[i + 1]) ?? 5;
    } else if (arguments[i] == '--quiet') {
      verbose = false;
    }
  }

  try {
    // Create simulation
    final SmallvilleSimulation sim = SmallvilleSimulation.starWars();

    // Run simulation
    await sim.run(ticks: ticks, verbose: verbose);

    // Show some example memories
    print('\n💭 Sample Agent Reflections:');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final SmallvilleAgent? luke = sim.getAgent('luke');
    if (luke != null) {
      final List reflections =
          luke.memory.all
              .where((item) => item.tags.contains('reflection'))
              .take(3)
              .toList();

      if (reflections.isNotEmpty) {
        print('\n🧑 Luke Skywalker:');
        for (final reflection in reflections) {
          print('   💡 ${reflection.text}');
        }
      }
    }

    final SmallvilleAgent? leia = sim.getAgent('leia');
    if (leia != null) {
      final List reflections =
          leia.memory.all
              .where((item) => item.tags.contains('reflection'))
              .take(3)
              .toList();

      if (reflections.isNotEmpty) {
        print('\n👸 Princess Leia:');
        for (final reflection in reflections) {
          print('   💡 ${reflection.text}');
        }
      }
    }

    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('\n✨ Tips:');
    print('  • Increase --ticks for longer simulations');
    print('  • Check agent memories to see reflections');
    print('  • Agents automatically reflect every ~10 ticks');
    print('  • LLM generates context-aware daily plans');
    print('');
  } catch (error, stackTrace) {
    print('\n❌ Error: $error');
    if (verbose) {
      print('\nStack trace:');
      print(stackTrace);
    }
    print('\n💡 Make sure Ollama is running:');
    print('   ollama serve');
    print('   ollama pull llama3.2:3b');
  }
}
