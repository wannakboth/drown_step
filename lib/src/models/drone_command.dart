import 'package:flutter/material.dart';

enum CommandType {
  takeoff,
  land,
  forward,
  rotateLeft,
  rotateRight,
  ascend,
  descend,
}

class DroneCommand {
  final CommandType type;
  
  const DroneCommand(this.type);

  String get label {
    switch (type) {
      case CommandType.takeoff:
        return 'TAKEOFF';
      case CommandType.land:
        return 'LAND';
      case CommandType.forward:
        return 'MOVE FORWARD';
      case CommandType.rotateLeft:
        return 'TURN LEFT';
      case CommandType.rotateRight:
        return 'TURN RIGHT';
      case CommandType.ascend:
        return 'ASCEND';
      case CommandType.descend:
        return 'DESCEND';
    }
  }

  String get shortLabel {
    switch (type) {
      case CommandType.takeoff:
        return 'T-OFF';
      case CommandType.land:
        return 'LAND';
      case CommandType.forward:
        return 'FWD';
      case CommandType.rotateLeft:
        return 'L-ROT';
      case CommandType.rotateRight:
        return 'R-ROT';
      case CommandType.ascend:
        return 'ASC';
      case CommandType.descend:
        return 'DSC';
    }
  }

  IconData get icon {
    switch (type) {
      case CommandType.takeoff:
        return Icons.flight_takeoff;
      case CommandType.land:
        return Icons.flight_land;
      case CommandType.forward:
        return Icons.arrow_upward;
      case CommandType.rotateLeft:
        return Icons.rotate_left;
      case CommandType.rotateRight:
        return Icons.rotate_right;
      case CommandType.ascend:
        return Icons.keyboard_double_arrow_up;
      case CommandType.descend:
        return Icons.keyboard_double_arrow_down;
    }
  }

  String get description {
    switch (type) {
      case CommandType.takeoff:
        return 'Liftoff to hovering altitude of 1.';
      case CommandType.land:
        return 'Land drone at current position.';
      case CommandType.forward:
        return 'Advance 1 cell in current heading.';
      case CommandType.rotateLeft:
        return 'Rotate 90° counter-clockwise.';
      case CommandType.rotateRight:
        return 'Rotate 90° clockwise.';
      case CommandType.ascend:
        return 'Increase altitude by 1 unit.';
      case CommandType.descend:
        return 'Decrease altitude by 1 unit.';
    }
  }
}
