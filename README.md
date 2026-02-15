# My Dart Project

Flutter-based multi-agent social simulation with CLI and web UI support.

## Run in Chrome (Flutter)
```bash
flutter run -d chrome
```

## Run CLI simulation
```bash
dart run bin/my_dart_project.dart
```

## Test
```bash
flutter test
```

## Optional free LLM mode (CLI)
```bash
ollama pull llama3.2:3b
LLM_PROVIDER=ollama OLLAMA_MODEL=llama3.2:3b dart run bin/my_dart_project.dart
```
