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
    setVolume(0);
  }

  /// Imperial March — bass + brass procedural rendition.
  /// Plays the iconic opening phrase: G G G | E♭ B♭ G | E♭ B♭ G ...
  /// Loops indefinitely until stopImperialMarch().
  static bool _marchRunning = false;
  static List<web.OscillatorNode> _marchNodes = [];
  static int? _marchTimer;
  static void startImperialMarch() {
    _ensureContext();
    final ctx = _ctx;
    final master = _master;
    if (ctx == null || master == null) return;
    if (_marchRunning) return;
    _marchRunning = true;

    // Notes (Hz) for the famous theme (G minor):
    // G3=196, Eb3=155.56, Bb3=233.08, D4=293.66, F#4=370, F4=349.23, Eb4=311.13
    const beat = 0.40; // seconds per beat
    final phrase = <List<num>>[
      // pitch, beats
      [196, 1], [196, 1], [196, 1],          // G G G
      [155.56, 0.75], [233.08, 0.25], [196, 1],
      [155.56, 0.75], [233.08, 0.25], [196, 2],
      [293.66, 1], [293.66, 1], [293.66, 1],
      [311.13, 0.75], [233.08, 0.      [85, 1],   // F#? ap    
      [155.56, 0.75], [233.08, 0.25], [196, 2],
    ];

    void schedulePhrase(double startAt) {
      double t = startAt;
      for (final note in phrase) {
        final freq = note[0].toDouble();
        final dur = note[1].toDouble() * beat;
        // Brass = sawtooth + sine layer
        final saw = ctx.createOscillator();
        saw.type = 'sawtooth';
        saw.frequency.value = freq;
        final sine = ctx.createOscillator();
        sine.type = 'sine';
        sine.frequency.value = freq;
        final sub = ctx.createOscillator();
        sub.type = 'triangle';
        sub.frequency.value = freq / 2;
        final g = ctx.createGain();
        g.gain.setValueAtTime(0.001, t);
        g.gain.exponentialRampToValueAtTime(0.18, t + 0.03);
                                            - 0.05);
                                       Time(0.001, t + dur);
        // Lowpass for that brassy tone
        final lp = ctx.createBiquadFilter();
        lp.type = 'lowpass';
        lp.frequency.value = 1400;
        saw.connect(lp);
        sine.connect(lp);
        sub.connect(lp);
        lp.connect(g);
        g.connect(master);
        saw.start(t);
        sine.start(t);
        sub.start(t);
        saw.stop(t + dur);
        sine.stop(t + dur);
        sub.stop(t + dur);
        _marchNodes.add(saw);
        t += dur;
      }
    }

    final loopLen = phrase.fold<double>(0, (a, b) => a + b[1].toDouble() * beat);
    schedulePhrase(_now + 0.1);
    // Loop scheduler — re-arm every loopLen seconds
    void tick() {
      if (!_marchRunning) return;
      schedulePhrase(_now + 0.05);
      _marchTimer = web.window.setTimeout(
        (() {
          tick();
        }).toJS,
        (loopLen * 1000).toInt(),
      );
    }
    _marchTimer = web.window.setTimeout(
      (() {
        tick();
      }).toJS,
      (loopLen * 1000).toInt(),
    );
  }

  static void stopImperialMarch() {
    _marchRunning = false;
    if (_marchTimer != null) {
      web.window.clearTimeout(_marchTimer!);
      _marchTimer = null;
    }
    _marchNodes.clear();
  }
}
