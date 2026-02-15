# Star Wars Simulation 🌌

A Flutter-based multi-agent social simulation set in the Star Wars universe, featuring AI-powered characters, interactive 3D environments, and both CLI and web UI support.

## ✨ Features

### 🎭 Multi-Agent Social Simulation
- AI-powered characters with memory, goals, and relationships
- Smallville-inspired generative agent architecture
- Dynamic social interactions and emergent storytelling
- Character avatars with unique personalities and backstories

### 🌍 Interactive Environments
- **Galaxy Map**: Navigate iconic Star Wars locations
- **3D Visualization**: Immersive 3D environments with LEGO-style aesthetics
- **Movie Set Mode**: Cinematic camera controls and scene composition
- **Premium UI**: Roblox-quality interface with smooth animations

### 🤖 LLM Integration
- Support for multiple LLM providers (OpenAI, Ollama)
- Local inference with Ollama for free usage
- Intelligent agent decision-making and dialogue generation

## 🚀 Quick Start

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0+)
- [Dart SDK](https://dart.dev/get-dart) (3.0+)
- (Optional) [Ollama](https://ollama.ai/) for free local LLM

### Installation

```bash
# Clone the repository
git clone https://github.com/haroldflint63/star-wars-simulation.git
cd star-wars-simulation

# Install dependencies
flutter pub get
```

## 🎮 Running the Simulation

### Web UI (Chrome)
```bash
flutter run -d chrome
```

### CLI Mode
```bash
dart run bin/my_dart_project.dart
```

### With Local LLM (Free)
```bash
# Pull the Ollama model
ollama pull llama3.2:3b

# Run with Ollama
LLM_PROVIDER=ollama OLLAMA_MODEL=llama3.2:3b dart run bin/my_dart_project.dart
```

## 🧪 Testing

```bash
flutter test
```

## 📚 Documentation

Explore detailed guides for specific features:

- **[AAA UI Design System](./AAA_UI_DESIGN_SYSTEM.md)** - Professional UI/UX patterns and components
- **[Avatar System](./AVATAR_SYSTEM.md)** - Character creation and customization
- **[Galaxy Map Guide](./GALAXY_MAP_GUIDE.md)** - Navigation and location system
- **[3D Simulation](./SIMULATION_3D_README.md)** - 3D environment setup and rendering
- **[LEGO Transformation](./LEGO_TRANSFORMATION.md)** - LEGO-style visual aesthetics
- **[Movie Set Mode](./STAR_WARS_MOVIE_SET.md)** - Cinematic camera and scene controls
- **[Smallville Integration](./SMALLVILLE_INTEGRATION.md)** - AI agent architecture
- **[Smallville README](./SMALLVILLE_README.md)** - Generative agent system details
- **[Premium UI Performance](./PREMIUM_UI_PERFORMANCE.md)** - Optimization techniques
- **[Roblox Quality Upgrade](./ROBLOX_QUALITY_UPGRADE.md)** - AAA-quality UI improvements
- **[API Building Features](./API_BUILDING_FEATURES.md)** - Building and construction system

## 🏗️ Architecture

```
star-wars-simulation/
├── bin/                    # CLI entry points
├── lib/                    # Main application code
│   ├── agents/            # AI agent implementations
│   ├── ui/                # Flutter UI components
│   ├── simulation/        # Simulation engine
│   └── models/            # Data models
├── test/                  # Test suites
├── web/                   # Web-specific assets
└── macos/                 # macOS platform support
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🌟 Acknowledgments

- Inspired by the [Smallville](https://github.com/google-research/google-research/tree/master/generative_agents) generative agents paper
- Star Wars universe © Lucasfilm Ltd.
- Built with [Flutter](https://flutter.dev/) and [Dart](https://dart.dev/)

---

*May the Force be with you!* ⚔️