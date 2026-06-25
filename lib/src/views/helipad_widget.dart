import 'dart:math' as math;
import 'package:flutter/material.dart';

class HelipadWidget extends StatelessWidget {
  final double size;

  const HelipadWidget({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // Stack structure:
    // - 8 layers representing the green volumetric base.
    // - Side wall colors: a nice shaded green, e.g. Color(0xFF1B5E20) for dark forest green, with Color(0xFF0F3D13) border.
    // - Top surface layer: Color(0xFF3BA756) (vibrant grass green).
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(8, (i) {
          final zVal = i * 1.0; // 1px offset per layer for thickness
          final isTop = i == 7;

          // Shading: lower layers are darker, top layer is bright grass green
          final Color baseColor = isTop
              ? const Color(0xFF3BA756) // Lighter vibrant grass green
              : const Color(0xFF1B5E20); // Dark forest green

          final Color borderColor = isTop
              ? const Color(0xFF76D18C) // Highlight border
              : const Color(0xFF0F3D13); // Darker shadow border

          return Transform(
            transform: Matrix4.translationValues(0, 0, zVal),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor,
                border: Border.all(
                  color: borderColor,
                  width: isTop ? 2.5 : 1.0,
                ),
              ),
              child: isTop ? _buildTopFace(context) : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTopFace(BuildContext context) {
    // The top face contains:
    // - A thick white ring.
    // - 6 red beacons positioned symmetrically around the white ring.
    // - A yellow inner ring.
    // - A bold white 'H' in the center.
    final whiteRingSize = size * 0.84;
    final yellowRingSize = size * 0.54;
    
    // Center of the white ring is size * 0.38
    final beaconRingRadius = size * 0.38;
    final beaconSize = size * 0.09; // size of each red beacon light

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 1. Thick White Ring
        Container(
          width: whiteRingSize,
          height: whiteRingSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: size * 0.08,
            ),
          ),
        ),

        // 2. Yellow Inner Ring
        Container(
          width: yellowRingSize,
          height: yellowRingSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFEB3B), // Yellow
              width: size * 0.045,
            ),
          ),
        ),

        // 3. Bold White 'H' in the center
        Center(
          child: Text(
            'H',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.30,
              fontWeight: FontWeight.w900,
              fontFamily: 'Roboto', // Use a standard system sans-serif font
            ),
          ),
        ),

        // 4. Six Red Beacons (Equally Spaced on the White Ring)
        // Positioned using Trigonometry around the center of the white ring
        ...List.generate(6, (index) {
          // Angles: 0, 60, 120, 180, 240, 300 degrees
          final angle = index * math.pi / 3;
          final dx = beaconRingRadius * math.cos(angle);
          final dy = beaconRingRadius * math.sin(angle);

          return Positioned(
            left: (size / 2) + dx - (beaconSize / 2),
            top: (size / 2) + dy - (beaconSize / 2),
            child: _buildRedBeacon(beaconSize),
          );
        }),
      ],
    );
  }

  Widget _buildRedBeacon(double beaconSize) {
    // Build a tiny 3D red dome (4 Z-layers for 3D appearance)
    return SizedBox(
      width: beaconSize,
      height: beaconSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(4, (i) {
          // Scale Z height and dome diameter proportionally to prevent negative sizing assertions
          final zVal = i * (beaconSize * 0.15);
          final scaleFactor = 1.0 - (i * 0.15);
          final isTop = i == 3;

          return Transform(
            transform: Matrix4.translationValues(0, 0, zVal),
            child: Container(
              width: beaconSize * scaleFactor,
              height: beaconSize * scaleFactor,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isTop
                    ? const RadialGradient(
                        colors: [
                          Color(0xFFFF8A80), // Bright light highlight
                          Color(0xFFE53935), // Pure Red
                          Color(0xFFB71C1C), // Dark Red edge
                        ],
                        stops: [0.1, 0.6, 1.0],
                        center: Alignment(-0.3, -0.3),
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFFB71C1C),
                          Color(0xFF7F0000),
                        ],
                      ),
                border: Border.all(
                  color: isTop ? const Color(0xFF5F0000) : Colors.transparent,
                  width: 0.5,
                ),
                boxShadow: isTop
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF5252).withValues(alpha: 0.6),
                          blurRadius: 3,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
