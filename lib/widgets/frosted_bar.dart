import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Frosted, shaded bar for top or bottom overlays.
class FrostedBar extends StatelessWidget {
  const FrostedBar({
    super.key,
    required this.child,
    this.placement = FrostedBarPlacement.top,
  });

  final Widget child;
  final FrostedBarPlacement placement;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.surfaceDark : AppColors.surface;
    final isTop = placement == FrostedBarPlacement.top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: ColoredBox(
          color: base.withValues(alpha: isTop ? 0.94 : 0.98),
          child: child,
        ),
      ),
    );
  }
}

enum FrostedBarPlacement { top, bottom }
