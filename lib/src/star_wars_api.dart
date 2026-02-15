import 'dart:convert';
import 'package:http/http.dart' as http;

/// Star Wars API service
class StarWarsAPI {
  static const String baseUrl = 'https://swapi.py4e.com/api';

  /// Fetch Star Wars character data
  static Future<Map<String, dynamic>> getCharacter(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/people/$id/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // Fallback to local data if API fails
    }
    return _fallbackCharacters[id] ?? _fallbackCharacters[1]!;
  }

  /// Fetch Star Wars planet data
  static Future<Map<String, dynamic>> getPlanet(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/planets/$id/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // Fallback to local data if API fails
    }
    return _fallbackPlanets[id] ?? _fallbackPlanets[1]!;
  }

  /// Fetch Star Wars species data
  static Future<Map<String, dynamic>> getSpecies(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/species/$id/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // Fallback to local data if API fails
    }
    return _fallbackSpecies[id] ?? _fallbackSpecies[1]!;
  }

  /// Get animation properties based on character data from API
  static Future<Map<String, dynamic>> getCharacterAnimationData(
    String characterName,
  ) async {
    // Map character names to SWAPI IDs
    final characterIds = {
      'luke': 1,
      'leia': 5,
      'han': 14,
      'darth_vader': 4,
      'yoda': 20,
      'chewbacca': 13,
      'obi_wan': 10,
      'r2d2': 3,
      'c3po': 2,
    };

    final id = characterIds[characterName.toLowerCase()] ?? 1;
    final charData = await getCharacter(id);

    // Parse height and mass for animation scaling
    final height =
        double.tryParse(charData['height']?.toString() ?? '170') ?? 170.0;
    final mass =
        double.tryParse(
          charData['mass']?.toString().replaceAll(',', '') ?? '77',
        ) ??
        77.0;

    // Calculate animation properties
    return {
      'name': charData['name'] ?? characterName,
      'height': height,
      'mass': mass,
      'scale': height / 170.0, // Normal height baseline
      'speed': _calculateSpeed(height, mass),
      'bobIntensity': _calculateBobIntensity(height, mass),
      'limbSwing': _calculateLimbSwing(height, mass),
    };
  }

  static double _calculateSpeed(double height, double mass) {
    // Taller = faster stride, heavier = slower
    final heightFactor = height / 170.0;
    final massFactor = 77.0 / mass;
    return (heightFactor * 0.7 + massFactor * 0.3).clamp(0.5, 2.0);
  }

  static double _calculateBobIntensity(double height, double mass) {
    // Heavier characters bob more
    return (mass / 77.0 * 1.2).clamp(0.5, 2.5);
  }

  static double _calculateLimbSwing(double height, double mass) {
    // Longer limbs = more swing
    return (height / 170.0 * 1.3).clamp(0.6, 2.0);
  }

  /// Get all major planets for the city
  static List<Map<String, String>> getCityLocations() {
    return [
      {
        'id': 'jedi_temple',
        'label': 'Jedi Temple (Coruscant)',
        'color': '#4169E1',
      },
      {
        'id': 'naboo_palace',
        'label': 'Theed Palace (Naboo)',
        'color': '#DDA0DD',
      },
      {
        'id': 'tatooine_cantina',
        'label': 'Mos Eisley Cantina',
        'color': '#F4A460',
      },
      {'id': 'cloud_city', 'label': 'Cloud City (Bespin)', 'color': '#FFD700'},
      {'id': 'dagobah_swamp', 'label': 'Dagobah Swamp', 'color': '#228B22'},
      {'id': 'death_star', 'label': 'Death Star Hangar', 'color': '#708090'},
      {'id': 'endor_forest', 'label': 'Endor Forest', 'color': '#2E8B57'},
      {'id': 'hoth_base', 'label': 'Echo Base (Hoth)', 'color': '#B0E0E6'},
    ];
  }

  /// Get 3D coordinates for galactic layout
  static Map<String, dynamic> getGalacticLayout() {
    // Galactic Coordinate System
    // Core (0,0,0) -> Coruscant
    // Mid Rim -> Naboo
    // Outer Rim -> Tatooine, Hoth, Endor, Dagobah
    // Mobile -> Death Star

    return {
      // Core World - Center
      'jedi_temple': {
        'x': 0.0,
        'y': 0.0,
        'z': 0.0,
        'planet_id': 9,
      }, // Coruscant=9
      // Mid Rim / Expansion Region
      'naboo_palace': {'x': 180.0, 'y': 0.0, 'z': 120.0, 'planet_id': 8},

      // Outer Rim Territories (Spiral Arm 1)
      'tatooine_cantina': {'x': 320.0, 'y': 0.0, 'z': -240.0, 'planet_id': 1},
      'hoth_base': {'x': 450.0, 'y': 0.0, 'z': -100.0, 'planet_id': 4},

      // Outer Rim Territories (Spiral Arm 2)
      'endor_forest': {'x': -380.0, 'y': 0.0, 'z': 220.0, 'planet_id': 7},
      'dagobah_swamp': {'x': -250.0, 'y': 0.0, 'z': 350.0, 'planet_id': 5},
      'cloud_city': {'x': -400.0, 'y': 0.0, 'z': -150.0, 'planet_id': 6},

      // Unknown Regions / Mobile
      'death_star': {'x': 0.0, 'y': 0.0, 'z': -500.0, 'planet_id': 0},
    };
  }

  // Fallback data if API is unavailable
  static final Map<int, Map<String, dynamic>> _fallbackCharacters = {
    1: {'name': 'Luke Skywalker', 'height': '172', 'mass': '77'},
    2: {'name': 'C-3PO', 'height': '167', 'mass': '75'},
    3: {'name': 'R2-D2', 'height': '96', 'mass': '32'},
    4: {'name': 'Darth Vader', 'height': '202', 'mass': '136'},
    5: {'name': 'Leia Organa', 'height': '150', 'mass': '49'},
    10: {'name': 'Obi-Wan Kenobi', 'height': '182', 'mass': '77'},
    11: {'name': 'Anakin Skywalker', 'height': '188', 'mass': '84'},
    13: {'name': 'Chewbacca', 'height': '228', 'mass': '112'},
    14: {'name': 'Han Solo', 'height': '180', 'mass': '80'},
    20: {'name': 'Yoda', 'height': '66', 'mass': '17'},
  };

  static final Map<int, Map<String, dynamic>> _fallbackPlanets = {
    1: {'name': 'Tatooine', 'climate': 'arid', 'terrain': 'desert'},
    2: {'name': 'Alderaan', 'climate': 'temperate', 'terrain': 'grasslands'},
    3: {'name': 'Yavin IV', 'climate': 'temperate', 'terrain': 'jungle'},
    4: {'name': 'Hoth', 'climate': 'frozen', 'terrain': 'ice'},
    5: {'name': 'Dagobah', 'climate': 'murky', 'terrain': 'swamp'},
    6: {'name': 'Bespin', 'climate': 'temperate', 'terrain': 'gas giant'},
    7: {'name': 'Endor', 'climate': 'temperate', 'terrain': 'forests'},
    8: {'name': 'Naboo', 'climate': 'temperate', 'terrain': 'plains'},
  };

  static final Map<int, Map<String, dynamic>> _fallbackSpecies = {
    1: {'name': 'Human', 'classification': 'mammal', 'average_height': '180'},
    2: {
      'name': 'Droid',
      'classification': 'artificial',
      'average_height': '167',
    },
    3: {'name': 'Wookiee', 'classification': 'mammal', 'average_height': '210'},
    4: {
      'name': 'Rodian',
      'classification': 'sentient',
      'average_height': '170',
    },
    5: {'name': 'Hutt', 'classification': 'gastropod', 'average_height': '300'},
    6: {
      'name': 'Yoda\'s species',
      'classification': 'mammal',
      'average_height': '66',
    },
  };
}
