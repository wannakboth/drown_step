import 'package:flutter/material.dart';

enum Direction { north, east, south, west }

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

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'height': height};
  }

  factory Obstacle.fromJson(Map<String, dynamic> json) {
    return Obstacle(
      x: json['x'] as int,
      y: json['y'] as int,
      height: json['height'] as int,
    );
  }
}

class EnergyCell {
  final int x;
  final int y;
  final int height; // Altitude needed to collect
  final int charge; // Battery restored upon collecting (e.g. 5)

  const EnergyCell({
    required this.x,
    required this.y,
    required this.height,
    this.charge = 5,
  });

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'height': height, 'charge': charge};
  }

  factory EnergyCell.fromJson(Map<String, dynamic> json) {
    return EnergyCell(
      x: json['x'] as int,
      y: json['y'] as int,
      height: json['height'] as int,
      charge: json['charge'] as int? ?? 5,
    );
  }
}

enum GameMode { daily, normal, hard, sandbox }

/// Identifies which UI element a tutorial step should highlight/point at.
enum TutorialTarget {
  none,
  takeoff,
  land,
  moveForward,
  turnLeft,
  turnRight,
  ascend,
  descend,
  repeatBlock,
  whileBlock,
  ifElse,
  workspace,
  runProgram,
  telemetry,
  console,
  gridArena,
  speed,
  hint,
  dismissHint,
  reset,
  confirmReset,
  firstRepeatBlock,
  firstRepeatDropdown,
  secondRepeatBlock,
  secondRepeatDropdown,
}

class TutorialStep {
  final String message;
  final TutorialTarget target;
  const TutorialStep(this.message, {this.target = TutorialTarget.none});
}

class Level {
  final String id;
  final String title;
  final String description;
  final String? hint;
  final List<TutorialStep>? tutorialSteps;
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
    this.tutorialSteps,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'hint': hint,
      'gridWidth': gridWidth,
      'gridHeight': gridHeight,
      'startX': startX,
      'startY': startY,
      'startDirection': startDirection.index,
      'boxX': boxX,
      'boxY': boxY,
      'targetX': targetX,
      'targetY': targetY,
      'initialBattery': initialBattery,
      'obstacles': obstacles.map((o) => o.toJson()).toList(),
      'energyCells': energyCells.map((e) => e.toJson()).toList(),
      'star3Target': star3Target,
    };
  }

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      hint: json['hint'] as String?,
      gridWidth: json['gridWidth'] as int,
      gridHeight: json['gridHeight'] as int,
      startX: json['startX'] as int,
      startY: json['startY'] as int,
      startDirection: Direction.values[json['startDirection'] as int],
      boxX: json['boxX'] as int,
      boxY: json['boxY'] as int,
      targetX: json['targetX'] as int,
      targetY: json['targetY'] as int,
      initialBattery: json['initialBattery'] as int,
      obstacles:
          (json['obstacles'] as List<dynamic>?)
              ?.map((o) => Obstacle.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      energyCells:
          (json['energyCells'] as List<dynamic>?)
              ?.map((e) => EnergyCell.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      star3Target: json['star3Target'] as int? ?? 10,
    );
  }

  int get maxStars {
    if (id.startsWith('N')) {
      final num = int.tryParse(id.substring(1)) ?? 1;
      return num <= 5 ? 3 : 4;
    }
    if (id.startsWith('H')) {
      final num = int.tryParse(id.substring(1)) ?? 1;
      return num <= 5 ? 3 : 4;
    }
    return 3;
  }

  static List<Level> get predefinedLevels => predefinedNormalLevels;

  static final List<Level> tutorialMissions = [
    Level(
      id: 'T1',
      title: 'TUTORIAL 1: COCKPIT HUD',
      description:
          'ACQUIRE CARGO AT (1, 2) AND LAND AT (2, 2) TO COMPLETE YOUR BASIC FLIGHT READOUT CALIBRATION.',
      hint:
          'FOLLOW THE CO-PILOT INSTRUCTIONS TO UNDERSTAND EACH PORTION OF THE DASHBOARD CARD BY CARD.',
      gridWidth: 3,
      gridHeight: 3,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 1,
      boxY: 2,
      targetX: 2,
      targetY: 2,
      initialBattery: 99,
      obstacles: [],
      energyCells: [],
      star3Target: 0,
      tutorialSteps: [
        TutorialStep(
          "Welcome to DroneStep! Let's inspect the interface. This is the FLIGHT TELEMETRY HUD showing battery, current altitude, coordinates, and program block limits.",
          target: TutorialTarget.telemetry,
        ),
        TutorialStep(
          "Next, view the command center card on the right: the PROGRAM CONSOLE. This shows your program commands queued for flight execution.",
          target: TutorialTarget.console,
        ),
        TutorialStep(
          "This is the FLIGHT ARENA grid. The drone must navigate here to acquire cargo boxes and deliver them to target pads.",
          target: TutorialTarget.gridArena,
        ),
        TutorialStep(
          "Tap the [ PROGRAM CONSOLE ] button to expand the programming panel and reveal the instruction palette.",
          target: TutorialTarget.console,
        ),
        TutorialStep(
          "Below the grid is the INSTRUCTION PALETTE. Tap on the [TAKEOFF] block to queue it first.",
          target: TutorialTarget.takeoff,
        ),
        TutorialStep(
          "Great! The takeoff block is now added to the ACTIVE FLIGHT SEQUENCE workspace. Here, you can reorder or nest loops and logic.",
          target: TutorialTarget.workspace,
        ),
        TutorialStep(
          "This is the SIMULATION SPEED toggle. Tap it to speed up or slow down flight execution.",
          target: TutorialTarget.speed,
        ),
        TutorialStep(
          "If you get stuck on a mission, tap the SECTOR MISSION BRIEFING (Hint) button to decrypt advice.",
          target: TutorialTarget.hint,
        ),
        TutorialStep(
          "Read the objective and hints, then tap [DISMISS] to close the briefing.",
          target: TutorialTarget.dismissHint,
        ),
        TutorialStep(
          "If your path goes wrong, tap the RETRY / RESET button to clear the sequence and recall the drone.",
          target: TutorialTarget.reset,
        ),
        TutorialStep(
          "Tap [CONFIRM] to reset your program sequence and start fresh.",
          target: TutorialTarget.confirmReset,
        ),
        TutorialStep(
          "Now, rebuild the cargo flight plan: tap [TAKEOFF], [MOVE FWD], and [LAND] to acquire the cargo box, then another [TAKEOFF], [MOVE FWD], and [LAND] to deliver it.",
          target: TutorialTarget.workspace,
        ),
        TutorialStep(
          "Flight plan ready! Tap [RUN PROGRAM] to execute the flight sequence and watch the automatic delivery.",
          target: TutorialTarget.runProgram,
        ),
      ],
    ),
    Level(
      id: 'T2',
      title: 'TUTORIAL 2: BASIC FLIGHT PLAN',
      description:
          'TAKE OFF, MOVE FORWARD TO PICK UP THE CARGO BOX, LIFT OFF AGAIN, ROTATE LEFT, FLY TO THE TARGET PAD AND LAND.',
      hint: 'FOLLOW THE STEP-BY-STEP FLIGHT INSTRUCTIONS TO DELIVER THE CARGO.',
      gridWidth: 4,
      gridHeight: 4,
      startX: 0,
      startY: 3,
      startDirection: Direction.east,
      boxX: 1,
      boxY: 3,
      targetX: 1,
      targetY: 1,
      initialBattery: 99,
      obstacles: [],
      energyCells: [],
      star3Target: 8,
      tutorialSteps: [
        TutorialStep(
          "Let's fly a complete logistics run. First, tap [TAKEOFF] to lift off.",
          target: TutorialTarget.takeoff,
        ),
        TutorialStep(
          "Move forward to the cell directly above the cargo box: tap [MOVE FWD].",
          target: TutorialTarget.moveForward,
        ),
        TutorialStep(
          "Lower the claw and grab the box: tap [LAND].",
          target: TutorialTarget.land,
        ),
        TutorialStep(
          "Box secured! Rise back into flight altitude: tap [TAKEOFF].",
          target: TutorialTarget.takeoff,
        ),
        TutorialStep(
          "The target pad is to our left. Pivot the drone 90 degrees left: tap [TURN LEFT].",
          target: TutorialTarget.turnLeft,
        ),
        TutorialStep(
          "Align with the target pad: tap [MOVE FWD].",
          target: TutorialTarget.moveForward,
        ),
        TutorialStep(
          "Move forward one more time to reach the target pad: tap [MOVE FWD].",
          target: TutorialTarget.moveForward,
        ),
        TutorialStep(
          "Finally, deliver the cargo by landing on the target pad: tap [LAND].",
          target: TutorialTarget.land,
        ),
        TutorialStep(
          "Flight queue ready! Tap [RUN PROGRAM] to watch the automatic execution.",
          target: TutorialTarget.runProgram,
        ),
      ],
    ),
    Level(
      id: 'T3',
      title: 'TUTORIAL 3: LOOPS & LOGIC',
      description:
          'LEARN TO USE LOOP STRUCTURES TO FLY AUTOMATICALLY AND COVER MULTIPLE SQUARES WITHOUT WASTING MEMORY BLOCKS.',
      hint: 'NEST THE MOVE FORWARD BLOCK INSIDE A REPEAT BLOCK.',
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 4,
      targetX: 3,
      targetY: 1,
      initialBattery: 99,
      obstacles: [],
      energyCells: [],
      star3Target: 9,
      tutorialSteps: [
        TutorialStep(
          "Loops let us fly long distances with fewer blocks. First, lift off: tap [TAKEOFF].",
          target: TutorialTarget.takeoff,
        ),
        TutorialStep(
          "Tap the [REPEAT] block in the palette to add a loop block structure.",
          target: TutorialTarget.repeatBlock,
        ),
        TutorialStep(
          "Change the repeat count to 3 by tapping the count dropdown.",
          target: TutorialTarget.firstRepeatDropdown,
        ),
        TutorialStep(
          "Tap the new REPEAT block in your workspace to select it.",
          target: TutorialTarget.firstRepeatBlock,
        ),
        TutorialStep(
          "With the loop active, tap [MOVE FWD] in the palette to insert it inside the loop.",
          target: TutorialTarget.moveForward,
        ),
        TutorialStep(
          "To add blocks after the loop, tap the workspace area or select the root container.",
          target: TutorialTarget.workspace,
        ),
        TutorialStep(
          "Now, land to pick up the cargo box: tap [LAND].",
          target: TutorialTarget.land,
        ),
        TutorialStep(
          "Lift off again with the cargo box: tap [TAKEOFF].",
          target: TutorialTarget.takeoff,
        ),
        TutorialStep(
          "Orient north towards the target pad: tap [TURN LEFT].",
          target: TutorialTarget.turnLeft,
        ),
        TutorialStep(
          "Add a second loop: tap the [REPEAT] block in the palette.",
          target: TutorialTarget.repeatBlock,
        ),
        TutorialStep(
          "Set its loop count to 3 as well.",
          target: TutorialTarget.secondRepeatDropdown,
        ),
        TutorialStep(
          "Tap this second REPEAT block in your workspace to select it.",
          target: TutorialTarget.secondRepeatBlock,
        ),
        TutorialStep(
          "Tap [MOVE FWD] to queue it inside this second loop.",
          target: TutorialTarget.moveForward,
        ),
        TutorialStep(
          "Select the workspace or root container to continue after the loop.",
          target: TutorialTarget.workspace,
        ),
        TutorialStep(
          "Finally, land on the target pad: tap [LAND].",
          target: TutorialTarget.land,
        ),
        TutorialStep(
          "Program complete! Tap [RUN PROGRAM] to execute your flight path!",
          target: TutorialTarget.runProgram,
        ),
      ],
    ),
  ];

  static final List<Level> predefinedNormalLevels = [
    Level(
      id: 'N1',
      title: 'FIRST LIFTOFF',
      description:
          'Acquire the cargo box at (2, 4) and deliver it to the target pad at (4, 4).',
      hint:
          'Takeoff, move forward twice, land to pick up cargo, takeoff again, move forward twice, land on target.',
      tutorialSteps: null,
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 2,
      boxY: 4,
      targetX: 4,
      targetY: 4,
      initialBattery: 40,
      obstacles: [],
      energyCells: [],
      star3Target:
          8, // 8 blocks minimum; 4★ unreachable (intro level by design)
    ),
    Level(
      id: 'N2',
      title: 'YAW DRIFT',
      description:
          'Navigate a right angle bend. Takeoff, turn right, and fly to the cargo.',
      hint:
          'Rotate the drone using [TURN RIGHT] to face south before moving forward.',
      tutorialSteps: null,
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 0,
      boxY: 4,
      targetX: 2,
      targetY: 4,
      initialBattery: 45,
      obstacles: [],
      energyCells: [],
      star3Target:
          10, // Tutorial path = 10 blocks = 3★; no shortcut available for 4★
    ),
    Level(
      id: 'N3',
      title: 'WALL TRANSIT',
      description:
          'A height 1 barrier blocks your path. Ascend to fly over it, and descend to land.',
      hint:
          'Ascend to height 2 to clear the height 1 wall. Descend to height 0 to grab cargo or land.',
      tutorialSteps: null,
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 2,
      boxY: 2,
      targetX: 4,
      targetY: 2,
      initialBattery: 50,
      obstacles: [
        Obstacle(x: 1, y: 2, height: 1),
        Obstacle(x: 3, y: 2, height: 1),
      ],
      energyCells: [],
      star3Target: 14,
    ),
    Level(
      id: 'N4',
      title: 'CALIBRATION LOOP',
      description:
          'Use the Repeat block to cover a long straight path efficiently.',
      hint:
          'Place a [MOVE FORWARD] block inside a [REPEAT] loop block to save space.',
      tutorialSteps: null,
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
      obstacles: [],
      energyCells: [],
      star3Target: 8,
    ),
    Level(
      id: 'N5',
      title: 'SENSORY SYSTEMS',
      description:
          'Utilize conditional blocks to check sensors and detect obstacles ahead.',
      hint:
          'Use a [WHILE] loop with a condition like (notHasCargo) to move forward automatically.',
      tutorialSteps: null,
      gridWidth: 7,
      gridHeight: 5,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 2,
      targetX: 6,
      targetY: 2,
      initialBattery: 40,
      obstacles: [Obstacle(x: 4, y: 2, height: 2)],
      energyCells: [],
      star3Target: 11,
    ),
    Level(
      id: 'N6',
      title: 'ELEVATED CO-DOCK',
      description:
          'The cargo box is situated on top of a height 2 tower. Fly up to retrieve it.',
      hint:
          'Climb to altitude 3. Hover exactly over (2, 2) and land. Land height will match the obstacle.',
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 2,
      boxY: 2,
      targetX: 4,
      targetY: 4,
      initialBattery: 50,
      obstacles: [Obstacle(x: 2, y: 2, height: 2)],
      energyCells: [],
      star3Target: 18,
    ),
    Level(
      id: 'N7',
      title: 'SPIRAL DOCK',
      description:
          'Navigate inward along a spiral wall corridor to reach the cargo.',
      hint:
          'Move forward, turn right, and repeat the pattern to spiral in to the center.',
      gridWidth: 6,
      gridHeight: 6,
      startX: 0,
      startY: 0,
      startDirection: Direction.east,
      boxX: 2,
      boxY: 2,
      targetX: 5,
      targetY: 5,
      initialBattery: 60,
      obstacles: [
        Obstacle(x: 1, y: 1, height: 1),
        Obstacle(x: 2, y: 1, height: 1),
        Obstacle(x: 3, y: 1, height: 1),
        Obstacle(x: 3, y: 2, height: 1),
        Obstacle(x: 3, y: 3, height: 1),
        Obstacle(x: 1, y: 3, height: 1),
      ],
      energyCells: [],
      star3Target: 22,
    ),
    Level(
      id: 'N8',
      title: 'SLALOM slalom',
      description: 'Wiggle through a sequence of alternating vertical pillars.',
      hint:
          'Alternate turns: left, move, right, move, or use loops if you can find a repeating pattern.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 6,
      startDirection: Direction.north,
      boxX: 3,
      boxY: 0,
      targetX: 6,
      targetY: 6,
      initialBattery: 65,
      obstacles: [
        Obstacle(x: 2, y: 1, height: 2),
        Obstacle(x: 2, y: 3, height: 2),
        Obstacle(x: 4, y: 3, height: 2),
        Obstacle(x: 4, y: 5, height: 2),
      ],
      energyCells: [],
      star3Target: 20,
    ),
    Level(
      id: 'N9',
      title: 'ENERGY DRAIN',
      description:
          'Your starting battery is extremely low. Collect fuel cells along the way.',
      hint:
          'The fuel cells are at altitude 1. Fly at height 1 to harvest them while moving forward.',
      gridWidth: 8,
      gridHeight: 5,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 2,
      targetX: 7,
      targetY: 2,
      initialBattery: 15,
      obstacles: [],
      energyCells: [
        EnergyCell(x: 1, y: 2, height: 1, charge: 15),
        EnergyCell(x: 5, y: 2, height: 1, charge: 15),
      ],
      star3Target: 14,
    ),
    Level(
      id: 'N10',
      title: 'CANYON VALLEY',
      description: 'Navigate up and down peaks to deliver the cargo.',
      hint:
          'Ascend over the first mountain, land to collect the box, then climb over the second peak.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 3,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 3,
      targetX: 6,
      targetY: 3,
      initialBattery: 55,
      obstacles: [
        Obstacle(x: 1, y: 3, height: 2),
        Obstacle(x: 5, y: 3, height: 2),
      ],
      energyCells: [],
      star3Target: 18,
    ),
    Level(
      id: 'N11',
      title: 'THE BRIDGEWAY',
      description:
          'Navigate a bridge with high walls. Avoid crashing into side girders.',
      hint:
          'Use symmetric movements or loops to glide straight down the central pathway.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 4,
      boxY: 4,
      targetX: 7,
      targetY: 4,
      initialBattery: 45,
      obstacles: [
        Obstacle(x: 2, y: 3, height: 1),
        Obstacle(x: 2, y: 5, height: 1),
        Obstacle(x: 5, y: 3, height: 1),
        Obstacle(x: 5, y: 5, height: 1),
      ],
      energyCells: [],
      star3Target: 12,
    ),
    Level(
      id: 'N12',
      title: 'MAZE RUNNER',
      description: 'Find your way through a narrow maze of two-level walls.',
      hint:
          'Keep track of your turns: right, left, right, left, to avoid colliding with columns.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 6,
      startDirection: Direction.north,
      boxX: 4,
      boxY: 1,
      targetX: 0,
      targetY: 0,
      initialBattery: 60,
      obstacles: [
        Obstacle(x: 1, y: 1, height: 2),
        Obstacle(x: 1, y: 3, height: 2),
        Obstacle(x: 3, y: 3, height: 2),
        Obstacle(x: 5, y: 3, height: 2),
      ],
      energyCells: [],
      star3Target: 22,
    ),
    Level(
      id: 'N13',
      title: 'NESTED LOOP SCAN',
      description:
          'Use a nested loop structure to fly a zig-zag sweep pattern across sectors.',
      hint:
          'Nest a loop of movement inside another loop of rotations to repeat rows.',
      gridWidth: 6,
      gridHeight: 6,
      startX: 0,
      startY: 5,
      startDirection: Direction.east,
      boxX: 5,
      boxY: 0,
      targetX: 0,
      targetY: 0,
      initialBattery: 70,
      obstacles: [],
      energyCells: [],
      star3Target: 15,
    ),
    Level(
      id: 'N14',
      title: 'DOUBLE WALL TRANSIT',
      description:
          'Two separate wall barriers block the target. Leap over both in high flight.',
      hint:
          'Climb to height 3. Use loops to carry you over the double barriers.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 7,
      startDirection: Direction.north,
      boxX: 2,
      boxY: 6,
      targetX: 7,
      targetY: 7,
      initialBattery: 55,
      obstacles: [
        Obstacle(x: 1, y: 4, height: 2),
        Obstacle(x: 5, y: 4, height: 2),
      ],
      energyCells: [EnergyCell(x: 3, y: 4, height: 3, charge: 15)],
      star3Target: 22,
    ),
    Level(
      id: 'N15',
      title: 'SINE WAVE FLIGHT',
      description:
          'Pillars oscillate in height: 1, 2, 3, 2, 1. Match your altitude changes.',
      hint:
          'Create a loop that ascends, moves forward, descends, and moves forward.',
      gridWidth: 9,
      gridHeight: 5,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 4,
      boxY: 2,
      targetX: 8,
      targetY: 2,
      initialBattery: 60,
      obstacles: [
        Obstacle(x: 2, y: 2, height: 1),
        Obstacle(x: 3, y: 2, height: 2),
        Obstacle(x: 4, y: 2, height: 3),
        Obstacle(x: 5, y: 2, height: 2),
        Obstacle(x: 6, y: 2, height: 1),
      ],
      energyCells: [],
      star3Target: 15,
    ),
    Level(
      id: 'N16',
      title: 'VERTICAL SHAFTS',
      description:
          'Columns form narrow shafts. Move vertically and horizontally to navigate.',
      hint:
          'Perform climbing actions inside tight columns to get over the dividers.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 7,
      startY: 7,
      startDirection: Direction.west,
      boxX: 5,
      boxY: 5,
      targetX: 1,
      targetY: 1,
      initialBattery: 70,
      obstacles: [
        Obstacle(x: 2, y: 3, height: 3),
        Obstacle(x: 4, y: 3, height: 3),
        Obstacle(x: 6, y: 3, height: 3),
      ],
      energyCells: [EnergyCell(x: 1, y: 5, height: 1, charge: 20)],
      star3Target: 25,
    ),
    Level(
      id: 'N17',
      title: 'CITY GRID TOWERS',
      description:
          'Towering skyscrapers block direct paths. Plan a winding horizontal route.',
      hint: ' buildings are height 4, too high to climb over. Go around them!',
      gridWidth: 9,
      gridHeight: 9,
      startX: 8,
      startY: 8,
      startDirection: Direction.north,
      boxX: 6,
      boxY: 6,
      targetX: 0,
      targetY: 0,
      initialBattery: 75,
      obstacles: [
        Obstacle(x: 3, y: 3, height: 4),
        Obstacle(x: 3, y: 4, height: 4),
        Obstacle(x: 3, y: 5, height: 4),
        Obstacle(x: 5, y: 3, height: 4),
        Obstacle(x: 5, y: 4, height: 4),
        Obstacle(x: 5, y: 5, height: 4),
      ],
      energyCells: [EnergyCell(x: 0, y: 6, height: 1, charge: 15)],
      star3Target: 30,
    ),
    Level(
      id: 'N18',
      title: 'SUMMIT RETRIEVAL',
      description:
          'Climb a massive mountain peak to retrieve cargo at the top.',
      hint:
          'The peak is height 3. Ascent to height 3 to grab the box at the summit.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 7,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 3,
      targetX: 7,
      targetY: 7,
      initialBattery: 60,
      obstacles: [Obstacle(x: 3, y: 3, height: 3)],
      energyCells: [EnergyCell(x: 3, y: 3, height: 4, charge: 25)],
      star3Target: 22,
    ),
    Level(
      id: 'N19',
      title: 'LABYRINTH LOOP',
      description:
          'Navigate a complex maze of walls using nested structures and sensors.',
      hint:
          'Combine a While loop with If checks to automatically follow the corridors.',
      gridWidth: 9,
      gridHeight: 9,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 8,
      boxY: 4,
      targetX: 0,
      targetY: 8,
      initialBattery: 75,
      obstacles: [
        Obstacle(x: 2, y: 3, height: 2),
        Obstacle(x: 2, y: 5, height: 2),
        Obstacle(x: 4, y: 3, height: 2),
        Obstacle(x: 4, y: 5, height: 2),
        Obstacle(x: 6, y: 3, height: 2),
        Obstacle(x: 6, y: 5, height: 2),
      ],
      energyCells: [EnergyCell(x: 4, y: 4, height: 1, charge: 15)],
      star3Target: 24,
    ),
    Level(
      id: 'N20',
      title: 'SECTOR COMMANDER',
      description:
          'The final exam. Combine nested loops, altitude shifts, and energy cell collection.',
      hint:
          'Plan your route to harvest energy, lift cargo from heights, and land under 30 blocks.',
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
        Obstacle(x: 6, y: 6, height: 3),
        Obstacle(x: 6, y: 7, height: 3),
      ],
      energyCells: [
        EnergyCell(x: 3, y: 9, height: 1, charge: 20),
        EnergyCell(x: 6, y: 9, height: 1, charge: 20),
        EnergyCell(x: 9, y: 5, height: 1, charge: 20),
      ],
      star3Target: 30,
    ),
  ];

  static final List<Level> predefinedHardLevels = [
    Level(
      id: 'H1',
      title: 'HARD LAUNCH',
      description:
          'Acquire the cargo box at (2, 4) and deliver it to the target pad with high winds and 70% battery.',
      hint: 'Navigate directly. Every move drains battery; don\'t waste steps.',
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 2,
      boxY: 4,
      targetX: 4,
      targetY: 4,
      initialBattery: 25,
      obstacles: [Obstacle(x: 1, y: 3, height: 1)],
      energyCells: [],
      star3Target: 8,
    ),
    Level(
      id: 'H2',
      title: 'HAZARDOUS YAW',
      description: 'Turn and weave around obstacles to fetch the cargo crate.',
      hint: 'Rotate quickly to orient the drone around the central pillar.',
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 0,
      startDirection: Direction.east,
      boxX: 4,
      boxY: 4,
      targetX: 0,
      targetY: 4,
      initialBattery: 28,
      obstacles: [
        Obstacle(x: 2, y: 2, height: 2),
        Obstacle(x: 2, y: 3, height: 2),
      ],
      energyCells: [],
      star3Target: 12,
    ),
    Level(
      id: 'H3',
      title: 'COMPACT WALLS',
      description:
          'Three high walls block your trajectory. Ascend high to clear them.',
      hint: 'Climb to height 3 to clear the buildings at altitude 2.',
      gridWidth: 6,
      gridHeight: 6,
      startX: 0,
      startY: 3,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 3,
      targetX: 5,
      targetY: 3,
      initialBattery: 32,
      obstacles: [
        Obstacle(x: 1, y: 3, height: 2),
        Obstacle(x: 2, y: 3, height: 2),
        Obstacle(x: 4, y: 3, height: 2),
      ],
      energyCells: [],
      star3Target: 15,
    ),
    Level(
      id: 'H4',
      title: 'TENSION PATROLS',
      description:
          'Perform repetitive scanning loops with very tight fuel reserves.',
      hint: 'Use a compact repeat loop to fly forward and pick up cargo.',
      gridWidth: 8,
      gridHeight: 5,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 5,
      boxY: 2,
      targetX: 7,
      targetY: 2,
      initialBattery: 30,
      obstacles: [Obstacle(x: 3, y: 2, height: 1)],
      energyCells: [EnergyCell(x: 2, y: 2, height: 1, charge: 10)],
      star3Target: 10,
    ),
    Level(
      id: 'H5',
      title: 'DENSE SECTOR SCAN',
      description:
          'Use sensory while/if statements to weave around active pillars.',
      hint:
          'Use sensors to check for obstacle ahead and turn right automatically.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 6,
      startDirection: Direction.north,
      boxX: 3,
      boxY: 1,
      targetX: 6,
      targetY: 6,
      initialBattery: 35,
      obstacles: [
        Obstacle(x: 1, y: 3, height: 2),
        Obstacle(x: 3, y: 3, height: 2),
        Obstacle(x: 5, y: 3, height: 2),
      ],
      energyCells: [EnergyCell(x: 3, y: 5, height: 1, charge: 15)],
      star3Target: 16,
    ),
    Level(
      id: 'H6',
      title: 'SKY-HIGH TERMINAL',
      description:
          'The cargo box is high on a height 3 skyscraper. Battery is extremely scarce.',
      hint:
          'Fly high to height 4 to grab the cargo at (2, 2). Collect the cell to survive.',
      gridWidth: 5,
      gridHeight: 5,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 2,
      boxY: 2,
      targetX: 4,
      targetY: 4,
      initialBattery: 25,
      obstacles: [Obstacle(x: 2, y: 2, height: 3)],
      energyCells: [EnergyCell(x: 2, y: 2, height: 4, charge: 15)],
      star3Target: 18,
    ),
    Level(
      id: 'H7',
      title: 'COMPRESSED SPIRAL',
      description: 'Inward spiral corridor with battery siphons.',
      hint:
          'Find the repeating rotate/move sequence to clear within constraints.',
      gridWidth: 6,
      gridHeight: 6,
      startX: 0,
      startY: 0,
      startDirection: Direction.east,
      boxX: 2,
      boxY: 2,
      targetX: 5,
      targetY: 5,
      initialBattery: 38,
      obstacles: [
        Obstacle(x: 1, y: 1, height: 2),
        Obstacle(x: 2, y: 1, height: 2),
        Obstacle(x: 3, y: 1, height: 2),
        Obstacle(x: 3, y: 2, height: 2),
        Obstacle(x: 3, y: 3, height: 2),
        Obstacle(x: 1, y: 3, height: 2),
      ],
      energyCells: [EnergyCell(x: 2, y: 2, height: 3, charge: 10)],
      star3Target: 22,
    ),
    Level(
      id: 'H8',
      title: 'DOUBLE SLALOM',
      description: 'Pillars form dual blockades. Zigzag precisely.',
      hint: 'Optimize your movements using repeat loops to conserve battery.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 6,
      startDirection: Direction.north,
      boxX: 3,
      boxY: 0,
      targetX: 6,
      targetY: 6,
      initialBattery: 40,
      obstacles: [
        Obstacle(x: 2, y: 1, height: 3),
        Obstacle(x: 2, y: 3, height: 3),
        Obstacle(x: 4, y: 3, height: 3),
        Obstacle(x: 4, y: 5, height: 3),
      ],
      energyCells: [EnergyCell(x: 3, y: 3, height: 1, charge: 15)],
      star3Target: 22,
    ),
    Level(
      id: 'H9',
      title: 'CRITICAL RESERVES',
      description:
          'Battery starts at 8. You must harvest cells at height 2 to survive.',
      hint: 'Ascend immediately to height 2 and sweep cells.',
      gridWidth: 8,
      gridHeight: 5,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 2,
      targetX: 7,
      targetY: 2,
      initialBattery: 8,
      obstacles: [],
      energyCells: [
        EnergyCell(x: 1, y: 2, height: 2, charge: 15),
        EnergyCell(x: 5, y: 2, height: 2, charge: 15),
      ],
      star3Target: 14,
    ),
    Level(
      id: 'H10',
      title: 'GORGE TRANSIT',
      description: 'Deep canyon navigation with high towers.',
      hint: 'Loop vertical movements to rise over heights.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 3,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 3,
      targetX: 6,
      targetY: 3,
      initialBattery: 35,
      obstacles: [
        Obstacle(x: 1, y: 3, height: 3),
        Obstacle(x: 5, y: 3, height: 3),
      ],
      energyCells: [EnergyCell(x: 3, y: 3, height: 4, charge: 20)],
      star3Target: 20,
    ),
    Level(
      id: 'H11',
      title: 'NARROW BRIDGE',
      description: 'Tight grid corridor with side wall obstacles.',
      hint: 'Any deviation will cause a collision. Fly straight.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 4,
      boxY: 4,
      targetX: 7,
      targetY: 4,
      initialBattery: 30,
      obstacles: [
        Obstacle(x: 2, y: 3, height: 2),
        Obstacle(x: 2, y: 5, height: 2),
        Obstacle(x: 5, y: 3, height: 2),
        Obstacle(x: 5, y: 5, height: 2),
      ],
      energyCells: [],
      star3Target: 12,
    ),
    Level(
      id: 'H12',
      title: 'MAZE CALIBRATION',
      description: 'Labyrinth routing with height 3 columns.',
      hint: 'Write a compact routine of turns and movements.',
      gridWidth: 7,
      gridHeight: 7,
      startX: 0,
      startY: 6,
      startDirection: Direction.north,
      boxX: 4,
      boxY: 1,
      targetX: 0,
      targetY: 0,
      initialBattery: 45,
      obstacles: [
        Obstacle(x: 1, y: 1, height: 3),
        Obstacle(x: 1, y: 3, height: 3),
        Obstacle(x: 3, y: 3, height: 3),
        Obstacle(x: 5, y: 3, height: 3),
      ],
      energyCells: [],
      star3Target: 22,
    ),
    Level(
      id: 'H13',
      title: 'HARD GRID SWEEP',
      description: 'Nested loops traversing larger grids with columns.',
      hint: 'Nest multiple loops to sweep coordinates efficiently.',
      gridWidth: 6,
      gridHeight: 6,
      startX: 0,
      startY: 5,
      startDirection: Direction.east,
      boxX: 5,
      boxY: 0,
      targetX: 0,
      targetY: 0,
      initialBattery: 45,
      obstacles: [Obstacle(x: 2, y: 2, height: 1)],
      energyCells: [],
      star3Target: 16,
    ),
    Level(
      id: 'H14',
      title: 'DOUBLE BARRIER HARD',
      description: 'Double walls at height 3. Requires high elevation leaps.',
      hint: 'Climb to maximum altitude. Collect fuel floating above towers.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 7,
      startDirection: Direction.north,
      boxX: 2,
      boxY: 6,
      targetX: 7,
      targetY: 7,
      initialBattery: 38,
      obstacles: [
        Obstacle(x: 1, y: 4, height: 3),
        Obstacle(x: 5, y: 4, height: 3),
      ],
      energyCells: [EnergyCell(x: 3, y: 4, height: 4, charge: 15)],
      star3Target: 22,
    ),
    Level(
      id: 'H15',
      title: 'SINE WAVE EXTRA',
      description: 'Oscillating pillars with restricted battery cells.',
      hint: 'Fly high and low dynamically inside repeat loops.',
      gridWidth: 9,
      gridHeight: 5,
      startX: 0,
      startY: 2,
      startDirection: Direction.east,
      boxX: 4,
      boxY: 2,
      targetX: 8,
      targetY: 2,
      initialBattery: 42,
      obstacles: [
        Obstacle(x: 2, y: 2, height: 2),
        Obstacle(x: 3, y: 2, height: 3),
        Obstacle(x: 4, y: 2, height: 4),
        Obstacle(x: 5, y: 2, height: 3),
        Obstacle(x: 6, y: 2, height: 2),
      ],
      energyCells: [],
      star3Target: 16,
    ),
    Level(
      id: 'H16',
      title: 'VERTICAL SHAFTS HARD',
      description: 'Tight vertical shafts with height 4 columns.',
      hint: 'Max out altitude to clear the dividers.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 7,
      startY: 7,
      startDirection: Direction.west,
      boxX: 5,
      boxY: 5,
      targetX: 1,
      targetY: 1,
      initialBattery: 50,
      obstacles: [
        Obstacle(x: 2, y: 3, height: 4),
        Obstacle(x: 4, y: 3, height: 4),
        Obstacle(x: 6, y: 3, height: 4),
      ],
      energyCells: [EnergyCell(x: 1, y: 5, height: 1, charge: 15)],
      star3Target: 25,
    ),
    Level(
      id: 'H17',
      title: 'METROPOLIS GRID',
      description: 'Metropolitan skyline with height 4 towers.',
      hint: 'Navigate horizontal turns. Do not attempt vertical clearance.',
      gridWidth: 9,
      gridHeight: 9,
      startX: 8,
      startY: 8,
      startDirection: Direction.north,
      boxX: 6,
      boxY: 6,
      targetX: 0,
      targetY: 0,
      initialBattery: 55,
      obstacles: [
        Obstacle(x: 3, y: 3, height: 4),
        Obstacle(x: 3, y: 4, height: 4),
        Obstacle(x: 3, y: 5, height: 4),
        Obstacle(x: 5, y: 3, height: 4),
        Obstacle(x: 5, y: 4, height: 4),
        Obstacle(x: 5, y: 5, height: 4),
      ],
      energyCells: [EnergyCell(x: 0, y: 6, height: 1, charge: 15)],
      star3Target: 30,
    ),
    Level(
      id: 'H18',
      title: 'SUMMIT RETRIEVAL HARD',
      description: 'Summit climb with 40 initial battery.',
      hint:
          'Quickly rise, collect the cargo, and descend straight to the target.',
      gridWidth: 8,
      gridHeight: 8,
      startX: 0,
      startY: 7,
      startDirection: Direction.east,
      boxX: 3,
      boxY: 3,
      targetX: 7,
      targetY: 7,
      initialBattery: 40,
      obstacles: [Obstacle(x: 3, y: 3, height: 3)],
      energyCells: [EnergyCell(x: 3, y: 3, height: 4, charge: 20)],
      star3Target: 22,
    ),
    Level(
      id: 'H19',
      title: 'LABYRINTH LOOP HARD',
      description: 'Labyrinth routing under tight battery.',
      hint: 'Use loops with sensors to minimize block usage and battery drain.',
      gridWidth: 9,
      gridHeight: 9,
      startX: 0,
      startY: 4,
      startDirection: Direction.east,
      boxX: 8,
      boxY: 4,
      targetX: 0,
      targetY: 8,
      initialBattery: 50,
      obstacles: [
        Obstacle(x: 2, y: 3, height: 2),
        Obstacle(x: 2, y: 5, height: 2),
        Obstacle(x: 4, y: 3, height: 2),
        Obstacle(x: 4, y: 5, height: 2),
        Obstacle(x: 6, y: 3, height: 2),
        Obstacle(x: 6, y: 5, height: 2),
      ],
      energyCells: [EnergyCell(x: 4, y: 4, height: 1, charge: 12)],
      star3Target: 24,
    ),
    Level(
      id: 'H20',
      title: 'HARD SECTOR COMMANDER',
      description:
          'The ultimate final exam in hard mode. Perfect code sequences are required.',
      hint:
          'Sweep cells, get cargo, fly over obstacle towers, and land perfectly.',
      gridWidth: 10,
      gridHeight: 10,
      startX: 0,
      startY: 9,
      startDirection: Direction.east,
      boxX: 9,
      boxY: 9,
      targetX: 0,
      targetY: 0,
      initialBattery: 32,
      obstacles: [
        Obstacle(x: 2, y: 2, height: 3),
        Obstacle(x: 2, y: 3, height: 3),
        Obstacle(x: 6, y: 6, height: 3),
        Obstacle(x: 6, y: 7, height: 3),
      ],
      energyCells: [
        EnergyCell(x: 3, y: 9, height: 1, charge: 15),
        EnergyCell(x: 6, y: 9, height: 1, charge: 15),
        EnergyCell(x: 9, y: 5, height: 1, charge: 15),
      ],
      star3Target: 30,
    ),
  ];

  static Level getDailyLevel() {
    final now = DateTime.now();
    final index =
        (now.day + now.month + now.year) % predefinedNormalLevels.length;
    final base = predefinedNormalLevels[index];

    return Level(
      id: 'D${now.day}',
      title: 'DAILY CALIBRATION: ${base.title}',
      description:
          'DAILY PILOT CHALLENGE. Complete this optimized calibration course to sync navigation telemetry. Target constraints are tightened!',
      hint: base.hint,
      gridWidth: base.gridWidth,
      gridHeight: base.gridHeight,
      startX: base.startX,
      startY: base.startY,
      startDirection: base.startDirection,
      boxX: base.boxX,
      boxY: base.boxY,
      targetX: base.targetX,
      targetY: base.targetY,
      initialBattery: (base.initialBattery * 0.95).round(),
      obstacles: base.obstacles,
      energyCells: base.energyCells,
      star3Target: (base.star3Target * 0.9).round(),
    );
  }

  static List<Level> getLevelsForMode(GameMode mode) {
    if (mode == GameMode.daily) {
      return [getDailyLevel()];
    }
    if (mode == GameMode.hard) {
      return predefinedHardLevels;
    }
    return predefinedNormalLevels;
  }
}
