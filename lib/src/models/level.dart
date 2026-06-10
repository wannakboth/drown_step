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
  final String? hint;
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
    this.hint,
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
  // Predefined Levels
  static final List<Level> predefinedLevels = [
    Level(
      id: 1,
      title: 'FIRST LIFTOFF',
      description: 'Acquire the cargo box at (0, 2) and deliver it to the target pad at (0, 0).',
      hint: 'Use [Takeoff], [Move Forward] twice to reach the box, then [Land] to pick it up. Takeoff again, move forward twice, and [Land] to finish.',
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 4,
      startDirection: Direction.north,
      boxX: 0,
      boxY: 2,
      targetX: 0,
      targetY: 0,
      initialBattery: 20,
      obstacles: [],
      energyCells: [],
      star3Target: 8,
    ),
    Level(
      id: 2,
      title: 'TURNING PRACTICE',
      description: 'Rotate to the right, collect the cargo box, rotate right again, and deliver to the pad.',
      hint: 'Yaw right at the start, fly to the cargo box, pick it up, yaw right again, and fly to the landing pad.',
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 4,
      startDirection: Direction.north,
      boxX: 2,
      boxY: 4,
      targetX: 4,
      targetY: 4,
      initialBattery: 25,
      obstacles: [],
      energyCells: [],
      star3Target: 9,
    ),
    Level(
      id: 3,
      title: 'THE RIGHT PATH',
      description: 'Fly around buildings (height 1) to collect the cargo crate and deliver it to the target.',
      hint: 'Rotate to dodge the buildings. Don\'t fly straight into obstacles at height 0!',
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
      id: 4,
      title: 'OVER THE WALL',
      description: 'Ascend to fly over the obstacle wall to collect the cargo block and deliver to target.',
      hint: 'Ascend to height 2 to fly over the obstacle wall, then descend back to height 0 to land.',
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
      id: 5,
      title: 'POWER HARVEST',
      description: 'Collect the cargo and harvest floating energy cells to recharge battery on the way to the pad.',
      hint: 'Harvest both energy cells to stay powered. Fly over the energy cells at height 1 to collect them.',
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
      id: 6,
      title: 'HEIGHT MATRIX',
      description: 'Climb elevations to collect the cargo box floating at height 3, then deliver it to target pad.',
      hint: 'The cargo block is floating at altitude 3 on top of a building. Climb to height 3 before picking it up!',
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
    Level(
      id: 7,
      title: 'SPIRAL CORRIDOR',
      description: 'Navigate a spiral path to reach the box in the center, then deliver it to the target pad.',
      hint: 'Follow the spiral path winding inward. Be careful not to bump into the high walls.',
      gridWidth: 6,
      gridHeight: 6,
      startX: 0,
      startY: 5,
      startDirection: Direction.north,
      boxX: 2,
      boxY: 2,
      targetX: 5,
      targetY: 5,
      initialBattery: 40,
      obstacles: [
        Obstacle(x: 1, y: 1, height: 2),
        Obstacle(x: 2, y: 1, height: 2),
        Obstacle(x: 3, y: 1, height: 2),
        Obstacle(x: 4, y: 1, height: 2),
        Obstacle(x: 4, y: 2, height: 2),
        Obstacle(x: 4, y: 3, height: 2),
        Obstacle(x: 4, y: 4, height: 2),
        Obstacle(x: 3, y: 4, height: 2),
        Obstacle(x: 2, y: 4, height: 2),
        Obstacle(x: 1, y: 4, height: 2),
        Obstacle(x: 1, y: 3, height: 2),
      ],
      energyCells: [],
      star3Target: 24,
    ),
    Level(
      id: 8,
      title: 'ZIGZAG LANE',
      description: 'Steer the drone in a zigzag pattern around walls to retrieve the box and reach the target.',
      hint: 'Alternate yaw rotations (left and right) to slalom through the walls.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 6,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 6,
      targetX: 6,
      targetY: 0,
      initialBattery: 45,
      obstacles: [
        Obstacle(x: 1, y: 1, height: 2),
        Obstacle(x: 1, y: 2, height: 2),
        Obstacle(x: 1, y: 3, height: 2),
        Obstacle(x: 3, y: 3, height: 2),
        Obstacle(x: 3, y: 4, height: 2),
        Obstacle(x: 3, y: 5, height: 2),
        Obstacle(x: 5, y: 1, height: 2),
        Obstacle(x: 5, y: 2, height: 2),
        Obstacle(x: 5, y: 3, height: 2),
      ],
      energyCells: [],
      star3Target: 18,
    ),
    Level(
      id: 9,
      title: 'SHUTTLE RUN',
      description: 'Extremely limited battery. Use a Repeat block loop to fetch multiple energy cells to survive.',
      hint: 'Try using a [Repeat 3] block enclosing a [Move Forward] and [Move Forward] to grab energy cells efficiently.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 7,
      startDirection: Direction.east,
      boxX: 4,
      boxY: 7,
      targetX: 7,
      targetY: 7,
      initialBattery: 12,
      obstacles: [
        Obstacle(x: 2, y: 6, height: 1),
        Obstacle(x: 4, y: 6, height: 1),
        Obstacle(x: 6, y: 6, height: 1),
      ],
      energyCells: [
        EnergyCell(x: 2, y: 7, height: 1, charge: 8),
        EnergyCell(x: 4, y: 7, height: 1, charge: 8),
        EnergyCell(x: 6, y: 7, height: 1, charge: 8),
      ],
      star3Target: 14,
    ),
    Level(
      id: 10,
      title: 'ALLEY WAY',
      description: 'Fly through a narrow canyon. Adjust altitude dynamically to pick up cells and box.',
      hint: 'Steer straight and use [Ascend] / [Descend] to navigate the mountain peaks.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 3,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 3,
      targetX: 6,
      targetY: 3,
      initialBattery: 30,
      obstacles: [
        Obstacle(x: 1, y: 2, height: 3),
        Obstacle(x: 1, y: 4, height: 3),
        Obstacle(x: 3, y: 2, height: 3),
        Obstacle(x: 3, y: 4, height: 3),
        Obstacle(x: 5, y: 2, height: 3),
        Obstacle(x: 5, y: 4, height: 3),
      ],
      energyCells: [
        EnergyCell(x: 3, y: 3, height: 2, charge: 10),
      ],
      star3Target: 16,
    ),
    Level(
      id: 11,
      title: 'THE BRIDGE',
      description: 'Cross the obstacle bridge. Use Repeat blocks to execute symmetric actions efficiently.',
      hint: 'Combine [Repeat] blocks to execute symmetric movements on both sides of the bridge.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 4,
      boxY: 4,
      targetX: 7,
      targetY: 4,
      initialBattery: 35,
      obstacles: [
        Obstacle(x: 2, y: 3, height: 1),
        Obstacle(x: 2, y: 5, height: 1),
        Obstacle(x: 3, y: 3, height: 2),
        Obstacle(x: 3, y: 5, height: 2),
        Obstacle(x: 5, y: 3, height: 1),
        Obstacle(x: 5, y: 5, height: 1),
      ],
      energyCells: [],
      star3Target: 12,
    ),
    Level(
      id: 12,
      title: 'MAZE RUNNER',
      description: 'Retrieve the box from a labyrinth using precise yaw rotations and steps.',
      hint: 'This labyrinth has multiple turns. Track your position relative to the grid coordinates.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 6,
      startDirection: Direction.north,
      boxX: 4,
      boxY: 1,
      targetX: 0,
      targetY: 0,
      initialBattery: 50,
      obstacles: [
        Obstacle(x: 1, y: 1, height: 2),
        Obstacle(x: 1, y: 2, height: 2),
        Obstacle(x: 1, y: 3, height: 2),
        Obstacle(x: 1, y: 4, height: 2),
        Obstacle(x: 1, y: 5, height: 2),
        Obstacle(x: 3, y: 1, height: 2),
        Obstacle(x: 3, y: 2, height: 2),
        Obstacle(x: 3, y: 3, height: 2),
        Obstacle(x: 3, y: 4, height: 2),
        Obstacle(x: 5, y: 2, height: 2),
        Obstacle(x: 5, y: 3, height: 2),
        Obstacle(x: 5, y: 4, height: 2),
      ],
      energyCells: [],
      star3Target: 25,
    ),
    Level(
      id: 13,
      title: 'ENERGY DRAIN',
      description: 'A large grid with high battery consumption. Map your path around mountains to grab all energy cells.',
      hint: 'Collect all 4 energy cells to keep your battery from hitting zero. Plan the shortest path!',
      gridWidth: 9,
      gridHeight: 9,
      startX: 0,
      startY: 8,
      startDirection: Direction.east,
      boxX: 4,
      boxY: 8,
      targetX: 8,
      targetY: 0,
      initialBattery: 15,
      obstacles: [
        Obstacle(x: 2, y: 2, height: 2),
        Obstacle(x: 3, y: 2, height: 2),
        Obstacle(x: 4, y: 2, height: 2),
        Obstacle(x: 4, y: 4, height: 2),
        Obstacle(x: 4, y: 5, height: 2),
        Obstacle(x: 4, y: 6, height: 2),
      ],
      energyCells: [
        EnergyCell(x: 2, y: 8, height: 1, charge: 10),
        EnergyCell(x: 6, y: 8, height: 1, charge: 10),
        EnergyCell(x: 8, y: 4, height: 1, charge: 10),
        EnergyCell(x: 4, y: 0, height: 1, charge: 10),
      ],
      star3Target: 26,
    ),
    Level(
      id: 14,
      title: 'DOUBLE WALL',
      description: 'Two layers of walls block your way. Rise over them, pick up battery cells, and deliver the cargo.',
      hint: 'Climb high to clear the double barrier. Grab the energy cell at height 4 for extra power.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 7,
      startDirection: Direction.north,
      boxX: 2,
      boxY: 6,
      targetX: 7,
      targetY: 7,
      initialBattery: 35,
      obstacles: [
        Obstacle(x: 0, y: 4, height: 1),
        Obstacle(x: 1, y: 4, height: 1),
        Obstacle(x: 2, y: 4, height: 1),
        Obstacle(x: 3, y: 4, height: 1),
        Obstacle(x: 4, y: 4, height: 2),
        Obstacle(x: 5, y: 4, height: 2),
        Obstacle(x: 6, y: 4, height: 2),
        Obstacle(x: 7, y: 4, height: 2),
        Obstacle(x: 2, y: 2, height: 3),
        Obstacle(x: 3, y: 2, height: 3),
        Obstacle(x: 4, y: 2, height: 3),
        Obstacle(x: 5, y: 2, height: 3),
      ],
      energyCells: [
        EnergyCell(x: 2, y: 4, height: 2, charge: 15),
        EnergyCell(x: 3, y: 2, height: 4, charge: 15),
      ],
      star3Target: 24,
    ),
    Level(
      id: 15,
      title: 'SINE WAVE',
      description: 'The height of obstacles oscillates: 1, 2, 3, 2, 1. Fly like a wave to collect the cargo block.',
      hint: 'Use a loop to repeatedly ascend and descend to match the wave-shaped obstacles.',
      gridWidth: 9,
      gridHeight: 5,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 4,
      boxY: 2,
      targetX: 8,
      targetY: 2,
      initialBattery: 45,
      obstacles: [
        Obstacle(x: 2, y: 2, height: 1),
        Obstacle(x: 3, y: 2, height: 2),
        Obstacle(x: 4, y: 2, height: 3),
        Obstacle(x: 5, y: 2, height: 2),
        Obstacle(x: 6, y: 2, height: 1),
      ],
      energyCells: [
        EnergyCell(x: 4, y: 2, height: 4, charge: 15),
      ],
      star3Target: 14,
    ),
    Level(
      id: 16,
      title: 'VERTICAL LABYRINTH',
      description: 'Navigate tall vertical columns with tight corridors to deliver cargo.',
      hint: 'Combine vertical height climbing with lateral movements to maneuver through the dense pillars.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 7,
      startY: 7,
      startDirection: Direction.west,
      boxX: 5,
      boxY: 5,
      targetX: 1,
      targetY: 1,
      initialBattery: 55,
      obstacles: [
        Obstacle(x: 2, y: 2, height: 3),
        Obstacle(x: 2, y: 3, height: 3),
        Obstacle(x: 2, y: 4, height: 3),
        Obstacle(x: 2, y: 5, height: 3),
        Obstacle(x: 4, y: 2, height: 3),
        Obstacle(x: 4, y: 3, height: 3),
        Obstacle(x: 4, y: 4, height: 3),
        Obstacle(x: 4, y: 5, height: 3),
        Obstacle(x: 6, y: 2, height: 3),
        Obstacle(x: 6, y: 3, height: 3),
        Obstacle(x: 6, y: 4, height: 3),
        Obstacle(x: 6, y: 5, height: 3),
      ],
      energyCells: [
        EnergyCell(x: 1, y: 5, height: 1, charge: 12),
        EnergyCell(x: 5, y: 1, height: 1, charge: 12),
      ],
      star3Target: 30,
    ),
    Level(
      id: 17,
      title: 'CITY GRID',
      description: 'A metropolitan grid with towering obstacles. Route the drone wisely to deliver the cargo.',
      hint: 'Fly high over some buildings or navigate around them. Optimize your block count for 3 stars.',
      gridWidth: 9,
      gridHeight: 9,
      startX: 8,
      startY: 8,
      startDirection: Direction.north,
      boxX: 6,
      boxY: 6,
      targetX: 0,
      targetY: 0,
      initialBattery: 60,
      obstacles: [
        Obstacle(x: 1, y: 1, height: 4),
        Obstacle(x: 2, y: 1, height: 4),
        Obstacle(x: 3, y: 3, height: 4),
        Obstacle(x: 4, y: 3, height: 4),
        Obstacle(x: 5, y: 3, height: 4),
        Obstacle(x: 7, y: 5, height: 4),
        Obstacle(x: 1, y: 7, height: 4),
        Obstacle(x: 2, y: 7, height: 4),
        Obstacle(x: 3, y: 7, height: 4),
      ],
      energyCells: [
        EnergyCell(x: 6, y: 6, height: 1, charge: 10),
        EnergyCell(x: 3, y: 0, height: 1, charge: 10),
        EnergyCell(x: 0, y: 6, height: 1, charge: 10),
      ],
      star3Target: 32,
    ),
    Level(
      id: 18,
      title: 'MOUNT EVEREST',
      description: 'Climb a massive central peak. Grab energy cells from heights and land safely on the target.',
      hint: 'The central peak reaches height 3. Climb up to pick up the cargo at the top.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 7,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 3,
      targetX: 7,
      targetY: 7,
      initialBattery: 35,
      obstacles: [
        Obstacle(x: 2, y: 2, height: 1),
        Obstacle(x: 2, y: 3, height: 2),
        Obstacle(x: 2, y: 4, height: 1),
        Obstacle(x: 3, y: 2, height: 2),
        Obstacle(x: 3, y: 3, height: 3),
        Obstacle(x: 3, y: 4, height: 2),
        Obstacle(x: 4, y: 2, height: 1),
        Obstacle(x: 4, y: 3, height: 2),
        Obstacle(x: 4, y: 4, height: 1),
      ],
      energyCells: [
        EnergyCell(x: 3, y: 3, height: 4, charge: 20),
        EnergyCell(x: 1, y: 1, height: 1, charge: 10),
        EnergyCell(x: 6, y: 6, height: 1, charge: 10),
      ],
      star3Target: 26,
    ),
    Level(
      id: 19,
      title: 'REPEAT LABYRINTH',
      description: 'A maze that requires structural loops to reach the box and target pad within 14 blocks.',
      hint: 'Write a repeating pattern (e.g. Move, Turn, Move) inside a Loop to finish in under 14 blocks.',
      gridWidth: 9,
      gridHeight: 9,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 8,
      boxY: 4,
      targetX: 0,
      targetY: 8,
      initialBattery: 60,
      obstacles: [
        Obstacle(x: 1, y: 3, height: 2),
        Obstacle(x: 1, y: 5, height: 2),
        Obstacle(x: 3, y: 3, height: 2),
        Obstacle(x: 3, y: 5, height: 2),
        Obstacle(x: 5, y: 3, height: 2),
        Obstacle(x: 5, y: 5, height: 2),
        Obstacle(x: 7, y: 3, height: 2),
        Obstacle(x: 7, y: 5, height: 2),
      ],
      energyCells: [
        EnergyCell(x: 4, y: 4, height: 1, charge: 10),
      ],
      star3Target: 14,
    ),
    Level(
      id: 20,
      title: 'ULTIMATE FLIGHT TEST',
      description: 'The final exam. Combine loops, rotations, altitude, and energy harvesting to win.',
      hint: 'Use a nested Repeat loop structure to manage battery, navigate obstacles, and deliver the cargo.',
      gridWidth: 10,
      gridHeight: 10,
      startX: 0,
      startY: 9,
      startDirection: Direction.east,
      boxX: 9,
      boxY: 9,
      targetX: 0,
      targetY: 0,
      initialBattery: 45,
      obstacles: [
        Obstacle(x: 2, y: 2, height: 3),
        Obstacle(x: 2, y: 3, height: 3),
        Obstacle(x: 3, y: 2, height: 3),
        Obstacle(x: 6, y: 6, height: 3),
        Obstacle(x: 6, y: 7, height: 3),
        Obstacle(x: 7, y: 6, height: 3),
      ],
      energyCells: [
        EnergyCell(x: 3, y: 9, height: 1, charge: 15),
        EnergyCell(x: 6, y: 9, height: 1, charge: 15),
        EnergyCell(x: 9, y: 5, height: 1, charge: 15),
        EnergyCell(x: 5, y: 0, height: 1, charge: 15),
      ],
      star3Target: 32,
    ),
  ];
}
