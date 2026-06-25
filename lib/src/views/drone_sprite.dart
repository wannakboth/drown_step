import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/level.dart';
import '../theme/colors.dart';
import '../providers/game_state.dart';

enum DroneLayer { claws, arms, body, rotors }

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

class _DroneSpriteState extends State<DroneSprite>
    with TickerProviderStateMixin {
  late AnimationController _rotorController;
  late AnimationController _bobbingController;
  late AnimationController
  _clawController; // Controls claw extension & cargo grip
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
      duration: Duration(milliseconds: (1600 / widget.speedMultiplier).round()),
    );

    // Entry landing controller: 1.0 (sky high) to 0.0 (grounded)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: 1.0,
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
      _clawController.duration = Duration(
        milliseconds: (1600 / widget.speedMultiplier).round(),
      );
    }

    // Propeller speed adjustments
    if (widget.isFlying && !_rotorController.isAnimating) {
      _rotorController.repeat();
    } else if (!widget.isFlying &&
        _rotorController.isAnimating &&
        widget.status != GameStatus.idle) {
      // Delay stopping rotors until landing animation finishes (1000ms)
      final delayMs = (1000 / widget.speedMultiplier).round();
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
    if (widget.status == GameStatus.idle &&
        oldWidget.status != GameStatus.idle) {
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
      final val =
          1.0 -
          Curves.easeOutCubic.transform(
            _entryController.value,
          ); // 1.0 (air) to 0.0 (ground)
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
      tween: Tween<double>(end: targetHeight),
      duration: Duration(milliseconds: (1600 / widget.speedMultiplier).round()),
      curve: Curves.easeInOutCubic,
      builder: (context, animatedHeight, child) {
        // Combine 3D flight scale with the entry drop-in scale
        return AnimatedBuilder(
          animation: Listenable.merge([
            _entryController,
            _bobbingController,
            _clawController,
            _rotorController,
          ]),
          builder: (context, child) {
            final entryVal =
                1.0 -
                Curves.easeOutCubic.transform(
                  _entryController.value,
                ); // 1.0 (high) to 0.0 (landed)

            // 3D scale based on height
            final baseScale = 1.0 + 0.15 * animatedHeight;

            // Apply drop-in scale (starts at 2.5 when entryVal is 1.0, shrinks to 1.0 when entryVal is 0.0)
            final entryScale = ui.lerpDouble(1.0, 2.5, entryVal)!;
            final scale = baseScale * entryScale;

            // Hover bobbing offset (sinus float in mid-air)
            final double bobOffset = animatedHeight > 0.05
                ? (widget.size * 0.05) *
                      math.sin(_bobbingController.value * 2 * math.pi)
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
                  duration: Duration(
                    milliseconds: (250 / widget.speedMultiplier).round(),
                  ),
                  curve: Curves.easeInOut,
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Thruster engine glow or status glow beneath drone
                        if (isCurrentlyFlying ||
                            entryVal > 0.05 ||
                            widget.status == GameStatus.crashed ||
                            widget.status == GameStatus.success)
                          Transform(
                            transform: Matrix4.translationValues(0, 0, -6.0),
                            child: Container(
                              width: widget.size * 0.48,
                              height: widget.size * 0.48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: CyberTheme.neonGlow(
                                  widget.status == GameStatus.crashed
                                      ? Colors.redAccent
                                      : (widget.status == GameStatus.success
                                            ? CyberTheme.neonGreen
                                            : (widget.hasCargo
                                                  ? CyberTheme.neonYellow
                                                  : CyberTheme.neonCyan)),
                                  radius:
                                      widget.size *
                                      0.3 *
                                      (isCurrentlyFlying
                                          ? 1.0
                                          : (widget.status != GameStatus.idle
                                                ? 1.0
                                                : entryVal)),
                                ),
                              ),
                            ),
                          ),

                        // 1. Landing Gear Skids / Claws layer (z = -4.0)
                        Transform(
                          transform: Matrix4.translationValues(0, 0, -4.0),
                          child: CustomPaint(
                            size: Size(widget.size, widget.size),
                            painter: _CustomDronePainter(
                              layer: DroneLayer.claws,
                              isBodyTop: false,
                              isArmTop: false,
                              bodyLayerIndex: 0,
                              rotorAngle: _rotorController.value * 2 * math.pi,
                              clawExtension: _clawController.value,
                              isCargoVisible: _isCargoVisible,
                              hasCargo: widget.hasCargo,
                              isFlying: isCurrentlyFlying,
                              status: widget.status,
                            ),
                          ),
                        ),

                        // Volumetric 3D Carried Cargo Crate (True Z-stacking centered inside the claws)
                        if (_isCargoVisible)
                          ...List.generate(6, (index) {
                            final double cargoCrateSize = widget.size * 0.22;
                            final double zVal = -6.0 + index * 1.0;
                            final isTop = index == 5;
                            final double clawYOffset =
                                (widget.size * 0.06) +
                                (_clawController.value * widget.size * 0.16);

                            return Transform(
                              transform: Matrix4.translationValues(
                                0.0,
                                clawYOffset,
                                zVal,
                              ),
                              child: Center(
                                child: Container(
                                  width: cargoCrateSize,
                                  height: cargoCrateSize,
                                  decoration: BoxDecoration(
                                    color: isTop
                                        ? Colors.transparent
                                        : const Color(
                                            0xFFB4703C,
                                          ).withValues(alpha: 0.95),
                                    border: isTop
                                        ? null
                                        : Border.all(
                                            color: const Color(
                                              0xFF8B4F21,
                                            ).withValues(alpha: 0.4),
                                            width: 1.0,
                                          ),
                                    borderRadius: BorderRadius.circular(2.0),
                                  ),
                                  child: isTop
                                      ? CustomPaint(
                                          size: Size(
                                            cargoCrateSize,
                                            cargoCrateSize,
                                          ),
                                          painter: CarriedCargoTopPainter(),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),

                        // 2. Arms bottom shadow layer (z = 0.0)
                        Transform(
                          transform: Matrix4.translationValues(0, 0, 0.0),
                          child: CustomPaint(
                            size: Size(widget.size, widget.size),
                            painter: _CustomDronePainter(
                              layer: DroneLayer.arms,
                              isBodyTop: false,
                              isArmTop: false,
                              bodyLayerIndex: 0,
                              rotorAngle: _rotorController.value * 2 * math.pi,
                              clawExtension: _clawController.value,
                              isCargoVisible: _isCargoVisible,
                              hasCargo: widget.hasCargo,
                              isFlying: isCurrentlyFlying,
                              status: widget.status,
                            ),
                          ),
                        ),

                        // 3. Arms top white layer (z = 1.5)
                        Transform(
                          transform: Matrix4.translationValues(0, 0, 1.5),
                          child: CustomPaint(
                            size: Size(widget.size, widget.size),
                            painter: _CustomDronePainter(
                              layer: DroneLayer.arms,
                              isBodyTop: false,
                              isArmTop: true,
                              bodyLayerIndex: 0,
                              rotorAngle: _rotorController.value * 2 * math.pi,
                              clawExtension: _clawController.value,
                              isCargoVisible: _isCargoVisible,
                              hasCargo: widget.hasCargo,
                              isFlying: isCurrentlyFlying,
                              status: widget.status,
                            ),
                          ),
                        ),

                        // 4. Volumetric Sculpted Body pod (stacked 5 times from z = 2.0 to z = 6.0)
                        ...List.generate(5, (index) {
                          final zVal = 2.0 + index * 1.0;
                          final isTop = index == 4;
                          return Transform(
                            transform: Matrix4.translationValues(0, 0, zVal),
                            child: CustomPaint(
                              size: Size(widget.size, widget.size),
                              painter: _CustomDronePainter(
                                layer: DroneLayer.body,
                                isBodyTop: isTop,
                                isArmTop: false,
                                bodyLayerIndex: index,
                                rotorAngle:
                                    _rotorController.value * 2 * math.pi,
                                clawExtension: _clawController.value,
                                isCargoVisible: _isCargoVisible,
                                hasCargo: widget.hasCargo,
                                isFlying: isCurrentlyFlying,
                                status: widget.status,
                              ),
                            ),
                          );
                        }),

                        // 5. Rotors layer (z = 8.0)
                        Transform(
                          transform: Matrix4.translationValues(0, 0, 8.0),
                          child: CustomPaint(
                            size: Size(widget.size, widget.size),
                            painter: _CustomDronePainter(
                              layer: DroneLayer.rotors,
                              isBodyTop: false,
                              isArmTop: false,
                              bodyLayerIndex: 0,
                              rotorAngle: _rotorController.value * 2 * math.pi,
                              clawExtension: _clawController.value,
                              isCargoVisible: _isCargoVisible,
                              hasCargo: widget.hasCargo,
                              isFlying: isCurrentlyFlying,
                              status: widget.status,
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
  final DroneLayer layer;
  final bool isBodyTop;
  final bool isArmTop;
  final int bodyLayerIndex;
  final double rotorAngle;
  final double clawExtension; // 0.0 to 1.0
  final bool isCargoVisible;
  final bool hasCargo;
  final bool isFlying;
  final GameStatus status;

  _CustomDronePainter({
    required this.layer,
    required this.isBodyTop,
    required this.isArmTop,
    required this.bodyLayerIndex,
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
        ? Colors.redAccent
        : (status == GameStatus.success
              ? CyberTheme.neonGreen
              : (hasCargo ? CyberTheme.neonYellow : CyberTheme.neonCyan));

    final armLen = size.width * 0.32;
    final rotorOffsets = [
      Offset(cx - armLen, cy - armLen), // Top-Left
      Offset(cx + armLen, cy - armLen), // Top-Right
      Offset(cx - armLen, cy + armLen), // Bottom-Left
      Offset(cx + armLen, cy + armLen), // Bottom-Right
    ];

    if (layer == DroneLayer.arms) {
      if (!isArmTop) {
        // Draw carbon-fiber/dark under-arms for 3D depth shadow
        final armPaint = Paint()
          ..color = const Color(0xFF0F172A)
          ..strokeWidth = size.width * 0.075
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(cx - armLen, cy - armLen),
          Offset(cx + armLen, cy + armLen),
          armPaint,
        );
        canvas.drawLine(
          Offset(cx - armLen, cy + armLen),
          Offset(cx + armLen, cy - armLen),
          armPaint,
        );

        // Draw motor pod base caps
        final motorRadius = size.width * 0.07;
        final motorPaint = Paint()
          ..color = const Color(0xFF1E293B)
          ..style = PaintingStyle.fill;
        for (final pos in rotorOffsets) {
          canvas.drawCircle(pos, motorRadius, motorPaint);
        }
      } else {
        // Draw white top-arms
        final armPaint = Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = size.width * 0.055
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(cx - armLen, cy - armLen),
          Offset(cx + armLen, cy + armLen),
          armPaint,
        );
        canvas.drawLine(
          Offset(cx - armLen, cy + armLen),
          Offset(cx + armLen, cy - armLen),
          armPaint,
        );

        // Draw motor pod casings & metallic rim ring
        final motorRadius = size.width * 0.06;
        final motorPaint = Paint()
          ..color = const Color(0xFF94A3B8)
          ..style = PaintingStyle.fill;

        final rimPaint = Paint()
          ..color = const Color(0xFF475569)
          ..strokeWidth = size.width * 0.018
          ..style = PaintingStyle.stroke;

        for (final pos in rotorOffsets) {
          canvas.drawCircle(pos, motorRadius, motorPaint);
          canvas.drawCircle(pos, motorRadius, rimPaint);
        }
      }
    }

    if (layer == DroneLayer.rotors) {
      final rotorRadius = size.width * 0.12;

      // Draw propeller blades
      final bladePaint = Paint()
        ..color = status == GameStatus.crashed
            ? Colors.redAccent.withValues(alpha: 0.8)
            : const Color(0xFF1E293B).withValues(alpha: 0.9)
        ..strokeWidth = size.width * 0.025
        ..strokeCap = StrokeCap.round;

      for (final pos in rotorOffsets) {
        // Draw circular motion blur disk if flying
        if (isFlying) {
          canvas.drawCircle(
            pos,
            rotorRadius,
            Paint()
              ..color = primaryColor.withValues(alpha: 0.12)
              ..style = PaintingStyle.fill,
          );
        }

        // Spinner center cap
        canvas.drawCircle(
          pos,
          size.width * 0.03,
          Paint()..color = const Color(0xFF0F172A),
        );

        // Opposing blades spinning
        canvas.drawLine(
          Offset(
            pos.dx + rotorRadius * 0.95 * math.cos(rotorAngle),
            pos.dy + rotorRadius * 0.95 * math.sin(rotorAngle),
          ),
          Offset(
            pos.dx - rotorRadius * 0.95 * math.cos(rotorAngle),
            pos.dy - rotorRadius * 0.95 * math.sin(rotorAngle),
          ),
          bladePaint,
        );
      }
    }

    if (layer == DroneLayer.claws) {
      // Draw landing skids and struts
      final double clawY =
          cy + (size.height * 0.06) + (clawExtension * size.height * 0.16);
      final double clawSpread =
          (size.width * 0.13) + (clawExtension * size.width * 0.08);

      final strutPaint = Paint()
        ..color = const Color(0xFF475569)
        ..strokeWidth = size.width * 0.025
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Left Skid Struts
      canvas.drawLine(
        Offset(cx - size.width * 0.1, cy),
        Offset(cx - clawSpread, clawY),
        strutPaint,
      );
      canvas.drawLine(
        Offset(cx - size.width * 0.1, cy + size.height * 0.06),
        Offset(cx - clawSpread, clawY),
        strutPaint,
      );

      // Right Skid Struts
      canvas.drawLine(
        Offset(cx + size.width * 0.1, cy),
        Offset(cx + clawSpread, clawY),
        strutPaint,
      );
      canvas.drawLine(
        Offset(cx + size.width * 0.1, cy + size.height * 0.06),
        Offset(cx + clawSpread, clawY),
        strutPaint,
      );

      // Horizontal skids (foot bars)
      final skidPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..strokeWidth = size.width * 0.035
        ..strokeCap = StrokeCap.round;

      // Left skid bar
      canvas.drawLine(
        Offset(cx - clawSpread - size.width * 0.06, clawY),
        Offset(cx - clawSpread + size.width * 0.08, clawY),
        skidPaint,
      );

      // Right skid bar
      canvas.drawLine(
        Offset(cx + clawSpread - size.width * 0.08, clawY),
        Offset(cx + clawSpread + size.width * 0.06, clawY),
        skidPaint,
      );
    }

    if (layer == DroneLayer.body) {
      if (bodyLayerIndex == 0) {
        // Bottom-most chassis plate: dark carbon base
        final bodyPaint = Paint()
          ..color = const Color(0xFF334155)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, size.width * 0.11, bodyPaint);

        // Draw camera gimbal pod
        final gimbalPaint = Paint()
          ..color = const Color(0xFF1E293B)
          ..style = PaintingStyle.fill;
        final gimbalOffset = Offset(cx, cy + size.height * 0.04);
        canvas.drawCircle(gimbalOffset, size.width * 0.05, gimbalPaint);

        // Glowing camera lens facing forward
        final lensPaint = Paint()
          ..color = primaryColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          gimbalOffset - Offset(0, size.height * 0.015),
          size.width * 0.02,
          lensPaint,
        );
      } else if (bodyLayerIndex == 1) {
        // Lower pod chassis: light gray
        final bodyPaint = Paint()
          ..color = const Color(0xFFCBD5E1)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, size.width * 0.14, bodyPaint);
      } else if (bodyLayerIndex == 2) {
        // Main pod chassis: soft off-white
        final bodyPaint = Paint()
          ..color = const Color(0xFFF1F5F9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, size.width * 0.165, bodyPaint);
      } else if (bodyLayerIndex == 3) {
        // Upper pod chassis: pure white
        final bodyPaint = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, size.width * 0.145, bodyPaint);
      } else if (bodyLayerIndex == 4) {
        // Top dome cap: white shell with border & status LED
        final bodyPaint = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill;

        final bodyBorder = Paint()
          ..color = primaryColor
          ..strokeWidth = size.width * 0.02
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(center, size.width * 0.11, bodyPaint);
        canvas.drawCircle(center, size.width * 0.11, bodyBorder);

        // LED Status Indicator Light (Points North/Up)
        final ledColor = status == GameStatus.crashed
            ? Colors.redAccent
            : (status == GameStatus.success
                  ? CyberTheme.neonGreen
                  : (isFlying ? CyberTheme.neonGreen : primaryColor));

        final ledPaint = Paint()
          ..color = ledColor
          ..style = PaintingStyle.fill;

        final ledOffset = Offset(
          cx,
          cy - size.width * 0.11 + size.height * 0.04,
        );
        final ledRadius = size.width * 0.035;
        canvas.drawCircle(ledOffset, ledRadius, ledPaint);
        canvas.drawCircle(
          ledOffset,
          ledRadius * 2,
          Paint()
            ..color = ledColor.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CustomDronePainter oldDelegate) {
    return oldDelegate.rotorAngle != rotorAngle ||
        oldDelegate.clawExtension != clawExtension ||
        oldDelegate.isCargoVisible != isCargoVisible ||
        oldDelegate.hasCargo != hasCargo ||
        oldDelegate.isFlying != isFlying ||
        oldDelegate.status != status ||
        oldDelegate.layer != layer ||
        oldDelegate.isBodyTop != isBodyTop ||
        oldDelegate.isArmTop != isArmTop ||
        oldDelegate.bodyLayerIndex != bodyLayerIndex;
  }
}

class CarriedCargoTopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Warm cardboard color
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2.0)),
      Paint()
        ..color = const Color(0xFFE5A96C)
        ..style = PaintingStyle.fill,
    );

    // Cardboard borders (darker brown)
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2.0)),
      Paint()
        ..color = const Color(0xFF8B4F21)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );

    // Central white packaging tape line
    final tapeWidth = size.width * 0.16;
    canvas.drawRect(
      Rect.fromLTWH(cx - tapeWidth / 2, 0, tapeWidth, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // Division line
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = const Color(0xFF8B4F21).withValues(alpha: 0.5)
        ..strokeWidth = 0.6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
