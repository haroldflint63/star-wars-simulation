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

import '../agents/agent_memory.dart';
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

  // Smallville-style agent state.
  final Map<String, MemoryStream> _memories = {};
  final Map<String, String> _reflections = {};
  final Map<String, DailyPlan> _plans = {};
  final Map<String, Map<String, int>> _trustGraph = {};
  int _turnCount = 0;
  String _focusAgent = 'Han Solo';

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
    for (final p in _personas) {
      _memories[p.name] = MemoryStream();
      _trustGraph[p.name] = {for (final o in _personas) if (o.name != p.name) o.name: 50};
      // Seed each stream with the agent's identity + goal as importance-9 observations.
      _memories[p.name]!.add(Memory(
        kind: MemoryKind.observation,
        content: 'My name is ${p.name}, ${p.faction}. Long-term goal: ${p.goal}',
        timestamp: DateTime.now(),
        importance: 9,
      ));
    }
    _scheduleNews();
    _scheduleAgents();
    _loadCodex();
    _bootstrapPlans();
  }

  Future<void> _bootstrapPlans() async {
    final futures = _personas.map((p) async {
      final slots = await _cohere.dailyPlan(
        agentName: p.name,
        faction: p.faction,
        longTermGoal: p.goal,
      );
      return MapEntry(
        p.name,
        DailyPlan(
          agentName: p.name,
          slots: slots
              .map((s) => PlanSlot(time: s['time']!, activity: s['activity']!))
              .toList(),
        ),
      );
    });
    final results = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      for (final e in results) {
        _plans[e.key] = e.value;
        // Seed plan memories.
        for (final slot in e.value.slots) {
          _memories[e.key]!.add(Memory(
            kind: MemoryKind.plan,
            content: '${slot.time}: ${slot.activity}',
            timestamp: DateTime.now(),
            importance: 6,
          ));
        }
      }
    });
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

    // Smallville §4.1.2: retrieve top-N relevant memories for this stimulus.
    final stream = _memories[p.name]!;
    final query = '$event ${nearby.join(' ')}';
    final retrieved = stream
        .retrieve(query: query, topN: 6)
        .map((m) => '[${m.kindLabel}] ${m.content}')
        .toList();

    String traits = p.traits;
    if (p.swapiPersonId != null) {
      try {
        final bio = await _swapi.person(p.swapiPersonId!);
        retrieved.add(
          '[CANON] ${bio.name}, born ${bio.birthYear}, homeworld '
          '${bio.homeworld.isNotEmpty ? bio.homeworld : 'unknown'}, '
          'eyes ${bio.eyeColor}.',
        );
        traits = '${p.traits}. Canon: ${bio.gender}, born ${bio.birthYear}.';
      } catch (_) {/* ignore */}
    }

    final turn = await _cohere.agentTurn(
      agentName: p.name,
      faction: p.faction,
      traits: traits,
      longTermGoal: p.goal,
      currentLocation: 'Outlander Club, Uscru District, Coruscant',
      nearbyCharacters: nearby,
      worldStateContext: event,
      retrievedMemories: retrieved,
    );
    if (!mounted) return;

    // Record this turn into the speaker's stream.
    final now = DateTime.now();
    stream.add(Memory(
      kind: MemoryKind.observation,
      content: 'I thought: ${turn.innerMonologue}',
      timestamp: now,
      importance: 5,
    ));
    if (turn.dialogue.isNotEmpty) {
      stream.add(Memory(
        kind: MemoryKind.dialogueSelf,
        content: 'I said to ${turn.socialTarget}: "${turn.dialogue}"',
        timestamp: now,
        importance: 6,
      ));
      // Smallville-style GOSSIP: nearby agents overhear the dialogue.
      for (final other in _personas.where((o) => o.name != p.name)) {
        _memories[other.name]!.add(Memory(
          kind: MemoryKind.dialogueHeard,
          content: '${p.name} told ${turn.socialTarget}: "${turn.dialogue}"',
          timestamp: now,
          importance: turn.socialTarget == other.name ? 8 : 4,
        ));
      }
    }
    if (turn.physicalActionType != 'IDLE') {
      stream.add(Memory(
        kind: MemoryKind.observation,
        content: '${turn.physicalActionType}: ${turn.physicalActionDetails}',
        timestamp: now,
        importance: 4,
      ));
    }
    // Apply relationship_updates to trust graph.
    for (final upd in turn.relationshipUpdates) {
      if (upd.character.isEmpty || upd.character == 'None' || upd.character == 'All') continue;
      final g = _trustGraph[p.name];
      if (g != null && g.containsKey(upd.character)) {
        g[upd.character] = (g[upd.character]! + upd.trustDelta).clamp(0, 100);
      }
    }

    _turnCount++;
    // Smallville §4.1.3: trigger reflection every 5 turns per agent.
    if (_turnCount % 5 == 0) {
      final recent = stream.recent(n: 10).map((m) => '[${m.kindLabel}] ${m.content}').toList();
      _cohere
          .reflect(agentName: p.name, faction: p.faction, recentMemories: recent)
          .then((insight) {
        if (!mounted) return;
        stream.add(Memory(
          kind: MemoryKind.reflection,
          content: insight,
          timestamp: DateTime.now(),
          importance: 8,
        ));
        setState(() => _reflections[p.name] = insight);
      });
    }

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
                    painter: _BoganoPainter(_world),
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
              _MemoryStreamPanel(
                focus: _focusAgent,
                personas: _personas,
                stream: _memories[_focusAgent],
                reflection: _reflections[_focusAgent],
                plan: _plans[_focusAgent],
                trust: _trustGraph[_focusAgent] ?? const {},
                onSelect: (n) => setState(() => _focusAgent = n),
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
  final List<_Walker> walkers = [];

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
    walkers.clear();

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

    // Ground walkers (Jedi + companions).
    final gy = h * 0.80;
    walkers.addAll([
      _Walker(
        name: 'CAL',
        x: w * 0.30, y: gy, dir: 1,
        speed: 22, scale: 1.0,
        bodyColor: const Color(0xFF7A4B2A),
        accentColor: const Color(0xFF3FB8FF),   // blue saber
        hasSaber: true,
      ),
      _Walker(
        name: 'MERRIN',
        x: w * 0.55, y: gy, dir: -1,
        speed: 18, scale: 0.95,
        bodyColor: const Color(0xFF2A1E1E),
        accentColor: const Color(0xFF8FE3A3),   // nightsister green
        hasSaber: false,
      ),
      _Walker(
        name: 'GREEZ',
        x: w * 0.78, y: gy, dir: 1,
        speed: 14, scale: 0.85,
        bodyColor: const Color(0xFF3A2C20),
        accentColor: const Color(0xFFFF8A4C),
        hasSaber: false,
      ),
    ]);
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
    for (final wkr in walkers) {
      wkr.x += wkr.speed * wkr.dir * dt;
      wkr.gait += dt * 6.0;
      // bounce off edges
      if (wkr.x < 30) { wkr.x = 30; wkr.dir = 1; }
      if (wkr.x > w - 30) { wkr.x = w - 30; wkr.dir = -1; }
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

class _Walker {
  _Walker({
    required this.name,
    required this.x,
    required this.y,
    required this.dir,
    required this.speed,
    required this.scale,
    required this.bodyColor,
    required this.accentColor,
    required this.hasSaber,
  }) : gait = 0;
  final String name;
  double x, y, gait;
  int dir;
  final double speed, scale;
  final Color bodyColor;
  final Color accentColor;
  final bool hasSaber;
}

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
                    'BOGANO · ZEFFO RUINS',
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
                  _chip('$ships motes', const Color(0xFFFF8A4C)),
                  const SizedBox(width: 6),
                  _chip(
                    liveAi ? 'LIVE TRANSMISSION' : 'STANDBY',
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
                    'GOD-RAYS · FORCE ECHOES · MEDITATION CIRCLE',
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
                      liveAi ? 'HOLONET BULLETIN' : 'HOLONET BULLETIN',
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
                    liveAi ? 'AGENT TRANSMISSIONS' : 'AGENT TRANSMISSIONS',
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
                    'GALACTIC CODEX',
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

// =====================================================================
// SMALLVILLE MEMORY STREAM PANEL (bottom-right)
// =====================================================================
//
// Inspired by Park et al., "Generative Agents: Interactive Simulacra of
// Human Behavior" (Stanford 2023). Shows: focus agent picker, current
// daily-plan slot, latest reflection, scrolling memory feed colored by
// kind, and live trust graph.

class _MemoryStreamPanel extends StatelessWidget {
  const _MemoryStreamPanel({
    required this.focus,
    required this.personas,
    required this.stream,
    required this.reflection,
    required this.plan,
    required this.trust,
    required this.onSelect,
  });

  final String focus;
  final List<_AgentPersona> personas;
  final MemoryStream? stream;
  final String? reflection;
  final DailyPlan? plan;
  final Map<String, int> trust;
  final ValueChanged<String> onSelect;

  Color _kindColor(MemoryKind k) {
    switch (k) {
      case MemoryKind.reflection:
        return const Color(0xFF7C5CFF);
      case MemoryKind.dialogueSelf:
        return const Color(0xFF26F0F0);
      case MemoryKind.dialogueHeard:
        return const Color(0xFFFFB347);
      case MemoryKind.plan:
        return const Color(0xFF00D4A8);
      case MemoryKind.observation:
        return const Color(0xFFA8AEBD);
    }
  }

  PlanSlot? _currentSlot() {
    if (plan == null || plan!.slots.isEmpty) return null;
    final hhmm = DateTime.now();
    final nowKey = '${hhmm.hour.toString().padLeft(2, '0')}${hhmm.minute.toString().padLeft(2, '0')}';
    PlanSlot? cur;
    for (final s in plan!.slots) {
      if (s.time.compareTo(nowKey) <= 0) cur = s;
    }
    return cur ?? plan!.slots.first;
  }

  @override
  Widget build(BuildContext context) {
    final memories = stream?.all ?? const <Memory>[];
    final slot = _currentSlot();
    final focusColor = personas.firstWhere(
      (p) => p.name == focus,
      orElse: () => personas.first,
    ).color;

    return Positioned(
      right: 16,
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
                    decoration: BoxDecoration(color: focusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AGENT DOSSIER',
                      style: TextStyle(
                        color: Color(0xFF7C5CFF),
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${memories.length} mem',
                    style: const TextStyle(color: Color(0xFF6B7184), fontSize: 9),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Persona picker
              Row(
                children: personas.map((p) {
                  final sel = p.name == focus;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => onSelect(p.name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: sel ? p.color.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: p.color.withValues(alpha: sel ? 0.9 : 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          p.name.split(' ').first,
                          style: TextStyle(
                            color: sel ? Colors.white : const Color(0xFFB8C4D4),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              if (slot != null)
                _strip(
                  'NOW \u00b7 ${slot.time}',
                  slot.activity,
                  const Color(0xFF00D4A8),
                ),
              if (reflection != null) ...[
                const SizedBox(height: 6),
                _strip('REFLECTION', reflection!, const Color(0xFF7C5CFF)),
              ],
              if (trust.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: trust.entries.map((e) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.key.split(' ').first} ${e.value}',
                              style: const TextStyle(color: Color(0xFFB8C4D4), fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: e.value / 100.0,
                                minHeight: 3,
                                backgroundColor: Colors.white.withValues(alpha: 0.06),
                                valueColor: AlwaysStoppedAnimation(
                                  e.value >= 50 ? const Color(0xFF00D4A8) : const Color(0xFFFF5C7A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: memories.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'Memory stream initialising\u2026',
                          style: TextStyle(color: Color(0xFF6B7184), fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: memories.length.clamp(0, 14),
                        itemBuilder: (ctx, i) {
                          final m = memories[i];
                          final c = _kindColor(m.kind);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 3, right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: c.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: c.withValues(alpha: 0.5), width: 0.6),
                                  ),
                                  child: Text(
                                    m.kindLabel,
                                    style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    m.content,
                                    style: const TextStyle(
                                      color: Color(0xFFE6EAF2),
                                      fontSize: 10.5,
                                      height: 1.3,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, top: 2),
                                  child: Text(
                                    'i${m.importance}',
                                    style: const TextStyle(color: Color(0xFF6B7184), fontSize: 8),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _strip(String label, String body, Color c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.4), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: c, fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// JEDI: FALLEN ORDER BIOME PAINTER
// =====================================================================
//
// Reinterprets the Coruscant `_World` as a Bogano/Zeffo ruin biome:
//   - bg/mid/fg buildings -> ancient stone pillars with rim light
//   - ships               -> fireflies / Force motes drifting in fog
//   - holograms           -> glowing Force Echoes (blue saber pulses)
//   - sky                 -> misty dusk + volumetric god rays
//   - ground              -> dark soil + meditation circle
// Plus: cinematic vignette + film grain.

class _BoganoPainter extends CustomPainter {
  _BoganoPainter(this.world);
  final _World world;

  static final _p = Paint();
  static final _glow = Paint();

  static const _sabreBlue = Color(0xFF3FB8FF);
  static const _rimOrange = Color(0xFFFF8A4C);
  static const _stoneDark = Color(0xFF1A2128);
  static const _stoneMid = Color(0xFF2B3640);
  static const _stoneLight = Color(0xFF3F4E5A);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawDistantPeaks(canvas, size);
    _drawGodRays(canvas, size);
    _drawFogBand(canvas, size, 0.45, 0.04);
    _drawRuins(canvas, world.bgBuildings, 0.30);
    _drawFogBand(canvas, size, 0.58, 0.06);
    _drawRuins(canvas, world.midBuildings, 0.55);
    _drawForceEchoes(canvas);
    _drawRuins(canvas, world.fgBuildings, 1.0);
    _drawFireflies(canvas);
    _drawGround(canvas, size);
    _drawWalkers(canvas);
    _drawVignette(canvas, size);
    _drawFilmGrain(canvas, size);
  }

  void _drawSky(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    _p
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A1218),
          Color(0xFF14232C),
          Color(0xFF3A3220),
          Color(0xFF1E1A14),
        ],
        stops: [0.0, 0.45, 0.70, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, _p);
    _p.shader = null;

    for (final st in world.stars) {
      final a = (sin(st.twinkle) * 0.35 + 0.55).clamp(0.0, 1.0);
      _p.color = const Color(0xFFCDE7FF).withValues(alpha: a * 0.35);
      canvas.drawCircle(Offset(st.x, st.y * 0.55), st.r * 0.9, _p);
    }
  }

  void _drawDistantPeaks(Canvas canvas, Size s) {
    final base = s.height * 0.62;
    final path = Path()..moveTo(0, base);
    final rng = Random(11);
    var x = 0.0;
    while (x < s.width) {
      final h = 35 + rng.nextDouble() * 70;
      path.lineTo(x, base - h);
      x += 40 + rng.nextDouble() * 60;
      path.lineTo(x, base - h * 0.6);
      x += 30 + rng.nextDouble() * 50;
    }
    path.lineTo(s.width, base);
    path.close();
    _p
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F1A22), Color(0xFF1B2A36)],
      ).createShader(Rect.fromLTWH(0, base - 110, s.width, 110))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, _p);
    _p.shader = null;

    _p
      ..color = _rimOrange.withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, _p);
    _p.style = PaintingStyle.fill;
  }

  void _drawGodRays(Canvas canvas, Size s) {
    final sun = Offset(s.width * 0.72, s.height * 0.18);
    const rays = 7;
    for (var i = 0; i < rays; i++) {
      final angle = (pi * 0.55) + (i / rays) * 0.55 + sin(world.t * 0.4 + i) * 0.02;
      final len = s.height * 1.4;
      final end = sun + Offset(cos(angle) * len, sin(angle) * len);
      final p = Path()
        ..moveTo(sun.dx - 6, sun.dy)
        ..lineTo(sun.dx + 6, sun.dy)
        ..lineTo(end.dx + 35, end.dy)
        ..lineTo(end.dx - 35, end.dy)
        ..close();
      _p
        ..shader = LinearGradient(
          colors: [
            _rimOrange.withValues(alpha: 0.16),
            _rimOrange.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromPoints(sun, end))
        ..blendMode = BlendMode.plus;
      canvas.drawPath(p, _p);
    }
    _p
      ..shader = null
      ..blendMode = BlendMode.srcOver;

    _glow
      ..shader = RadialGradient(
        colors: [
          _rimOrange.withValues(alpha: 0.9),
          _rimOrange.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: sun, radius: 80))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(sun, 80, _glow);
    _glow
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = const Color(0xFFFFE0B5);
    canvas.drawCircle(sun, 18, _glow);
  }

  void _drawFogBand(Canvas canvas, Size s, double yFrac, double alpha) {
    final rect = Rect.fromLTWH(0, s.height * yFrac, s.width, s.height * 0.32);
    _p
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: alpha),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect)
      ..blendMode = BlendMode.plus;
    canvas.drawRect(rect, _p);
    _p
      ..shader = null
      ..blendMode = BlendMode.srcOver;
  }

  void _drawRuins(Canvas canvas, List<_Building> list, double depth) {
    for (final b in list) {
      _drawPillar(canvas, b, depth);
    }
  }

  void _drawPillar(Canvas canvas, _Building b, double depth) {
    final top = b.baseY - b.height;
    final cx = b.x + b.width * 0.5;
    final rect = Rect.fromLTWH(b.x, top, b.width, b.height);

    final dark = Color.lerp(_stoneDark, Colors.black, 1.0 - depth)!;
    final mid = Color.lerp(_stoneMid, _stoneDark, 1.0 - depth)!;
    _p
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [mid, dark],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, _p);

    _p
      ..shader = null
      ..color = _stoneLight.withValues(alpha: 0.35 * depth)
      ..style = PaintingStyle.fill;
    final bands = (b.height / 45).floor().clamp(2, 7);
    for (var i = 1; i <= bands; i++) {
      final y = top + (b.height * i / (bands + 1));
      canvas.drawRect(Rect.fromLTWH(b.x + 2, y, b.width - 4, 2.5), _p);
    }

    _p.color = const Color(0xFF0B0F13).withValues(alpha: 0.6 * depth);
    canvas.drawRect(Rect.fromLTWH(cx - 2, top + 8, 4, b.height - 16), _p);

    final capH = 10 + (b.roofKind * 4).toDouble();
    _p.color = mid;
    final cap = Path()
      ..moveTo(b.x - 4, top)
      ..lineTo(b.x + b.width + 4, top)
      ..lineTo(b.x + b.width, top - capH)
      ..lineTo(b.x, top - capH)
      ..close();
    canvas.drawPath(cap, _p);

    _p.color = _rimOrange.withValues(alpha: 0.55 * depth);
    canvas.drawRect(Rect.fromLTWH(b.x, top, 1.6, b.height), _p);

    _p.color = _sabreBlue.withValues(alpha: 0.20 * depth);
    canvas.drawRect(Rect.fromLTWH(b.x + b.width - 1.6, top, 1.6, b.height), _p);

    final rng = Random(b.windowSeed);
    final crystals = 1 + rng.nextInt(3);
    for (var i = 0; i < crystals; i++) {
      final ox = b.x + 8 + rng.nextDouble() * (b.width - 16);
      final oy = top + 20 + rng.nextDouble() * (b.height - 40);
      _glow
        ..shader = RadialGradient(
          colors: [
            _sabreBlue.withValues(alpha: 0.9 * depth),
            _sabreBlue.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(ox, oy), radius: 14))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(ox, oy), 14, _glow);
      _glow
        ..shader = null
        ..blendMode = BlendMode.srcOver
        ..color = const Color(0xFFB6E6FF);
      canvas.drawCircle(Offset(ox, oy), 1.6 * depth, _glow);
    }
  }

  void _drawForceEchoes(Canvas canvas) {
    for (final h in world.holos) {
      final pulse = (sin(h.phase * 1.6) * 0.5 + 0.5);
      final r = 60.0 + pulse * 18.0;
      _glow
        ..shader = RadialGradient(
          colors: [
            _sabreBlue.withValues(alpha: 0.55),
            _sabreBlue.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(h.x, h.y), radius: r))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(h.x, h.y), r, _glow);
      _glow
        ..shader = null
        ..blendMode = BlendMode.srcOver
        ..color = const Color(0xFFE0F4FF).withValues(alpha: 0.85);
      canvas.drawCircle(Offset(h.x, h.y), 3.2, _glow);

      _p
        ..color = _sabreBlue.withValues(alpha: 0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < 4; i++) {
        final dy = (h.phase * 30 + i * 18) % 90;
        canvas.drawLine(
          Offset(h.x - 8, h.y - dy),
          Offset(h.x + 8, h.y - dy),
          _p,
        );
      }
      _p.style = PaintingStyle.fill;
    }
  }

  void _drawFireflies(Canvas canvas) {
    for (final s in world.ships) {
      final flicker = (sin(world.t * 3 + s.x * 0.07) * 0.35 + 0.65);
      final wy = s.y + sin(world.t * 1.2 + s.x * 0.04) * 6;
      _glow
        ..shader = RadialGradient(
          colors: [
            _rimOrange.withValues(alpha: 0.8 * flicker),
            _rimOrange.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(s.x, wy), radius: 9 * s.scale))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(s.x, wy), 9 * s.scale, _glow);
      _glow
        ..shader = null
        ..blendMode = BlendMode.srcOver
        ..color = const Color(0xFFFFE2B0).withValues(alpha: flicker);
      canvas.drawCircle(Offset(s.x, wy), 1.4 * s.scale, _glow);
    }
  }

  void _drawGround(Canvas canvas, Size s) {
    final groundY = s.height * 0.78;
    final rect = Rect.fromLTWH(0, groundY, s.width, s.height - groundY);
    _p
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1A1410),
          Color(0xFF080606),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, _p);
    _p.shader = null;

    final c = Offset(s.width * 0.5, s.height * 0.86);
    for (var i = 0; i < 3; i++) {
      _p
        ..color = _sabreBlue.withValues(alpha: 0.10 - i * 0.025)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 220 + i * 80.0, height: 36 + i * 14.0),
        _p,
      );
    }
    _p.style = PaintingStyle.fill;
  }

  void _drawVignette(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    _p
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.55),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, _p);
    _p.shader = null;
  }

  void _drawFilmGrain(Canvas canvas, Size s) {
    final rng = Random((world.t * 60).floor());
    _p.color = Colors.white.withValues(alpha: 0.025);
    for (var i = 0; i < 90; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * s.width, rng.nextDouble() * s.height),
        0.6,
        _p,
      );
    }
  }

  void _drawWalkers(Canvas canvas) {
    for (final w in world.walkers) {
      _drawWalker(canvas, w);
    }
  }

  void _drawWalker(Canvas canvas, _Walker w) {
    final s = w.scale;
    final cx = w.x;
    final feetY = w.y;
    final headR = 4.5 * s;
    final torsoTop = feetY - 36 * s;
    final torsoBot = feetY - 16 * s;
    final headY = torsoTop - headR;

    // Walk gait — sinusoidal limbs.
    final leg = sin(w.gait) * 6 * s;
    final arm = sin(w.gait + pi) * 6 * s;

    // Long shadow on the ground.
    _p
      ..shader = null
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, feetY + 3), width: 22 * s, height: 5 * s),
      _p,
    );

    // Body silhouette
    final body = Paint()
      ..color = w.bodyColor
      ..style = PaintingStyle.fill;
    // torso
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - 5 * s, torsoTop, cx + 5 * s, torsoBot),
        Radius.circular(2 * s),
      ),
      body,
    );
    // head
    canvas.drawCircle(Offset(cx, headY), headR, body);
    // arms
    _p
      ..color = w.bodyColor
      ..strokeWidth = 2.2 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 4 * s, torsoTop + 2), Offset(cx - 7 * s, torsoTop + 14 * s + arm), _p);
    canvas.drawLine(Offset(cx + 4 * s, torsoTop + 2), Offset(cx + 7 * s, torsoTop + 14 * s - arm), _p);
    // legs
    canvas.drawLine(Offset(cx - 2 * s, torsoBot), Offset(cx - 3 * s, feetY + leg.abs() * 0.0), _p);
    canvas.drawLine(Offset(cx + 2 * s, torsoBot), Offset(cx + 3 * s, feetY - leg.abs() * 0.0), _p);
    canvas.drawLine(Offset(cx - 2 * s, torsoBot), Offset(cx - 3 * s + leg * 0.4, feetY), _p);
    canvas.drawLine(Offset(cx + 2 * s, torsoBot), Offset(cx + 3 * s - leg * 0.4, feetY), _p);

    // Cloak/poncho rim light
    _p
      ..style = PaintingStyle.fill
      ..color = _rimOrange.withValues(alpha: 0.45);
    final cloak = Path()
      ..moveTo(cx - 6 * s, torsoTop + 4)
      ..lineTo(cx + 6 * s, torsoTop + 4)
      ..lineTo(cx + 8 * s, torsoBot + 2 * s)
      ..lineTo(cx - 8 * s, torsoBot + 2 * s)
      ..close();
    canvas.drawPath(cloak, _p);

    // Lightsaber for Cal
    if (w.hasSaber) {
      final hiltX = cx + (w.dir > 0 ? 8 * s : -8 * s);
      final hiltY = torsoTop + 18 * s;
      final tipX = hiltX + (w.dir > 0 ? 26 * s : -26 * s);
      final tipY = hiltY - 22 * s;

      // Glow halo
      _glow
        ..shader = RadialGradient(
          colors: [
            w.accentColor.withValues(alpha: 0.7),
            w.accentColor.withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset((hiltX + tipX) / 2, (hiltY + tipY) / 2), radius: 28 * s))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(
        Offset((hiltX + tipX) / 2, (hiltY + tipY) / 2),
        28 * s,
        _glow,
      );
      _glow
        ..shader = null
        ..blendMode = BlendMode.srcOver;

      // Outer blade
      _p
        ..color = w.accentColor.withValues(alpha: 0.55)
        ..strokeWidth = 6 * s
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(hiltX, hiltY), Offset(tipX, tipY), _p);
      // Inner white core
      _p
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 2.4 * s;
      canvas.drawLine(Offset(hiltX, hiltY), Offset(tipX, tipY), _p);

      // Hilt
      _p
        ..color = const Color(0xFF2A2A2A)
        ..strokeWidth = 4 * s
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawLine(
        Offset(hiltX, hiltY),
        Offset(hiltX - (w.dir > 0 ? 6 * s : -6 * s), hiltY + 4 * s),
        _p,
      );
    }

    // Name tag floating above
    final tp = TextPainter(
      text: TextSpan(
        text: w.name,
        style: TextStyle(
          color: w.accentColor.withValues(alpha: 0.95),
          fontSize: 9,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, headY - 18));
    // Tag underline
    _p
      ..color = w.accentColor.withValues(alpha: 0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx - tp.width / 2 - 2, headY - 6),
      Offset(cx + tp.width / 2 + 2, headY - 6),
      _p,
    );
    _p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant _BoganoPainter old) => true;
}
