import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../world.dart';
import '../agent.dart';
import '../star_wars_api.dart';
import '../rendering/sci_fi_design_system.dart';
import '../rendering/premium_building_painter.dart';
import 'premium_ui_components.dart';

/// Cinematic Galaxy Map Screen - LEGO Star Wars Style
class GalaxyMapScreen extends StatefulWidget {
  final List<Location> locations;
  final List<Agent> agents;
  final ValueChanged<Location>? onLocationSelected;

  const GalaxyMapScreen({
    super.key,
    required this.locations,
    required this.agents,
    this.onLocationSelected,
  });

  @override
  State<GalaxyMapScreen> createState() => _GalaxyMapScreenState();
}

class _GalaxyMapScreenState extends State<GalaxyMapScreen> {
  Location? _selectedLocation;
  final Map<String, Map<String, dynamic>> _planetData = {};

  @override
  void initState() {
    super.initState();
    _loadPlanetData();

    // Select first location by default
    if (widget.locations.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _selectLocation(widget.locations.first);
        }
      });
    }
  }

  Future<void> _loadPlanetData() async {
    for (final location in widget.locations) {
      try {
        final layoutData = StarWarsAPI.getGalacticLayout();
        final data = layoutData[location.id] as Map<String, dynamic>?;
        if (data != null) {
          final planetId = data['planet_id'] as int;
          if (planetId > 0) {
            final planetInfo = await StarWarsAPI.getPlanet(planetId);
            if (mounted) {
              setState(() {
                _planetData[location.id] = planetInfo;
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading planet data for ${location.id}: $e');
      }
    }
  }

  void _selectLocation(Location location) {
    setState(() {
      _selectedLocation = location;
    });
    widget.onLocationSelected?.call(location);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            SciFiDesignSystem.spaceDeep,
            SciFiDesignSystem.spaceMid,
            Colors.black,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Premium starfield background
          const StarfieldBackground(starCount: 150),

          // Planet nodes
          ..._buildPlanetNodes(),

          // Selected planet mission card
          if (_selectedLocation != null)
            Positioned(
              right: 40,
              top: 100,
              child: _buildMissionCard(_selectedLocation!),
            ),

          // Galaxy title
          Positioned(top: 40, left: 40, child: _buildGalaxyTitle()),
        ],
      ),
    );
  }

  List<Widget> _buildPlanetNodes() {
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(size.width, size.height) * 0.35;

    return List.generate(widget.locations.length, (index) {
      final location = widget.locations[index];
      final angle = (index / widget.locations.length) * 2 * math.pi;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);

      final isSelected = _selectedLocation?.id == location.id;
      final buildingStyle = _getBuildingStyle(location.id);
      final planetColor = _getPlanetColor(location.id);

      return Positioned(
        left: x - 60,
        top: y - 90,
        child: GalaxyBuildingMarker(
          locationName: location.label,
          style: buildingStyle,
          accentColor: planetColor,
          isSelected: isSelected,
          onTap: () => _selectLocation(location),
        ),
      );
    });
  }

  BuildingStyle _getBuildingStyle(String locationId) {
    switch (locationId) {
      case 'tatooine_cantina':
        return BuildingStyle.dome;
      case 'hoth_base':
        return BuildingStyle.cube;
      case 'cloud_city':
        return BuildingStyle.spire;
      case 'jedi_temple':
        return BuildingStyle.spire;
      case 'dagobah_swamp':
        return BuildingStyle.tower;
      case 'naboo_palace':
        return BuildingStyle.spire;
      case 'endor_forest':
        return BuildingStyle.cube;
      case 'death_star':
        return BuildingStyle.dome;
      default:
        return BuildingStyle.tower;
    }
  }

  Color _getPlanetColor(String locationId) {
    switch (locationId) {
      case 'tatooine_cantina':
        return const Color(0xFFD4A574);
      case 'hoth_base':
        return const Color(0xFFADD8E6);
      case 'dagobah_swamp':
        return const Color(0xFF2E8B57);
      case 'cloud_city':
        return const Color(0xFFFFD700);
      case 'jedi_temple':
        return const Color(0xFF4169E1);
      case 'naboo_palace':
        return const Color(0xFFDDA0DD);
      case 'endor_forest':
        return const Color(0xFF228B22);
      case 'death_star':
        return const Color(0xFF708090);
      default:
        return SciFiDesignSystem.accentPrimary;
    }
  }

  Widget _buildGalaxyTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SciFiDesignSystem.space24,
        vertical: SciFiDesignSystem.space16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SciFiDesignSystem.spaceDeep.withValues(alpha: 0.8),
            SciFiDesignSystem.spaceDeep.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(SciFiDesignSystem.radiusLarge),
        border: Border.all(
          color: SciFiDesignSystem.accentPrimary.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [SciFiDesignSystem.ambientOcclusion(intensity: 0.4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GALAXY MAP',
            style: SciFiDesignSystem.titleHero.copyWith(fontSize: 28),
          ),
          const SizedBox(height: SciFiDesignSystem.space4),
          Text('Star Wars Galaxy', style: SciFiDesignSystem.labelSecondary),
        ],
      ),
    );
  }

  Widget _buildMissionCard(Location location) {
    final planetData = _planetData[location.id];
    final agents = widget.agents;
    final planetColor = _getPlanetColor(location.id);

    return Container(
      width: 350,
      padding: const EdgeInsets.all(SciFiDesignSystem.space24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SciFiDesignSystem.spaceDeep.withValues(alpha: 0.95),
            SciFiDesignSystem.spaceMid.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(SciFiDesignSystem.radiusLarge),
        border: Border.all(color: planetColor.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          SciFiDesignSystem.ambientOcclusion(),
          ...SciFiDesignSystem.neonGlow(color: planetColor, intensity: 0.3),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Location name
          Text(
            location.label.toUpperCase(),
            style: SciFiDesignSystem.titleSection.copyWith(
              color: planetColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: SciFiDesignSystem.space16),

          // Planet info
          if (planetData != null) ...[
            _buildInfoRow('Climate', planetData['climate'] ?? 'Unknown'),
            _buildInfoRow('Terrain', planetData['terrain'] ?? 'Unknown'),
            _buildInfoRow('Population', planetData['population'] ?? 'Unknown'),
            const SizedBox(height: SciFiDesignSystem.space16),
          ],

          // Agents list
          Text(
            'ACTIVE AGENTS',
            style: SciFiDesignSystem.labelPrimary.copyWith(
              fontSize: 12,
              color: SciFiDesignSystem.neutralLight,
            ),
          ),
          const SizedBox(height: SciFiDesignSystem.space8),
          ...agents.map(
            (agent) => Padding(
              padding: const EdgeInsets.only(bottom: SciFiDesignSystem.space8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: SciFiDesignSystem.success,
                      shape: BoxShape.circle,
                      boxShadow: SciFiDesignSystem.neonGlow(
                        color: SciFiDesignSystem.success,
                        intensity: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: SciFiDesignSystem.space12),
                  Text(
                    agent.profile.displayName,
                    style: SciFiDesignSystem.labelSecondary.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SciFiDesignSystem.space8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label.toUpperCase(),
              style: SciFiDesignSystem.labelMicro.copyWith(
                color: SciFiDesignSystem.neutralMid,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: SciFiDesignSystem.labelSecondary.copyWith(
                color: SciFiDesignSystem.neutralBright,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
