import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/level.dart';
import '../theme/colors.dart';
import '../providers/game_state.dart';

class DroneSprite extends StatefulWidget {
  final double size; // Dynamic layout constraints
  final int height;
  final Direction direction;
  final bool isFlying;
  final bool hasCargo;
  final GameStatus status;
  final double speedMultiplier;

  const DroneSprite({
    super.key,
    required this.size,
    required this.height,
    required this.direction,
    required this.isFlying,
    required this.hasCargo,
    required this.status,
    required this.speedMultiplier,
  });

  @override
  State<DroneSprite> createState() => _DroneSpriteState();
}

class _DroneSpriteState extends State<DroneSprite> with TickerProviderStateMixin {
  late AnimationController _rotorController;
  late AnimationController _bobbingController;
  late AnimationController _clawController; // Controls claw extension & cargo grip
  late AnimationController _entryController; // Controls initial drop-in landing

  bool _isCargoVisible = false;

  @override
  void initState() {
    super.initState();

    // Propeller spinning controller
    _rotorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Hover bobbing controller (delicate vertical float)
    _bobbingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Claw extension controller: 0.0 (retracted), 1.0 (fully extended down to grab)
    _clawController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (700 / widget.speedMultiplier).round()),
    );

    // Entry landing controller: 1.0 (sky high) to 0.0 (grounded)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _isCargoVisible = widget.hasCargo;

    // Start with the landing intro if the game is idle
    if (widget.status == GameStatus.idle) {
      _playEntryLanding();
    } else if (widget.isFlying) {
      _rotorController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DroneSprite oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.speedMultiplier != oldWidget.speedMultiplier) {
      _clawController.duration = Duration(milliseconds: (700 / widget.speedMultiplier).round());
    }

    // Propeller speed adjustments
    if (widget.isFlying && !_rotorController.isAnimating) {
      _rotorController.repeat();
    } else if (!widget.isFlying && _rotorController.isAnimating && widget.status != GameStatus.idle) {
      // Delay stopping rotors until landing animation finishes (600ms)
      final delayMs = (600 / widget.speedMultiplier).round();
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted && !widget.isFlying) {
          _rotorController.stop();
        }
      });
    }

    // Trigger pickup animation when cargo state changes from false -> true
    if (widget.hasCargo && !oldWidget.hasCargo) {
      _playPickupAnimation();
    }

    // Trigger dropoff animation when cargo state changes from true -> false (delivered)
    if (!widget.hasCargo && oldWidget.hasCargo) {
      _playDropoffAnimation();
    }

    // Replay entry landing animation if level resets to idle
    if (widget.status == GameStatus.idle && oldWidget.status != GameStatus.idle) {
      _playEntryLanding();
    }
  }

  @override
  void dispose() {
    _rotorController.dispose();
    _bobbingController.dispose();
    _clawController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // Play cinematic sky drop-in landing animation
  void _playEntryLanding() {
    _isCargoVisible = false;
    _entryController.forward(from: 0.0);
    _rotorController.repeat(); // Spin props while dropping
    
    // Slow down propellers as touchdown occurs
    _entryController.addListener(() {
      final val = 1.0 - Curves.easeOutCubic.transform(_entryController.value); // 1.0 (air) to 0.0 (ground)
      if (val > 0.6) {
        _rotorController.duration = const Duration(milliseconds: 300);
        if (!_rotorController.isAnimating) _rotorController.repeat();
      } else if (val > 0.1) {
        _rotorController.duration = const Duration(milliseconds: 600);
        if (!_rotorController.isAnimating) _rotorController.repeat();
      } else {
        _rotorController.stop();
      }
    });
  }

  // Play claw grab sequence
  void _playPickupAnimation() {
    // 1. Extend claws down
    _clawController.forward().then((_) {
      setState(() {
        _isCargoVisible = true; // Cargo is now grabbed
      });
      // 2. Retract claws back with cargo
      _clawController.reverse();
    });
  }

  // Play claw drop-off sequence
  void _playDropoffAnimation() {
    // 1. Extend claws to drop cargo
    _clawController.forward().then((_) {
      setState(() {
        _isCargoVisible = false; // Cargo is released on target
      });
      // 2. Retract empty claws
      _clawController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetHeight = widget.height.toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: targetHeight, end: targetHeight),
      duration: Duration(milliseconds: (600 / widget.speedMultiplier).round()),
      curve: Curves.easeInOutCubic,
      builder: (context, animatedHeight, child) {
        // Combine 3D flight scale with the entry drop-in scale
        return AnimatedBuilder(
          animation: Listenable.merge([_entryController, _bobbingController, _clawController, _rotorController]),
          builder: (context, child) {
            final entryVal = 1.0 - Curves.easeOutCubic.transform(_entryController.value); // 1.0 (high) to 0.0 (landed)
            
            // 3D scale based on height
            final baseScale = 1.0 + 0.15 * animatedHeight;

            // Apply drop-in scale (starts at 2.5 when entryVal is 1.0, shrinks to 1.0 when entryVal is 0.0)
            final entryScale = ui.lerpDouble(1.0, 2.5, entryVal)!;
            final scale = baseScale * entryScale;

            // Hover bobbing offset (sinus float in mid-air)
            final double bobOffset = animatedHeight > 0.05 
                ? (widget.size * 0.05) * math.sin(_bobbingController.value * 2 * math.pi)
                : 0.0;

            // Visual landing drop offset (falls from -100px when entryVal is 1.0 down to 0px when entryVal is 0.0)
            final double entryYOffset = -100.0 * entryVal;

            final isCurrentlyFlying = widget.isFlying || animatedHeight > 0.05;

            return Transform.translate(
              offset: Offset(0.0, entryYOffset + bobOffset),
              child: Transform.scale(
                scale: scale,
                child: AnimatedRotation(
                  turns: widget.direction.angleInRadians / (2 * math.pi),
                  duration: Duration(milliseconds: (250 / widget.speedMultiplier).round()),
                  curve: Curves.easeInOut,
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Thruster engine glow beneath drone
                        if (isCurrentlyFlying || entryVal > 0.05)
                          Container(
                            width: widget.size * 0.48,
                            height: widget.size * 0.48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: CyberTheme.neonGlow(
                                widget.hasCargo ? CyberTheme.neonYellow : CyberTheme.neonCyan,
                                radius: widget.size * 0.3 * (isCurrentlyFlying ? 1.0 : entryVal),
                              ),
                            ),
                          ),

                        // Custom Painted Drone
                        CustomPaint(
                          size: Size(widget.size, widget.size),
                          painter: _CustomDronePainter(
                            rotorAngle: _rotorController.value * 2 * math.pi,
                            clawExtension: _clawController.value,
                            isCargoVisible: _isCargoVisible,
                            hasCargo: widget.hasCargo,
                            isFlying: isCurrentlyFlying,
                            status: widget.status,
                          ),
                        ),

                        // Counter-rotating telemetry altitude badge
                        Positioned(
                          bottom: -(widget.size * 0.1),
                          child: AnimatedRotation(
                            turns: -widget.direction.angleInRadians / (2 * math.pi),
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.size * 0.0875,
                                vertical: widget.size * 0.025,
                              ),
                              decoration: BoxDecoration(
                                color: CyberTheme.cardBg.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20.0),
                                border: Border.all(
                                  color: isCurrentlyFlying
                                      ? (widget.hasCargo ? CyberTheme.neonYellow : CyberTheme.neonCyan)
                                      : CyberTheme.borderTranslucent,
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                'ALT ${widget.height}',
                                style: CyberTheme.fontCode(
                                  size: math.max(6.0, widget.size * 0.1),
                                  color: isCurrentlyFlying
                                      ? (widget.hasCargo ? CyberTheme.neonYellow : CyberTheme.neonCyan)
                                      : CyberTheme.textMuted,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CustomDronePainter extends CustomPainter {
  final double rotorAngle;
  final double clawExtension; // 0.0 to 1.0
  final bool isCargoVisible;
  final bool hasCargo;
  final bool isFlying;
  final GameStatus status;

  _CustomDronePainter({
    required this.rotorAngle,
    required this.clawExtension,
    required this.isCargoVisible,
    required this.hasCargo,
    required this.isFlying,
    required this.status,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // Color definitions based on status
    final primaryColor = status == GameStatus.crashed
        ? CyberTheme.neonPink
        : (hasCargo ? CyberTheme.neonYellow : CyberTheme.neonCyan);

    // 1. Draw carbon-fiber quadcopter arms
    final armPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = size.width * 0.056
      ..strokeCap = StrokeCap.round;

    final armLen = size.width * 0.32;
    canvas.drawLine(Offset(cx - armLen, cy - armLen), Offset(cx + armLen, cy + armLen), armPaint);
    canvas.drawLine(Offset(cx - armLen, cy + armLen), Offset(cx + armLen, cy - armLen), armPaint);

    // 2. Draw metallic rotor rings at corners
    final rotorRadius = size.width * 0.12;
    final rotorOffsets = [
      Offset(cx - armLen, cy - armLen), // Top-Left
      Offset(cx + armLen, cy - armLen), // Top-Right
      Offset(cx - armLen, cy + armLen), // Bottom-Left
      Offset(cx + armLen, cy + armLen), // Bottom-Right
    ];

    final rimPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = size.width * 0.022
      ..style = PaintingStyle.stroke;

    final bladePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..strokeWidth = size.width * 0.022
      ..strokeCap = StrokeCap.round;

    for (final pos in rotorOffsets) {
      canvas.drawCircle(pos, rotorRadius, rimPaint);

      // Draw spinning propeller blades
      canvas.drawLine(
        Offset(
          pos.dx + rotorRadius * 0.9 * math.cos(rotorAngle),
          pos.dy + rotorRadius * 0.9 * math.sin(rotorAngle),
        ),
        Offset(
          pos.dx - rotorRadius * 0.9 * math.cos(rotorAngle),
          pos.dy - rotorRadius * 0.9 * math.sin(rotorAngle),
        ),
        bladePaint,
      );
    }

    // 3. Draw Grabber Claws & Cargo Crate (Drawn behind body fuselage)
    // Claws extend vertically downwards under the drone body
    final double clawY = cy + (size.height * 0.075) + (clawExtension * size.height * 0.2);
    final double clawSpread = (size.width * 0.125) - (clawExtension * size.width * 0.05);

    final clawPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = size.width * 0.031
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Left Claw claw path
    final leftClaw = Path()
      ..moveTo(cx - size.width * 0.1, cy + size.height * 0.05)
      ..lineTo(cx - clawSpread, clawY)
      ..lineTo(cx - clawSpread + size.width * 0.05, clawY + size.height * 0.05);
    canvas.drawPath(leftClaw, clawPaint);

    // Right Claw path
    final rightClaw = Path()
      ..moveTo(cx + size.width * 0.1, cy + size.height * 0.05)
      ..lineTo(cx + clawSpread, clawY)
      ..lineTo(cx + clawSpread - size.width * 0.05, clawY + size.height * 0.05);
    canvas.drawPath(rightClaw, clawPaint);

    // Render Carried Cargo Box Crate if visible
    if (isCargoVisible) {
      final double crateSize = size.width * 0.175;
      final crateRect = Rect.fromLTWH(
        cx - crateSize / 2,
        clawY,
        crateSize,
        crateSize,
      );
      
      // Glowing orange cargo crate body
      final cratePaint = Paint()
        ..color = CyberTheme.neonYellow
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(crateRect, const Radius.circular(3.0)), cratePaint);

      // Cargo diagonal stripe markings
      final stripePaint = Paint()
        ..color = CyberTheme.darkBg.withValues(alpha: 0.6)
        ..strokeWidth = 1.5;
      canvas.drawLine(crateRect.topLeft, crateRect.bottomRight, stripePaint);
      canvas.drawLine(crateRect.bottomLeft, crateRect.topRight, stripePaint);
    }

    // 4. Draw Core Fuselage / Body Pod
    final bodyPaint = Paint()
      ..color = CyberTheme.cardBg
      ..style = PaintingStyle.fill;

    final bodyBorder = Paint()
      ..color = primaryColor
      ..strokeWidth = size.width * 0.025
      ..style = PaintingStyle.stroke;

    final bodyRadius = size.width * 0.16;
    canvas.drawCircle(center, bodyRadius, bodyPaint);
    canvas.drawCircle(center, bodyRadius, bodyBorder);

    // LED Status Indicator Light (Points North/Up)
    final ledColor = status == GameStatus.crashed
        ? CyberTheme.neonPink
        : (isFlying ? CyberTheme.neonGreen : primaryColor);

    final ledPaint = Paint()
      ..color = ledColor
      ..style = PaintingStyle.fill;

    // LED forward heading indicator
    final ledOffset = Offset(cx, cy - bodyRadius + size.height * 0.05);
    final ledRadius = size.width * 0.038;
    canvas.drawCircle(ledOffset, ledRadius, ledPaint);
    canvas.drawCircle(ledOffset, ledRadius * 2, Paint()
      ..color = ledColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0));
  }

  @override
  bool shouldRepaint(covariant _CustomDronePainter oldDelegate) {
    return oldDelegate.rotorAngle != rotorAngle ||
        oldDelegate.clawExtension != clawExtension ||
        oldDelegate.isCargoVisible != isCargoVisible ||
        oldDelegate.hasCargo != hasCargo ||
        oldDelegate.isFlying != isFlying ||
        oldDelegate.status != status;
  }
}
