/// Coruscant Skyline — high-performance Star Wars city scene.
///
/// Single SingleTickerProviderStateMixin drives one CustomPainter at 60fps.
/// Everything renders through Canvas primitives — no widget rebuilds per
/// frame, no expensive layout, no asset I/O. Designed to feel like a
/// senior Flutter team's portfolio piece.
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../api/cohere_client.dart';
import '../api/swapi_client.dart';

class CoruscantScene extends StatefulWidget {
  const CoruscantScene({super.key});

  @override
  State<CoruscantScene> createState() => _CoruscantSceneState();
}

class _CoruscantSceneState extends State<CoruscantScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _world = _World();
  Duration _last = Duration.zero;

  // FPS smoothing
  double _fps = 60;
  int _frame = 0;

  // News ticker
  final _cohere = CohereClient();
  final List<String> _bulletins = [
    'Welcome to Coruscant · Senate session in 4 standard hours.',
  ];
  int _tickerIdx = 0;
  Timer? _newsTimer;
  bool _liveAi = false;

  // Autonomous agents (visible NPC theater) — bound to real SWAPI characters.
  static const List<_AgentPersona> _personas = [
    _AgentPersona(
      name: 'Han Solo',
      swapiPersonId: 14,
      faction: 'Rebel Alliance',
      traits: 'Cocky smuggler, fiercely loyal, allergic to authority, in debt to Jabba',
      goal: 'Pay off the Hutts and keep the Falcon flying.',
      color: Color(0xFFFFB347),
    ),
    _AgentPersona(
      name: 'Leia Organa',
      swapiPersonId: 5,
      faction: 'Rebel Alliance',
      traits: 'Senator-strategist, ruthless under pressure, morally certain',
      goal: 'Move stolen Death Star intel off Coruscant within 12 standard hours.',
      color: Color(0xFF26F0F0),
    ),
    _AgentPersona(
      name: 'Boba Fett',
      swapiPersonId: 22,
      faction: 'Bounty Hunters Guild',
      traits: 'Mandalorian discipline, silent operator, mercenary precision',
      goal: 'Collect the bounty on the smuggler captain Solo — alive if possible.',
      color: Color(0xFFFF5C7A),
    ),
  ];
  final Map<String, AgentTurn?> _agentTurns = {};
  final Map<String, bool> _agentBusy = {};
  Timer? _agentTimer;
  int _agentRotor = 0;

  // SWAPI codex
  final _swapi = SwapiClient();
  SwPerson? _focusPerson;
  SwPlanet? _focusPlanet;
  SwStarship? _focusShip;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _liveAi = _cohere.hasKey;
    _scheduleNews();
    _scheduleAgents();
    _loadCodex();
  }

  Future<void> _loadCodex() async {
    final results = await Future.wait([
      _swapi.planet(9),     // Coruscant
      _swapi.starship(10),  // Millennium Falcon
      _swapi.person(14),    // Han Solo
    ]);
    if (!mounted) return;
    setState(() {
      _focusPlanet = results[0] as SwPlanet;
      _focusShip = results[1] as SwStarship;
      _focusPerson = results[2] as SwPerson;
    });
  }

  void _scheduleNews() {
    // First fetch quickly, then every 12s.
    Timer.run(_fetchBulletin);
    _newsTimer = Timer.periodic(const Duration(seconds: 12), (_) => _fetchBulletin());
  }

  Future<void> _fetchBulletin() async {
    final next = await _cohere.coruscantBulletin();
    if (!mounted) return;
    setState(() {
      _bulletins.add(next);
      if (_bulletins.length > 12) _bulletins.removeAt(0);
      _tickerIdx = _bulletins.length - 1;
    });
  }

  void _scheduleAgents() {
    // Stagger one agent every 8s so requests don't bunch.
    Timer.run(_tickOneAgent);
    _agentTimer = Timer.periodic(const Duration(seconds: 8), (_) => _tickOneAgent());
  }

  Future<void> _tickOneAgent() async {
    final p = _personas[_agentRotor % _personas.length];
    _agentRotor++;
    if (_agentBusy[p.name] == true) return;
    _agentBusy[p.name] = true;
    final nearby = _personas.where((o) => o.name != p.name).map((o) => o.name).toList();
    final event = _bulletins.isEmpty ? 'A quiet moment in the upper levels.' : _bulletins.last;
    final memories = <String>[
      'You last saw ${nearby.first} arguing with a Czerka rep about credits.',
      if (nearby.length > 1) 'You owe ${nearby[1]} a favor from the Battle of Scarif.',
    ];
    // Pull canonical SWAPI bio for the persona to give Cohere real data.
    String traits = p.traits;
    if (p.swapiPersonId != null) {
      try {
        final bio = await _swapi.person(p.swapiPersonId!);
        memories.add(
          'Canonical SWAPI bio: ${bio.name}, born ${bio.birthYear}, '
          'homeworld signal traces to ${bio.homeworld.isNotEmpty ? bio.homeworld : 'unknown'}, '
          'height ${bio.height}cm, mass ${bio.mass}kg, eye color ${bio.eyeColor}.',
        );
        traits = '${p.traits}. Canon: ${bio.gender}, born ${bio.birthYear}.';
      } catch (_) {/* ignore, fall back to traits */}
    }
    final turn = await _cohere.agentTurn(
      agentName: p.name,
      faction: p.faction,
      traits: traits,
      longTermGoal: p.goal,
      currentLocation: 'Outlander Club, Uscru District, Coruscant',
      nearbyCharacters: nearby,
      worldStateContext: event,
      retrievedMemories: memories,
    );
    if (!mounted) return;
    setState(() {
      _agentTurns[p.name] = turn;
      _agentBusy[p.name] = false;
    });
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.1) return; // skip first frame / big stalls
    _world.tick(dt);
    _frame++;
    if (_frame % 15 == 0) {
      _fps = 0.7 * _fps + 0.3 * (1 / dt);
    }
    // Targeted, cheap rebuild: only the painter repaints via Listenable.
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _newsTimer?.cancel();
    _agentTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02030A),
      body: LayoutBuilder(
        builder: (context, c) {
          _world.ensureSized(c.maxWidth, c.maxHeight);
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _CityPainter(_world),
                  ),
                ),
              ),
              _Hud(fps: _fps, liveAi: _liveAi, ships: _world.ships.length),
              _CodexPanel(
                planet: _focusPlanet,
                ship: _focusShip,
                person: _focusPerson,
              ),
              _AgentTheater(
                personas: _personas,
                turns: _agentTurns,
                liveAi: _liveAi,
              ),
              _NewsTicker(messages: _bulletins, current: _tickerIdx, liveAi: _liveAi),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================================
// WORLD MODEL
// =====================================================================

class _World {
  final _rand = Random(7);
  double w = 0, h = 0;
  bool _seeded = false;

  // Layers
  final List<_Star> stars = [];
  final List<_Building> bgBuildings = [];
  final List<_Building> midBuildings = [];
  final List<_Building> fgBuildings = [];
  final List<_Ship> ships = [];
  final List<_Hologram> holos = [];

  // Animated globals
  double t = 0;
  double sunPhase = 0; // 0..1 across the sky

  void ensureSized(double width, double height) {
    if (width <= 0 || height <= 0) return;
    if (!_seeded || (width - w).abs() > 1 || (height - h).abs() > 1) {
      w = width;
      h = height;
      _seed();
      _seeded = true;
    }
  }

  void _seed() {
    stars.clear();
    bgBuildings.clear();
    midBuildings.clear();
    fgBuildings.clear();
    ships.clear();
    holos.clear();

    // Starfield
    for (var i = 0; i < 220; i++) {
      stars.add(_Star(
        x: _rand.nextDouble() * w,
        y: _rand.nextDouble() * h * 0.62,
        r: _rand.nextDouble() * 1.4 + 0.2,
        twinkle: _rand.nextDouble() * 2 * pi,
      ));
    }

    // Background skyline (far)
    final groundY = h * 0.78;
    _seedLayer(bgBuildings, count: 18, depth: 0.25,
        minH: 0.18, maxH: 0.42, baseY: groundY, palette: _Palette.bg);
    _seedLayer(midBuildings, count: 14, depth: 0.55,
        minH: 0.28, maxH: 0.58, baseY: groundY, palette: _Palette.mid);
    _seedLayer(fgBuildings, count: 9, depth: 1.0,
        minH: 0.34, maxH: 0.68, baseY: groundY, palette: _Palette.fg);

    // Holograms (giant ad spires)
    holos.addAll([
      _Hologram(x: w * 0.18, y: h * 0.46, color: const Color(0xFF26F0F0), label: 'SENATE'),
      _Hologram(x: w * 0.48, y: h * 0.40, color: const Color(0xFFFF3158), label: 'IMPERIAL\nNEWS'),
      _Hologram(x: w * 0.82, y: h * 0.48, color: const Color(0xFF7C5CFF), label: 'CZERKA'),
    ]);

    // Ships across 5 traffic lanes
    final lanes = [0.32, 0.42, 0.52, 0.62, 0.71].map((p) => h * p).toList();
    for (var i = 0; i < 26; i++) {
      final lane = lanes[i % lanes.length];
      ships.add(_Ship(
        x: _rand.nextDouble() * w,
        y: lane + (_rand.nextDouble() - 0.5) * 8,
        speed: 35 + _rand.nextDouble() * 85,
        dir: _rand.nextBool() ? 1 : -1,
        kind: _kindFor(i),
        scale: 0.6 + _rand.nextDouble() * 0.9,
      ));
    }
  }

  _ShipKind _kindFor(int i) {
    switch (i % 5) {
      case 0:
        return _ShipKind.taxi;
      case 1:
        return _ShipKind.xwing;
      case 2:
        return _ShipKind.tie;
      case 3:
        return _ShipKind.speeder;
      default:
        return _ShipKind.freighter;
    }
  }

  void _seedLayer(
    List<_Building> bucket, {
    required int count,
    required double depth,
    required double minH,
    required double maxH,
    required double baseY,
    required _Palette palette,
  }) {
    var x = -40.0;
    while (x < w + 40) {
      final bw = 50 + _rand.nextDouble() * 100;
      final bh = h * (minH + _rand.nextDouble() * (maxH - minH));
      bucket.add(_Building(
        x: x,
        baseY: baseY,
        width: bw,
        height: bh,
        depth: depth,
        palette: palette,
        roofKind: _rand.nextInt(4),
        windowSeed: _rand.nextInt(1 << 30),
      ));
      x += bw + _rand.nextDouble() * 16;
    }
  }

  void tick(double dt) {
    t += dt;
    sunPhase = (sunPhase + dt * 0.012) % 1.0;
    for (final s in ships) {
      s.x += s.speed * s.dir * dt;
      if (s.dir > 0 && s.x > w + 80) s.x = -80;
      if (s.dir < 0 && s.x < -80) s.x = w + 80;
    }
    for (final s in stars) {
      s.twinkle += dt * 2.2;
    }
    for (final hg in holos) {
      hg.phase += dt;
    }
  }
}

class _Star {
  _Star({required this.x, required this.y, required this.r, required this.twinkle});
  double x, y, r, twinkle;
}

class _Building {
  _Building({
    required this.x,
    required this.baseY,
    required this.width,
    required this.height,
    required this.depth,
    required this.palette,
    required this.roofKind,
    required this.windowSeed,
  });
  final double x, baseY, width, height, depth;
  final _Palette palette;
  final int roofKind;
  final int windowSeed;
}

class _Hologram {
  _Hologram({required this.x, required this.y, required this.color, required this.label})
      : phase = 0;
  double x, y, phase;
  final Color color;
  final String label;
}

enum _ShipKind { taxi, xwing, tie, speeder, freighter }

class _Ship {
  _Ship({
    required this.x,
    required this.y,
    required this.speed,
    required this.dir,
    required this.kind,
    required this.scale,
  });
  double x, y;
  final double speed, scale;
  final int dir;
  final _ShipKind kind;
}

enum _Palette { bg, mid, fg }

// =====================================================================
// PAINTER
// =====================================================================

class _CityPainter extends CustomPainter {
  _CityPainter(this.world);
  final _World world;

  // Reused paint objects (less GC pressure)
  static final _p = Paint();
  static final _glow = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawStars(canvas);
    _drawSuns(canvas, size);
    _drawDistantHaze(canvas, size);

    // Far skyline
    _drawSkyline(canvas, size, world.bgBuildings, alpha: 0.55, glow: 0.35);

    _drawShipLayer(canvas, kindsSlow: true);

    // Mid skyline
    _drawSkyline(canvas, size, world.midBuildings, alpha: 0.85, glow: 0.7);

    // Holograms in between
    _drawHolograms(canvas);

    _drawShipLayer(canvas, kindsSlow: false);

    // Foreground skyline
    _drawSkyline(canvas, size, world.fgBuildings, alpha: 1.0, glow: 1.0);

    _drawGround(canvas, size);
    _drawScanlines(canvas, size);
  }

  // ---- Sky ----------------------------------------------------------
  void _drawSky(Canvas canvas, Size s) {
    // Twin-sunset gradient that shifts with sunPhase.
    final phase = world.sunPhase;
    final top = Color.lerp(
        const Color(0xFF0A0B1E), const Color(0xFF170A28), phase)!;
    final mid = Color.lerp(
        const Color(0xFF3B1C5A), const Color(0xFFB23A6C), phase)!;
    final low = Color.lerp(
        const Color(0xFFFF6F3C), const Color(0xFFFFB347), phase)!;
    final rect = Offset.zero & s;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, s.height * 0.85),
        [top, mid, low],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(rect, paint);
  }

  void _drawStars(Canvas canvas) {
    for (final st in world.stars) {
      final tw = (sin(st.twinkle) + 1) / 2; // 0..1
      _p
        ..color = Color.fromRGBO(220, 230, 255, 0.35 + 0.5 * tw)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(st.x, st.y), st.r, _p);
    }
  }

  void _drawSuns(Canvas canvas, Size s) {
    // Twin suns of Tatooine — wink, but actually Coruscant. Looks great.
    final phase = world.sunPhase;
    final cx1 = s.width * (0.18 + 0.05 * sin(world.t * 0.05));
    final cy1 = s.height * (0.6 - 0.05 * phase);
    final cx2 = cx1 + 70;
    final cy2 = cy1 + 26;

    void sun(double x, double y, double r, Color core, Color halo) {
      _glow
        ..shader = ui.Gradient.radial(Offset(x, y), r * 4, [
          halo.withValues(alpha: 0.45),
          halo.withValues(alpha: 0.0),
        ])
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), r * 4, _glow);
      _p
        ..shader = null
        ..color = core
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), r, _p);
    }

    sun(cx1, cy1, 22, const Color(0xFFFFE9A8), const Color(0xFFFFC76A));
    sun(cx2, cy2, 14, const Color(0xFFFFD6A8), const Color(0xFFFF8A5A));
  }

  void _drawDistantHaze(Canvas canvas, Size s) {
    final p = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, s.height * 0.55),
        Offset(0, s.height * 0.82),
        [
          const Color(0x00000000),
          const Color(0xFFFFAA77).withValues(alpha: 0.18),
        ],
      );
    canvas.drawRect(
        Rect.fromLTWH(0, s.height * 0.55, s.width, s.height * 0.32), p);
  }

  // ---- Skyline ------------------------------------------------------
  void _drawSkyline(Canvas canvas, Size s, List<_Building> list,
      {required double alpha, required double glow}) {
    for (final b in list) {
      _drawBuilding(canvas, b, alpha: alpha, glow: glow);
    }
  }

  void _drawBuilding(Canvas canvas, _Building b,
      {required double alpha, required double glow}) {
    final rect =
        Rect.fromLTWH(b.x, b.baseY - b.height, b.width, b.height);

    // Body — vertical gradient with palette tint
    final palette = _paletteColors(b.palette);
    final p = Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.left, rect.top),
        Offset(rect.left, rect.bottom),
        [
          palette.$1.withValues(alpha: alpha * 0.95),
          palette.$2.withValues(alpha: alpha),
        ],
      );
    canvas.drawRect(rect, p);

    // Edge highlight (left)
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.08 * alpha)
      ..strokeWidth = 1;
    canvas.drawLine(rect.topLeft, rect.bottomLeft, edge);

    // Windows — deterministic grid using windowSeed
    final rng = Random(b.windowSeed);
    final cols = (b.width / 9).floor();
    final rows = (b.height / 11).floor();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (rng.nextDouble() < 0.35) continue; // gaps
        final lit = rng.nextDouble() < 0.62;
        final flick =
            lit && ((world.t * 6 + r * 7 + c * 3).floor() % 41 < 2);
        final color = flick
            ? const Color(0xFFFFE9A0)
            : (lit
                ? const Color(0xFFFFC56A).withValues(alpha: 0.85 * alpha)
                : const Color(0xFF1A1322).withValues(alpha: 0.55 * alpha));
        final wx = rect.left + 3 + c * 9;
        final wy = rect.top + 6 + r * 11;
        canvas.drawRect(Rect.fromLTWH(wx, wy, 5, 6),
            Paint()..color = color);
      }
    }

    // Roof spire / antenna
    final roofX = rect.left + b.width / 2;
    final roofY = rect.top;
    switch (b.roofKind) {
      case 0:
        // spike with blinking light
        canvas.drawLine(Offset(roofX, roofY), Offset(roofX, roofY - 18),
            Paint()..color = Colors.white.withValues(alpha: 0.5 * alpha));
        final blink = (world.t * 1.8).floor() % 2 == 0;
        canvas.drawCircle(
          Offset(roofX, roofY - 18),
          2.5,
          Paint()
            ..color = blink ? const Color(0xFFFF3158) : const Color(0xFFFFB347),
        );
        break;
      case 1:
        // dish
        canvas.drawArc(
          Rect.fromCenter(center: Offset(roofX, roofY - 4), width: 18, height: 8),
          pi,
          pi,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        break;
      case 2:
        // double antenna
        for (final ox in [-5.0, 5.0]) {
          canvas.drawLine(
            Offset(roofX + ox, roofY),
            Offset(roofX + ox, roofY - 14),
            Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha),
          );
        }
        break;
      default:
        break;
    }

    // Bottom glow into the haze
    if (glow > 0.3) {
      final g = Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.center.dx, rect.bottom - 30),
          Offset(rect.center.dx, rect.bottom + 4),
          [
            const Color(0x00000000),
            const Color(0xFFFFB347).withValues(alpha: 0.35 * glow),
          ],
        );
      canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - 30, b.width, 30), g);
    }
  }

  (Color, Color) _paletteColors(_Palette p) {
    switch (p) {
      case _Palette.bg:
        return (const Color(0xFF1A1736), const Color(0xFF06070F));
      case _Palette.mid:
        return (const Color(0xFF2A1F4A), const Color(0xFF08081A));
      case _Palette.fg:
        return (const Color(0xFF15183A), const Color(0xFF02030A));
    }
  }

  // ---- Holograms ----------------------------------------------------
  void _drawHolograms(Canvas canvas) {
    for (final hg in world.holos) {
      final flicker = 0.78 + 0.22 * sin(hg.phase * 6);
      final base = hg.color.withValues(alpha: 0.35 * flicker);
      final glow = hg.color.withValues(alpha: 0.18 * flicker);

      // Vertical light beam
      final beam = Paint()
        ..shader = ui.Gradient.linear(
          Offset(hg.x, hg.y - 90),
          Offset(hg.x, hg.y + 50),
          [
            hg.color.withValues(alpha: 0.0),
            hg.color.withValues(alpha: 0.6 * flicker),
            hg.color.withValues(alpha: 0.0),
          ],
          const [0.0, 0.5, 1.0],
        );
      canvas.drawRect(Rect.fromLTWH(hg.x - 2, hg.y - 90, 4, 140), beam);

      // Floating glyph rectangle
      final rect = Rect.fromCenter(
          center: Offset(hg.x, hg.y), width: 86, height: 36);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = glow);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()
            ..color = base
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: hg.label,
          style: TextStyle(
            color: hg.color.withValues(alpha: 0.95 * flicker),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);
      tp.paint(canvas, Offset(hg.x - tp.width / 2, hg.y - tp.height / 2));
    }
  }

  // ---- Ships --------------------------------------------------------
  void _drawShipLayer(Canvas canvas, {required bool kindsSlow}) {
    for (final s in world.ships) {
      final isSlow = s.kind == _ShipKind.freighter || s.kind == _ShipKind.taxi;
      if (isSlow != kindsSlow) continue;
      _drawShip(canvas, s);
    }
  }

  void _drawShip(Canvas canvas, _Ship s) {
    canvas.save();
    canvas.translate(s.x, s.y);
    canvas.scale(s.dir.toDouble() * s.scale, s.scale);

    // Engine trail
    final trail = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(-60, 0),
        const Offset(0, 0),
        [
          const Color(0x0000D9FF),
          const Color(0xFF00D9FF).withValues(alpha: 0.7),
        ],
      )
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    canvas.drawLine(const Offset(-50, 0), const Offset(0, 0), trail);

    switch (s.kind) {
      case _ShipKind.taxi:
        _paintTaxi(canvas);
        break;
      case _ShipKind.xwing:
        _paintXwing(canvas);
        break;
      case _ShipKind.tie:
        _paintTie(canvas);
        break;
      case _ShipKind.speeder:
        _paintSpeeder(canvas);
        break;
      case _ShipKind.freighter:
        _paintFreighter(canvas);
        break;
    }
    canvas.restore();
  }

  void _paintTaxi(Canvas canvas) {
    final body = Paint()..color = const Color(0xFFFFB347);
    final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, -5, 28, 10), const Radius.circular(4));
    canvas.drawRRect(rrect, body);
    canvas.drawRect(const Rect.fromLTWH(-6, -7, 10, 4),
        Paint()..color = const Color(0xFF26F0F0));
    // Headlight
    canvas.drawCircle(const Offset(14, 0), 1.6,
        Paint()..color = const Color(0xFFFFFFFF));
  }

  void _paintXwing(Canvas canvas) {
    final body = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawRect(const Rect.fromLTWH(-16, -2, 32, 4), body);
    // S-foils
    final wing = Paint()..color = const Color(0xFFB8BEC9);
    canvas.drawPath(
        Path()
          ..moveTo(-8, -2)
          ..lineTo(-2, -10)
          ..lineTo(4, -10)
          ..lineTo(-2, -2)
          ..close(),
        wing);
    canvas.drawPath(
        Path()
          ..moveTo(-8, 2)
          ..lineTo(-2, 10)
          ..lineTo(4, 10)
          ..lineTo(-2, 2)
          ..close(),
        wing);
    canvas.drawCircle(const Offset(16, 0), 1.4,
        Paint()..color = const Color(0xFFFF3158));
  }

  void _paintTie(Canvas canvas) {
    final hex = Paint()..color = const Color(0xFFD0D5DC);
    canvas.drawRect(const Rect.fromLTWH(-10, -8, 1.6, 16), hex);
    canvas.drawRect(const Rect.fromLTWH(8.4, -8, 1.6, 16), hex);
    // wings (octagons approximated)
    void wing(double cx) {
      final p = Path()
        ..moveTo(cx - 6, -8)
        ..lineTo(cx + 6, -8)
        ..lineTo(cx + 8, 0)
        ..lineTo(cx + 6, 8)
        ..lineTo(cx - 6, 8)
        ..lineTo(cx - 8, 0)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFF2A2F3A));
      canvas.drawPath(
          p,
          Paint()
            ..color = const Color(0xFF8A93A6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6);
    }

    wing(-10);
    wing(10);
    // pod
    canvas.drawCircle(const Offset(0, 0), 4.4,
        Paint()..color = const Color(0xFFE5E7EB));
    canvas.drawCircle(const Offset(0, 0), 2.0,
        Paint()..color = const Color(0xFF1A1F2E));
  }

  void _paintSpeeder(Canvas canvas) {
    final body = Paint()..color = const Color(0xFFFF3158);
    final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -3, 22, 6), const Radius.circular(3));
    canvas.drawRRect(rrect, body);
    canvas.drawCircle(const Offset(8, 0), 1.2,
        Paint()..color = const Color(0xFFFFFFFF));
  }

  void _paintFreighter(Canvas canvas) {
    final body = Paint()..color = const Color(0xFF4A5060);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-22, -6, 44, 12), const Radius.circular(3)),
        body);
    // cargo blocks
    for (var i = -18; i < 18; i += 7) {
      canvas.drawRect(Rect.fromLTWH(i.toDouble(), -4, 5, 8),
          Paint()..color = const Color(0xFF2C313E));
    }
    canvas.drawCircle(const Offset(22, 0), 1.6,
        Paint()..color = const Color(0xFFFFB347));
  }

  // ---- Ground / scanlines -------------------------------------------
  void _drawGround(Canvas canvas, Size s) {
    final y = s.height * 0.78;
    final p = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y),
        Offset(0, s.height),
        [
          const Color(0xFF06070F),
          const Color(0xFF02030A),
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, y, s.width, s.height - y), p);

    // Skyway light strips
    for (var i = 0; i < 4; i++) {
      final ly = y + 12 + i * 16;
      final stripe = Paint()
        ..color = const Color(0xFF26F0F0).withValues(alpha: 0.18 - i * 0.04);
      canvas.drawRect(Rect.fromLTWH(0, ly, s.width, 0.8), stripe);
    }
  }

  void _drawScanlines(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.05);
    for (double y = 0; y < s.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, s.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant _CityPainter old) => true;
}

// =====================================================================
// HUD
// =====================================================================

class _Hud extends StatelessWidget {
  const _Hud({required this.fps, required this.liveAi, required this.ships});
  final double fps;
  final bool liveAi;
  final int ships;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlassCard(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00D4A8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CORUSCANT · LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _chip('${fps.toStringAsFixed(0)} FPS',
                      const Color(0xFF26F0F0)),
                  const SizedBox(width: 6),
                  _chip('$ships craft', const Color(0xFFFFB347)),
                  const SizedBox(width: 6),
                  _chip(
                    liveAi ? 'COHERE · LIVE' : 'COHERE · OFFLINE',
                    liveAi
                        ? const Color(0xFF7C5CFF)
                        : const Color(0xFF6B7184),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _GlassCard(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.layers_rounded,
                      size: 14, color: Color(0xFFA8AEBD)),
                  SizedBox(width: 6),
                  Text(
                    'PARALLAX 3-LAYER · 5 TRAFFIC LANES',
                    style: TextStyle(
                      color: Color(0xFFA8AEBD),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0B14).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: child,
    );
  }
}

// =====================================================================
// NEWS TICKER
// =====================================================================

class _NewsTicker extends StatelessWidget {
  const _NewsTicker(
      {required this.messages, required this.current, required this.liveAi});
  final List<String> messages;
  final int current;
  final bool liveAi;

  @override
  Widget build(BuildContext context) {
    final msg = messages.isEmpty ? '...' : messages[current.clamp(0, messages.length - 1)];
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.4), end: Offset.zero)
                        .animate(a),
                    child: c)),
            child: _GlassCard(
              key: ValueKey(msg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: liveAi
                          ? const Color(0xFF7C5CFF).withValues(alpha: 0.18)
                          : const Color(0xFF6B7184).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      liveAi ? 'COHERE · HOLO-NEWS' : 'HOLO-NEWS',
                      style: TextStyle(
                        color: liveAi
                            ? const Color(0xFF7C5CFF)
                            : const Color(0xFFA8AEBD),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// AGENT THEATER (visible NPC turns driven by Cohere)
// =====================================================================

class _AgentPersona {
  const _AgentPersona({
    required this.name,
    required this.faction,
    required this.traits,
    required this.goal,
    required this.color,
    this.swapiPersonId,
  });
  final String name;
  final String faction;
  final String traits;
  final String goal;
  final Color color;
  final int? swapiPersonId;
}

class _AgentTheater extends StatelessWidget {
  const _AgentTheater({
    required this.personas,
    required this.turns,
    required this.liveAi,
  });

  final List<_AgentPersona> personas;
  final Map<String, AgentTurn?> turns;
  final bool liveAi;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 110,
      width: 380,
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF26F0F0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    liveAi ? 'COHERE \u00b7 AGENT THEATER' : 'AGENT THEATER \u00b7 CANNED',
                    style: const TextStyle(
                      color: Color(0xFF26F0F0),
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final p in personas) ...[
                _AgentCard(persona: p, turn: turns[p.name]),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.persona, required this.turn});
  final _AgentPersona persona;
  final AgentTurn? turn;

  @override
  Widget build(BuildContext context) {
    final t = turn;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: persona.color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: persona.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  persona.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                persona.faction,
                style: TextStyle(
                  color: persona.color,
                  fontSize: 9,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (t == null)
            const Text(
              'Awaiting transmission\u2026',
              style: TextStyle(color: Color(0xFF8AA0B6), fontSize: 11, fontStyle: FontStyle.italic),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 6),
                  child: Icon(Icons.psychology, size: 11, color: Color(0xFF8AA0B6)),
                ),
                Expanded(
                  child: Text(
                    t.innerMonologue,
                    style: const TextStyle(
                      color: Color(0xFFB8C4D4),
                      fontSize: 10.5,
                      height: 1.35,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: persona.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(color: persona.color, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2192 ${t.socialTarget}',
                    style: TextStyle(
                      color: persona.color.withValues(alpha: 0.85),
                      fontSize: 9,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '"${t.dialogue}"',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.35),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _ActionChip(label: t.physicalActionType, color: persona.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.physicalActionDetails,
                    style: const TextStyle(color: Color(0xFFB8C4D4), fontSize: 10.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (t.relationshipUpdates.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final r in t.relationshipUpdates)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${r.character}  ${r.trustDelta >= 0 ? '+' : ''}${r.trustDelta}  \u00b7 ${r.reason}',
                    style: TextStyle(
                      color: r.trustDelta >= 0 ? const Color(0xFF7CFFB2) : const Color(0xFFFF8A95),
                      fontSize: 9.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// =====================================================================
// SWAPI CODEX PANEL (top-right)
// =====================================================================

class _CodexPanel extends StatelessWidget {
  const _CodexPanel({required this.planet, required this.ship, required this.person});
  final SwPlanet? planet;
  final SwStarship? ship;
  final SwPerson? person;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 64,
      right: 16,
      width: 320,
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFFFFB347), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SWAPI \u00b7 GALACTIC CODEX',
                    style: TextStyle(
                      color: Color(0xFFFFB347),
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _codexBlock(
                'PLANET',
                planet?.name ?? 'Loading\u2026',
                [
                  if (planet != null) 'Climate: ${planet!.climate}',
                  if (planet != null) 'Terrain: ${planet!.terrain}',
                  if (planet != null) 'Pop: ${_humanize(planet!.population)}',
                  if (planet != null) 'Gravity: ${planet!.gravity}',
                ],
                const Color(0xFF26F0F0),
              ),
              const SizedBox(height: 8),
              _codexBlock(
                'STARSHIP',
                ship?.name ?? 'Loading\u2026',
                [
                  if (ship != null) 'Class: ${ship!.starshipClass}',
                  if (ship != null) 'Model: ${ship!.model}',
                  if (ship != null) 'Hyperdrive: ${ship!.hyperdrive}',
                  if (ship != null) 'Crew: ${ship!.crew}',
                ],
                const Color(0xFFFFB347),
              ),
              const SizedBox(height: 8),
              _codexBlock(
                'CAPTAIN',
                person?.name ?? 'Loading\u2026',
                [
                  if (person != null) 'Born: ${person!.birthYear}',
                  if (person != null) 'Height: ${person!.height}cm',
                  if (person != null) 'Mass: ${person!.mass}kg',
                  if (person != null) 'Eyes: ${person!.eyeColor}',
                ],
                const Color(0xFFFF5C7A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _humanize(String pop) {
    final n = int.tryParse(pop);
    if (n == null) return pop;
    if (n >= 1e12) return '${(n / 1e12).toStringAsFixed(1)}T';
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)}B';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
    return pop;
  }

  Widget _codexBlock(String label, String title, List<String> rows, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) const SizedBox(height: 4),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                r,
                style: const TextStyle(color: Color(0xFFB8C4D4), fontSize: 10.5, height: 1.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
