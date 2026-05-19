import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;

import 'web_synth.dart';

/// Star Wars sound effects manager
///
/// Professional audio system with web compatibility
///
/// FREE APIs FOR AUDIO ASSETS:
/// - FreeSFX: https://www.freesfx.co.uk/ (100% free sound effects)
/// - Mixkit: https://mixkit.co/free-sound-effects/ (Free sound effects)
/// - Freesound: https://freesound.org/ (Creative Commons sounds)
/// - SoundBible: https://soundbible.com/ (Free sound clips)
/// - ZapSplat: https://www.zapsplat.com/ (Free SFX library)
///
/// To use real sounds:
/// 1. Download Star Wars sound effects from above APIs
/// 2. Place in assets/sounds/ folder
/// 3. Update pubspec.yaml with asset paths
/// 4. Replace _playTone() calls with: await p.play(AssetSource('sounds/filename.mp3'));
class StarWarsSounds {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _ambientPlayer = AudioPlayer();
  static final AudioPlayer _musicPlayer = AudioPlayer();
  static final math.Random _random = math.Random();

  static bool _soundEnabled = true;
  static double _volume = 0.6;

  /// Initialize sound system
  static Future<void> initialize() async {
    await _player.setVolume(_volume);
    await _ambientPlayer.setVolume(_volume * 0.4);
    await _musicPlayer.setVolume(_volume * 0.3);
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
  }

  /// Toggle sound on/off
  static void toggleSound() {
    _soundEnabled = !_soundEnabled;
    if (!_soundEnabled) {
      stopAll();
    }
  }

  /// Set volume (0.0 to 1.0)
  static void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _player.setVolume(_volume);
    _ambientPlayer.setVolume(_volume * 0.4);
    _musicPlayer.setVolume(_volume * 0.3);
  }

  /// Play lightsaber ignition — procedural (no network).
  static Future<void> lightsaberIgnite() async {
    if (!_soundEnabled) return;
    if (kIsWeb) {
      WebSynth.lightsaber();
    }
  }

  /// Play lightsaber swing — procedural (no network).
  static Future<void> lightsaberSwing() async {
    if (!_soundEnabled) return;
    if (kIsWeb) {
      WebSynth.lightsaber();
    }
  }

  /// Play blaster fire — procedural Web Audio (no network).
  static Future<void> blasterFire() async {
    if (!_soundEnabled) return;
    if (kIsWeb) {
      WebSynth.blaster();
    }
  }

  /// Play door open/close
  static Future<void> doorSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(
        UrlSource(
          'https://cdn.freesound.org/previews/244/244270_2398403-lq.mp3',
        ),
      );
      debugPrint('🔊 Playing: Door Sound');
    } catch (e) {
      // Silent fallback
    }
  }

  /// Play R2-D2 beep
  static Future<void> r2d2Beep() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(
        UrlSource(
          'https://cdn.freesound.org/previews/173/173608_2394245-lq.mp3',
        ),
      );
      debugPrint('🔊 Playing: R2-D2 Beep');
    } catch (e) {
      // Silent fallback
    }
  }

  /// Play footstep sound
  static Future<void> footstep() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(
        UrlSource(
          'https://cdn.freesound.org/previews/393/393255_7080281-lq.mp3',
        ),
      );
    } catch (e) {
      // Silent fallback
    }
  }

  /// Play ambient space sound — procedural drone (no network).
  static Future<void> playAmbientSpace() async {
    if (!_soundEnabled) return;
    if (kIsWeb) {
      WebSynth.startSpaceDrone();
    }
  }

  /// Play cantina music (placeholder)
  static Future<void> playCantinaMusic() async {
    if (!_soundEnabled) return;
    try {
      await _musicPlayer.play(
        UrlSource(
          'https://cdn.freesound.org/previews/352/352514_5121236-lq.mp3',
        ),
      );
      debugPrint('🔊 Playing: Cantina Music');
    } catch (e) {
      // Silent fallback
    }
  }

  /// Play Imperial March theme (placeholder)
  static Future<void> playImperialMarch() async {
    if (!_soundEnabled) return;
    try {
      await _musicPlayer.play(
        UrlSource(
          'https://cdn.freesound.org/previews/450/450974_9067471-lq.mp3',
        ),
      );
      debugPrint('🔊 Playing: Imperial March');
    } catch (e) {
      // Silent fallback
    }
  }

  /// Play force power sound
  static Future<void> forcePower() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(
        UrlSource(
          'https://cdn.freesound.org/previews/376/376968_5858296-lq.mp3',
        ),
      );
      debugPrint('🔊 Playing: Force Power');
    } catch (e) {
      // Silent fallback
    }
  }

  /// Play hologram activation
  static Future<void> hologramActivate() async {
    // Silent - no beeping sounds
    return;
  }

  /// Play engine hum
  static Future<void> engineHum() async {
    if (!_soundEnabled) return;
    try {
      await _ambientPlayer.play(
        UrlSource(
          'https://cdn.freesound.org/previews/245/245645_3997831-lq.mp3',
        ),
      );
      debugPrint('🔊 Playing: Engine Hum');
    } catch (e) {
      // Silent fallback
    }
  }

  /// Play explosion — procedural noise burst (no network).
  static Future<void> explosion() async {
    if (!_soundEnabled) return;
    if (kIsWeb) {
      WebSynth.explosion();
    }
  }

  /// Stop all sounds
  static Future<void> stopAll() async {
    try {
      await _player.stop();
      await _ambientPlayer.stop();
      await _musicPlayer.stop();
    } catch (e) {
      // Ignore stop errors
    }
  }

  /// Helper: Play actual audio tone using Web Audio API compatible approach
  // static Future<void> _playTone(
  //   double frequency,
  //   int durationMs, {
  //   AudioPlayer? player,
  // }) async {
  //   final p = player ?? _player;
  //
  //   try {
  //     // Generate a simple WAV file data URI for immediate playback
  //     final wavData = _generateWavTone(frequency, durationMs);
  //     final dataUrl = 'data:audio/wav;base64,$wavData';
  //
  //     await p.play(UrlSource(dataUrl));
  //     debugPrint('🔊 Playing tone: ${frequency.toInt()}Hz for ${durationMs}ms');
  //   } catch (e) {
  //     debugPrint('⚠️ Audio playback error: $e');
  //     // Fallback: at least show we tried
  //     await Future.delayed(Duration(milliseconds: durationMs ~/ 4));
  //   }
  // }

  /// Generate a simple WAV file as base64 for a sine wave tone
  // static String _generateWavTone(double frequency, int durationMs) {
  //   final sampleRate = 44100;
  //   final numSamples = (sampleRate * durationMs / 1000).toInt();
  //   final amplitude = 0.3; // 30% volume to avoid clipping
  //
  //   // WAV file header (44 bytes)
  //   final header = <int>[
  //     // "RIFF" chunk
  //     0x52, 0x49, 0x46, 0x46, // "RIFF"
  //     0, 0, 0, 0, // File size (will fill later)
  //     0x57, 0x41, 0x56, 0x45, // "WAVE"
  //
  //     // "fmt " subchunk
  //     0x66, 0x6d, 0x74, 0x20, // "fmt "
  //     16, 0, 0, 0, // Subchunk size (16 for PCM)
  //     1, 0, // Audio format (1 = PCM)
  //     1, 0, // Number of channels (1 = mono)
  //     0x44, 0xAC, 0, 0, // Sample rate (44100)
  //     0x88, 0x58, 0x01, 0, // Byte rate (44100 * 1 * 2)
  //     2, 0, // Block align (1 * 2)
  //     16, 0, // Bits per sample (16)
  //
  //     // "data" subchunk
  //     0x64, 0x61, 0x74, 0x61, // "data"
  //     0, 0, 0, 0, // Subchunk size (will fill later)
  //   ];
  //
  //   // Generate sine wave samples
  //   final samples = <int>[];
  //   for (int i = 0; i < numSamples; i++) {
  //     final t = i / sampleRate;
  //     final value = (amplitude * 32767 * math.sin(2 * math.pi * frequency * t)).toInt();
  //
  //     // Add 16-bit sample (little-endian)
  //     samples.add(value & 0xFF);
  //     samples.add((value >> 8) & 0xFF);
  //   }
  //
  //   // Update file size in header
  //   final fileSize = 36 + samples.length;
  //   header[4] = fileSize & 0xFF;
  //   header[5] = (fileSize >> 8) & 0xFF;
  //   header[6] = (fileSize >> 16) & 0xFF;
  //   header[7] = (fileSize >> 24) & 0xFF;
  //
  //   // Update data chunk size
  //   header[40] = samples.length & 0xFF;
  //   header[41] = (samples.length >> 8) & 0xFF;
  //   header[42] = (samples.length >> 16) & 0xFF;
  //   header[43] = (samples.length >> 24) & 0xFF;
  //
  //   // Combine header and samples
  //   final wavBytes = [...header, ...samples];
  //
  //   // Convert to base64
  //   return _bytesToBase64(wavBytes);
  // }

  /// Convert bytes to base64 string
  // static String _bytesToBase64(List<int> bytes) {
  //   const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  //   final result = StringBuffer();
  //
  //   for (int i = 0; i < bytes.length; i += 3) {
  //     final b1 = bytes[i];
  //     final b2 = i + 1 < bytes.length ? bytes[i + 1] : 0;
  //     final b3 = i + 2 < bytes.length ? bytes[i + 2] : 0;
  //
  //     final n = (b1 << 16) | (b2 << 8) | b3;
  //
  //     result.write(chars[(n >> 18) & 0x3F]);
  //     result.write(chars[(n >> 12) & 0x3F]);
  //     result.write(i + 1 < bytes.length ? chars[(n >> 6) & 0x3F] : '=');
  //     result.write(i + 2 < bytes.length ? chars[n & 0x3F] : '=');
  //   }
  //
  //   return result.toString();
  // }

  /// Play random ambient sound effect
  static Future<void> playRandomAmbient() async {
    if (!_soundEnabled) return;

    final sounds = [
      () => r2d2Beep(),
      () => engineHum(),
      () => playAmbientSpace(),
    ];

    final randomSound = sounds[_random.nextInt(sounds.length)];
    await randomSound();
  }

  /// Play location-specific sound
  static Future<void> playLocationSound(String locationId) async {
    if (!_soundEnabled) return;

    switch (locationId) {
      case 'tatooine_cantina':
        await playCantinaMusic();
        break;
      case 'death_star':
        await playImperialMarch();
        break;
      case 'jedi_temple':
        await forcePower();
        break;
      case 'cloud_city':
        await engineHum();
        break;
      case 'hoth_base':
        await playAmbientSpace();
        break;
      default:
        await playRandomAmbient();
    }
  }

  /// Dispose audio players
  static void dispose() {
    _player.dispose();
    _ambientPlayer.dispose();
    _musicPlayer.dispose();
  }
}
