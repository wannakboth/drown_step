import 'package:flutter/material.dart';

enum Direction {
  north,
  east,
  south,
  west,
}

extension DirectionExtension on Direction {
  double get angleInRadians {
    switch (this) {
      case Direction.north:
        return 0.0;
      case Direction.east:
        return 1.5708; // 90 degrees
      case Direction.south:
        return 3.1416; // 180 degrees
      case Direction.west:
        return 4.7124; // 270 degrees
    }
  }

  Direction rotateRight() {
    return Direction.values[(index + 1) % 4];
  }

  Direction rotateLeft() {
    return Direction.values[(index - 1 + 4) % 4];
  }

  Offset get delta {
    switch (this) {
      case Direction.north:
        return const Offset(0, -1);
      case Direction.east:
        return const Offset(1, 0);
      case Direction.south:
        return const Offset(0, 1);
      case Direction.west:
        return const Offset(-1, 0);
    }
  }
}

class Obstacle {
  final int x;
  final int y;
  final int height; // If drone height > obstacle height, it can fly over it!

  const Obstacle({required this.x, required this.y, required this.height});
}

class EnergyCell {
  final int x;
  final int y;
  final int height; // Altitude needed to collect
  final int charge; // Battery restored upon collecting (e.g. 5)

  const EnergyCell({required this.x, required this.y, required this.height, this.charge = 5});
}

class Level {
  final int id;
  final String title;
  final String description;
  final int gridWidth;
  final int gridHeight;
  final int startX;
  final int startY;
  final Direction startDirection;
  final int boxX; // Cargo box X coordinate
  final int boxY; // Cargo box Y coordinate
  final int targetX;
  final int targetY;
  final int initialBattery;
  final List<Obstacle> obstacles;
  final List<EnergyCell> energyCells;
  final int star3Target; // Maximum commands allowed for 3 stars

  const Level({
    required this.id,
    required this.title,
    required this.description,
    required this.gridWidth,
    required this.gridHeight,
    required this.startX,
    required this.startY,
    required this.startDirection,
    required this.boxX,
    required this.boxY,
    required this.targetX,
    required this.targetY,
    required this.initialBattery,
    required this.obstacles,
    required this.energyCells,
    required this.star3Target,
  });

  // Predefined Levels
  static final List<Level> predefinedLevels = [
    Level(
      id: 1,
      title: 'FIRST LIFTOFF',
      description: 'Acquire the cargo box at (0, 3) and deliver it to the target pad at (0, 1).',
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 4,
      startDirection: Direction.north,
      boxX: 0,
      boxY: 3,
      targetX: 0,
      targetY: 1,
      initialBattery: 20,
      obstacles: [],
      energyCells: [],
      star3Target: 7,
    ),
    Level(
      id: 2,
      title: 'THE RIGHT PATH',
      description: 'Fly around buildings (height 1) to collect the cargo crate and deliver it to target.',
      gridWidth: 6,
      gridHeight: 6,
      startX: 0,
      startY: 5,
      startDirection: Direction.north,
      boxX: 0,
      boxY: 2,
      targetX: 5,
      targetY: 0,
      initialBattery: 30,
      obstacles: [
        Obstacle(x: 2, y: 3, height: 1),
        Obstacle(x: 3, y: 3, height: 1),
        Obstacle(x: 4, y: 3, height: 1),
      ],
      energyCells: [],
      star3Target: 13,
    ),
    Level(
      id: 3,
      title: 'OVER THE WALL',
      description: 'Ascend to fly over the obstacle wall to collect the cargo block and deliver to target.',
      gridWidth: 5,
      gridHeight: 7,
      startX: 2,
      startY: 6,
      startDirection: Direction.north,
      boxX: 2,
      boxY: 5,
      targetX: 2,
      targetY: 0,
      initialBattery: 25,
      obstacles: [
        Obstacle(x: 0, y: 3, height: 1),
        Obstacle(x: 1, y: 3, height: 1),
        Obstacle(x: 2, y: 3, height: 1),
        Obstacle(x: 3, y: 3, height: 1),
        Obstacle(x: 4, y: 3, height: 1),
      ],
      energyCells: [],
      star3Target: 11,
    ),
    Level(
      id: 4,
      title: 'POWER HARVEST',
      description: 'Collect the cargo and harvest floating energy cells to recharge battery on the way to the pad.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 7,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 7,
      targetX: 7,
      targetY: 0,
      initialBattery: 15,
      obstacles: [
        Obstacle(x: 4, y: 4, height: 1),
        Obstacle(x: 4, y: 5, height: 1),
      ],
      energyCells: [
        EnergyCell(x: 3, y: 7, height: 1, charge: 10),
        EnergyCell(x: 7, y: 4, height: 1, charge: 10),
      ],
      star3Target: 22,
    ),
    Level(
      id: 5,
      title: 'HEIGHT MATRIX',
      description: 'Climb elevations to collect the cargo box floating at height 3, then deliver it to target pad.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 6,
      startDirection: Direction.north,
      boxX: 2,
      boxY: 4,
      targetX: 6,
      targetY: 0,
      initialBattery: 35,
      obstacles: [
        Obstacle(x: 1, y: 4, height: 1),
        Obstacle(x: 2, y: 4, height: 2),
        Obstacle(x: 3, y: 4, height: 1),
        Obstacle(x: 4, y: 2, height: 2),
        Obstacle(x: 5, y: 2, height: 1),
      ],
      energyCells: [
        EnergyCell(x: 2, y: 4, height: 3, charge: 12),
      ],
      star3Target: 20,
    ),
  ];
}
