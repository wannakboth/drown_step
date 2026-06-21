import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import '../models/tutorial_keys.dart';
import '../models/level.dart';
import '../theme/colors.dart';
import '../providers/audio_provider.dart';

/// Full-screen tutorial overlay that highlights a target widget and
/// shows a callout card with a directional arrow pointing at the target.
class TutorialOverlay extends ConsumerStatefulWidget {
  final TutorialStep step;
  final int stepIndex;
  final int totalSteps;
  /// GlobalKey of the widget to spotlight. If null a centred card is shown.
  final GlobalKey? targetKey;
  final VoidCallback onNext;
  final VoidCallback? onPrev;

  const TutorialOverlay({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    this.targetKey,
    required this.onNext,
    this.onPrev,
  });

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _entryCtrl;
  late final Animation<double> _pulse;
  late final Animation<double> _bounce;
  late final Animation<double> _entryFade;
  late final Animation<double> _entryScale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _bounce = Tween<double>(begin: 0.0, end: 10.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn);
    _entryScale = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack));
    _entryCtrl.forward();
  }

  void _playClick() {
    ref.read(audioControllerProvider).playClick();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLast = widget.stepIndex == widget.totalSteps - 1;

    Rect? tRect;
    final key = widget.targetKey;
    if (key != null && key.currentContext != null) {
      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && key.currentContext!.mounted) {
        final offset = box.localToGlobal(Offset.zero);
        tRect = offset & box.size;
      }
    }

    Rect? consoleRect;
    final consoleKey = TutorialKeys.console;
    if (consoleKey.currentContext != null) {
      final box = consoleKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && consoleKey.currentContext!.mounted) {
        final offset = box.localToGlobal(Offset.zero);
        consoleRect = offset & box.size;
      }
    }

    final allowConsolePass = widget.step.target == TutorialTarget.workspace;
    final isInformational = widget.step.target == TutorialTarget.telemetry ||
        widget.step.target == TutorialTarget.console ||
        widget.step.target == TutorialTarget.gridArena;

    return SpotlightHitTestBlocker(
      targetRect: tRect,
      consoleRect: consoleRect,
      allowConsolePassThrough: allowConsolePass,
      onTargetTapped: isInformational
          ? () {
              _playClick();
              widget.onNext();
            }
          : null,
      child: FadeTransition(
        opacity: _entryFade,
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              // ── Callout card geometry ──────────────────────────────────────
              const cardW = 270.0;
              const cardH = 150.0;
              late double cardLeft, cardTop;
              String arrowDir = 'none';

              if (tRect != null) {
                cardLeft = (tRect.center.dx - cardW / 2).clamp(12.0, size.width - cardW - 12.0);

                if (tRect.center.dy > size.height / 2) {
                  cardTop = (tRect.top - cardH - 32.0).clamp(12.0, size.height - cardH - 12.0);
                  arrowDir = 'down';
                } else {
                  cardTop = (tRect.bottom + 32.0).clamp(12.0, size.height - cardH - 12.0);
                  arrowDir = 'up';
                }
              } else {
                cardLeft = (size.width - cardW) / 2;
                cardTop = size.height - cardH - 80.0;
              }

              final cardRect = Rect.fromLTWH(cardLeft, cardTop, cardW, cardH);

              return Stack(
                children: [
                  // ── Dark overlay with spotlight hole ─────────────────────
                  CustomPaint(
                    size: size,
                    painter: _SpotlightPainter(
                      targetRect: tRect?.inflate(10.0),
                      pulseValue: _pulse.value,
                    ),
                  ),

                  // ── Pulsing glow ring around target ──────────────────────
                  if (tRect != null)
                    Positioned(
                      left: tRect.left - 10,
                      top: tRect.top - 10,
                      width: tRect.width + 20,
                      height: tRect.height + 20,
                      child: ScaleTransition(
                        scale: _entryScale,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: CyberTheme.neonCyan
                                  .withValues(alpha: 0.4 + 0.6 * _pulse.value),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: CyberTheme.neonCyan
                                    .withValues(alpha: 0.35 * _pulse.value),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Animated bouncing arrow ───────────────────────────────
                  if (tRect != null && arrowDir != 'none')
                    _buildBounceArrow(tRect, arrowDir, _bounce.value),

                  // ── Callout card ──────────────────────────────────────────
                  Positioned(
                    left: cardRect.left,
                    top: cardRect.top,
                    width: cardRect.width,
                    child: ScaleTransition(
                      scale: _entryScale,
                      child: _buildCard(isLast),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBounceArrow(Rect tRect, String dir, double bounce) {
    double x, y;
    if (dir == 'up') {
      x = tRect.center.dx - 14;
      y = tRect.top - 28 - bounce;
    } else {
      x = tRect.center.dx - 14;
      y = tRect.bottom + 6 + bounce;
    }
    final rotation = dir == 'up' ? 0.0 : math.pi;

    return Positioned(
      left: x,
      top: y,
      child: ScaleTransition(
        scale: _entryScale,
        child: Transform.rotate(
          angle: rotation,
          child: Icon(
            Icons.arrow_drop_up,
            size: 32,
            color: CyberTheme.neonCyan.withValues(alpha: 0.9),
            shadows: [
              Shadow(
                color: CyberTheme.neonCyan.withValues(alpha: 0.6),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(bool isLast) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07111F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CyberTheme.neonCyan, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: CyberTheme.neonCyan.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.psychology, color: CyberTheme.neonCyan, size: 16),
                const SizedBox(width: 6),
                Text(
                  'CO-PILOT  ${widget.stepIndex + 1} / ${widget.totalSteps}',
                  style: CyberTheme.fontCode(size: 11, color: CyberTheme.neonCyan)
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            // Step dots
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.totalSteps, (i) {
                final active = i == widget.stepIndex;
                final done = i < widget.stepIndex;
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: active ? 16 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: done
                        ? CyberTheme.neonGreen.withValues(alpha: 0.7)
                        : active
                            ? CyberTheme.neonCyan
                            : Colors.white12,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            // Message
            Text(
              widget.step.message,
              style: CyberTheme.fontBody(size: 12.5, color: CyberTheme.textMain),
            ),
            const SizedBox(height: 12),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onPrev != null)
                  GestureDetector(
                    onTap: () {
                      _playClick();
                      widget.onPrev!();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: CyberTheme.borderTranslucent),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '← PREV',
                        style: CyberTheme.fontCode(size: 10.5, color: Colors.white54),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _playClick();
                    widget.onNext();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLast
                          ? CyberTheme.neonGreen.withValues(alpha: 0.15)
                          : CyberTheme.neonCyan.withValues(alpha: 0.15),
                      border: Border.all(
                        color: isLast ? CyberTheme.neonGreen : CyberTheme.neonCyan,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isLast ? 'START  ▶' : 'NEXT  →',
                      style: CyberTheme.fontCode(
                        size: 10.5,
                        color: isLast ? CyberTheme.neonGreen : CyberTheme.neonCyan,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom painter ─────────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double pulseValue;

  const _SpotlightPainter({this.targetRect, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = const Color(0xCC000000);

    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, overlay);
      return;
    }

    // Dim everything except spotlight hole
    final rRect = RRect.fromRectAndRadius(targetRect!, const Radius.circular(10));
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rRect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    // Animated cyan glow ring
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + 2.0 * pulseValue
      ..color = const Color(0xFF00FFFF).withValues(alpha: 0.5 * pulseValue)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 * pulseValue);
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect!.inflate(2), const Radius.circular(12)),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.targetRect != targetRect || old.pulseValue != pulseValue;
}

class SpotlightHitTestBlocker extends SingleChildRenderObjectWidget {
  final Rect? targetRect;
  final Rect? consoleRect;
  final bool allowConsolePassThrough;
  final VoidCallback? onTargetTapped;

  const SpotlightHitTestBlocker({
    super.key,
    required super.child,
    this.targetRect,
    this.consoleRect,
    this.allowConsolePassThrough = false,
    this.onTargetTapped,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSpotlightHitTestBlocker(
      targetRect: targetRect,
      consoleRect: consoleRect,
      allowConsolePassThrough: allowConsolePassThrough,
      onTargetTapped: onTargetTapped,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObject) {
    final blocker = renderObject as _RenderSpotlightHitTestBlocker;
    blocker.targetRect = targetRect;
    blocker.consoleRect = consoleRect;
    blocker.allowConsolePassThrough = allowConsolePassThrough;
    blocker.onTargetTapped = onTargetTapped;
  }
}

class _RenderSpotlightHitTestBlocker extends RenderProxyBox {
  Rect? _targetRect;
  Rect? _consoleRect;
  bool _allowConsolePassThrough;
  VoidCallback? _onTargetTapped;

  _RenderSpotlightHitTestBlocker({
    Rect? targetRect,
    Rect? consoleRect,
    required bool allowConsolePassThrough,
    VoidCallback? onTargetTapped,
  })  : _targetRect = targetRect,
        _consoleRect = consoleRect,
        _allowConsolePassThrough = allowConsolePassThrough,
        _onTargetTapped = onTargetTapped;

  Rect? get targetRect => _targetRect;
  set targetRect(Rect? value) {
    if (_targetRect != value) {
      _targetRect = value;
      markNeedsPaint();
    }
  }

  Rect? get consoleRect => _consoleRect;
  set consoleRect(Rect? value) {
    if (_consoleRect != value) {
      _consoleRect = value;
      markNeedsPaint();
    }
  }

  bool get allowConsolePassThrough => _allowConsolePassThrough;
  set allowConsolePassThrough(bool value) {
    if (_allowConsolePassThrough != value) {
      _allowConsolePassThrough = value;
      markNeedsPaint();
    }
  }

  VoidCallback? get onTargetTapped => _onTargetTapped;
  set onTargetTapped(VoidCallback? value) {
    if (_onTargetTapped != value) {
      _onTargetTapped = value;
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 1. Check if it hits the overlay card/buttons (like NEXT button) to prioritize them.
    final hitChild = super.hitTest(result, position: position);
    if (hitChild) {
      return true; // handled by overlay
    }

    // 2. If inside the target spotlight, let click pass through.
    if (_targetRect != null && _targetRect!.contains(position)) {
      if (_onTargetTapped != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onTargetTapped!();
        });
      }
      return false; // pass through
    }

    // 3. If allowConsolePassThrough is true and click is inside consoleRect, let it pass through.
    if (_allowConsolePassThrough && _consoleRect != null && _consoleRect!.contains(position)) {
      return false; // pass through
    }

    // 4. Otherwise, block the click.
    return true;
  }
}
