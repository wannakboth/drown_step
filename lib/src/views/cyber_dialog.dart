import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Shows a dialog with a smooth scale-fade transition and an animating backdrop blur.
Future<T?> showCyberDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) {
      return builder(context);
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 5.0 * anim1.value,
          sigmaY: 5.0 * anim1.value,
        ),
        child: FadeTransition(
          opacity: anim1,
          child: Transform.scale(
            scale: 0.94 + (0.06 * anim1.value),
            child: child,
          ),
        ),
      );
    },
  );
}
