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
import '../audio/star_wars_sounds.dart';

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
  SwVehicle? _focusVehicle;

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
    // Free ambient space sound (freesound.org CDN, no key required).
    StarWarsSounds.playAmbientSpace();
    // Procedural Imperial March loop kicks in shortly after user clicks.
    StarWarsSounds.playImperialMarch();
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
      _swapi.vehicle(14),   // 74-Z speeder bike
    ]);
    if (!mounted) return;
    setState(() {
      _focusPlanet = results[0] as SwPlanet;
      _focusShip = results[1] as SwStarship;
      _focusPerson = results[2] as SwPerson;
      _focusVehicle = results[3] as SwVehicle;
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
    // Sims-style: surface the action above the matching walker.
    final actionLabel = turn.physicalActionType == 'IDLE' || turn.physicalActionDetails.isEmpty
        ? (turn.dialogue.isNotEmpty ? turn.dialogue : turn.innerMonologue)
        : '${turn.physicalActionType.toLowerCase()} · ${turn.physicalActionDetails}';
    _world.setActionForPersona(p.name, actionLabel);
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
              // Minimal top-bar: faction score only. All chat/codex/memory
              // panels removed — only the per-character action bubbles
              // (drawn directly on the canvas above each walker) remain.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _ScoreChip(label: 'REBELS', value: _world.rebelScore, color: const Color(0xFF26F0F0)),
                      const SizedBox(width: 8),
                      _ScoreChip(label: 'EMPIRE', value: _world.imperialScore, color: const Color(0xFFFF3158)),
                    ],
                  ),
                ),
              ),
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
  final List<_Bolt> bolts = [];
  final List<_Fighter> fighters = [];

  // Combat HUD state
  int rebelScore = 0;
  int imperialScore = 0;
  double shake = 0;     // decays
  double shakeX = 0, shakeY = 0;
  final _combatRand = Random(11);

  // Animated globals
  double t = 0;
  double sunPhase = 0; // 0..1 across the sky

  // Millennium Falcon flyby — cycles across the screen, then waits.
  double falconX = -200;
  double falconY = 0;
  double falconCooldown = 6; // seconds until next flyby

  // Star Destroyer slow drift (parallax background)
  double destroyerX = 0;

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

    // Ground walkers — Sims-style NPCs. Some are wired to LLM personas so
    // their action bubble mirrors the latest agent turn; some are static
    // antagonists/protagonists to drive combat.
    final gy = h * 0.80;
    walkers.addAll([
      // CAL — neutral Jedi (no faction combat), lit blue saber
      _Walker(
        name: 'CAL',
        x: w * 0.18, y: gy, dir: 1,
        speed: 22, scale: 1.0,
        bodyColor: const Color(0xFF7A4B2A),
        accentColor: const Color(0xFF3FB8FF),
        hasSaber: true,
      ),
      // HAN SOLO — Rebel, blaster, mapped to persona
      _Walker(
        name: 'HAN',
        personaName: 'Han Solo',
        faction: 'Rebel',
        x: w * 0.34, y: gy, dir: 1,
        speed: 26, scale: 1.0,
        bodyColor: const Color(0xFF2C2620),
        accentColor: const Color(0xFFFFB347),
        hasSaber: false,
      ),
      // LEIA — Rebel, blaster, mapped to persona
      _Walker(
        name: 'LEIA',
        personaName: 'Leia Organa',
        faction: 'Rebel',
        x: w * 0.46, y: gy, dir: 1,
        speed: 22, scale: 0.96,
        bodyColor: const Color(0xFFEFEFEF),
        accentColor: const Color(0xFF26F0F0),
        hasSaber: false,
      ),
      // BOBA FETT — Empire-aligned, blaster, mapped to persona
      _Walker(
        name: 'BOBA',
        personaName: 'Boba Fett',
        faction: 'Empire',
        x: w * 0.66, y: gy, dir: -1,
        speed: 24, scale: 1.0,
        bodyColor: const Color(0xFF3F4534),
        accentColor: const Color(0xFFFF5C7A),
        hasSaber: false,
      ),
      // VADER — Empire, red saber, no persona (cycles canned actions)
      _Walker(
        name: 'VADER',
        faction: 'Empire',
        x: w * 0.84, y: gy, dir: -1,
        speed: 18, scale: 1.05,
        bodyColor: const Color(0xFF0A0A0A),
        accentColor: const Color(0xFFFF3158),
        hasSaber: true,
      ),
    ]);

    // Sky dogfight — 4 X-wings vs 4 TIEs at high altitude.
    fighters.clear();
    for (var i = 0; i < 4; i++) {
      fighters.add(_Fighter(
        kind: 'xwing',
        faction: 'Rebel',
        x: 40.0 + i * 90,
        y: h * 0.18 + (i % 2) * 30,
        vx: 60 + i * 10.0,
        vy: 0,
      ));
      fighters.add(_Fighter(
        kind: 'tie',
        faction: 'Empire',
        x: w - 40 - i * 90,
        y: h * 0.22 + (i % 2) * 30,
        vx: -55 - i * 10.0,
        vy: 0,
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

    // Millennium Falcon flyby
    if (falconX > w + 220) {
      falconCooldown -= dt;
      if (falconCooldown <= 0) {
        falconX = -200;
        falconY = h * (0.12 + _combatRand.nextDouble() * 0.10);
        falconCooldown = 9 + _combatRand.nextDouble() * 8;
      }
    } else {
      falconX += 220 * dt;
    }

    // Star Destroyer slow drift
    destroyerX += dt * 4;
    if (destroyerX > w + 400) destroyerX = -500;

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
      // decay timers
      if (wkr.hitFlash > 0) wkr.hitFlash = max(0, wkr.hitFlash - dt * 2.5);
      if (wkr.muzzleFlash > 0) wkr.muzzleFlash = max(0, wkr.muzzleFlash - dt * 6);
      if (wkr.saberSwing > 0) wkr.saberSwing = max(0, wkr.saberSwing - dt * 4);
      if (wkr.fireCooldown > 0) wkr.fireCooldown -= dt;
      if (wkr.actionTtl > 0) {
        wkr.actionTtl -= dt;
        if (wkr.actionTtl <= 0) wkr.action = null;
      }
      // respawn if dead
      if (wkr.hp <= 0) {
        wkr.hp = wkr.maxHp;
        wkr.x = wkr.dir > 0 ? 30 : w - 30;
        wkr.hitFlash = 0;
        wkr.action = 'respawn · reinforcements arrive';
        wkr.actionTtl = 4.0;
      }
    }

    // Combat: opposing-faction walkers in range exchange fire.
    for (final shooter in walkers) {
      if (shooter.faction == 'Neutral') continue;
      if (shooter.fireCooldown > 0) continue;
      _Walker? target;
      double bestDx = double.infinity;
      for (final other in walkers) {
        if (other == shooter) continue;
        if (other.faction == 'Neutral' || other.faction == shooter.faction) continue;
        final dx = (other.x - shooter.x).abs();
        if (dx < shooter.weaponRange && dx < bestDx) {
          bestDx = dx;
          target = other;
        }
      }
      if (target == null) continue;
      // face target
      shooter.dir = target.x > shooter.x ? 1 : -1;
      shooter.fireCooldown = 1.0 / shooter.fireRate + _combatRand.nextDouble() * 0.6;
      shooter.muzzleFlash = 1.0;
      // spawn bolt from shooter chest toward target chest
      final sx = shooter.x + shooter.dir * 10;
      final sy = shooter.y - 22;
      final tx = target.x;
      final ty = target.y - 22;
      final dxv = tx - sx;
      final dyv = ty - sy;
      final dist = sqrt(dxv * dxv + dyv * dyv).clamp(1, double.infinity);
      const boltSpeed = 520.0;
      final color = shooter.faction == 'Rebel'
          ? const Color(0xFFFF3158)    // Rebel blaster bolts are red
          : const Color(0xFF3FB8FF);   // Imperial blaster bolts are blue
      bolts.add(_Bolt(
        x: sx, y: sy,
        vx: dxv / dist * boltSpeed,
        vy: dyv / dist * boltSpeed,
        color: color,
        fromFaction: shooter.faction,
      ));
      // Throttled SFX so we don't spam audio context
      if (_combatRand.nextDouble() < 0.35) {
        StarWarsSounds.blasterFire();
      }
    }

    // Move bolts + collide with opposing-faction walkers.
    for (final b in bolts) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.age += dt;
      if (b.age > 2.4 || b.x < -20 || b.x > w + 20 || b.y < 0 || b.y > h) {
        b.alive = false;
        continue;
      }
      for (final wkr in walkers) {
        if (wkr.faction == 'Neutral') continue;
        if (wkr.faction == b.fromFaction) continue;
        final dx = wkr.x - b.x;
        final dy = (wkr.y - 22) - b.y;
        if (dx * dx + dy * dy < 14 * 14) {
          b.alive = false;
          wkr.hp -= 18;
          wkr.hitFlash = 1.0;
          shake = (shake + 0.5).clamp(0, 1.6);
          if (wkr.hp <= 0) {
            if (b.fromFaction == 'Rebel') rebelScore++;
            else imperialScore++;
            StarWarsSounds.explosion();
          }
          break;
        }
      }
    }
    bolts.removeWhere((b) => !b.alive);

    // Camera shake decay + offsets.
    if (shake > 0) {
      shake = max(0, shake - dt * 2.0);
      shakeX = (_combatRand.nextDouble() - 0.5) * 6 * shake;
      shakeY = (_combatRand.nextDouble() - 0.5) * 4 * shake;
    } else {
      shakeX = 0; shakeY = 0;
    }

    // ----- DOGFIGHT: starfighter AI + steering + firing -----
    for (final f in fighters) {
      if (!f.alive) continue;
      // Find nearest enemy
      _Fighter? target;
      double bestD = double.infinity;
      for (final o in fighters) {
        if (o == f || !o.alive || o.faction == f.faction) continue;
        final d = (o.x - f.x).abs() + (o.y - f.y).abs();
        if (d < bestD) { bestD = d; target = o; }
      }
      if (target != null) {
        final dx = target.x - f.x;
        final dy = target.y - f.y;
        final dist = sqrt(dx * dx + dy * dy).clamp(1, double.infinity);
        // Steer toward target
        final desiredVx = dx / dist * 110;
        final desiredVy = dy / dist * 70;
        f.vx += (desiredVx - f.vx) * dt * 0.8;
        f.vy += (desiredVy - f.vy) * dt * 0.8;
        // Fire when reasonably close + aligned
        if (f.fireCooldown <= 0 && dist < 420) {
          f.fireCooldown = 0.7 + _combatRand.nextDouble() * 0.6;
          f.muzzle = 1.0;
          final color = f.faction == 'Rebel'
              ? const Color(0xFFFF3158)
              : const Color(0xFF3FB8FF);
          bolts.add(_Bolt(
            x: f.x + (f.vx > 0 ? 14 : -14),
            y: f.y,
            vx: dx / dist * 560 + f.vx * 0.3,
            vy: dy / dist * 560 + f.vy * 0.3,
            color: color,
            fromFaction: f.faction,
          ));
          if (_combatRand.nextDouble() < 0.25) StarWarsSounds.blasterFire();
        }
      }
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      // Keep within sky band
      if (f.y < h * 0.06) { f.y = h * 0.06; f.vy = f.vy.abs(); }
      if (f.y > h * 0.42) { f.y = h * 0.42; f.vy = -f.vy.abs(); }
      if (f.x < -40) f.x = w + 40;
      if (f.x > w + 40) f.x = -40;
      if (f.fireCooldown > 0) f.fireCooldown -= dt;
      if (f.hitFlash > 0) f.hitFlash = max(0, f.hitFlash - dt * 2.5);
      if (f.muzzle > 0) f.muzzle = max(0, f.muzzle - dt * 5);
    }

    // Bolt vs fighter collisions (bolts already moved above)
    for (final b in bolts) {
      if (!b.alive) continue;
      for (final f in fighters) {
        if (!f.alive || f.faction == b.fromFaction) continue;
        final dx = f.x - b.x;
        final dy = f.y - b.y;
        if (dx * dx + dy * dy < 16 * 16) {
          b.alive = false;
          f.hp -= 14;
          f.hitFlash = 1.0;
          shake = (shake + 0.4).clamp(0, 1.6);
          if (f.hp <= 0) {
            if (b.fromFaction == 'Rebel') rebelScore++;
            else imperialScore++;
            StarWarsSounds.explosion();
          }
          break;
        }
      }
    }
    bolts.removeWhere((b) => !b.alive);

    // Respawn dead fighters at edge after a beat
    for (final f in fighters) {
      if (!f.alive) {
        f.hp = f.maxHp;
        f.x = f.faction == 'Rebel' ? -40 : w + 40;
        f.y = h * 0.15 + _combatRand.nextDouble() * h * 0.20;
        f.vx = f.faction == 'Rebel' ? 60 : -60;
        f.vy = 0;
        f.hitFlash = 0;
      }
    }
  }

  /// Mirror an LLM agent's latest action onto its matching ground walker
  /// as a Sims-style action bubble.
  void setActionForPersona(String personaName, String text) {
    for (final wkr in walkers) {
      if (wkr.personaName == personaName) {
        wkr.action = text.length > 80 ? '${text.substring(0, 77)}…' : text;
        wkr.actionTtl = 7.0;
        return;
      }
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
    this.personaName,
    this.faction = 'Neutral',
    this.maxHp = 100,
    this.weaponRange = 320,
    this.fireRate = 1.6,
  })  : gait = 0,
        hp = maxHp,
        hitFlash = 0,
        fireCooldown = 0,
        action = null,
        actionTtl = 0,
        muzzleFlash = 0,
        saberSwing = 0;
  final String name;
  final String? personaName;
  final String faction; // 'Rebel' | 'Empire' | 'Neutral'
  double x, y, gait;
  int dir;
  final double speed, scale;
  final Color bodyColor;
  final Color accentColor;
  final bool hasSaber;

  final double maxHp;
  double hp;
  double hitFlash;        // 0..1, decays
  double fireCooldown;    // seconds until can fire
  final double weaponRange;
  final double fireRate;  // shots per second
  String? action;         // Sims-style bubble text
  double actionTtl;       // seconds remaining
  double muzzleFlash;
  double saberSwing;
}

class _Bolt {
  _Bolt({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.fromFaction,
  })  : age = 0,
        alive = true;
  double x, y, vx, vy, age;
  bool alive;
  final Color color;
  final String fromFaction;
}

/// Sky starfighter — X-wing (Rebel) or TIE (Empire). Dogfight: each
/// fighter steers toward the nearest enemy and fires when in range.
class _Fighter {
  _Fighter({
    required this.kind,
    required this.faction,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  })  : hp = 60,
        maxHp = 60,
        fireCooldown = 0,
        hitFlash = 0,
        muzzle = 0;
  final String kind; // 'xwing' | 'tie'
  final String faction;
  double x, y, vx, vy;
  double hp;
  final double maxHp;
  double fireCooldown;
  double hitFlash;
  double muzzle;
  bool get alive => hp > 0;
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
  const _Hud({required this.fps, required this.liveAi, required this.ships, required this.rebelScore, required this.imperialScore});
  final double fps;
  final bool liveAi;
  final int ships;
  final int rebelScore;
  final int imperialScore;

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
                  const SizedBox(width: 6),
                  _chip('REBELS $rebelScore', const Color(0xFF26F0F0)),
                  const SizedBox(width: 4),
                  _chip('EMPIRE $imperialScore', const Color(0xFFFF3158)),
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

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Text('$value', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
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
  const _CodexPanel({required this.planet, required this.ship, required this.person, required this.vehicle});
  final SwPlanet? planet;
  final SwStarship? ship;
  final SwPerson? person;
  final SwVehicle? vehicle;

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
              const SizedBox(height: 8),
              _codexBlock(
                'VEHICLE',
                vehicle?.name ?? 'Loading\u2026',
                [
                  if (vehicle != null) 'Class: ${vehicle!.vehicleClass}',
                  if (vehicle != null) 'Model: ${vehicle!.model}',
                  if (vehicle != null) 'Crew: ${vehicle!.crew}',
                  if (vehicle != null) 'Max Speed: ${vehicle!.maxSpeed}',
                ],
                const Color(0xFF8FE3A3),
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
    canvas.save();
    if (world.shakeX != 0 || world.shakeY != 0) {
      canvas.translate(world.shakeX, world.shakeY);
    }
    _drawSky(canvas, size);
    _drawDeathStar(canvas, size);
    _drawStarDestroyer(canvas, size);
    _drawDistantPeaks(canvas, size);
    _drawGodRays(canvas, size);
    _drawFogBand(canvas, size, 0.45, 0.04);
    _drawRuins(canvas, world.bgBuildings, 0.30);
    _drawFogBand(canvas, size, 0.58, 0.06);
    _drawRuins(canvas, world.midBuildings, 0.55);
    _drawForceEchoes(canvas);
    _drawRuins(canvas, world.fgBuildings, 1.0);
    _drawFireflies(canvas);
    _drawFighters(canvas);
    _drawFalcon(canvas, size);
    _drawGround(canvas, size);
    _drawWalkers(canvas);
    _drawBolts(canvas);
    _drawVignette(canvas, size);
    _drawFilmGrain(canvas, size);
    canvas.restore();
  }

  void _drawFighters(Canvas canvas) {
    for (final f in world.fighters) {
      if (f.kind == 'xwing') {
        _drawXwing(canvas, f);
      } else {
        _drawTie(canvas, f);
      }
      // HP bar
      const barW = 26.0;
      final by = f.y - 18;
      _p
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(f.x - barW / 2, by, barW, 2.6), _p);
      _p.color = f.faction == 'Rebel' ? const Color(0xFF26F0F0) : const Color(0xFFFF3158);
      canvas.drawRect(
        Rect.fromLTWH(f.x - barW / 2, by, barW * (f.hp / f.maxHp).clamp(0.0, 1.0), 2.6),
        _p,
      );
      // Hit flash
      if (f.hitFlash > 0) {
        _glow
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: 0.8 * f.hitFlash), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: Offset(f.x, f.y), radius: 22))
          ..blendMode = BlendMode.plus;
        canvas.drawCircle(Offset(f.x, f.y), 22, _glow);
        _glow
          ..shader = null
          ..blendMode = BlendMode.srcOver;
      }
    }
  }

  void _drawXwing(Canvas canvas, _Fighter f) {
    final dir = f.vx >= 0 ? 1 : -1;
    final cx = f.x, cy = f.y;
    // Engine glow / thruster trail
    _glow
      ..shader = RadialGradient(
        colors: [const Color(0xFFFF6A2A).withValues(alpha: 0.7), const Color(0xFFFF6A2A).withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(cx - dir * 16, cy), radius: 12))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(cx - dir * 16, cy), 12, _glow);
    _glow..shader = null..blendMode = BlendMode.srcOver;

    // Body fuselage (long taper)
    _p
      ..color = const Color(0xFFC8CDD4)
      ..style = PaintingStyle.fill;
    final body = Path()
      ..moveTo(cx + dir * 18, cy)
      ..lineTo(cx - dir * 14, cy - 3)
      ..lineTo(cx - dir * 14, cy + 3)
      ..close();
    canvas.drawPath(body, _p);
    // Cockpit
    _p.color = const Color(0xFF22303C);
    canvas.drawCircle(Offset(cx + dir * 4, cy - 2), 3, _p);
    // S-foils (X pattern wings)
    _p
      ..color = const Color(0xFFB0B7BF)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - dir * 6, cy - 6), Offset(cx - dir * 14, cy - 12), _p);
    canvas.drawLine(Offset(cx - dir * 6, cy + 6), Offset(cx - dir * 14, cy + 12), _p);
    canvas.drawLine(Offset(cx - dir * 6, cy - 6), Offset(cx - dir * 2, cy - 12), _p);
    canvas.drawLine(Offset(cx - dir * 6, cy + 6), Offset(cx - dir * 2, cy + 12), _p);
    // Wing tip cannons (red)
    _p
      ..color = const Color(0xFFFF3158)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(cx - dir * 14, cy - 12), Offset(cx + dir * 6, cy - 12), _p);
    canvas.drawLine(Offset(cx - dir * 14, cy + 12), Offset(cx + dir * 6, cy + 12), _p);
    _p.style = PaintingStyle.fill;
    // Muzzle flash on cannons
    if (f.muzzle > 0) {
      _p.color = const Color(0xFFFFE08A).withValues(alpha: f.muzzle);
      canvas.drawCircle(Offset(cx + dir * 6, cy - 12), 2.4, _p);
      canvas.drawCircle(Offset(cx + dir * 6, cy + 12), 2.4, _p);
    }
  }

  void _drawTie(Canvas canvas, _Fighter f) {
    final cx = f.x, cy = f.y;
    final dir = f.vx >= 0 ? 1 : -1;
    // Twin hexagonal solar panels
    _p
      ..color = const Color(0xFF1E1E22)
      ..style = PaintingStyle.fill;
    final panel = (double pyCenter) {
      final path = Path()
        ..moveTo(cx, pyCenter)
        ..lineTo(cx + 7, pyCenter - 11)
        ..lineTo(cx + 7, pyCenter + 11)
        ..close();
      final p2 = Path()
        ..moveTo(cx, pyCenter)
        ..lineTo(cx - 7, pyCenter - 11)
        ..lineTo(cx - 7, pyCenter + 11)
        ..close();
      canvas.drawPath(path, _p);
      canvas.drawPath(p2, _p);
    };
    panel(cy - 11);
    panel(cy + 11);
    // Panel outlines
    _p
      ..color = const Color(0xFF55606A)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(cx - 7, cy - 22, 14, 22), _p);
    canvas.drawRect(Rect.fromLTWH(cx - 7, cy, 14, 22), _p);
    canvas.drawLine(Offset(cx - 7, cy), Offset(cx + 7, cy), _p);
    // Center cockpit sphere
    _p
      ..color = const Color(0xFF2A2F36)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 6, _p);
    _p.color = const Color(0xFF14181D);
    canvas.drawCircle(Offset(cx, cy), 3.4, _p);
    // Vader-red gun glow
    if (f.muzzle > 0) {
      _p.color = const Color(0xFF3FB8FF).withValues(alpha: f.muzzle);
      canvas.drawCircle(Offset(cx + dir * 6, cy), 2.6, _p);
    }
  }

  void _drawBolts(Canvas canvas) {
    for (final b in world.bolts) {
      _glow
        ..shader = RadialGradient(
          colors: [b.color.withValues(alpha: 0.55), b.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(b.x, b.y), radius: 10))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(b.x, b.y), 10, _glow);
      _glow
        ..shader = null
        ..blendMode = BlendMode.srcOver;
      // motion-blur trail
      final tailLen = 14.0;
      final speed = sqrt(b.vx * b.vx + b.vy * b.vy).clamp(1, double.infinity);
      final tx = b.x - b.vx / speed * tailLen;
      final ty = b.y - b.vy / speed * tailLen;
      _p
        ..color = b.color.withValues(alpha: 0.55)
        ..strokeWidth = 3.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(tx, ty), Offset(b.x, b.y), _p);
      _p
        ..color = Colors.white
        ..strokeWidth = 1.4;
      canvas.drawLine(Offset(tx, ty), Offset(b.x, b.y), _p);
      _p.style = PaintingStyle.fill;
    }
  }

  void _drawSky(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    // Multi-stop atmospheric gradient — deep space top → magenta/violet
    // upper atmosphere → amber horizon haze → city-glow base.
    _p
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF03060E), // outer space
          Color(0xFF0A1530), // upper sky
          Color(0xFF2A1A48), // violet band
          Color(0xFF7B3A2E), // dusk amber
          Color(0xFFE2A45A), // horizon glow
          Color(0xFF1A1108), // smog floor
        ],
        stops: [0.0, 0.22, 0.42, 0.58, 0.72, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, _p);
    _p.shader = null;

    // Soft purple nebula clouds in upper sky
    for (var i = 0; i < 4; i++) {
      final cx = (i * 211 + 80) % s.width.toInt() * 1.0;
      final cy = s.height * (0.08 + (i % 2) * 0.07);
      final rad = 220.0 + (i * 47) % 90;
      _glow
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFB259FF).withValues(alpha: 0.12),
            const Color(0xFF3A1A6B).withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: rad))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(cx, cy), rad, _glow);
    }
    _glow..shader = null..blendMode = BlendMode.srcOver;

    // Distant planet — large ringed gas giant top-left
    final planetC = Offset(s.width * 0.18, s.height * 0.16);
    const planetR = 46.0;
    // halo
    _glow
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFCDA0).withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: planetC, radius: planetR * 1.9))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(planetC, planetR * 1.9, _glow);
    _glow..shader = null..blendMode = BlendMode.srcOver;
    // body
    _p
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: const [
          Color(0xFFFFE5BC),
          Color(0xFFD89762),
          Color(0xFF6B3F22),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: planetC, radius: planetR))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(planetC, planetR, _p);
    _p.shader = null;
    // bands
    _p
      ..color = const Color(0xFF8A5530).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: planetC, radius: planetR)));
    for (var i = -3; i <= 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(planetC.dx - planetR, planetC.dy + i * 10.0, planetR * 2, 3.5),
        _p,
      );
    }
    canvas.restore();
    // ring
    _p
      ..color = const Color(0xFFEFC79B).withValues(alpha: 0.55)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawOval(
      Rect.fromCenter(center: planetC, width: planetR * 3.2, height: planetR * 0.7),
      _p,
    );
    _p
      ..color = const Color(0xFF8A5530).withValues(alpha: 0.35)
      ..strokeWidth = 4.0;
    canvas.drawOval(
      Rect.fromCenter(center: planetC, width: planetR * 3.6, height: planetR * 0.9),
      _p,
    );
    _p.style = PaintingStyle.fill;

    // Small moon
    final moonC = Offset(s.width * 0.32, s.height * 0.10);
    _glow
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: 0.5),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: moonC, radius: 24))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(moonC, 24, _glow);
    _glow..shader = null..blendMode = BlendMode.srcOver..color = const Color(0xFFE8E2D6);
    canvas.drawCircle(moonC, 8, _glow);

    // Stars — twinkle + size variation
    for (final st in world.stars) {
      final a = (sin(st.twinkle) * 0.4 + 0.6).clamp(0.0, 1.0);
      _p.color = const Color(0xFFE8F1FF).withValues(alpha: a * 0.7);
      canvas.drawCircle(Offset(st.x, st.y * 0.55), st.r * 1.1, _p);
      // Cross-flare on brighter stars
      if (st.r > 1.2) {
        _p
          ..color = const Color(0xFFCDE7FF).withValues(alpha: a * 0.4)
          ..strokeWidth = 0.6
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(st.x - 3, st.y * 0.55),
          Offset(st.x + 3, st.y * 0.55),
          _p,
        );
        canvas.drawLine(
          Offset(st.x, st.y * 0.55 - 3),
          Offset(st.x, st.y * 0.55 + 3),
          _p,
        );
        _p.style = PaintingStyle.fill;
      }
    }
  }

  // ====================================================================
  // ICONIC STAR WARS SET-PIECES — Death Star, Star Destroyer, Falcon
  // ====================================================================

  void _drawDeathStar(Canvas canvas, Size s) {
    // Top-right of the sky, fairly large but desaturated/distant.
    final c = Offset(s.width * 0.82, s.height * 0.16);
    const r = 56.0;

    // Outer halo
    _glow
      ..shader = RadialGradient(colors: [
        const Color(0xFFB8C2CC).withValues(alpha: 0.35),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: c, radius: r * 2.0))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(c, r * 2.0, _glow);
    _glow..shader = null..blendMode = BlendMode.srcOver;

    // Body — radial light from upper-left, dark on the bottom-right.
    _p
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: const [
          Color(0xFFCED4DA),
          Color(0xFF6B7480),
          Color(0xFF1E2228),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r, _p);
    _p.shader = null;

    // Equatorial trench
    _p
      ..color = const Color(0xFF1A1D22)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(c.dx - r + 4, c.dy + 2), Offset(c.dx + r - 4, c.dy + 2), _p);

    // Surface lat lines
    _p
      ..color = const Color(0xFF2A3038).withValues(alpha: 0.45)
      ..strokeWidth = 0.6;
    for (var i = -3; i <= 3; i++) {
      if (i == 0) continue;
      final y = c.dy + i * 11.0;
      final dx = sqrt((r * r - (i * 11.0).abs() * (i * 11.0).abs()).clamp(0.0, r * r));
      canvas.drawLine(Offset(c.dx - dx, y), Offset(c.dx + dx, y), _p);
    }
    _p.style = PaintingStyle.fill;

    // Superlaser dish — upper-left concave circle
    final dishC = Offset(c.dx - r * 0.42, c.dy - r * 0.42);
    const dishR = 13.0;
    _p
      ..shader = RadialGradient(colors: const [
        Color(0xFF8E96A0),
        Color(0xFF2C3138),
      ]).createShader(Rect.fromCircle(center: dishC, radius: dishR))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dishC, dishR, _p);
    _p.shader = null;
    _p
      ..color = const Color(0xFF12161B)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(dishC, dishR, _p);
    _p.style = PaintingStyle.fill;
    // Dish inner crosshair
    _p
      ..color = const Color(0xFF12161B)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(dishC.dx - dishR, dishC.dy), Offset(dishC.dx + dishR, dishC.dy), _p);
    canvas.drawLine(Offset(dishC.dx, dishC.dy - dishR), Offset(dishC.dx, dishC.dy + dishR), _p);
    _p.style = PaintingStyle.fill;

    // Outline
    _p
      ..color = const Color(0xFF12161B)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r, _p);
    _p.style = PaintingStyle.fill;
  }

  void _drawStarDestroyer(Canvas canvas, Size s) {
    // Massive triangular wedge slowly drifting in the mid-sky band.
    final x = world.destroyerX;
    final y = s.height * 0.30;
    final len = 280.0;
    final wid = 70.0;

    // Distant atmospheric haze
    _glow
      ..shader = RadialGradient(colors: [
        const Color(0xFF8FA2B8).withValues(alpha: 0.18),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(x + len * 0.4, y), radius: 220))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(x + len * 0.4, y), 220, _glow);
    _glow..shader = null..blendMode = BlendMode.srcOver;

    // Hull — long pointed wedge, point facing left.
    _p
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFBFC6CD),
          Color(0xFF6E7882),
          Color(0xFF313840),
        ],
      ).createShader(Rect.fromLTWH(x, y - wid * 0.5, len, wid))
      ..style = PaintingStyle.fill;
    final hull = Path()
      ..moveTo(x, y)
      ..lineTo(x + len * 0.42, y - wid * 0.42)
      ..lineTo(x + len, y - wid * 0.18)
      ..lineTo(x + len, y + wid * 0.32)
      ..lineTo(x + len * 0.42, y + wid * 0.50)
      ..close();
    canvas.drawPath(hull, _p);
    _p.shader = null;

    // Top superstructure — small command tower stack near the rear.
    _p.color = const Color(0xFF8A949E);
    canvas.drawRect(Rect.fromLTWH(x + len * 0.78, y - wid * 0.62, 22, 8), _p);
    canvas.drawRect(Rect.fromLTWH(x + len * 0.82, y - wid * 0.78, 14, 8), _p);
    // Bridge windows (cool blue specks)
    _p.color = const Color(0xFF7FD3FF).withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(x + len * 0.82, y - wid * 0.76, 12, 1.2), _p);

    // Hull window strips along the bottom — long row of dotted lights.
    _p.color = const Color(0xFFFFC56A).withValues(alpha: 0.6);
    for (var i = 0; i < 22; i++) {
      final wx = x + len * 0.45 + i * 7.5;
      if (wx > x + len - 6) break;
      canvas.drawRect(Rect.fromLTWH(wx, y + wid * 0.20, 1.4, 1.1), _p);
    }

    // Engine glow at the rear (3 huge thrusters)
    for (var i = -1; i <= 1; i++) {
      _glow
        ..shader = RadialGradient(colors: [
          const Color(0xFF7FD3FF).withValues(alpha: 0.8),
          const Color(0xFF26F0F0).withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: Offset(x + len + 2, y + i * 8.0), radius: 10))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(x + len + 2, y + i * 8.0), 10, _glow);
    }
    _glow..shader = null..blendMode = BlendMode.srcOver;

    // Dark outline
    _p
      ..color = const Color(0xFF14181E)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(hull, _p);
    _p.style = PaintingStyle.fill;

    // TIE fighter escort dots near the destroyer
    _p.color = const Color(0xFF2A2F36);
    for (var i = 0; i < 5; i++) {
      final tx = x + len * 0.3 + i * 36.0 + sin(world.t * 0.4 + i) * 5;
      final ty = y - 22 - (i % 2) * 6;
      canvas.drawCircle(Offset(tx, ty), 1.6, _p);
    }
  }

  void _drawFalcon(Canvas canvas, Size s) {
    final x = world.falconX;
    final y = world.falconY;
    if (x < -150 || x > s.width + 200) return;

    // Engine thrust glow (rear is left side since it flies right)
    _glow
      ..shader = RadialGradient(colors: [
        const Color(0xFF7FD3FF).withValues(alpha: 0.85),
        const Color(0xFF26F0F0).withValues(alpha: 0.0),
      ]).createShader(Rect.fromCircle(center: Offset(x - 22, y), radius: 18))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(x - 22, y), 18, _glow);
    _glow..shader = null..blendMode = BlendMode.srcOver;

    // Main saucer disk
    _p
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFC8CED5),
          Color(0xFF7B848D),
          Color(0xFF3A4047),
        ],
      ).createShader(Rect.fromLTWH(x - 28, y - 8, 56, 16))
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(x - 28, y - 7, 56, 14), _p);
    _p.shader = null;

    // Forward mandibles (the iconic Y prongs facing right)
    _p.color = const Color(0xFFA3ABB3);
    canvas.drawRect(Rect.fromLTWH(x + 16, y - 5, 18, 2.2), _p);
    canvas.drawRect(Rect.fromLTWH(x + 16, y + 3, 18, 2.2), _p);
    // Tip of mandibles
    _p.color = const Color(0xFF5C6168);
    canvas.drawRect(Rect.fromLTWH(x + 32, y - 5.5, 3, 3.0), _p);
    canvas.drawRect(Rect.fromLTWH(x + 32, y + 2.5, 3, 3.0), _p);

    // Cockpit pod (off-center to starboard / front-right)
    _p.color = const Color(0xFF4B5158);
    canvas.drawRect(Rect.fromLTWH(x + 8, y + 4, 8, 3.2), _p);
    _p.color = const Color(0xFF7FD3FF).withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTWH(x + 9, y + 4.6, 6, 1.6), _p);

    // Top dish (sensor rectenna)
    _p.color = const Color(0xFFA3ABB3);
    canvas.drawRect(Rect.fromLTWH(x - 12, y - 9, 6, 1.6), _p);
    canvas.drawCircle(Offset(x - 9, y - 11), 2.4, _p);

    // Lower hull shadow
    _p.color = const Color(0xFF14181E).withValues(alpha: 0.65);
    canvas.drawOval(Rect.fromLTWH(x - 26, y + 1, 52, 7), _p);

    // Quad-engine glow strip on the rear edge
    _p.color = const Color(0xFF26F0F0).withValues(alpha: 0.9);
    canvas.drawRect(Rect.fromLTWH(x - 30, y - 1.2, 4, 2.4), _p);
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
    final light = Color.lerp(_stoneLight, _stoneMid, 1.0 - depth)!;

    // Stepped silhouette — narrow setbacks at intervals like a Coruscant
    // arcology tower instead of a featureless slab.
    final rng = Random(b.windowSeed);
    final segments = 2 + rng.nextInt(3); // 2..4 setbacks
    var segTop = top;
    var segX = b.x;
    var segW = b.width;
    final segs = <Rect>[];
    for (var i = 0; i < segments; i++) {
      final segH = (b.height - (segTop - top)) * (i == segments - 1 ? 1.0 : (0.35 + rng.nextDouble() * 0.25));
      final r = Rect.fromLTWH(segX, segTop, segW, segH);
      segs.add(r);
      // Inset for next segment
      final inset = 4 + rng.nextDouble() * (segW * 0.18);
      segX += inset / 2;
      segW -= inset;
      segTop += segH;
      if (segW < 8) break;
    }

    // Body fill (deep) with vertical gradient
    _p
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [mid, dark],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    for (final r in segs) {
      canvas.drawRect(r, _p);
    }
    _p.shader = null;

    // Edge highlights (sun-side rim warm, shadow-side cool)
    _p.color = _rimOrange.withValues(alpha: 0.55 * depth);
    for (final r in segs) {
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, 1.6, r.height), _p);
    }
    _p.color = _sabreBlue.withValues(alpha: 0.22 * depth);
    for (final r in segs) {
      canvas.drawRect(Rect.fromLTWH(r.right - 1.6, r.top, 1.6, r.height), _p);
    }

    // Window grid — rows of lit cells. Some on, some off.
    final winCols = ((b.width - 6) / 5).floor().clamp(2, 8);
    final colW = (b.width - 6) / winCols;
    final winRng = Random(b.windowSeed * 17 + 3);
    for (final r in segs) {
      final winRows = (r.height / 7).floor().clamp(2, 30);
      for (var row = 0; row < winRows; row++) {
        for (var col = 0; col < winCols; col++) {
          final wx = r.left + 3 + col * colW;
          final wy = r.top + 4 + row * 7;
          final on = winRng.nextDouble();
          if (on < 0.55) {
            // unlit — dim recess
            _p.color = const Color(0xFF050709).withValues(alpha: 0.6 * depth);
            canvas.drawRect(Rect.fromLTWH(wx, wy, colW - 2, 3.4), _p);
          } else {
            // lit — warm or cyan
            final warm = on > 0.78;
            final c = warm ? const Color(0xFFFFC56A) : const Color(0xFF7FD3FF);
            _p.color = c.withValues(alpha: (0.55 + (on - 0.55) * 0.9) * depth);
            canvas.drawRect(Rect.fromLTWH(wx, wy, colW - 2, 3.4), _p);
            // soft bloom on the brightest windows
            if (on > 0.86 && depth > 0.6) {
              _glow
                ..shader = RadialGradient(colors: [
                  c.withValues(alpha: 0.5 * depth),
                  c.withValues(alpha: 0.0),
                ]).createShader(Rect.fromCircle(
                  center: Offset(wx + colW / 2, wy + 1.7),
                  radius: 7,
                ))
                ..blendMode = BlendMode.plus;
              canvas.drawCircle(Offset(wx + colW / 2, wy + 1.7), 7, _glow);
              _glow..shader = null..blendMode = BlendMode.srcOver;
            }
          }
        }
      }
    }

    // Mechanical seam down the middle of base segment
    _p.color = const Color(0xFF0B0F13).withValues(alpha: 0.5 * depth);
    canvas.drawRect(Rect.fromLTWH(cx - 0.8, top + 8, 1.6, b.height - 16), _p);

    // Crown / roof structure variations
    final capH = 10 + (b.roofKind * 4).toDouble();
    final topRect = segs.last;
    _p.color = light.withValues(alpha: 0.9);
    switch (b.roofKind % 4) {
      case 0:
        // Trapezoidal cap
        final cap = Path()
          ..moveTo(topRect.left - 4, topRect.top)
          ..lineTo(topRect.right + 4, topRect.top)
          ..lineTo(topRect.right, topRect.top - capH)
          ..lineTo(topRect.left, topRect.top - capH)
          ..close();
        canvas.drawPath(cap, _p);
        break;
      case 1:
        // Twin antenna spires
        canvas.drawRect(
          Rect.fromLTWH(topRect.left - 2, topRect.top - 4, topRect.width + 4, 4),
          _p,
        );
        _p.color = const Color(0xFF2A2A2E);
        canvas.drawRect(Rect.fromLTWH(topRect.left + topRect.width * 0.25 - 0.8, topRect.top - capH * 2, 1.6, capH * 2), _p);
        canvas.drawRect(Rect.fromLTWH(topRect.left + topRect.width * 0.75 - 0.8, topRect.top - capH * 1.4, 1.6, capH * 1.4), _p);
        // red aircraft warning lights
        _p.color = const Color(0xFFFF3148).withValues(alpha: 0.6 + 0.4 * sin(world.t * 3 + b.windowSeed));
        canvas.drawCircle(Offset(topRect.left + topRect.width * 0.25, topRect.top - capH * 2), 1.2, _p);
        canvas.drawCircle(Offset(topRect.left + topRect.width * 0.75, topRect.top - capH * 1.4), 1.2, _p);
        break;
      case 2:
        // Domed observation deck
        canvas.drawArc(
          Rect.fromLTWH(topRect.left, topRect.top - capH, topRect.width, capH * 2),
          pi, pi, false, _p,
        );
        _p.color = const Color(0xFF7FD3FF).withValues(alpha: 0.7 * depth);
        canvas.drawArc(
          Rect.fromLTWH(topRect.left + 2, topRect.top - capH + 1, topRect.width - 4, (capH - 1) * 2),
          pi + 0.4, pi - 0.8, false, _p,
        );
        break;
      case 3:
        // Stepped pyramid cap
        canvas.drawRect(Rect.fromLTWH(topRect.left + 2, topRect.top - capH * 0.5, topRect.width - 4, capH * 0.5), _p);
        canvas.drawRect(Rect.fromLTWH(topRect.left + topRect.width * 0.3, topRect.top - capH, topRect.width * 0.4, capH * 0.5), _p);
        _p.color = const Color(0xFFFF3148).withValues(alpha: 0.7 + 0.3 * sin(world.t * 2));
        canvas.drawCircle(Offset(cx, topRect.top - capH - 1), 1.1, _p);
        break;
    }

    // Soft halo at building base (city ambient bloom)
    if (depth > 0.55) {
      _glow
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFC56A).withValues(alpha: 0.18 * depth),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: Offset(cx, b.baseY), radius: b.width * 1.2))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(cx, b.baseY), b.width * 1.2, _glow);
      _glow..shader = null..blendMode = BlendMode.srcOver;
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

    // Wet reflective duracrete plaza — dark teal -> near-black,
    // with subtle horizontal scanline reflection of horizon glow.
    _p
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2A1A10), // wet horizon reflection (matches dusk amber)
          Color(0xFF14181C),
          Color(0xFF07090C),
          Color(0xFF020304),
        ],
        stops: [0.0, 0.18, 0.55, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, _p);
    _p.shader = null;

    // Perspective grid — vanishing toward center horizon.
    final vp = Offset(s.width * 0.5, groundY - 4);
    _p
      ..color = _sabreBlue.withValues(alpha: 0.18)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    // Radial lines (perspective)
    for (var i = -8; i <= 8; i++) {
      final endX = s.width * 0.5 + i * (s.width * 0.16);
      canvas.drawLine(vp, Offset(endX, s.height + 4), _p);
    }
    // Horizontal scanlines spaced by perspective (denser near horizon)
    for (var i = 1; i <= 14; i++) {
      final t = i / 14.0;
      final y = groundY + pow(t, 2.2).toDouble() * (s.height - groundY) * 1.05;
      if (y > s.height) break;
      final alpha = (0.22 * (1 - t * 0.6)).clamp(0.0, 0.22);
      _p.color = _sabreBlue.withValues(alpha: alpha);
      canvas.drawLine(Offset(0, y), Offset(s.width, y), _p);
    }
    _p.style = PaintingStyle.fill;

    // Wet puddles — orange/blue light reflections smeared along ground.
    final puddleRng = Random(7);
    for (var i = 0; i < 8; i++) {
      final px = puddleRng.nextDouble() * s.width;
      final py = groundY + 8 + puddleRng.nextDouble() * (s.height - groundY - 12);
      final pw = 40 + puddleRng.nextDouble() * 110;
      final ph = 4 + puddleRng.nextDouble() * 6;
      final warm = puddleRng.nextBool();
      final col = warm ? const Color(0xFFFF9A4A) : const Color(0xFF7FD3FF);
      _glow
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            col.withValues(alpha: 0.22),
            col.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(px, py, pw, ph * 4))
        ..blendMode = BlendMode.plus;
      canvas.drawOval(Rect.fromLTWH(px, py, pw, ph), _glow);
      _glow..shader = null..blendMode = BlendMode.srcOver;
    }

    // Landing pad — concentric rings + hazard chevrons at center plaza.
    final c = Offset(s.width * 0.5, s.height * 0.86);
    for (var i = 0; i < 3; i++) {
      _p
        ..color = _rimOrange.withValues(alpha: 0.18 - i * 0.045)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 220 + i * 90.0, height: 38 + i * 16.0),
        _p,
      );
    }
    // Inner pad cross
    _p
      ..color = _rimOrange.withValues(alpha: 0.35)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(c.dx - 60, c.dy), Offset(c.dx + 60, c.dy), _p);
    canvas.drawLine(Offset(c.dx, c.dy - 12), Offset(c.dx, c.dy + 12), _p);
    // Hazard stripes near edge
    _p.style = PaintingStyle.fill;
    _p.color = const Color(0xFFFFC56A).withValues(alpha: 0.35);
    for (var i = 0; i < 10; i++) {
      final ang = (i / 10) * pi * 2;
      final r1 = 95.0;
      final r2 = 102.0;
      canvas.drawLine(
        Offset(c.dx + cos(ang) * r1, c.dy + sin(ang) * r1 * 0.32),
        Offset(c.dx + cos(ang) * r2, c.dy + sin(ang) * r2 * 0.32),
        Paint()
          ..color = const Color(0xFFFFC56A).withValues(alpha: 0.55)
          ..strokeWidth = 2.0,
      );
    }

    // Subtle ground bloom from horizon
    _glow
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFF8B3D).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, groundY, s.width, 28))
      ..blendMode = BlendMode.plus;
    canvas.drawRect(Rect.fromLTWH(0, groundY, s.width, 28), _glow);
    _glow..shader = null..blendMode = BlendMode.srcOver;
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
    _drawCharacterHead(canvas, w, cx, headY, headR);
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

    // HP bar for combatants
    if (w.faction != 'Neutral') {
      final barW = 28 * s;
      final barY = headY - 26;
      _p
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, barY, barW, 3.2),
          const Radius.circular(2),
        ),
        _p,
      );
      final pct = (w.hp / w.maxHp).clamp(0.0, 1.0);
      _p.color = w.faction == 'Rebel'
          ? const Color(0xFF26F0F0)
          : const Color(0xFFFF3158);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, barY, barW * pct, 3.2),
          const Radius.circular(2),
        ),
        _p,
      );
    }

    // Muzzle flash burst
    if (w.muzzleFlash > 0) {
      final mx = cx + w.dir * 11 * s;
      final my = torsoTop + 16 * s;
      _glow
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE08A).withValues(alpha: 0.85 * w.muzzleFlash),
            const Color(0xFFFFE08A).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(mx, my), radius: 14 * s))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(mx, my), 14 * s, _glow);
      _glow
        ..shader = null
        ..blendMode = BlendMode.srcOver;
    }

    // Hit flash white overlay
    if (w.hitFlash > 0) {
      _p
        ..color = Colors.white.withValues(alpha: 0.55 * w.hitFlash)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(cx - 8 * s, headY - headR, cx + 8 * s, feetY),
        _p,
      );
    }

    // Sims-style activity bubble above name
    if (w.action != null && w.action!.isNotEmpty) {
      final bubble = TextPainter(
        text: TextSpan(
          text: w.action!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: 150);
      final bx = (cx - bubble.width / 2 - 8).clamp(4.0, 1e6);
      final by = headY - 26 - bubble.height - 12;
      final rect = Rect.fromLTWH(bx, by, bubble.width + 16, bubble.height + 10);
      _p
        ..color = Colors.black.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        _p,
      );
      _p
        ..color = w.accentColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        _p,
      );
      _p.style = PaintingStyle.fill;
      bubble.paint(canvas, Offset(bx + 8, by + 5));
      // Little tail
      final tail = Path()
        ..moveTo(cx - 3, by + bubble.height + 10)
        ..lineTo(cx + 3, by + bubble.height + 10)
        ..lineTo(cx, by + bubble.height + 16)
        ..close();
      _p.color = Colors.black.withValues(alpha: 0.75);
      canvas.drawPath(tail, _p);
    }
  }

  /// Per-character cosmetic features (helmets, hair, capes) so each
  /// walker actually looks like the Star Wars character they represent.
  void _drawCharacterHead(Canvas canvas, _Walker w, double cx, double headY, double headR) {
    final s = w.scale;
    switch (w.name) {
      case 'VADER':
        // Black helmet dome + flared neck + chest panel
        _p
          ..color = const Color(0xFF050505)
          ..style = PaintingStyle.fill;
        // Helmet (taller dome)
        canvas.drawCircle(Offset(cx, headY - 1), headR + 1.5, _p);
        // Helmet ear-flares
        _p.color = const Color(0xFF1A1A1A);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - headR - 2.5, headY - 0.5, 2.2, 4.5),
            const Radius.circular(1),
          ),
          _p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + headR + 0.3, headY - 0.5, 2.2, 4.5),
            const Radius.circular(1),
          ),
          _p,
        );
        // Triangular eye slits (red glow)
        _p.color = const Color(0xFFFF1A1A);
        canvas.drawRect(Rect.fromLTWH(cx - 2.6, headY - 1, 1.8, 1.2), _p);
        canvas.drawRect(Rect.fromLTWH(cx + 0.8, headY - 1, 1.8, 1.2), _p);
        // Chest control box (red + green LEDs)
        final boxTop = headY + headR + 6 * s;
        _p.color = const Color(0xFF1A1A1A);
        canvas.drawRect(Rect.fromLTWH(cx - 4 * s, boxTop, 8 * s, 4 * s), _p);
        _p.color = const Color(0xFFFF3158);
        canvas.drawCircle(Offset(cx - 2 * s, boxTop + 2 * s), 0.8, _p);
        _p.color = const Color(0xFF26F0F0);
        canvas.drawCircle(Offset(cx + 1.5 * s, boxTop + 2 * s), 0.7, _p);
        // Long cape
        _p.color = const Color(0xFF050505);
        final cape = Path()
          ..moveTo(cx - headR, headY + headR)
          ..lineTo(cx + headR, headY + headR)
          ..lineTo(cx + 11 * s, headY + 38 * s)
          ..lineTo(cx - 11 * s, headY + 38 * s)
          ..close();
        canvas.drawPath(cape, _p);
        break;

      case 'BOBA':
        // Mandalorian helmet — green w/ T-visor
        _p
          ..color = const Color(0xFF4A6B3A)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, headY), headR + 1, _p);
        // Dent stripes
        _p.color = const Color(0xFF7A2A1F);
        canvas.drawRect(Rect.fromLTWH(cx - 1, headY - headR + 0.5, 2, 1.5), _p);
        // T-visor
        _p.color = const Color(0xFF080808);
        final visor = Path()
          ..moveTo(cx - headR + 0.6, headY - 0.5)
          ..lineTo(cx + headR - 0.6, headY - 0.5)
          ..lineTo(cx + headR - 0.6, headY + 0.6)
          ..lineTo(cx + 0.9, headY + 0.6)
          ..lineTo(cx + 0.9, headY + 2.4)
          ..lineTo(cx - 0.9, headY + 2.4)
          ..lineTo(cx - 0.9, headY + 0.6)
          ..lineTo(cx - headR + 0.6, headY + 0.6)
          ..close();
        canvas.drawPath(visor, _p);
        // Range-finder antenna
        _p.color = const Color(0xFF202020);
        canvas.drawRect(Rect.fromLTWH(cx + headR - 0.5, headY - headR - 3, 1.0, 4.0), _p);
        // Jetpack on back
        _p.color = const Color(0xFF2C3835);
        final jpY = headY + headR + 2;
        canvas.drawRect(Rect.fromLTWH(cx - 4 * s, jpY, 8 * s, 12 * s), _p);
        _p.color = const Color(0xFFFF8A4C);
        canvas.drawCircle(Offset(cx - 2.2 * s, jpY + 12 * s), 1.4, _p);
        canvas.drawCircle(Offset(cx + 2.2 * s, jpY + 12 * s), 1.4, _p);
        break;

      case 'LEIA':
        // Iconic side-bun hair
        _p
          ..color = const Color(0xFF3A2418)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx - headR - 0.6, headY + 0.5), 2.6, _p);
        canvas.drawCircle(Offset(cx + headR + 0.6, headY + 0.5), 2.6, _p);
        // Hair top
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, headY), radius: headR + 0.5),
          pi, pi, true, _p,
        );
        // White senatorial robe
        _p.color = const Color(0xFFEFEFEF);
        final robe = Path()
          ..moveTo(cx - 6 * s, headY + headR + 1)
          ..lineTo(cx + 6 * s, headY + headR + 1)
          ..lineTo(cx + 9 * s, headY + 30 * s)
          ..lineTo(cx - 9 * s, headY + 30 * s)
          ..close();
        canvas.drawPath(robe, _p);
        break;

      case 'HAN':
        // Brown wavy hair
        _p
          ..color = const Color(0xFF3A2014)
          ..style = PaintingStyle.fill;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, headY - 0.5), radius: headR + 0.8),
          pi, pi, true, _p,
        );
        // Cocky smirk hint
        _p.color = const Color(0xFFE0B796);
        canvas.drawCircle(Offset(cx, headY + 0.3), headR - 0.4, _p);
        _p.color = const Color(0xFF202020);
        canvas.drawCircle(Offset(cx - 1.4, headY - 0.2), 0.5, _p);
        canvas.drawCircle(Offset(cx + 1.4, headY - 0.2), 0.5, _p);
        // Blue Rebel jacket (vest stripe)
        _p.color = const Color(0xFF1E2A38);
        canvas.drawRect(
          Rect.fromLTWH(cx - 5 * s, headY + headR + 0.5, 10 * s, 8 * s),
          _p,
        );
        // Yellow Corellian bloodstripe on pants
        _p.color = const Color(0xFFFFD46B);
        canvas.drawRect(Rect.fromLTWH(cx - 0.5, headY + 22 * s, 1.0, 12 * s), _p);
        // Blaster holster
        _p.color = const Color(0xFF0E0E10);
        canvas.drawCircle(Offset(cx + (w.dir > 0 ? 6 * s : -6 * s), headY + 18 * s), 2.2, _p);
        break;

      case 'CAL':
        // Tousled red-brown hair
        _p
          ..color = const Color(0xFF6A2A1A)
          ..style = PaintingStyle.fill;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, headY - 1), radius: headR + 0.6),
          pi + 0.3, pi - 0.6, true, _p,
        );
        // Face tone
        _p.color = const Color(0xFFE7BC9B);
        canvas.drawCircle(Offset(cx, headY + 0.4), headR - 0.5, _p);
        _p.color = const Color(0xFF1A1A1A);
        canvas.drawCircle(Offset(cx - 1.4, headY - 0.2), 0.5, _p);
        canvas.drawCircle(Offset(cx + 1.4, headY - 0.2), 0.5, _p);
        // Jedi poncho (orange-brown)
        _p.color = const Color(0xFF7A4B2A);
        final pcho = Path()
          ..moveTo(cx - 8 * s, headY + headR + 1)
          ..lineTo(cx + 8 * s, headY + headR + 1)
          ..lineTo(cx + 11 * s, headY + 28 * s)
          ..lineTo(cx - 11 * s, headY + 28 * s)
          ..close();
        canvas.drawPath(pcho, _p);
        // BD-1 droid on shoulder (cyan eye + white body)
        final bdX = cx - (w.dir > 0 ? 6 * s : -6 * s);
        final bdY = headY + 2;
        _p.color = const Color(0xFFE8E8E8);
        canvas.drawCircle(Offset(bdX, bdY), 2.4, _p);
        _p.color = const Color(0xFF26F0F0);
        canvas.drawCircle(Offset(bdX, bdY - 0.5), 0.9, _p);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BoganoPainter old) => true;
}
