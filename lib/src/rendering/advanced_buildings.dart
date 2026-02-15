import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;
import 'star_wars_effects.dart';

/// Professional-grade 3D building renderer with API-driven customization
class AdvancedBuildingRenderer {
  static final Map<String, Map<String, dynamic>> _buildingCache = {};

  /// Get building properties based on location (using hardcoded API data)
  static Map<String, dynamic> getBuildingProperties(String locationId) {
    if (_buildingCache.containsKey(locationId)) {
      return _buildingCache[locationId]!;
    }

    // Planet-specific properties from Star Wars API data
    final Map<String, Map<String, dynamic>> apiData = {
      'tatooine_cantina': {
        'climate': 'arid',
        'terrain': 'desert',
        'atmosphere': 'breathable',
        'gravity': '1.0',
        'population': '200000',
        'diameter': '10465',
        'weather_factor': 1.3, // Extra weathering for harsh desert
      },
      'hoth_base': {
        'climate': 'frozen',
        'terrain': 'ice caves, mountain ranges',
        'atmosphere': 'breathable',
        'gravity': '1.1',
        'population': 'unknown',
        'diameter': '7200',
        'ice_factor': 1.5, // Enhanced crystalline features
      },
      'dagobah_swamp': {
        'climate': 'murky',
        'terrain': 'swamp, jungles',
        'atmosphere': 'breathable',
        'gravity': '0.9',
        'population': 'unknown',
        'diameter': '8900',
        'organic_factor': 1.4, // More vines and moss
      },
      'cloud_city': {
        'climate': 'temperate',
        'terrain': 'gas giant',
        'atmosphere': 'breathable',
        'gravity': '1.5',
        'population': '6000000',
        'diameter': '118000',
        'tech_level': 2.0, // Advanced technology
      },
      'jedi_temple': {
        'climate': 'temperate',
        'terrain': 'cityscape, mountains',
        'atmosphere': 'breathable',
        'gravity': '1.0',
        'population': '1000000000000',
        'diameter': '12240',
        'urban_density': 3.0, // Coruscant mega-city
      },
      'naboo_palace': {
        'climate': 'temperate',
        'terrain': 'grassy hills, swamps, forests, mountains',
        'atmosphere': 'breathable',
        'gravity': '1.0',
        'population': '4500000000',
        'diameter': '12120',
        'elegance_factor': 1.8, // Royal architecture
      },
      'endor_forest': {
        'climate': 'temperate',
        'terrain': 'forests, mountains, lakes',
        'atmosphere': 'breathable',
        'gravity': '0.85',
        'population': '30000000',
        'diameter': '4900',
        'natural_integration': 1.6, // Forest camouflage
      },
      'death_star': {
        'climate': 'artificial',
        'terrain': 'space station',
        'atmosphere': 'artificial',
        'gravity': '1.0',
        'population': '1000000',
        'diameter': '120000',
        'imperial_design': 2.5, // Massive scale
      },
    };

    _buildingCache[locationId] =
        apiData[locationId] ??
        {
          'climate': 'temperate',
          'terrain': 'unknown',
          'atmosphere': 'breathable',
          'gravity': '1.0',
          'population': '0',
          'diameter': 'unknown',
        };

    return _buildingCache[locationId]!;
  }

  /// Draw detailed Star Wars themed building
  static void drawBuilding({
    required Canvas canvas,
    required vm.Vector3 position,
    required String locationId,
    required Function(vm.Vector3) worldToScreen,
  }) {
    switch (locationId) {
      case 'tatooine_cantina':
        _drawCantina(canvas, position, worldToScreen);
        break;
      case 'jedi_temple':
        _drawJediTemple(canvas, position, worldToScreen);
        break;
      case 'cloud_city':
        _drawCloudCity(canvas, position, worldToScreen);
        break;
      case 'dagobah_swamp':
        _drawDagobahHut(canvas, position, worldToScreen);
        break;
      case 'death_star':
        _drawDeathStar(canvas, position, worldToScreen);
        break;
      case 'endor_forest':
        _drawEndorBase(canvas, position, worldToScreen);
        break;
      case 'hoth_base':
        _drawHothBase(canvas, position, worldToScreen);
        break;
      case 'naboo_palace':
        _drawNabooPalace(canvas, position, worldToScreen);
        break;
      default:
        _drawGenericBuilding(canvas, position, worldToScreen, Colors.grey);
    }
  }

  /// Mos Eisley Cantina - API-enhanced desert adobe style
  static void _drawCantina(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    // Get planet properties from API
    final props = getBuildingProperties('tatooine_cantina');
    final isArid = props['climate'].toString().contains('arid');
    final isDesert = props['terrain'].toString().contains('desert');
    final weatherFactor = props['weather_factor'] as double? ?? 1.0;

    // Adapt colors based on climate
    final baseColor =
        isArid
            ? const Color(0xFFD4A574) // Sandy beige
            : const Color(0xFFC19A6B); // Dusty tan

    final width = 100.0;
    final height = isDesert ? 75.0 : 80.0; // Lower buildings in harsh desert

    // Main building body with climate-adapted shading
    _drawIsometricBox(canvas, pos, width, height, width * 0.9, baseColor, w2s);

    // Adobe-style rounded corners and walls
    final cornerRadius = 15.0;
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final cornerX = pos.x + math.cos(angle) * (width / 2 - cornerRadius);
      final cornerZ = pos.z + math.sin(angle) * (width * 0.45 - cornerRadius);
      final cornerPos = vm.Vector3(cornerX, pos.y + height / 2, cornerZ);
      _drawCylinder(
        canvas,
        cornerPos,
        cornerRadius,
        height,
        baseColor.withValues(alpha: 0.9),
        w2s,
      );
    }

    // Secondary dome structure
    _drawDome(
      canvas,
      vm.Vector3(pos.x - 30, pos.y, pos.z),
      width * 0.35,
      height * 0.8,
      baseColor.withValues(alpha: 0.85),
      w2s,
    );

    // Star Wars movie set: Energy shield shimmer
    StarWarsEffects.drawEnergyShield(canvas, pos, width, height, w2s);

    // Enhanced weathering for arid climates
    final random = math.Random(42);
    final weatherCount = (20 * weatherFactor).toInt(); // API-driven weathering

    for (int i = 0; i < weatherCount; i++) {
      final x = random.nextDouble() * width - width / 2;
      final y = random.nextDouble() * height;
      final z = random.nextDouble() * width * 0.9 - width * 0.45;
      final weatherPos = vm.Vector3(pos.x + x, pos.y + y, pos.z + z);
      final weatherScreen = w2s(weatherPos);

      // Sand erosion patterns
      final size = random.nextDouble() * 3 + 0.5;
      final opacity = random.nextDouble() * 0.3 + 0.1;

      canvas.drawCircle(
        weatherScreen,
        size,
        Paint()
          ..color = Colors.brown.shade800.withValues(alpha: opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.5),
      );
    }

    // Dome on top
    _drawDome(
      canvas,
      pos,
      width * 0.4,
      height,
      baseColor.withValues(alpha: 0.8),
      w2s,
    );

    // Entrance archway with depth
    final doorPos = vm.Vector3(pos.x, pos.y + 5, pos.z + width / 2);
    _drawArchway(canvas, doorPos, 20, 35, Colors.black87, w2s);

    // Door frame detail
    _drawArchway(
      canvas,
      doorPos,
      22,
      37,
      baseColor.withValues(alpha: 0.9),
      w2s,
    );

    // Windows with enhanced glow and depth
    for (int i = -1; i <= 1; i++) {
      final windowPos = vm.Vector3(
        pos.x + i * 25,
        pos.y + 40,
        pos.z + width / 2,
      );

      // Window recess (shadow)
      _drawGlowingWindow(
        canvas,
        windowPos,
        15,
        21,
        Colors.black.withValues(alpha: 0.6),
        w2s,
      );

      // Window frame
      _drawGlowingWindow(
        canvas,
        windowPos,
        14,
        20,
        baseColor.withValues(alpha: 0.8),
        w2s,
      );

      // Window glow (brighter)
      final glowPaint =
          Paint()
            ..color = Colors.orange.shade300
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final windowScreen = w2s(windowPos);
      canvas.drawRect(
        Rect.fromCenter(center: windowScreen, width: 12, height: 18),
        glowPaint,
      );

      // Window glass
      _drawGlowingWindow(
        canvas,
        windowPos,
        12,
        18,
        Colors.orange.shade400,
        w2s,
      );
    }

    // Roof ventilation and antenna arrays
    for (int i = 0; i < 3; i++) {
      final ventPos = vm.Vector3(
        pos.x + (i - 1) * 20,
        pos.y + height + 10,
        pos.z,
      );
      _drawIsometricBox(
        canvas,
        ventPos,
        8,
        6,
        8,
        baseColor.withValues(alpha: 0.6),
        w2s,
      );
    }

    // Communication antenna array
    final antennaPos = vm.Vector3(pos.x + 35, pos.y + height + 5, pos.z - 30);
    _drawCylinder(canvas, antennaPos, 3, 25, const Color(0xFF888888), w2s);
    _drawSphere(
      canvas,
      vm.Vector3(antennaPos.x, antennaPos.y + 25, antennaPos.z),
      6,
      const Color(0xFF666666),
      w2s,
    );

    // Sensor dish
    final dishBasePos = vm.Vector3(pos.x - 40, pos.y + height, pos.z + 20);
    _drawCylinder(canvas, dishBasePos, 2, 15, const Color(0xFF777777), w2s);
    final dishTop = vm.Vector3(
      dishBasePos.x,
      dishBasePos.y + 15,
      dishBasePos.z,
    );
    _drawSphere(canvas, dishTop, 8, const Color(0xFF555555), w2s);
  }

  /// Jedi Temple - Towering spires
  /// Jedi Temple - API-enhanced Coruscant cityscape monument
  static void _drawJediTemple(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    // Get planet properties from API
    final props = getBuildingProperties('jedi_temple');
    final urbanDensity = props['urban_density'] as double? ?? 1.0;
    final population = props['population'].toString();
    final isMassive = population.contains('trillion') || population.length > 10;

    final baseColor = const Color(0xFF4169E1);

    // Scale up for mega-city density
    final scale = isMassive ? 1.2 : 1.0;
    final baseSize = 120.0 * scale;
    final baseHeight = 140.0 * scale;

    // Main temple base with sophisticated stepped pyramid (ziggurat design)
    final stepCount = 5;
    for (int i = 0; i < stepCount; i++) {
      final stepSize = baseSize - (i * 20);
      final stepY = pos.y + (i * 25);
      final tierColor = Color.lerp(baseColor, Colors.white, i * 0.05)!;
      _drawIsometricBox(
        canvas,
        vm.Vector3(pos.x, stepY, pos.z),
        stepSize,
        25,
        stepSize,
        tierColor,
        w2s,
      );

      // Meditation balconies on each tier
      if (i > 0 && i < stepCount - 1) {
        for (int j = 0; j < 4; j++) {
          final balconyAngle = j * math.pi / 2;
          final balconyX = pos.x + math.cos(balconyAngle) * (stepSize / 2 + 8);
          final balconyZ = pos.z + math.sin(balconyAngle) * (stepSize / 2 + 8);
          _drawIsometricBox(
            canvas,
            vm.Vector3(balconyX, stepY + 20, balconyZ),
            15,
            3,
            12,
            tierColor.withValues(alpha: 0.8),
            w2s,
          );
        }
      }
    }

    // Top ceremonial platform
    _drawIsometricBox(
      canvas,
      vm.Vector3(pos.x, pos.y + baseHeight, pos.z),
      40 * scale,
      15 * scale,
      40 * scale,
      Color.lerp(baseColor, Colors.cyan, 0.2)!,
      w2s,
    );

    // Central spire with enhanced detail - taller for urban density
    final spireColor = Color.lerp(baseColor, Colors.cyan, 0.15)!;
    final spireHeight = 200.0 * scale * urbanDensity;
    _drawSpire(canvas, pos, 40 * scale, spireHeight, spireColor, w2s);

    // Spire windows (more for dense cities)
    final windowCount = (5 * urbanDensity).toInt();
    for (int i = 0; i < windowCount; i++) {
      final windowPos = vm.Vector3(
        pos.x + 18 * scale,
        pos.y + 160 * scale + i * 8,
        pos.z,
      );
      _drawGlowingWindow(canvas, windowPos, 4, 6, Colors.cyan.shade200, w2s);
    }

    // Four corner spires with enhanced detail
    for (int x = -1; x <= 1; x += 2) {
      for (int z = -1; z <= 1; z += 2) {
        final spirePos = vm.Vector3(
          pos.x + x * 45,
          pos.y + 140,
          pos.z + z * 45,
        );
        _drawSpire(
          canvas,
          spirePos,
          20,
          80,
          baseColor.withValues(alpha: 0.7),
          w2s,
        );

        // Spire top decorations
        final topPos = vm.Vector3(spirePos.x, spirePos.y + 80, spirePos.z);
        _drawSphere(canvas, topPos, 8, Colors.cyan.shade200, w2s);
      }
    }

    // Grand entrance stairs
    for (int i = 0; i < 5; i++) {
      final stairPos = vm.Vector3(pos.x, pos.y + i * 3, pos.z + 60 + i * 2);
      _drawIsometricBox(
        canvas,
        stairPos,
        80 - i * 5,
        2,
        10,
        baseColor.withValues(alpha: 0.5),
        w2s,
      );
    }

    // Holographic Jedi symbols (movie set style)
    StarWarsEffects.drawHolographicJediSymbols(canvas, pos, w2s);

    // Glowing symbols
    _drawJediSymbols(canvas, pos, w2s);

    // Pillars around temple
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final pillarPos = vm.Vector3(
        pos.x + math.cos(angle) * 70,
        pos.y,
        pos.z + math.sin(angle) * 70,
      );
      _drawIsometricBox(
        canvas,
        pillarPos,
        10,
        100,
        10,
        baseColor.withValues(alpha: 0.6),
        w2s,
      );
    }
  }

  /// Cloud City - Floating platform
  /// Cloud City - API-enhanced floating mining colony
  static void _drawCloudCity(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    // Get planet properties from API
    final props = getBuildingProperties('cloud_city');
    final techLevel = props['tech_level'] as double? ?? 1.0;
    final gravity = double.tryParse(props['gravity'].toString()) ?? 1.0;
    final highGravity = gravity > 1.2;

    final baseColor = const Color(0xFFFFD700);

    // Main cylindrical tower - reinforced structure for high gravity
    final towerHeight = highGravity ? 140.0 : 160.0; // Shorter in high gravity
    _drawCylinder(canvas, pos, 50, towerHeight, baseColor, w2s);

    // External ribbing and structural supports
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final ribX = pos.x + math.cos(angle) * 52;
      final ribZ = pos.z + math.sin(angle) * 52;
      _drawIsometricBox(
        canvas,
        vm.Vector3(ribX, pos.y + towerHeight / 2, ribZ),
        4,
        towerHeight,
        4,
        const Color(0xFFDAA520),
        w2s,
      );
    }

    // Circular external walkways
    for (int level = 0; level < 3; level++) {
      final walkwayY = pos.y + 40 + level * 45;
      for (int i = 0; i < 16; i++) {
        final angle = i * math.pi / 8;
        final walkX = pos.x + math.cos(angle) * 62;
        final walkZ = pos.z + math.sin(angle) * 62;
        _drawIsometricBox(
          canvas,
          vm.Vector3(walkX, walkwayY, walkZ),
          8,
          2,
          6,
          const Color(0xFFB8860B).withValues(alpha: 0.7),
          w2s,
        );
      }
    }

    // Landing platforms (more for high-tech) and docking bays
    final platformCount = (3 * techLevel).toInt().clamp(3, 6);
    for (int i = 0; i < platformCount; i++) {
      final platformY = pos.y + 40 + i * (towerHeight - 80) / platformCount;
      final platformPos = vm.Vector3(pos.x, platformY, pos.z);
      _drawPlatform(
        canvas,
        platformPos,
        90 - i * 10,
        baseColor.withValues(alpha: 0.6),
        w2s,
      );
    }

    // Top dome
    _drawDome(
      canvas,
      pos,
      30,
      towerHeight,
      Colors.white.withValues(alpha: 0.8),
      w2s,
    );

    // Glowing landing lights (more for high-tech)
    final lightCount = (8 * techLevel).toInt().clamp(8, 16);
    for (int i = 0; i < lightCount; i++) {
      final angle = i * 2 * math.pi / lightCount;
      final lightPos = vm.Vector3(
        pos.x + math.cos(angle) * 55,
        pos.y + 80,
        pos.z + math.sin(angle) * 55,
      );
      _drawLandingLight(canvas, lightPos, w2s);
    }
  }

  /// Dagobah Swamp Hut - Small organic structure
  /// Dagobah Hut - API-enhanced murky swamp dwelling
  static void _drawDagobahHut(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    // Get planet properties from API
    final props = getBuildingProperties('dagobah_swamp');
    final isMurky = props['climate'].toString().contains('murky');
    final isSwamp = props['terrain'].toString().contains('swamp');
    final organicFactor = props['organic_factor'] as double? ?? 1.0;

    // Adapt colors for swamp environment
    final baseColor =
        isMurky
            ? const Color(0xFF1B4D3E) // Dark murky green
            : const Color(0xFF2E8B57);

    final mossColor =
        isSwamp
            ? const Color(0xFF3D5E4F) // Swamp moss
            : const Color(0xFF4A7C59);

    // Organic hut shape - smaller and lower in swamp
    final size = isSwamp ? 55.0 : 60.0;
    final height = isMurky ? 45.0 : 50.0; // Lower profile in murky conditions

    _drawIsometricBox(canvas, pos, size, height, size, baseColor, w2s);
    _drawDome(canvas, pos, 35, height, mossColor.withValues(alpha: 0.7), w2s);

    // Enhanced vines and foliage for swamp (API-driven)
    final vineCount = (10 * organicFactor).toInt();
    _drawVines(canvas, pos, w2s, count: vineCount);

    // Murky mist effect
    if (isMurky) {
      final random = math.Random(456);
      for (int i = 0; i < 8; i++) {
        final x = random.nextDouble() * 80 - 40;
        final y = random.nextDouble() * 30;
        final z = random.nextDouble() * 80 - 40;
        final mistPos = vm.Vector3(pos.x + x, pos.y + y, pos.z + z);
        final mistScreen = w2s(mistPos);

        // Swamp fog
        canvas.drawCircle(
          mistScreen,
          random.nextDouble() * 15 + 10,
          Paint()
            ..color = const Color(0xFF4A7C59).withValues(alpha: 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
        );
      }
    }

    // Small window
    final windowPos = vm.Vector3(pos.x + 20, pos.y + 30, pos.z + 30);
    _drawGlowingWindow(canvas, windowPos, 8, 8, Colors.yellow.shade700, w2s);
  }

  /// Death Star - Massive sphere with detail
  static void _drawDeathStar(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final baseColor = const Color(0xFF708090);

    // Main sphere body with darker imperial grey
    _drawSphere(canvas, pos, 100, baseColor, w2s);

    // Equatorial trench (iconic Death Star feature)
    final trenchCount = 24;
    for (int i = 0; i < trenchCount; i++) {
      final angle = i * math.pi * 2 / trenchCount;
      final trenchX = pos.x + math.cos(angle) * 85;
      final trenchZ = pos.z + math.sin(angle) * 85;
      _drawIsometricBox(
        canvas,
        vm.Vector3(trenchX, pos.y, trenchZ),
        6,
        8,
        4,
        const Color(0xFF2F4F4F),
        w2s,
      );
    }

    // Turbolaser turrets across surface
    for (int i = 0; i < 12; i++) {
      final turretAngle = i * math.pi / 6;
      final turretRadius = 70 + (i % 3) * 15;
      final turretX = pos.x + math.cos(turretAngle) * turretRadius;
      final turretZ = pos.z + math.sin(turretAngle) * turretRadius;
      final turretY = pos.y + math.sin(i * 1.3) * 30;

      final turretPos = vm.Vector3(turretX, turretY, turretZ);
      _drawCylinder(canvas, turretPos, 4, 12, const Color(0xFF556B2F), w2s);
      _drawSphere(
        canvas,
        vm.Vector3(turretX, turretY + 12, turretZ),
        5,
        const Color(0xFF696969),
        w2s,
      );
    }

    // Imperial hangar bay opening
    final hangarPos = vm.Vector3(pos.x + 40, pos.y - 20, pos.z + 60);
    _drawIsometricBox(
      canvas,
      hangarPos,
      30,
      25,
      15,
      const Color(0xFF000000).withValues(alpha: 0.9),
      w2s,
    );
    // Hangar blue force field
    _drawIsometricBox(
      canvas,
      vm.Vector3(hangarPos.x, hangarPos.y, hangarPos.z + 10),
      28,
      23,
      1,
      Colors.blue.withValues(alpha: 0.3),
      w2s,
    );

    // Superlaser dish with charging energy
    final dishPos = vm.Vector3(pos.x - 30, pos.y + 50, pos.z - 30);
    _drawSuperlaserDish(canvas, dishPos, w2s);
    StarWarsEffects.drawSuperlaserCharge(canvas, dishPos, w2s);

    // Panel details
    _drawPanels(canvas, pos, w2s);

    // Trench detail
    _drawTrench(canvas, pos, w2s);
  }

  /// Endor Base - Forest outpost
  static void _drawEndorBase(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final baseColor = const Color(0xFF228B22);

    // Base platform
    _drawIsometricBox(
      canvas,
      pos,
      90,
      60,
      90,
      baseColor.withValues(alpha: 0.7),
      w2s,
    );

    // Shield generator
    _drawShieldGenerator(canvas, pos, w2s);

    // Trees around
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final treePos = vm.Vector3(
        pos.x + math.cos(angle) * 70,
        pos.y,
        pos.z + math.sin(angle) * 70,
      );
      _drawTree(canvas, treePos, w2s);
    }
  }

  /// Hoth Base - API-enhanced ice fortress
  static void _drawHothBase(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    // Get planet properties from API
    final props = getBuildingProperties('hoth_base');
    final isFrozen = props['climate'].toString().contains('frozen');
    final iceFactor = props['ice_factor'] as double? ?? 1.0;

    // Adapt colors for extreme cold
    final baseColor =
        isFrozen
            ? const Color(0xFFE0F7FF) // Bright ice blue
            : const Color(0xFFADD8E6); // Light blue

    // Main ice structure - reinforced for harsh climate
    final width = isFrozen ? 115.0 : 110.0; // Thicker walls for insulation
    _drawIsometricBox(canvas, pos, width, 90, width, baseColor, w2s);

    // Shield generator power dome (iconic Hoth element)
    final generatorPos = vm.Vector3(pos.x + 50, pos.y, pos.z - 50);
    _drawCylinder(canvas, generatorPos, 25, 15, const Color(0xFFB0C4DE), w2s);
    _drawDome(
      canvas,
      generatorPos,
      25,
      15,
      const Color(0xFFADD8E6).withValues(alpha: 0.8),
      w2s,
    );

    // Energy shield visual
    final shieldRadius = 35.0;
    final shieldPaint =
        Paint()
          ..color = Colors.cyan.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final shieldScreen = w2s(
      vm.Vector3(generatorPos.x, generatorPos.y + 30, generatorPos.z),
    );
    canvas.drawCircle(shieldScreen, shieldRadius, shieldPaint);

    // Ion cannon turret
    final ionCannonPos = vm.Vector3(pos.x - 45, pos.y + 90, pos.z + 40);
    _drawCylinder(canvas, ionCannonPos, 8, 30, const Color(0xFF778899), w2s);
    _drawIsometricBox(
      canvas,
      vm.Vector3(ionCannonPos.x, ionCannonPos.y + 30, ionCannonPos.z),
      18,
      8,
      18,
      const Color(0xFF708090),
      w2s,
    );

    // Defensive ice trenches
    for (int i = 0; i < 4; i++) {
      final trenchAngle = i * math.pi / 2;
      final trenchX = pos.x + math.cos(trenchAngle) * 75;
      final trenchZ = pos.z + math.sin(trenchAngle) * 75;
      _drawIsometricBox(
        canvas,
        vm.Vector3(trenchX, pos.y, trenchZ),
        40,
        8,
        12,
        const Color(0xFFCEE5F2).withValues(alpha: 0.7),
        w2s,
      );
    }

    // Hangar entrance
    final hangarPos = vm.Vector3(pos.x, pos.y + 10, pos.z + width / 2);
    _drawHangarDoor(canvas, hangarPos, w2s);

    // Ion cannon
    final cannonPos = vm.Vector3(pos.x + 50, pos.y + 90, pos.z);
    _drawIonCannon(canvas, cannonPos, w2s);

    // Enhanced ice crystals for frozen climate (API-driven)
    final crystalCount = (20 * iceFactor).toInt();
    _drawIceCrystals(canvas, pos, w2s, count: crystalCount);

    // Frost patterns on surface
    if (isFrozen) {
      final random = math.Random(789);
      final frostCount = (15 * iceFactor).toInt();
      for (int i = 0; i < frostCount; i++) {
        final x = random.nextDouble() * width - width / 2;
        final y = random.nextDouble() * 60 + 20;
        final z = random.nextDouble() * width - width / 2;
        final frostPos = vm.Vector3(pos.x + x, pos.y + y, pos.z + z);
        final frostScreen = w2s(frostPos);

        // Crystalline frost
        canvas.drawCircle(
          frostScreen,
          random.nextDouble() * 2 + 1,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
      }
    }
  }

  /// Naboo Palace - Elegant architecture
  static void _drawNabooPalace(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final baseColor = const Color(0xFFDDA0DD);

    // Main palace structure with refined color
    final palaceColor = Color.lerp(baseColor, Colors.white, 0.05)!;
    _drawIsometricBox(canvas, pos, 130, 120, 100, palaceColor, w2s);

    // Grand entrance with depth
    final entrancePos = vm.Vector3(pos.x, pos.y + 10, pos.z + 50);
    _drawGrandArchway(canvas, entrancePos, w2s);

    // Decorative domes with elegant styling
    for (int i = -1; i <= 1; i++) {
      final domePos = vm.Vector3(pos.x + i * 50, pos.y + 120, pos.z);
      final domeColor =
          i == 0
              ? Colors.white.withValues(alpha: 0.95)
              : const Color(0xFFFFF8DC).withValues(alpha: 0.9);
      _drawDome(canvas, domePos, 25, 0, domeColor, w2s);
    }

    // Gardens
    _drawGardens(canvas, pos, w2s);
  }

  // Helper drawing functions - Enhanced for "Tech-Noir" / Sci-Fi feel
  static void _drawIsometricBox(
    Canvas canvas,
    vm.Vector3 pos,
    double width,
    double height,
    double depth,
    Color color,
    Function(vm.Vector3) w2s,
  ) {
    final corners = [
      w2s(vm.Vector3(pos.x - width / 2, pos.y, pos.z - depth / 2)),
      w2s(vm.Vector3(pos.x + width / 2, pos.y, pos.z - depth / 2)),
      w2s(vm.Vector3(pos.x + width / 2, pos.y, pos.z + depth / 2)),
      w2s(vm.Vector3(pos.x - width / 2, pos.y, pos.z + depth / 2)),
    ];

    final topCorners = [
      w2s(vm.Vector3(pos.x - width / 2, pos.y + height, pos.z - depth / 2)),
      w2s(vm.Vector3(pos.x + width / 2, pos.y + height, pos.z - depth / 2)),
      w2s(vm.Vector3(pos.x + width / 2, pos.y + height, pos.z + depth / 2)),
      w2s(vm.Vector3(pos.x - width / 2, pos.y + height, pos.z + depth / 2)),
    ];

    // Front face with sophisticated lighting and ambient occlusion
    final frontPath =
        Path()
          ..moveTo(corners[0].dx, corners[0].dy)
          ..lineTo(corners[1].dx, corners[1].dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..lineTo(topCorners[0].dx, topCorners[0].dy)
          ..close();

    // Ambient occlusion at base
    final aoGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent],
      stops: const [0.0, 0.3],
    );

    canvas.drawPath(
      frontPath,
      Paint()
        ..shader = aoGradient.createShader(
          Rect.fromPoints(corners[0], topCorners[1]),
        ),
    );

    canvas.drawPath(
      frontPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color, // Full brightness at top
            Color.lerp(color, Colors.black, 0.4)!, // Darker at bottom
          ],
        ).createShader(Rect.fromPoints(topCorners[0], corners[1])),
    );

    // Right face (Shadow side)
    final rightPath =
        Path()
          ..moveTo(corners[1].dx, corners[1].dy)
          ..lineTo(corners[2].dx, corners[2].dy)
          ..lineTo(topCorners[2].dx, topCorners[2].dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..close();

    final shadowColor = Color.lerp(color, Colors.black, 0.6)!;
    canvas.drawPath(
      rightPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [shadowColor, Color.lerp(shadowColor, Colors.black, 0.3)!],
        ).createShader(Rect.fromPoints(topCorners[1], corners[2])),
    );

    // Top face (Highlight)
    final topPath =
        Path()
          ..moveTo(topCorners[0].dx, topCorners[0].dy)
          ..lineTo(topCorners[1].dx, topCorners[1].dy)
          ..lineTo(topCorners[2].dx, topCorners[2].dy)
          ..lineTo(topCorners[3].dx, topCorners[3].dy)
          ..close();

    final highlightColor = Color.lerp(color, Colors.white, 0.1)!;
    canvas.drawPath(topPath, Paint()..color = highlightColor);

    // Star Wars Tech Details - Holographic Panels & Greebling
    StarWarsEffects.drawHolographicPanels(
      canvas,
      pos,
      width,
      height,
      depth,
      w2s,
    );
    StarWarsEffects.drawMetallicGreebling(
      canvas,
      pos,
      width,
      height,
      depth,
      w2s,
    );

    // Tech Panel Details (Greebling)
    final panelPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Draw horizontal panel lines on front face
    for (int i = 1; i < 4; i++) {
      final double t = i / 4.0;
      final p1 = Offset.lerp(topCorners[0], corners[0], t)!;
      final p2 = Offset.lerp(topCorners[1], corners[1], t)!;
      canvas.drawLine(p1, p2, panelPaint);
    }
    // Draw vertical panel lines on side face
    for (int i = 1; i < 3; i++) {
      final double t = i / 3.0;
      final p1 = Offset.lerp(topCorners[1], topCorners[2], t)!;
      final p2 = Offset.lerp(corners[1], corners[2], t)!;
      canvas.drawLine(p1, p2, panelPaint);
    }

    // High-contrast Outlines for "toon" or "schematic" look
    final outline =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2) // Subtle highlight edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Top edges get highlight
    canvas.drawLine(topCorners[0], topCorners[1], outline);
    canvas.drawLine(topCorners[1], topCorners[2], outline);
    canvas.drawLine(topCorners[3], topCorners[0], outline);

    // Darker structural outline
    final structOutline =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    canvas.drawPath(frontPath, structOutline);
    canvas.drawPath(rightPath, structOutline);
  }

  static void _drawDome(
    Canvas canvas,
    vm.Vector3 pos,
    double radius,
    double baseHeight,
    Color color,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(vm.Vector3(pos.x, pos.y + baseHeight, pos.z));
    final width = radius * 1.8;
    final height = radius * 0.9;
    final rect = Rect.fromCenter(center: center, width: width, height: height);

    // Draw dome background (darker at edges)
    final domePaint =
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3), // Light source from top-left
            radius: 1.0,
            colors: [
              Color.lerp(color, Colors.white, 0.2)!, // Highlight
              color,
              Color.lerp(color, Colors.black, 0.4)!, // Shadow
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect);

    canvas.drawOval(rect, domePaint);

    // Tech Rings on Dome
    final ringPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    for (int i = 1; i < 4; i++) {
      final scale = 1.0 - (i * 0.2);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: width * scale,
          height: height * scale,
        ),
        ringPaint,
      );
    }

    // Vertical meridian lines
    canvas.drawArc(rect, -math.pi / 2 - 0.5, 1.0, false, ringPaint);
    canvas.drawArc(rect, -math.pi / 2 - 1.5, 3.0, false, ringPaint);

    // Rim Highlight
    canvas.drawOval(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  static void _drawSpire(
    Canvas canvas,
    vm.Vector3 pos,
    double baseRadius,
    double height,
    Color color,
    Function(vm.Vector3) w2s,
  ) {
    final base = w2s(vm.Vector3(pos.x, pos.y, pos.z));
    final top = w2s(vm.Vector3(pos.x, pos.y + height, pos.z));

    final spirePath =
        Path()
          ..moveTo(base.dx - baseRadius, base.dy)
          ..lineTo(top.dx - 5, top.dy)
          ..lineTo(top.dx + 5, top.dy)
          ..lineTo(base.dx + baseRadius, base.dy)
          ..close();

    canvas.drawPath(
      spirePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.9), color],
        ).createShader(Rect.fromPoints(top, base)),
    );

    canvas.drawPath(
      spirePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  static void _drawCylinder(
    Canvas canvas,
    vm.Vector3 pos,
    double radius,
    double height,
    Color color,
    Function(vm.Vector3) w2s,
  ) {
    final base = w2s(vm.Vector3(pos.x, pos.y, pos.z));
    final top = w2s(vm.Vector3(pos.x, pos.y + height, pos.z));

    // Cylinder body
    canvas.drawRect(
      Rect.fromPoints(
        Offset(base.dx - radius, top.dy),
        Offset(base.dx + radius, base.dy),
      ),
      Paint()..color = color.withValues(alpha: 0.8),
    );

    // Top ellipse
    canvas.drawOval(
      Rect.fromCenter(center: top, width: radius * 2, height: radius * 0.5),
      Paint()..color = color,
    );

    // Highlights
    canvas.drawLine(
      Offset(base.dx - radius, top.dy),
      Offset(base.dx - radius, base.dy),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 2,
    );
  }

  static void _drawSphere(
    Canvas canvas,
    vm.Vector3 pos,
    double radius,
    Color color,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(vm.Vector3(pos.x, pos.y + radius, pos.z));

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.5)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  static void _drawGlowingWindow(
    Canvas canvas,
    vm.Vector3 pos,
    double width,
    double height,
    Color glowColor,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    // Glow effect
    canvas.drawRect(
      Rect.fromCenter(center: center, width: width + 8, height: height + 8),
      Paint()
        ..color = glowColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Window
    canvas.drawRect(
      Rect.fromCenter(center: center, width: width, height: height),
      Paint()..color = glowColor,
    );
  }

  static void _drawArchway(
    Canvas canvas,
    vm.Vector3 pos,
    double width,
    double height,
    Color color,
    Function(vm.Vector3) w2s,
  ) {
    final base = w2s(pos);
    final top = w2s(vm.Vector3(pos.x, pos.y + height, pos.z));

    final path =
        Path()
          ..moveTo(base.dx - width / 2, base.dy)
          ..lineTo(base.dx - width / 2, top.dy + 5)
          ..quadraticBezierTo(
            base.dx,
            top.dy - 5,
            base.dx + width / 2,
            top.dy + 5,
          )
          ..lineTo(base.dx + width / 2, base.dy)
          ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  // Placeholder implementations for specialized features
  static void _drawGenericBuilding(c, p, w, col) =>
      _drawIsometricBox(c, p, 80, 100, 80, col, w);

  /// Draw Jedi symbols on temple
  static void _drawJediSymbols(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(vm.Vector3(pos.x, pos.y + 70, pos.z + 60));

    // Jedi Order symbol - simplified circular emblem
    final symbolPaint =
        Paint()
          ..color = Colors.cyan.shade200.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawCircle(center, 15, symbolPaint);

    // Inner wings
    final wingPath =
        Path()
          ..moveTo(center.dx, center.dy - 12)
          ..lineTo(center.dx - 8, center.dy + 8)
          ..moveTo(center.dx, center.dy - 12)
          ..lineTo(center.dx + 8, center.dy + 8);
    canvas.drawPath(wingPath, symbolPaint);

    // Glowing effect
    canvas.drawCircle(
      center,
      18,
      Paint()
        ..color = Colors.cyan.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  /// Draw landing platform
  static void _drawPlatform(
    Canvas canvas,
    vm.Vector3 pos,
    double radius,
    Color col,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    // Platform disk
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 0.4),
      Paint()
        ..shader = RadialGradient(
          colors: [col, col.withValues(alpha: 0.6)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Landing markers
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final markerPos = Offset(
        center.dx + math.cos(angle) * radius * 0.6,
        center.dy + math.sin(angle) * radius * 0.2,
      );
      canvas.drawCircle(markerPos, 3, Paint()..color = Colors.orange);
    }

    // Edge lights
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 0.4),
      Paint()
        ..color = Colors.yellow.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Draw landing light
  static void _drawLandingLight(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    // Glow
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = Colors.blue.shade200.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Light core
    canvas.drawCircle(center, 3, Paint()..color = Colors.blue.shade100);
  }

  /// Draw vines and foliage
  static void _drawVines(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s, {
    int count = 10,
  }) {
    final base = w2s(vm.Vector3(pos.x + 25, pos.y + 20, pos.z + 25));

    final vinePaint =
        Paint()
          ..color = Colors.green.shade800
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    // Wavy vines (API-driven count)
    final vineCount = (count / 3).ceil().clamp(1, 10);
    for (int i = 0; i < vineCount; i++) {
      final vinePath = Path()..moveTo(base.dx + i * 8, base.dy);
      for (int j = 0; j < 5; j++) {
        vinePath.quadraticBezierTo(
          base.dx + i * 8 + (j % 2 == 0 ? 3 : -3),
          base.dy - j * 8,
          base.dx + i * 8,
          base.dy - (j + 1) * 8,
        );
      }
      canvas.drawPath(vinePath, vinePaint);

      // Leaves
      for (int j = 1; j < 5; j++) {
        canvas.drawCircle(
          Offset(base.dx + i * 8, base.dy - j * 8),
          3,
          Paint()..color = Colors.green.shade600,
        );
      }
    }
  }

  /// Draw Death Star superlaser dish
  static void _drawSuperlaserDish(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    // Dish depression
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 40, height: 20),
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.grey.shade800, Colors.grey.shade600],
        ).createShader(Rect.fromCircle(center: center, radius: 20)),
    );

    // Laser emitter
    canvas.drawCircle(center, 6, Paint()..color = Colors.red.shade900);

    // Charging glow
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  /// Draw Death Star panels
  static void _drawPanels(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(vm.Vector3(pos.x, pos.y + 100, pos.z));

    final panelPaint =
        Paint()
          ..color = Colors.grey.shade700
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;

    // Grid pattern
    for (int i = -8; i <= 8; i++) {
      canvas.drawLine(
        Offset(center.dx + i * 10, center.dy - 80),
        Offset(center.dx + i * 10, center.dy + 80),
        panelPaint,
      );
    }

    for (int i = -8; i <= 8; i++) {
      canvas.drawLine(
        Offset(center.dx - 80, center.dy + i * 10),
        Offset(center.dx + 80, center.dy + i * 10),
        panelPaint,
      );
    }
  }

  /// Draw equatorial trench
  static void _drawTrench(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(vm.Vector3(pos.x, pos.y + 100, pos.z));

    // Trench band
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 180, height: 15),
      Paint()..color = Colors.black54,
    );

    // Trench details
    final detailPaint =
        Paint()
          ..color = Colors.grey.shade800
          ..strokeWidth = 1;

    for (int i = -9; i <= 9; i++) {
      canvas.drawLine(
        Offset(center.dx + i * 10, center.dy - 7),
        Offset(center.dx + i * 10, center.dy + 7),
        detailPaint,
      );
    }
  }

  /// Draw shield generator
  static void _drawShieldGenerator(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final base = w2s(vm.Vector3(pos.x, pos.y + 60, pos.z));

    // Tower base
    canvas.drawRect(
      Rect.fromCenter(center: base, width: 20, height: 40),
      Paint()..color = Colors.grey.shade600,
    );

    // Dish
    final dishTop = Offset(base.dx, base.dy - 25);
    canvas.drawOval(
      Rect.fromCenter(center: dishTop, width: 30, height: 15),
      Paint()..color = Colors.grey.shade500,
    );

    // Shield bubble effect
    canvas.drawCircle(
      Offset(base.dx, base.dy - 10),
      45,
      Paint()
        ..color = Colors.blue.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );

    // Energy lines
    final energyPaint =
        Paint()
          ..color = Colors.cyan.withValues(alpha: 0.3)
          ..strokeWidth = 1.5;

    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawLine(
        dishTop,
        Offset(
          dishTop.dx + math.cos(angle) * 40,
          dishTop.dy + math.sin(angle) * 20,
        ),
        energyPaint,
      );
    }
  }

  /// Draw tree
  static void _drawTree(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final base = w2s(pos);

    // Trunk
    final trunkPaint = Paint()..color = const Color(0xFF4A2511);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(base.dx, base.dy - 15),
        width: 6,
        height: 30,
      ),
      trunkPaint,
    );

    // Foliage layers
    final foliageColors = [
      Colors.green.shade800,
      Colors.green.shade700,
      Colors.green.shade600,
    ];

    for (int i = 0; i < 3; i++) {
      final foliagePath =
          Path()
            ..moveTo(base.dx, base.dy - 30 - i * 12)
            ..lineTo(base.dx - 15 + i * 3, base.dy - 20 - i * 12)
            ..lineTo(base.dx + 15 - i * 3, base.dy - 20 - i * 12)
            ..close();

      canvas.drawPath(foliagePath, Paint()..color = foliageColors[i]);
    }
  }

  /// Draw hangar door
  static void _drawHangarDoor(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final center = w2s(pos);

    // Door frame
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 40, height: 50),
      Paint()..color = Colors.grey.shade800,
    );

    // Door panels
    final doorPaint =
        Paint()
          ..color = Colors.grey.shade600
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    // Vertical split
    canvas.drawLine(
      Offset(center.dx, center.dy - 25),
      Offset(center.dx, center.dy + 25),
      doorPaint,
    );

    // Horizontal segments
    for (int i = -2; i <= 2; i++) {
      canvas.drawLine(
        Offset(center.dx - 20, center.dy + i * 10),
        Offset(center.dx + 20, center.dy + i * 10),
        doorPaint,
      );
    }

    // Warning lights
    canvas.drawCircle(
      Offset(center.dx - 18, center.dy - 22),
      3,
      Paint()..color = Colors.orange.shade700,
    );
    canvas.drawCircle(
      Offset(center.dx + 18, center.dy - 22),
      3,
      Paint()..color = Colors.orange.shade700,
    );
  }

  /// Draw ion cannon
  static void _drawIonCannon(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final base = w2s(pos);

    // Mount
    canvas.drawRect(
      Rect.fromCenter(center: base, width: 15, height: 12),
      Paint()..color = Colors.grey.shade700,
    );

    // Barrel
    final barrelEnd = Offset(base.dx + 25, base.dy - 8);
    canvas.drawRect(
      Rect.fromPoints(Offset(base.dx, base.dy - 5), barrelEnd),
      Paint()..color = Colors.grey.shade600,
    );

    // Barrel tip
    canvas.drawCircle(barrelEnd, 4, Paint()..color = Colors.grey.shade800);

    // Energy glow
    canvas.drawCircle(
      barrelEnd,
      6,
      Paint()
        ..color = Colors.blue.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  /// Draw ice crystals
  static void _drawIceCrystals(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s, {
    int count = 20,
  }) {
    // Scale crystal count based on API data
    final crystalDensity = (count / 5).clamp(1, 8).toInt();
    final random = math.Random(789);

    for (int i = 0; i < crystalDensity; i++) {
      // Random positions around base
      final angle = (i / crystalDensity) * 2 * math.pi + random.nextDouble();
      final distance = 35 + random.nextDouble() * 15;
      final crystalPos = vm.Vector3(
        pos.x + math.cos(angle) * distance,
        pos.y,
        pos.z + math.sin(angle) * distance,
      );

      final center = w2s(crystalPos);

      // Crystal spire
      final crystalHeight = 20 + random.nextDouble() * 10;
      final crystalPath =
          Path()
            ..moveTo(center.dx, center.dy - crystalHeight)
            ..lineTo(center.dx - 4, center.dy)
            ..lineTo(center.dx + 4, center.dy)
            ..close();

      canvas.drawPath(
        crystalPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.9),
              Colors.lightBlue.shade200.withValues(alpha: 0.7),
            ],
          ).createShader(
            Rect.fromPoints(
              Offset(center.dx, center.dy - crystalHeight),
              Offset(center.dx, center.dy),
            ),
          ),
      );

      // Sparkle
      canvas.drawCircle(
        Offset(center.dx, center.dy - 25),
        3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  /// Draw grand archway
  static void _drawGrandArchway(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    final base = w2s(pos);

    // Arch columns
    final columnPaint = Paint()..color = const Color(0xFFDDA0DD);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(base.dx - 20, base.dy - 15),
        width: 8,
        height: 40,
      ),
      columnPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(base.dx + 20, base.dy - 15),
        width: 8,
        height: 40,
      ),
      columnPaint,
    );

    // Arch top
    final archPath =
        Path()
          ..moveTo(base.dx - 24, base.dy - 35)
          ..quadraticBezierTo(
            base.dx,
            base.dy - 45,
            base.dx + 24,
            base.dy - 35,
          );

    canvas.drawPath(
      archPath,
      Paint()
        ..color = const Color(0xFFDDA0DD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Decorative details
    final detailPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(base.dx - 20, base.dy - 10 - i * 8),
        Offset(base.dx - 20, base.dy - 12 - i * 8),
        detailPaint,
      );
      canvas.drawLine(
        Offset(base.dx + 20, base.dy - 10 - i * 8),
        Offset(base.dx + 20, base.dy - 12 - i * 8),
        detailPaint,
      );
    }
  }

  /// Draw palace gardens
  static void _drawGardens(
    Canvas canvas,
    vm.Vector3 pos,
    Function(vm.Vector3) w2s,
  ) {
    // Decorative plants around palace
    final gardenPositions = [
      vm.Vector3(pos.x - 55, pos.y, pos.z + 45),
      vm.Vector3(pos.x + 55, pos.y, pos.z + 45),
      vm.Vector3(pos.x - 65, pos.y, pos.z),
      vm.Vector3(pos.x + 65, pos.y, pos.z),
    ];

    for (final gardenPos in gardenPositions) {
      final center = w2s(gardenPos);

      // Bush/shrub
      canvas.drawCircle(
        center,
        12,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.green.shade400, Colors.green.shade700],
          ).createShader(Rect.fromCircle(center: center, radius: 12)),
      );

      // Flowers
      for (int i = 0; i < 3; i++) {
        final angle = i * 2 * math.pi / 3;
        final flowerPos = Offset(
          center.dx + math.cos(angle) * 8,
          center.dy + math.sin(angle) * 4,
        );
        canvas.drawCircle(flowerPos, 3, Paint()..color = Colors.pink.shade300);
      }
    }

    // Fountain
    final fountainCenter = w2s(vm.Vector3(pos.x, pos.y, pos.z + 70));
    canvas.drawCircle(
      fountainCenter,
      15,
      Paint()..color = Colors.lightBlue.shade200.withValues(alpha: 0.6),
    );

    // Water spray effect
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(fountainCenter.dx, fountainCenter.dy - 5 - i * 3),
        2 - i * 0.3,
        Paint()
          ..color = Colors.lightBlue.shade100.withValues(alpha: 0.7 - i * 0.1),
      );
    }
  }
}
