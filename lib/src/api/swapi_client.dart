/// SWAPI (Star Wars API) client — https://www.swapi.tech
///
/// Pulls real canonical Star Wars data (people, starships, planets) and
/// caches it in-memory. Falls back to a small built-in roster on failure
/// so the UI is never empty.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SwPerson {
  SwPerson({
    required this.name,
    required this.gender,
    required this.birthYear,
    required this.height,
    required this.mass,
    required this.eyeColor,
    required this.hairColor,
    required this.homeworld,
  });
  final String name;
  final String gender;
  final String birthYear;
  final String height;
  final String mass;
  final String eyeColor;
  final String hairColor;
  final String homeworld;

  factory SwPerson.fromJson(Map<String, dynamic> p) => SwPerson(
        name: (p['name'] as String?) ?? 'Unknown',
        gender: (p['gender'] as String?) ?? 'unknown',
        birthYear: (p['birth_year'] as String?) ?? 'unknown',
        height: (p['height'] as String?) ?? '?',
        mass: (p['mass'] as String?) ?? '?',
        eyeColor: (p['eye_color'] as String?) ?? 'unknown',
        hairColor: (p['hair_color'] as String?) ?? 'unknown',
        homeworld: (p['homeworld'] as String?) ?? '',
      );
}

class SwPlanet {
  SwPlanet({
    required this.name,
    required this.climate,
    required this.terrain,
    required this.population,
    required this.diameter,
    required this.gravity,
  });
  final String name;
  final String climate;
  final String terrain;
  final String population;
  final String diameter;
  final String gravity;

  factory SwPlanet.fromJson(Map<String, dynamic> p) => SwPlanet(
        name: (p['name'] as String?) ?? 'Unknown',
        climate: (p['climate'] as String?) ?? 'unknown',
        terrain: (p['terrain'] as String?) ?? 'unknown',
        population: (p['population'] as String?) ?? 'unknown',
        diameter: (p['diameter'] as String?) ?? '?',
        gravity: (p['gravity'] as String?) ?? '?',
      );
}

class SwStarship {
  SwStarship({
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.starshipClass,
    required this.crew,
    required this.hyperdrive,
    required this.maxSpeed,
  });
  final String name;
  final String model;
  final String manufacturer;
  final String starshipClass;
  final String crew;
  final String hyperdrive;
  final String maxSpeed;

  factory SwStarship.fromJson(Map<String, dynamic> p) => SwStarship(
        name: (p['name'] as String?) ?? 'Unknown',
        model: (p['model'] as String?) ?? '?',
        manufacturer: (p['manufacturer'] as String?) ?? '?',
        starshipClass: (p['starship_class'] as String?) ?? '?',
        crew: (p['crew'] as String?) ?? '?',
        hyperdrive: (p['hyperdrive_rating'] as String?) ?? '?',
        maxSpeed: (p['max_atmosphering_speed'] as String?) ?? '?',
      );
}

class SwapiClient {
  static const _base = 'https://www.swapi.tech/api';
  static const _timeout = Duration(seconds: 15);

  final Map<String, SwPerson> _peopleCache = {};
  final Map<String, SwPlanet> _planetCache = {};
  final Map<String, SwStarship> _starshipCache = {};

  Future<SwPerson> person(int id) async {
    final key = 'p$id';
    if (_peopleCache.containsKey(key)) return _peopleCache[key]!;
    try {
      final res = await http.get(Uri.parse('$_base/people/$id')).timeout(_timeout);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final props = ((json['result'] as Map?)?['properties'] as Map?)?.cast<String, dynamic>();
        if (props != null) {
          final p = SwPerson.fromJson(props);
          _peopleCache[key] = p;
          return p;
        }
      }
    } catch (e) {
      debugPrint('SWAPI person($id) error: $e');
    }
    final fb = _fallbackPeople[id] ?? _fallbackPeople[1]!;
    _peopleCache[key] = fb;
    return fb;
  }

  Future<SwPlanet> planet(int id) async {
    final key = 'pl$id';
    if (_planetCache.containsKey(key)) return _planetCache[key]!;
    try {
      final res = await http.get(Uri.parse('$_base/planets/$id')).timeout(_timeout);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final props = ((json['result'] as Map?)?['properties'] as Map?)?.cast<String, dynamic>();
        if (props != null) {
          final p = SwPlanet.fromJson(props);
          _planetCache[key] = p;
          return p;
        }
      }
    } catch (e) {
      debugPrint('SWAPI planet($id) error: $e');
    }
    final fb = _fallbackPlanets[id] ?? _fallbackPlanets[9]!;
    _planetCache[key] = fb;
    return fb;
  }

  Future<SwStarship> starship(int id) async {
    final key = 's$id';
    if (_starshipCache.containsKey(key)) return _starshipCache[key]!;
    try {
      final res = await http.get(Uri.parse('$_base/starships/$id')).timeout(_timeout);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final props = ((json['result'] as Map?)?['properties'] as Map?)?.cast<String, dynamic>();
        if (props != null) {
          final s = SwStarship.fromJson(props);
          _starshipCache[key] = s;
          return s;
        }
      }
    } catch (e) {
      debugPrint('SWAPI starship($id) error: $e');
    }
    final fb = _fallbackStarships[id] ?? _fallbackStarships[10]!;
    _starshipCache[key] = fb;
    return fb;
  }

  static final Map<int, SwPerson> _fallbackPeople = {
    1: SwPerson(name: 'Luke Skywalker', gender: 'male', birthYear: '19BBY', height: '172', mass: '77', eyeColor: 'blue', hairColor: 'blond', homeworld: 'Tatooine'),
    5: SwPerson(name: 'Leia Organa', gender: 'female', birthYear: '19BBY', height: '150', mass: '49', eyeColor: 'brown', hairColor: 'brown', homeworld: 'Alderaan'),
    14: SwPerson(name: 'Han Solo', gender: 'male', birthYear: '29BBY', height: '180', mass: '80', eyeColor: 'brown', hairColor: 'brown', homeworld: 'Corellia'),
    22: SwPerson(name: 'Boba Fett', gender: 'male', birthYear: '31.5BBY', height: '183', mass: '78.2', eyeColor: 'brown', hairColor: 'black', homeworld: 'Kamino'),
    44: SwPerson(name: 'Mon Mothma', gender: 'female', birthYear: '48BBY', height: '150', mass: 'unknown', eyeColor: 'blue', hairColor: 'auburn', homeworld: 'Chandrila'),
  };

  static final Map<int, SwPlanet> _fallbackPlanets = {
    1: SwPlanet(name: 'Tatooine', climate: 'arid', terrain: 'desert', population: '200000', diameter: '10465', gravity: '1 standard'),
    9: SwPlanet(name: 'Coruscant', climate: 'temperate', terrain: 'cityscape, mountains', population: '1000000000000', diameter: '12240', gravity: '1 standard'),
    10: SwPlanet(name: 'Kamino', climate: 'temperate', terrain: 'ocean', population: '1000000000', diameter: '19720', gravity: '1 standard'),
  };

  static final Map<int, SwStarship> _fallbackStarships = {
    10: SwStarship(name: 'Millennium Falcon', model: 'YT-1300 light freighter', manufacturer: 'Corellian Engineering Corp', starshipClass: 'Light freighter', crew: '4', hyperdrive: '0.5', maxSpeed: '1050'),
    12: SwStarship(name: 'X-wing', model: 'T-65 X-wing', manufacturer: 'Incom Corporation', starshipClass: 'Starfighter', crew: '1', hyperdrive: '1.0', maxSpeed: '1050'),
    15: SwStarship(name: 'Executor', model: 'Executor-class star dreadnought', manufacturer: 'Kuat Drive Yards', starshipClass: 'Star dreadnought', crew: '279144', hyperdrive: '2.0', maxSpeed: 'unknown'),
  };
}
