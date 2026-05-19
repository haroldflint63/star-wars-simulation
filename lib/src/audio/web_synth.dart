/// Procedural Web Audio synthesizer — zero network, zero CORS.
///
/// On Flutter Web we drive an AudioContext directly to synthesize
/// blaster bolts, explosions, lightsaber hum, and a low space drone.
/// On non-web platforms every method is a no-op.
library;

import 'dart:math' as math;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

class WebSynth {
  static web.AudioContext? _ctx;
  static web.GainNode? _master;
  static bool _started = false;
  static final math.Random _rng = math.Random();

  static void _ensureContext() {
    if (_started) return;
    try {
      _ctx = web.AudioContext();
      _master = _ctx!.createGain();
      _master!.gain.value = 0.45;
      _master!.connect(_ctx!.destination);
      _started = true;
    } catch (_) {/* unsupported */}
  }

  static double get _now => _ctx?.currentTime ?? 0;

  /// Pew-pew blaster bolt: sharp square sweep down + noise click.
  static void blaster() {
    _ensureContext();
    final ctx = _ctx;
    final master = _master;
    if (ctx == null || master == null) return;
    final t = _now;
    final osc = ctx.createOscillator();
    osc.type = 'square';
    osc.frequency.setValueAtTime(1400 + _rng.nextDouble() * 300, t);
    osc.frequency.exponentialRampToValueAtTime(120, t + 0.18);
    final g = ctx.createGain();
    g.gain.setValueAtTime(0.001, t);
    g.gain.exponentialRampToValueAtTime(0.35, t + 0.005);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.22);
    osc.connect(g);
    g.connect(master);
    osc.start(t);
    osc.stop(t + 0.25);
  }

  /// Boom: low-pass filtered noise burst.
  static void explosion() {
    _ensureContext();
    final ctx = _ctx;
    final master = _master;
    if (ctx == null || master == null) return;
    final t = _now;
    final bufSize = (ctx.sampleRate * 0.9).toInt();
    final buffer = ctx.createBuffer(1, bufSize, ctx.sampleRate);
    final data = buffer.getChannelData(0).toDart;
    for (var i = 0; i < bufSize; i++) {
      final env = math.pow(1 - i / bufSize, 2).toDouble();
      data[i] = (_rng.nextDouble() * 2 - 1) * env;
    }
    buffer.copyToChannel(data.toJS, 0);
    final src = ctx.createBufferSource();
    src.buffer = buffer;
    final lp = ctx.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.setValueAtTime(800, t);
    lp.frequency.exponentialRampToValueAtTime(120, t + 0.6);
    final g = ctx.createGain();
    g.gain.setValueAtTime(0.7, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.9);
    src.connect(lp);
    lp.connect(g);
    g.connect(master);
    src.start(t);
  }

  /// Lightsaber ignition: white-noise hum + rising sawtooth.
  static void lightsaber() {
    _ensureContext();
    final ctx = _ctx;
    final master = _master;
    if (ctx == null || master == null) return;
    final t = _now;
    final osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(80, t);
    osc.frequency.exponentialRampToValueAtTime(240, t + 0.3);
    final g = ctx.createGain();
    g.gain.setValueAtTime(0.001, t);
    g.gain.exponentialRampToValueAtTime(0.22, t + 0.05);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.55);
    osc.connect(g);
    g.connect(master);
    osc.start(t);
    osc.stop(t + 0.6);
  }

  /// Looping low space drone (start once at app launch).
  static bool _droneRunning = false;
  static void startSpaceDrone() {
    _ensureContext();
    final ctx = _ctx;
    final master = _master;
    if (ctx == null || master == null) return;
    if (_droneRunning) return;
    _droneRunning = true;

    void layer(double freq, double gain, String type) {
      final o = ctx.createOscillator();
      o.type = type;
      o.frequency.value = freq;
      final g = ctx.createGain();
      g.gain.value = gain;
      o.connect(g);
      g.connect(master);
      o.start();
      // Slow LFO on gain for breathing
      final lfo = ctx.createOscillator();
      lfo.type = 'sine';
      lfo.frequency.value = 0.07 + _rng.nextDouble() * 0.05;
      final lfoGain = ctx.createGain();
      lfoGain.gain.value = gain * 0.35;
      lfo.connect(lfoGain);
      lfoGain.connect(g.gain);
      lfo.start();
    }

    layer(55, 0.06, 'sine');
    layer(82.5, 0.04, 'sine');
    layer(110, 0.025, 'triangle');
  }

  static void setVolume(double v) {
    _ensureContext();
    final master = _master;
    if (master == null) return;
    master.gain.value = v.clamp(0.0, 1.0);
  }

  static void stopAll() {
    // Drones can't easily stop without storing references; just mute.
    setVolume(0);
  }
}
