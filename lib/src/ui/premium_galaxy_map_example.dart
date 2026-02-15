import 'package:flutter/material.dart';
import '../rendering/sci_fi_design_system.dart';
import '../rendering/premium_building_painter.dart';
import 'premium_ui_components.dart';

/// Example screen showcasing premium building system
/// Demonstrates studio-quality sci-fi aesthetic
class PremiumGalaxyMapExample extends StatefulWidget {
  const PremiumGalaxyMapExample({super.key});

  @override
  State<PremiumGalaxyMapExample> createState() =>
      _PremiumGalaxyMapExampleState();
}

class _PremiumGalaxyMapExampleState extends State<PremiumGalaxyMapExample> {
  int _selectedBuildingIndex = 0;

  final List<_BuildingData> _buildings = [
    _BuildingData(
      name: 'Tatooine Outpost',
      style: BuildingStyle.tower,
      color: const Color(0xFFD4A574),
      x: 200,
      y: 300,
    ),
    _BuildingData(
      name: 'Cloud City',
      style: BuildingStyle.dome,
      color: const Color(0xFFFFD700),
      x: 500,
      y: 200,
    ),
    _BuildingData(
      name: 'Hoth Base',
      style: BuildingStyle.cube,
      color: const Color(0xFFADD8E6),
      x: 800,
      y: 350,
    ),
    _BuildingData(
      name: 'Jedi Temple',
      style: BuildingStyle.spire,
      color: const Color(0xFF4169E1),
      x: 350,
      y: 450,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
            // Layer 1: Starfield background
            const Positioned.fill(child: StarfieldBackground(starCount: 150)),

            // Layer 2: Buildings
            ..._buildings.asMap().entries.map((entry) {
              final index = entry.key;
              final building = entry.value;
              final isSelected = index == _selectedBuildingIndex;

              return Positioned(
                left: building.x,
                top: building.y,
                child: GalaxyBuildingMarker(
                  locationName: building.name,
                  style: building.style,
                  accentColor: building.color,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedBuildingIndex = index;
                    });
                  },
                ),
              );
            }),

            // Layer 3: Mission callout (for selected building)
            if (_selectedBuildingIndex >= 0)
              Positioned(
                right: 40,
                top: 100,
                child: MissionCalloutBubble(
                  title: _buildings[_selectedBuildingIndex].name,
                  description:
                      'Strategic location in the Outer Rim. High priority target.',
                  icon: Icons.location_on,
                  accentColor: _buildings[_selectedBuildingIndex].color,
                ),
              ),

            // Layer 4: Header
            Positioned(top: 40, left: 40, child: _buildHeader()),

            // Layer 5: Bottom HUD
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomHUD()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          Text(
            'Premium Building System Demo',
            style: SciFiDesignSystem.labelSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHUD() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SciFiDesignSystem.spaceDeep.withValues(alpha: 0.0),
            SciFiDesignSystem.spaceDeep.withValues(alpha: 0.95),
          ],
        ),
        border: const Border(
          top: BorderSide(color: SciFiDesignSystem.accentPrimary, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SciFiDesignSystem.space24,
          vertical: SciFiDesignSystem.space16,
        ),
        child: Row(
          children: [
            // Building count
            _buildStatBox(
              label: 'LOCATIONS',
              value: '${_buildings.length}',
              icon: Icons.apartment,
            ),
            const SizedBox(width: SciFiDesignSystem.space24),

            // Selected building
            _buildStatBox(
              label: 'SELECTED',
              value: _buildings[_selectedBuildingIndex].name,
              icon: Icons.check_circle_outline,
              accentColor: _buildings[_selectedBuildingIndex].color,
            ),

            const Spacer(),

            // Action buttons
            _buildActionButton(
              label: 'ZOOM IN',
              icon: Icons.zoom_in,
              onPressed: () {},
            ),
            const SizedBox(width: SciFiDesignSystem.space12),
            _buildActionButton(
              label: 'DETAILS',
              icon: Icons.info_outline,
              onPressed: () {},
              isPrimary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required IconData icon,
    Color accentColor = SciFiDesignSystem.accentPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SciFiDesignSystem.space16,
        vertical: SciFiDesignSystem.space8,
      ),
      decoration: BoxDecoration(
        color: SciFiDesignSystem.neutralDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(SciFiDesignSystem.radiusMedium),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: SciFiDesignSystem.space8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: SciFiDesignSystem.labelMicro),
              Text(
                value,
                style: SciFiDesignSystem.labelPrimary.copyWith(
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(SciFiDesignSystem.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SciFiDesignSystem.space16,
            vertical: SciFiDesignSystem.space12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  isPrimary
                      ? [
                        SciFiDesignSystem.accentPrimary.withValues(alpha: 0.4),
                        SciFiDesignSystem.accentPrimary.withValues(alpha: 0.2),
                      ]
                      : [
                        SciFiDesignSystem.neutralDark.withValues(alpha: 0.6),
                        SciFiDesignSystem.neutralDark.withValues(alpha: 0.4),
                      ],
            ),
            borderRadius: BorderRadius.circular(SciFiDesignSystem.radiusMedium),
            border: Border.all(
              color:
                  isPrimary
                      ? SciFiDesignSystem.accentPrimary
                      : SciFiDesignSystem.neutralMid,
              width: 1.5,
            ),
            boxShadow:
                isPrimary
                    ? SciFiDesignSystem.neonGlow(
                      color: SciFiDesignSystem.accentPrimary,
                      intensity: 0.3,
                    )
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    isPrimary ? Colors.white : SciFiDesignSystem.neutralLight,
                size: 18,
              ),
              const SizedBox(width: SciFiDesignSystem.space8),
              Text(
                label,
                style: SciFiDesignSystem.labelSecondary.copyWith(
                  color:
                      isPrimary ? Colors.white : SciFiDesignSystem.neutralLight,
                  fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildingData {
  final String name;
  final BuildingStyle style;
  final Color color;
  final double x;
  final double y;

  _BuildingData({
    required this.name,
    required this.style,
    required this.color,
    required this.x,
    required this.y,
  });
}
