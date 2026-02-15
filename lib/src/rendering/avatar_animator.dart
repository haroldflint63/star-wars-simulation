import 'dart:math' as math;

/// Defines different activity types for agents
enum AgentActivity {
  idle,
  walking,
  working,
  sitting,
  eating,
  talking,
  thinking,
  fighting,
}

/// Determines activity based on location and event description
class ActivityDetector {
  static AgentActivity detectActivity(
    String locationId,
    String? eventDescription,
  ) {
    final desc = eventDescription?.toLowerCase() ?? '';

    // Check event description for activity keywords
    if (desc.contains('fighting') ||
        desc.contains('combat') ||
        desc.contains('battling') ||
        desc.contains('dueling') ||
        desc.contains('sparring') ||
        desc.contains('clashing')) {
      return AgentActivity.fighting;
    }
    if (desc.contains('training') ||
        desc.contains('practicing') ||
        desc.contains('honing') ||
        desc.contains('running')) {
      return AgentActivity.working;
    }
    if (desc.contains('meditating') ||
        desc.contains('studying') ||
        desc.contains('confronting') ||
        desc.contains('seeking')) {
      return AgentActivity.thinking;
    }
    if (desc.contains('heading') ||
        desc.contains('traveling') ||
        desc.contains('moving') ||
        desc.contains('going')) {
      return AgentActivity.walking;
    }
    if (desc.contains('strategizing') ||
        desc.contains('coordinating') ||
        desc.contains('planning') ||
        desc.contains('negotiating') ||
        desc.contains('gathering')) {
      return AgentActivity.talking;
    }
    if (desc.contains('fortifying') ||
        desc.contains('monitoring') ||
        desc.contains('organizing') ||
        desc.contains('preparing') ||
        desc.contains('infiltrating') ||
        desc.contains('sabotaging')) {
      return AgentActivity.working;
    }
    if (desc.contains('allying') ||
        desc.contains('recruiting') ||
        desc.contains('making deals') ||
        desc.contains('securing')) {
      return AgentActivity.talking;
    }

    // Default based on location (Star Wars themed)
    switch (locationId) {
      case 'jedi_temple':
        return AgentActivity.thinking; // Meditating with Force
      case 'dagobah_swamp':
        return AgentActivity.working; // Training
      case 'tatooine_cantina':
      case 'naboo_palace':
        return AgentActivity.talking; // Negotiations
      case 'cloud_city':
        return AgentActivity.sitting; // Diplomatic meeting
      case 'death_star':
        return AgentActivity.working; // Infiltration
      case 'endor_forest':
        return AgentActivity.working; // Preparing assault
      case 'hoth_base':
        return AgentActivity.working; // Operations
      default:
        return AgentActivity.idle;
    }
  }
}

/// Calculates animation values for different activities
class ActivityAnimator {
  /// Get animation offset for activity
  static Map<String, double> getAnimationValues(
    AgentActivity activity,
    double animValue,
  ) {
    switch (activity) {
      case AgentActivity.walking:
        return _walkingAnimation(animValue);
      case AgentActivity.fighting:
        return _fightingAnimation(animValue);
      case AgentActivity.working:
        return _workingAnimation(animValue);
      case AgentActivity.sitting:
        return _sittingAnimation(animValue);
      case AgentActivity.eating:
        return _eatingAnimation(animValue);
      case AgentActivity.talking:
        return _talkingAnimation(animValue);
      case AgentActivity.thinking:
        return _thinkingAnimation(animValue);
      case AgentActivity.idle:
        return _idleAnimation(animValue);
    }
  }

  static Map<String, double> _idleAnimation(double t) {
    return {
      'bobOffset': math.sin(t * 2 * math.pi) * 2,
      'leftArmAngle': math.sin(t * math.pi) * 0.05,
      'rightArmAngle': -math.sin(t * math.pi) * 0.05,
      'leftLegAngle': 0.0,
      'rightLegAngle': 0.0,
      'headTilt': math.sin(t * 2 * math.pi) * 0.05,
      'bodyRotation': 0.0,
    };
  }

  static Map<String, double> _walkingAnimation(double t) {
    return {
      'bobOffset': math.sin(t * 4 * math.pi) * 5,
      'leftArmAngle': math.sin(t * 2 * math.pi) * 0.3,
      'rightArmAngle': -math.sin(t * 2 * math.pi) * 0.3,
      'leftLegAngle': math.sin(t * 2 * math.pi) * 0.4,
      'rightLegAngle': -math.sin(t * 2 * math.pi) * 0.4,
      'headTilt': 0.0,
      'bodyRotation': math.sin(t * 4 * math.pi) * 0.02,
    };
  }

  static Map<String, double> _workingAnimation(double t) {
    // Typing motion
    return {
      'bobOffset': 0.0,
      'leftArmAngle': -0.6 + math.sin(t * 8 * math.pi) * 0.15,
      'rightArmAngle': -0.6 + math.sin((t * 8 + 0.5) * math.pi) * 0.15,
      'leftLegAngle': -0.3, // Sitting position
      'rightLegAngle': -0.3,
      'headTilt': -0.1 + math.sin(t * math.pi) * 0.05,
      'bodyRotation': 0.0,
    };
  }

  static Map<String, double> _sittingAnimation(double t) {
    return {
      'bobOffset': -10.0, // Lower to ground
      'leftArmAngle': math.sin(t * math.pi) * 0.1,
      'rightArmAngle': -math.sin(t * math.pi) * 0.1,
      'leftLegAngle': -0.5, // Bent legs
      'rightLegAngle': -0.5,
      'headTilt': math.sin(t * 2 * math.pi) * 0.08,
      'bodyRotation': 0.0,
    };
  }

  static Map<String, double> _eatingAnimation(double t) {
    // Hand to mouth motion
    final eatCycle = (t * 3) % 1.0;
    final handToMouth =
        eatCycle < 0.5
            ? math.sin(eatCycle * 2 * math.pi) * 0.8
            : 0.8 - (eatCycle - 0.5) * 1.6;

    return {
      'bobOffset': -5.0,
      'leftArmAngle': -0.2,
      'rightArmAngle': -handToMouth,
      'leftLegAngle': -0.4,
      'rightLegAngle': -0.4,
      'headTilt': handToMouth * 0.1,
      'bodyRotation': 0.0,
    };
  }

  static Map<String, double> _talkingAnimation(double t) {
    return {
      'bobOffset': math.sin(t * 3 * math.pi) * 3,
      'leftArmAngle': 0.2 + math.sin(t * 4 * math.pi) * 0.2,
      'rightArmAngle': -0.2 + math.sin((t * 4 + 0.3) * math.pi) * 0.2,
      'leftLegAngle': 0.0,
      'rightLegAngle': 0.0,
      'headTilt': math.sin(t * 5 * math.pi) * 0.1,
      'bodyRotation': math.sin(t * 2 * math.pi) * 0.05,
    };
  }

  static Map<String, double> _thinkingAnimation(double t) {
    return {
      'bobOffset': 0.0,
      'leftArmAngle': -0.3,
      'rightArmAngle': -0.8, // Hand to chin
      'leftLegAngle': 0.0,
      'rightLegAngle': 0.0,
      'headTilt': 0.1,
      'bodyRotation': 0.0,
    };
  }

  static Map<String, double> _fightingAnimation(double t) {
    // Dynamic combat animation with punch/kick cycles
    final combatCycle = (t * 4) % 1.0;
    final attackPhase = combatCycle < 0.5;

    return {
      'bobOffset': math.sin(t * 8 * math.pi) * 5 + (attackPhase ? -3 : 0),
      'leftArmAngle':
          attackPhase
              ? -1.2 +
                  math.sin(t * 12 * math.pi) *
                      0.3 // Punching
              : 0.6, // Guard position
      'rightArmAngle':
          !attackPhase
              ? -1.2 +
                  math.sin(t * 12 * math.pi) *
                      0.3 // Punching
              : 0.6, // Guard position
      'leftLegAngle': math.sin(t * 10 * math.pi) * 0.6, // Dynamic footwork
      'rightLegAngle': -math.sin(t * 10 * math.pi) * 0.6,
      'headTilt': math.sin(t * 6 * math.pi) * 0.15, // Dodging
      'bodyRotation':
          math.sin(t * 8 * math.pi) * 0.2, // Body rotation for attacks
    };
  }
}
