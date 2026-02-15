import 'package:flutter/material.dart';
import '../audio/star_wars_sounds.dart';

/// Sound test panel for debugging audio system
class SoundTestPanel extends StatefulWidget {
  const SoundTestPanel({super.key});

  @override
  State<SoundTestPanel> createState() => _SoundTestPanelState();
}

class _SoundTestPanelState extends State<SoundTestPanel> {
  bool _soundEnabled = true;
  double _volume = 0.6;
  String _lastPlayed = 'None';

  void _playSound(String name, Future<void> Function() soundFunc) async {
    setState(() => _lastPlayed = name);
    debugPrint('🔊 Playing: $name');
    await soundFunc();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D9FF), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.music_note, color: Color(0xFF00D9FF)),
              const SizedBox(width: 8),
              const Text(
                'Sound Test Panel',
                style: TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _soundEnabled ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                ),
                onPressed: () {
                  StarWarsSounds.toggleSound();
                  setState(() => _soundEnabled = !_soundEnabled);
                },
              ),
            ],
          ),
          const Divider(color: Color(0xFF00D9FF)),

          // Volume Control
          Row(
            children: [
              const Text('Volume:', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: _volume,
                  activeColor: const Color(0xFF00D9FF),
                  onChanged: (value) {
                    StarWarsSounds.setVolume(value);
                    setState(() => _volume = value);
                  },
                ),
              ),
              Text(
                '${(_volume * 100).toInt()}%',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Sound Test Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSoundButton(
                '⚔️ Lightsaber',
                () => _playSound(
                  'Lightsaber Swing',
                  StarWarsSounds.lightsaberSwing,
                ),
              ),
              _buildSoundButton(
                '🔫 Blaster',
                () => _playSound('Blaster Fire', StarWarsSounds.blasterFire),
              ),
              _buildSoundButton(
                '🤖 R2-D2',
                () => _playSound('R2-D2 Beep', StarWarsSounds.r2d2Beep),
              ),
              _buildSoundButton(
                '✨ Force',
                () => _playSound('Force Power', StarWarsSounds.forcePower),
              ),
              _buildSoundButton(
                '🚪 Door',
                () => _playSound('Door Sound', StarWarsSounds.doorSound),
              ),
              _buildSoundButton(
                '🚀 Engine',
                () => _playSound('Engine Hum', StarWarsSounds.engineHum),
              ),
              _buildSoundButton(
                '💥 Explosion',
                () => _playSound('Explosion', StarWarsSounds.explosion),
              ),
              _buildSoundButton(
                '🎵 Cantina',
                () => _playSound(
                  'Cantina Music',
                  StarWarsSounds.playCantinaMusic,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Status
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${_soundEnabled ? "🟢 Enabled" : "🔴 Disabled"}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Last Played: $_lastPlayed',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  '💡 Tip: Check browser console (F12) for audio debug messages',
                  style: TextStyle(color: Colors.yellow, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF00D9FF)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
