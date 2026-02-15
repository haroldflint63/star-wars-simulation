import 'dart:math' as math;
import 'memory.dart';
import 'planner.dart';
import 'relationships.dart';
import 'world.dart';

/// Plans agent movements based on task-relevant locations
class TaskAwarePlanner implements Planner {
  TaskAwarePlanner({Planner? fallback})
    : fallback = fallback ?? const HeuristicPlanner();

  final Planner fallback;

  // Track which locations agents have visited for task rotation
  final Map<String, List<String>> _visitHistory = {};
  final Map<String, int> _lastVisitTick = {};

  // Define task-relevant locations for each type of goal
  static final Map<String, List<String>> _taskLocations = {
    'force': ['jedi_temple', 'dagobah_swamp', 'endor_forest'],
    'leadership': ['naboo_palace', 'hoth_base', 'cloud_city'],
    'rebellion': ['naboo_palace', 'hoth_base', 'endor_forest'],
    'pilot': ['tatooine_cantina', 'cloud_city', 'hoth_base'],
    'trade': ['tatooine_cantina', 'cloud_city', 'naboo_palace'],
    'combat': ['death_star', 'hoth_base', 'endor_forest'],
    'fighting': ['death_star', 'endor_forest', 'jedi_temple'],
    'diplomacy': ['naboo_palace', 'cloud_city', 'jedi_temple'],
    'smuggling': ['tatooine_cantina', 'cloud_city', 'death_star'],
  };

  @override
  Future<PlanAction> nextAction({
    required WorldSnapshot snapshot,
    required MemoryStore memory,
    required String agentId,
    required String primaryGoal,
    required String fallbackLocationId,
    required List<RelationshipSignal> socialSignals,
  }) async {
    // Determine task category from goal
    final taskCategory = _categorizeGoal(primaryGoal);
    final relevantLocations = _taskLocations[taskCategory] ?? [];

    if (relevantLocations.isEmpty) {
      return fallback.nextAction(
        snapshot: snapshot,
        memory: memory,
        agentId: agentId,
        primaryGoal: primaryGoal,
        fallbackLocationId: fallbackLocationId,
        socialSignals: socialSignals,
      );
    }

    // Get current location
    final currentLocation = _getCurrentLocation(
      snapshot,
      agentId,
      fallbackLocationId,
    );

    // Initialize visit history
    if (!_visitHistory.containsKey(agentId)) {
      _visitHistory[agentId] = [];
    }

    final visitHistory = _visitHistory[agentId]!;
    final lastVisitTick = _lastVisitTick[agentId] ?? 0;
    final ticksSinceLastMove = snapshot.tick - lastVisitTick;

    // Stay at location for at least 5 ticks to "work" there
    if (ticksSinceLastMove < 5) {
      return PlanAction(
        locationId: currentLocation,
        description: _generateWorkDescription(
          currentLocation,
          primaryGoal,
          taskCategory,
        ),
      );
    }

    // Time to move to next location
    String nextLocation = _selectNextLocation(
      relevantLocations,
      visitHistory,
      currentLocation,
      socialSignals,
      snapshot,
    );

    // Update visit history
    if (nextLocation != currentLocation) {
      visitHistory.add(nextLocation);
      if (visitHistory.length > 10) {
        visitHistory.removeAt(0); // Keep history manageable
      }
      _lastVisitTick[agentId] = snapshot.tick;
    }

    return PlanAction(
      locationId: nextLocation,
      description: _generateMovementDescription(
        nextLocation,
        primaryGoal,
        taskCategory,
        socialSignals,
      ),
    );
  }

  String _categorizeGoal(String goal) {
    final lowerGoal = goal.toLowerCase();

    if (lowerGoal.contains('force') ||
        lowerGoal.contains('jedi') ||
        lowerGoal.contains('balance')) {
      return 'force';
    } else if (lowerGoal.contains('rebellion') ||
        lowerGoal.contains('resist')) {
      return 'rebellion';
    } else if (lowerGoal.contains('lead') || lowerGoal.contains('command')) {
      return 'leadership';
    } else if (lowerGoal.contains('kessel') ||
        lowerGoal.contains('smuggl') ||
        lowerGoal.contains('credits')) {
      return 'smuggling';
    } else if (lowerGoal.contains('fight') ||
        lowerGoal.contains('combat') ||
        lowerGoal.contains('defeat')) {
      return 'combat';
    } else if (lowerGoal.contains('trade') || lowerGoal.contains('merchant')) {
      return 'trade';
    } else if (lowerGoal.contains('diplomat') || lowerGoal.contains('peace')) {
      return 'diplomacy';
    }

    return 'force'; // Default
  }

  String _getCurrentLocation(
    WorldSnapshot snapshot,
    String agentId,
    String fallback,
  ) {
    // Find most recent event for this agent
    for (final event in snapshot.recentEvents.reversed) {
      if (event.actorId == agentId) {
        return event.locationId;
      }
    }
    return fallback;
  }

  String _selectNextLocation(
    List<String> relevantLocations,
    List<String> visitHistory,
    String currentLocation,
    List<RelationshipSignal> socialSignals,
    WorldSnapshot snapshot,
  ) {
    // If there's a friend at another location, consider visiting them
    if (socialSignals.isNotEmpty) {
      final friendId = socialSignals.first.otherAgentId;
      final friendLocation = _getCurrentLocation(snapshot, friendId, '');

      if (friendLocation.isNotEmpty &&
          relevantLocations.contains(friendLocation) &&
          friendLocation != currentLocation) {
        // 30% chance to go visit friend
        if (math.Random().nextDouble() < 0.3) {
          return friendLocation;
        }
      }
    }

    // Find least visited relevant location
    final unvisitedLocations =
        relevantLocations.where((loc) {
          return !visitHistory.contains(loc) && loc != currentLocation;
        }).toList();

    if (unvisitedLocations.isNotEmpty) {
      return unvisitedLocations[math.Random().nextInt(
        unvisitedLocations.length,
      )];
    }

    // All locations visited, pick one that's not current
    final otherLocations =
        relevantLocations.where((loc) => loc != currentLocation).toList();
    if (otherLocations.isEmpty) {
      return relevantLocations[0];
    }

    return otherLocations[math.Random().nextInt(otherLocations.length)];
  }

  String _generateWorkDescription(
    String locationId,
    String goal,
    String taskCategory,
  ) {
    final actions = _getLocationActions(locationId, taskCategory);
    final action = actions[math.Random().nextInt(actions.length)];
    return '$action to advance: "$goal"';
  }

  String _generateMovementDescription(
    String locationId,
    String goal,
    String taskCategory,
    List<RelationshipSignal> socialSignals,
  ) {
    final locationName = _getLocationName(locationId);

    if (socialSignals.isNotEmpty && math.Random().nextDouble() < 0.3) {
      return 'Traveling to $locationName to coordinate with ${socialSignals.first.otherAgentId}';
    }

    final purposes = _getLocationPurposes(locationId, taskCategory);
    final purpose = purposes[math.Random().nextInt(purposes.length)];
    return 'Heading to $locationName to $purpose';
  }

  List<String> _getLocationActions(String locationId, String taskCategory) {
    switch (locationId) {
      case 'jedi_temple':
        return [
          'Training in lightsaber forms',
          'Meditating on the Force',
          'Studying ancient Jedi texts',
          'Practicing Force techniques',
          'Sparring with training droids',
        ];
      case 'dagobah_swamp':
        return [
          'Training with Yoda',
          'Practicing Force discipline',
          'Confronting inner darkness',
          'Honing Force abilities',
          'Combat meditation',
        ];
      case 'naboo_palace':
        return [
          'Strategizing with allies',
          'Coordinating rebellion efforts',
          'Planning diplomatic missions',
          'Organizing resources',
        ];
      case 'hoth_base':
        return [
          'Fortifying defenses',
          'Running combat drills',
          'Coordinating evacuation plans',
          'Monitoring Imperial movements',
          'Fighting off probe droids',
        ];
      case 'tatooine_cantina':
        return [
          'Gathering intelligence',
          'Recruiting smugglers',
          'Making deals',
          'Finding transport',
          'Bar fight with bounty hunters',
        ];
      case 'cloud_city':
        return [
          'Negotiating with Lando',
          'Securing safe passage',
          'Trading equipment',
          'Refueling ships',
        ];
      case 'death_star':
        return [
          'Infiltrating Imperial base',
          'Sabotaging systems',
          'Gathering intelligence',
          'Rescuing prisoners',
          'Fighting stormtroopers',
          'Dueling Sith Lords',
        ];
      case 'endor_forest':
        return [
          'Allying with Ewoks',
          'Preparing assault',
          'Setting up ambushes',
          'Scouting shield generator',
          'Combat training with rebels',
        ];
      default:
        return ['Working on mission objectives'];
    }
  }

  List<String> _getLocationPurposes(String locationId, String taskCategory) {
    switch (locationId) {
      case 'jedi_temple':
        return ['train in the Force', 'seek Jedi wisdom', 'meditate'];
      case 'dagobah_swamp':
        return ['continue Force training', 'seek guidance from Yoda'];
      case 'naboo_palace':
        return ['coordinate with leadership', 'plan strategy', 'gather allies'];
      case 'hoth_base':
        return ['prepare defenses', 'organize troops', 'plan operations'];
      case 'tatooine_cantina':
        return ['gather intel', 'find allies', 'make deals'];
      case 'cloud_city':
        return ['negotiate passage', 'resupply', 'meet contacts'];
      case 'death_star':
        return ['infiltrate enemy base', 'sabotage operations'];
      case 'endor_forest':
        return ['prepare assault', 'ally with locals', 'scout targets'];
      default:
        return ['complete mission'];
    }
  }

  String _getLocationName(String locationId) {
    final names = {
      'jedi_temple': 'Jedi Temple',
      'dagobah_swamp': 'Dagobah',
      'naboo_palace': 'Naboo Palace',
      'hoth_base': 'Echo Base',
      'tatooine_cantina': 'Mos Eisley Cantina',
      'cloud_city': 'Cloud City',
      'death_star': 'Death Star',
      'endor_forest': 'Endor',
    };
    return names[locationId] ?? locationId;
  }
}
