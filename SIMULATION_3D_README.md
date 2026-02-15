# Town Simulation 3D - Sims-Style Multi-Agent Simulation

## Overview
A beautifully rendered 3D isometric simulation of a multi-agent town, inspired by The Sims game aesthetics and gameplay.

## Features

### 🎮 3D Isometric View
- **Real-time 3D rendering** with isometric projection
- **Animated agents** with walking animations, arm/leg swinging, and bobbing effects
- **3D buildings** with proper lighting and shadows
- **Interactive grid floor** with Sims-style green tiles
- **Camera controls**: Pan, zoom, and rotate the view

### 🎨 Sims-Like UI
- **Bottom control panel** similar to The Sims interface
- **Agent selection** with green plumbob (diamond) above selected characters
- **Activity feed** showing real-time simulation events
- **Speed controls** to adjust simulation speed (0.5x to 3.0x)
- **Dark theme** with teal/cyan accents

### 👥 Agent System
- **3 AI agents**: Ava (Pink), Noah (Blue), and Liam (Amber)
- **Unique colors** for easy identification
- **Animated movement** with realistic walking cycles
- **Location tracking** - agents move between buildings
- **Social relationships** displayed in control panel

### 🏢 Locations
- **Town Square** (Blue building)
- **Cafe** (Orange building)
- **Office** (Gray building)
- **Park** (Green building)

### 🎯 Interactive Features
- **Click agents** to select and view their info
- **Relationship stats** showing affinity and trust levels
- **Live activity feed** with color-coded events
- **Play/Pause simulation** controls
- **Adjustable speed** slider

### ✨ Visual Effects
- **Shadows** under agents and buildings
- **Glowing plumbob** for selected agent
- **Gradient buildings** with window details
- **Radial background** gradient
- **Smooth animations** at 60 FPS

## Controls

| Action | Input |
|--------|-------|
| **Pan Camera** | Click and drag |
| **Zoom** | Pinch gesture or scroll |
| **Select Agent** | Click/tap on agent |
| **Play/Pause** | Click PLAY/PAUSE button |
| **Adjust Speed** | Use speed slider |

## Architecture

### Core Components
- `WorldRenderer3DInteractive` - Main 3D rendering engine with isometric projection
- `SimsControlPanel` - UI control panel with Sims-style design
- `Simulation3DView` - Main view coordinating the renderer and controls
- `SimulationEngine` - Tick-based simulation engine
- `Agent` - AI agent with memory, planning, and social relationships

### Rendering Pipeline
1. Isometric projection converts 3D world coordinates to 2D screen space
2. Layered rendering: Grid → Buildings → Agents → UI
3. Animation controllers for smooth agent movement
4. Custom painters for complex 3D shapes

### Visual Design
- **Color Palette**: Teal/Cyan primary, dark backgrounds
- **Typography**: Orbitron for headers, Roboto Mono for data
- **Shadows & Glows**: Subtle effects for depth
- **Animations**: 2-second loops with sine wave motion

## Running the App

```bash
# Install dependencies
flutter pub get

# Run on web (recommended for best performance)
flutter run -d chrome

# Run on macOS (requires CocoaPods)
flutter run -d macos
```

## Technical Details

### Dependencies
- `flutter` - UI framework
- `vector_math` ^2.1.4 - 3D vector mathematics
- `google_fonts` ^6.3.2 - Custom typography
- `flutter_cube` ^0.1.1 - 3D rendering utilities

### Performance
- Optimized custom painter with selective repainting
- Event buffer limited to 50 most recent events
- Efficient isometric projection calculations
- Hardware-accelerated rendering via Flutter

## Future Enhancements
- [ ] 3D camera rotation
- [ ] More complex building models
- [ ] Agent-to-agent interactions with dialogue
- [ ] Weather and day/night cycles
- [ ] Additional locations and activities
- [ ] Save/load simulation state
- [ ] Agent customization

## Credits
Inspired by **The Sims** series by Maxis/EA for the visual style and UI design.

Built with **Flutter** and **Dart** for cross-platform compatibility.
