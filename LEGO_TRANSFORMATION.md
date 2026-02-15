# LEGO Avatar Transformation

## Overview
Characters have been transformed from detailed realistic figures into LEGO minifigure style with blocky shapes, cylindrical heads, and simplified features.

## LEGO Minifigure Characteristics

### 🟡 **Head**
- **Cylindrical shape** with rounded corners (RRect with radius 2)
- **Yellow LEGO skin color** (#FFD700) - classic minifig yellow
- **Stud on top** - iconic LEGO head stud (2.5px radius)
- **Printed face**:
  - Simple black dot eyes (1.2px radius)
  - Curved smile (arc drawing)
  - No detailed features - just printed design

### 🧱 **Torso**
- **Blocky rectangular body** (18px width x 20px height)
- **Rounded corners** (2px radius) for LEGO brick aesthetic
- **Printed designs** instead of 3D clothing:
  - Luke: White tunic with belt print
  - Leia: White robe with grey belt
  - Han: Cream shirt with black vest print
- **Belt prints** as flat rectangles (authentic LEGO printing style)

### 💪 **Arms**
- **Cylindrical tubes** (5px width x 12px height)
- **Rounded ends** (2.5px radius) for authentic LEGO arm shape
- **Yellow LEGO hands** instead of skin-tone hands
- **Claw-shaped hands** (6px width x 5px height)
- **Color-matched to torso** (white, cream, etc.)
- **Rotation at shoulder** for natural movement

### 🦵 **Legs**
- **Simple rectangles** (7px width x 18px height)
- **Joint line at knee** (subtle black line at 9px)
- **Rounded corners** (1px radius)
- **Color-coded**:
  - Luke: Blue (#0055AA)
  - Leia: White
  - Han: Dark blue (#1a1a4d)
- **No boots** - LEGO minifigs have integrated legs

## Character-Specific Details

### Luke Skywalker
- Yellow cylindrical head with stud
- White torso with grey belt print
- Blue legs
- Blue lightsaber accessory
- Simple printed face

### Princess Leia
- Yellow cylindrical head
- **Brown hair buns** as circular studs (5px radius) on sides of head
- White robe torso with grey belt
- White legs
- Blaster accessory

### Han Solo
- Yellow cylindrical head
- **Brown LEGO hair piece** (14px width x 8px height, rounded)
- Cream torso with black vest print (side panels)
- Dark blue legs with brown belt print
- Blaster accessory

## Floor Enhancement - LEGO Baseplate

### 🟦 **LEGO Stud Floor**
- **40px grid spacing** - standard LEGO stud pattern
- **Circular studs** (3px radius) at each grid intersection
- **Dark grey/blue color** (#3A4A5A) with transparency
- **Stud highlights** for 3D depth effect
- **Subtle grid lines** connecting studs
- **Only renders visible studs** (performance optimization)

### Visual Features
- Grid from -2000 to +2000 in both X and Z
- Isometric projection respects camera angle
- Studs have highlight offset (-0.5, -0.5) for 3D appearance
- Transparent overlay (0.3-0.4 alpha) doesn't obscure space background

## Technical Implementation

### New LEGO Drawing Methods

```dart
_drawLegoLeg(canvas, pos, offsetX, angle, color)
```
- Draws blocky rectangular leg with joint line
- Uses RRect for rounded corners
- Single color (no boot separation)

```dart
_drawLegoArm(canvas, pos, offsetX, angle, color)
```
- Cylindrical arm with rounded profile
- Yellow LEGO hand claw
- Rotates at shoulder for animations

```dart
_drawLegoHead(canvas, pos, color, isLuke)
```
- Cylindrical head with stud on top
- Printed face (dots for eyes, arc for smile)
- Classic LEGO yellow color
- RRect for rounded rectangular shape

```dart
_drawLegoFloor(canvas, size)
```
- Iterates grid of studs (40px spacing)
- Draws circles for stud tops
- Adds highlights for 3D effect
- Connects with subtle grid lines
- Performance: Only renders visible studs

### Animation Compatibility
- All LEGO parts retain original animation system
- Arms still rotate with `leftArmAngle` / `rightArmAngle`
- Legs still swing with `leftLegAngle` / `rightLegAngle`
- Body still bobs with `bodyBob`
- Activity-specific poses preserved

## Benefits

✅ **Iconic LEGO aesthetic** - Instantly recognizable minifigure style  
✅ **Simplified rendering** - Blocky shapes are faster to draw  
✅ **Clean visual style** - Matches professional LEGO games  
✅ **Maintains animations** - All movement preserved  
✅ **Authentic details** - Head studs, printed torsos, yellow hands  
✅ **LEGO baseplate floor** - Complete LEGO environment  
✅ **Character variety** - Each minifig has unique prints and accessories  

## Color Palette

**LEGO Yellow**: #FFD700 (heads, hands)  
**White**: #FFFFFF (Luke/Leia torsos)  
**Blue**: #0055AA (Luke legs)  
**Dark Blue**: #1a1a4d (Han legs)  
**Brown**: #3E2723 (Han hair)  
**Tan/Cream**: #F5F5DC (Han torso)  
**Dark Brown**: #4A2511 (Leia hair buns)  
**Floor Grey**: #3A4A5A (baseplate studs)  

## Future Enhancements

- Add more LEGO hair pieces (helmets, caps, etc.)
- Implement LEGO vehicle accessories
- Add LEGO brick buildings instead of realistic ones
- Weapon accessories (lightsabers as separate LEGO pieces)
- LEGO-style shadows (blocky, not realistic)
- Snap-to-grid movement (LEGO stud alignment)
