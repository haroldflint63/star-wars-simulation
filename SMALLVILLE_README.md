# Stanford Smallville-Inspired Multi-Agent Simulation

This project implements a **Stanford Smallville-style** generative agent simulation using **Ollama** for local LLM inference. Agents have memory streams, reflection capabilities, and LLM-powered planning.

## 🎯 Overview

Based on the [Stanford Smallville paper](https://arxiv.org/abs/2304.03442), this simulation creates believable AI agents that:

1. **Observe** their environment and store memories
2. **Reflect** on experiences to generate insights
3. **Plan** daily schedules using context-aware LLM generation
4. **Act** based on memories, goals, and social relationships

### Key Differences from Original Smallville

- **Local-first**: Uses Ollama instead of cloud LLMs (free!)
- **Star Wars theme**: Agents are Star Wars characters in iconic locations
- **Dart implementation**: Built with Flutter/Dart for cross-platform compatibility

## 🏗️ Architecture

### Core Components

```
lib/src/
├── smallville_memory.dart        # Memory streams + reflection
├── smallville_planner.dart       # LLM-powered daily planning
├── smallville_agent.dart         # Enhanced agent with reflection
└── smallville_simulation.dart    # Simulation engine
```

### Memory System (`SmallvilleMemory`)

- **Observation stream**: Stores events as memories with importance scores
- **Reflection mechanism**: Automatically generates insights when importance threshold is reached
- **Retrieval**: Uses recency + relevance + importance scoring (like the paper)

```dart
// Memory reflects when importance accumulates
if (importanceSum >= reflectionThreshold) {
  await memory.reflect(currentTick: tick, agentName: name);
}
```

### Planning System (`SmallvillePlanner`)

- **LLM-generated plans**: Uses Ollama to create realistic daily schedules
- **Context-aware**: Considers memories, relationships, and goals
- **Multi-step plans**: Generates 6-8 hourly activities per day

```dart
// Example LLM-generated plan
tatooine_cantina|Have breakfast and listen to local gossip
jedi_temple|Morning meditation and lightsaber training
cloud_city|Meet with friends for lunch
hoth_base|Afternoon patrol duty
```

### Reflection Process

1. **Trigger**: When `importanceSum >= threshold` (default: 100)
2. **Generate questions**: LLM creates 3 high-level reflection questions
3. **Generate insights**: LLM answers questions based on recent memories
4. **Store**: Insights saved as high-importance memories (0.8)

Example reflection:
```
Question: What does Luke think about his recent training?
Insight: I feel my connection to the Force growing stronger each day.
```

## 🚀 Getting Started

### Prerequisites

1. **Install Ollama**: https://ollama.ai
2. **Pull a model**:
   ```bash
   ollama pull llama3.2:3b
   ```

3. **Start Ollama server**:
   ```bash
   ollama serve
   ```

### Run the Demo

```bash
# Basic simulation (5 ticks)
dart run bin/smallville_demo.dart

# Longer simulation
dart run bin/smallville_demo.dart --ticks 20

# Quiet mode
dart run bin/smallville_demo.dart --quiet
```

### Configure LLM

Set environment variables:

```bash
export OLLAMA_BASE_URL=http://localhost:11434
export OLLAMA_MODEL=llama3.2:3b

dart run bin/smallville_demo.dart
```

## 📊 Example Output

```
🌟 Starting Smallville-style Star Wars Simulation
📊 Agents: 6
🗺️  Locations: 8
⏱️  Ticks to simulate: 5

━━━ Tick 0 ━━━
🧠 Agent luke ready for reflection (importance: 105.2)
💭 Agent Luke Skywalker reflecting on recent experiences...
  💡 Reflection: I feel my training is progressing well
📋 Generating new plan for luke...
  ✅ Generated 7-step plan for luke

  📍 Luke Skywalker at jedi_temple: Morning meditation and lightsaber training
  📍 Princess Leia at hoth_base: Review rebel intelligence reports
  📍 Han Solo at tatooine_cantina: Check ship repairs and cargo manifests
  ...

━━━ Tick 1 ━━━
  📍 Luke Skywalker at dagobah_swamp: Visit Master Yoda for advanced training
  📍 Princess Leia at cloud_city: Diplomatic meeting with Lando Calrissian
  ...

📈 Simulation Summary:
Total ticks: 5
Total events: 30

🧠 Agent Memory Stats:
  Luke Skywalker: 42 memories (3 reflections)
  Princess Leia: 38 memories (2 reflections)
  Han Solo: 35 memories (1 reflections)
  ...
```

## 🎮 Integration with Flutter UI

The simulation can run alongside the existing 3D visualization:

```dart
import 'package:my_dart_project/src/smallville_simulation.dart';

// Create simulation
final sim = SmallvilleSimulation.starWars();

// Run one tick per frame
await sim.tick();

// Display agent locations on 3D map
for (final agent in sim.agents) {
  final location = getCurrentLocation(agent.profile.id);
  renderAgentAt3DPosition(agent, location);
}
```

## 🧠 Agent Personalities

The simulation includes 6 Star Wars agents:

| Agent | Goal | Home |
|-------|------|------|
| Luke Skywalker | Become a Jedi Knight | Tatooine Cantina |
| Princess Leia | Lead the Rebellion | Hoth Base |
| Han Solo | Pay off debts and help friends | Tatooine Cantina |
| Darth Vader | Hunt rebels and serve Emperor | Death Star |
| Master Yoda | Train young Jedi | Dagobah Swamp |
| Padmé Amidala | Maintain peace and democracy | Naboo Palace |

### Social Relationships

- Luke ↔ Leia: 0.9 (siblings)
- Luke ↔ Han: 0.85 (best friends)
- Luke ↔ Yoda: 0.95 (master-apprentice)
- Leia ↔ Han: 0.9 (romance)
- Vader ↔ Luke: -0.7 (enemy but family)

## 🔧 Customization

### Add New Agents

```dart
final profile = AgentProfile(
  id: 'obi-wan',
  displayName: 'Obi-Wan Kenobi',
  primaryGoal: 'Guard Luke and preserve Jedi teachings',
  homeLocationId: 'tatooine_cantina',
);

final agent = factory.createAgent(profile: profile);
```

### Adjust Reflection Frequency

```dart
// Reflect more often (lower threshold)
SmallvilleAgent(
  reflectionThreshold: 50.0, // Reflects after 50 importance
  ...
);

// Reflect less often (higher threshold)
SmallvilleAgent(
  reflectionThreshold: 200.0, // Reflects after 200 importance
  ...
);
```

### Use Different LLM Models

```bash
# Faster, less capable
export OLLAMA_MODEL=llama3.2:1b

# Slower, more capable
export OLLAMA_MODEL=llama3.1:8b

# Code-optimized (for technical agents)
export OLLAMA_MODEL=codellama:7b
```

## 📚 Implementation Details

### Memory Scoring Formula

```dart
score = (0.5 × importance) + (0.3 × recency) + (0.2 × relevance)
```

- **Importance**: Agent-assigned value (0-1)
- **Recency**: `1 / (1 + age × 0.01)` 
- **Relevance**: Token overlap with query

### Reflection Triggers

1. **Importance threshold**: `importanceSum >= 100`
2. **Time-based**: Every 10 ticks
3. **Manual**: Call `agent.maybeReflect()`

### Planning Horizon

- Generates 6-8 activities per plan
- Each activity lasts ~3 ticks
- Replans after 24 ticks or plan completion

## 🎯 Comparison to Original Paper

| Feature | Paper | This Implementation |
|---------|-------|-------------------|
| Memory streams | ✅ | ✅ |
| Reflection | ✅ | ✅ |
| Planning | ✅ | ✅ |
| LLM | GPT-3.5/4 | Ollama (local) |
| Retrieval | Embedding-based | Token-based |
| Environment | Sims-like town | Star Wars galaxy |
| Language | Python | Dart |

## 🚀 Performance Tips

1. **Use smaller models** for faster responses:
   ```bash
   ollama pull llama3.2:1b  # Fastest
   ```

2. **Adjust tick delay** to reduce LLM load:
   ```dart
   await Future.delayed(Duration(seconds: 2)); // Slower but less load
   ```

3. **Reduce reflection frequency**:
   ```dart
   reflectionThreshold: 200.0  // Reflects less often
   ```

## 🐛 Troubleshooting

### "Connection refused" errors

Make sure Ollama is running:
```bash
ollama serve
```

### Slow generation

Try a smaller model:
```bash
ollama pull llama3.2:1b
export OLLAMA_MODEL=llama3.2:1b
```

### Empty reflections

Increase simulation length:
```bash
dart run bin/smallville_demo.dart --ticks 20
```

## 📖 References

- **Original Paper**: [Generative Agents: Interactive Simulacra of Human Behavior](https://arxiv.org/abs/2304.03442)
- **Medium Article**: [Stanford Smallville is Officially Open Source](https://rikiphukon.medium.com/stanford-smallville-is-officially-open-source-9882e3fbc981)
- **Ollama**: https://ollama.ai
- **Project Repo**: https://github.com/your-repo/smallville-dart

## 📝 License

MIT License - See LICENSE file for details

---

**Built with 🤖 Ollama + 🎯 Dart + ⭐ Star Wars**
