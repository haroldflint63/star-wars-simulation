# Smallville + Ollama Integration Guide

## Quick Start (5 minutes)

### 1. Install Ollama

```bash
# macOS/Linux
curl https://ollama.ai/install.sh | sh

# Or download from https://ollama.ai
```

### 2. Start Ollama & Pull Model

```bash
# Start Ollama server
ollama serve

# In another terminal, pull a model
ollama pull llama3.2:3b  # Fast, recommended for testing
# or
ollama pull llama3.1:8b  # Better quality, slower
```

### 3. Run Test

```bash
cd /Users/harold/Desktop/sim_multi_agent/my-dart-project

# Quick 3-tick test (30 seconds)
dart run bin/smallville_test.dart

# Full demo (5 ticks with reflections)
dart run bin/smallville_demo.dart

# Longer simulation
dart run bin/smallville_demo.dart --ticks 20
```

## What You Should See

```
🌟 Starting Smallville-style Star Wars Simulation
📊 Agents: 6
🗺️  Locations: 8
⏱️  Ticks to simulate: 5

━━━ Tick 0 ━━━
📋 Generating new plan for luke...
  ✅ Generated 7-step plan for luke
📋 Generating new plan for leia...
  ✅ Generated 6-step plan for leia
  
  📍 Luke Skywalker at jedi_temple: Morning meditation and lightsaber training
  📍 Princess Leia at hoth_base: Review rebel intelligence reports
  📍 Han Solo at tatooine_cantina: Check ship repairs with Chewbacca
  📍 Darth Vader at death_star: Oversee construction of new weapon systems
  📍 Master Yoda at dagobah_swamp: Commune with the Force in solitude
  📍 Padmé Amidala at naboo_palace: Meet with senators about trade routes

━━━ Tick 1 ━━━
🧠 Agent luke ready for reflection (importance: 125.4)
💭 Agent Luke Skywalker reflecting on recent experiences...
  💡 Reflection: I sense my connection to the Force growing stronger
  💡 Reflection: My training with Master Yoda has been transformative
  💡 Reflection: I'm ready to face greater challenges

  📍 Luke Skywalker at dagobah_swamp: Visit Master Yoda for advanced Force training
  ...
```

## Architecture Overview

```
SmallvilleSimulation
├── SmallvilleAgent (6 Star Wars characters)
│   ├── SmallvilleMemory (observations + reflections)
│   ├── SmallvillePlanner (LLM-powered daily plans)
│   └── RelationshipGraph (social ties)
└── WorldState (locations + events)
```

### Key Classes

#### `SmallvilleMemory`
- Stores observations with importance scores
- Auto-triggers reflection when `importanceSum >= threshold`
- Generates insights using Ollama
- Example reflection:
  ```
  Question: What does Luke think about his training?
  Insight: I feel my Force abilities growing each day.
  ```

#### `SmallvillePlanner`
- Generates 6-8 activity schedule per agent
- Uses memories + relationships for context
- Example LLM prompt:
  ```
  Character: Luke Skywalker
  Goal: Become a Jedi Knight
  Recent Memory: Completed lightsaber training
  
  Generate daily schedule...
  ```

#### `SmallvilleAgent`
- Combines memory + planning + relationships
- Reflects every 10 ticks automatically
- Acts based on current plan

## Integration with Existing UI

### Option 1: Replace Existing Engine

```dart
// lib/src/engine.dart
import 'smallville_simulation.dart';

class SimulationEngine {
  late SmallvilleSimulation _simulation;
  
  void initialize() {
    _simulation = SmallvilleSimulation.starWars();
  }
  
  Future<void> tick() async {
    await _simulation.tick();
  }
  
  List<AgentProfile> get agents => _simulation.profiles;
}
```

### Option 2: Side-by-Side (Recommended)

```dart
// Keep existing engine for simple simulation
// Add SmallvilleSimulation for AI-powered mode

class Simulation3DView extends StatefulWidget {
  final bool useSmallville; // Toggle between modes
  
  @override
  Widget build(BuildContext context) {
    return _isSmallvilleMode 
      ? SmallvilleVisualization(simulation: _smallville)
      : InteractiveWorldRenderer3D(...);
  }
}
```

### Option 3: Hybrid Approach

```dart
// Use Smallville planning for some agents
// Keep simple logic for background NPCs

final premiumAgents = ['luke', 'leia', 'vader']; // AI-powered
final backgroundAgents = ['guard1', 'citizen2']; // Heuristic

for (final agent in agents) {
  if (premiumAgents.contains(agent.id)) {
    await agent.actWithAI(); // Uses Ollama
  } else {
    agent.actWithHeuristic(); // Fast fallback
  }
}
```

## Performance Tuning

### Model Selection

```bash
# Fast (200-500ms/response)
ollama pull llama3.2:1b
export OLLAMA_MODEL=llama3.2:1b

# Balanced (500ms-2s/response) - RECOMMENDED
ollama pull llama3.2:3b
export OLLAMA_MODEL=llama3.2:3b

# Quality (2-5s/response)
ollama pull llama3.1:8b
export OLLAMA_MODEL=llama3.1:8b
```

### Reflection Tuning

```dart
// Frequent reflections (every 50 importance)
SmallvilleAgent(reflectionThreshold: 50.0)

// Balanced (every 100-150 importance) - RECOMMENDED
SmallvilleAgent(reflectionThreshold: 100.0)

// Rare reflections (every 300 importance)
SmallvilleAgent(reflectionThreshold: 300.0)
```

### Batch Processing

```dart
// DON'T: Sequential (slow)
for (final agent in agents) {
  await agent.reflect(); // Waits for each
}

// DO: Parallel (fast)
await Future.wait(
  agents.map((a) => a.reflect())
);
```

## Troubleshooting

### Ollama Connection Errors

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Restart Ollama
pkill ollama && ollama serve
```

### Slow Performance

1. Use smaller model: `llama3.2:1b`
2. Increase reflection threshold: `300.0`
3. Add delay between ticks: `await Future.delayed(Duration(seconds: 1))`

### Empty Plans

Check Ollama model is downloaded:
```bash
ollama list  # Should show your model
ollama pull llama3.2:3b  # Download if missing
```

### Memory Leaks

Limit memory size:
```dart
class SmallvilleMemory {
  List<MemoryItem> get all {
    // Keep only last 200 memories
    final recent = [..._observations, ..._reflections]
      ..sort((a, b) => b.tick.compareTo(a.tick));
    return recent.take(200).toList();
  }
}
```

## Advanced Customization

### Add Custom Agent

```dart
final customProfile = AgentProfile(
  id: 'obi_wan',
  displayName: 'Obi-Wan Kenobi',
  primaryGoal: 'Protect Luke and preserve Jedi knowledge',
  homeLocationId: 'tatooine_cantina',
);

final customAgent = factory.createAgent(
  profile: customProfile,
  reflectionThreshold: 120.0,
);
```

### Custom Relationship Dynamics

```dart
// Add rivalry
relationships.setBidirectional(
  a: 'luke', 
  b: 'vader',
  affinity: -0.9,  // Strong dislike
  trust: 0.1,      // Low trust
  tick: 0,
);

// Add mentorship
relationships.setBidirectional(
  a: 'yoda',
  b: 'luke', 
  affinity: 0.95,  // Mutual respect
  trust: 1.0,      // Complete trust
  tick: 0,
);
```

### Custom Reflection Questions

Edit `SmallvilleMemory._generateReflectionQuestions()`:

```dart
final String userPrompt = '''
Agent: $agentName
Recent observations: $memoryContext

Generate 3 reflection questions about:
1. Emotional state and feelings
2. Relationships with other characters
3. Progress toward primary goal

Format: One question per line.
''';
```

## Production Deployment

### 1. Error Handling

```dart
try {
  await simulation.tick();
} catch (error) {
  // Fallback to heuristic planning
  print('LLM failed, using backup planner');
  useHeuristicFallback();
}
```

### 2. Caching

```dart
// Cache plans to reduce LLM calls
final Map<String, PlanAction> _planCache = {};

PlanAction? getCachedPlan(String agentId, int tick) {
  return _planCache['${agentId}_$tick'];
}
```

### 3. Rate Limiting

```dart
class RateLimitedLLM {
  final Queue<Future> _queue = Queue();
  int _activeRequests = 0;
  final int maxConcurrent = 3; // Limit parallel requests
  
  Future<String> complete(String prompt) async {
    while (_activeRequests >= maxConcurrent) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    _activeRequests++;
    try {
      return await _llm.complete(prompt);
    } finally {
      _activeRequests--;
    }
  }
}
```

## Next Steps

1. **Test the basics**: Run `smallville_test.dart`
2. **Explore reflections**: Run full demo with `--ticks 20`
3. **Integrate with UI**: Add Smallville visualization
4. **Customize agents**: Add your own characters
5. **Tune performance**: Adjust model and thresholds

## Resources

- **Ollama Models**: https://ollama.ai/library
- **Smallville Paper**: https://arxiv.org/abs/2304.03442
- **Dart Async**: https://dart.dev/codelabs/async-await
- **Flutter Integration**: [SMALLVILLE_README.md](SMALLVILLE_README.md)
