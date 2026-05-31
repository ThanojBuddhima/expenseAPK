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

/// Frosted fade at the top of tab screens so content scrolls beneath a soft edge.
class TopFadeOverlay extends StatelessWidget {
  const TopFadeOverlay({
    super.key,
    required this.child,
    this.horizontalPadding = 16,
    this.topPadding = AppTheme.screenTopPadding,
  });

  final Widget child;
  final double horizontalPadding;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final fadeHeight = topInset + topPadding;
    final base = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, fadeHeight, horizontalPadding, 0),
          child: child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: fadeHeight,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      base.withValues(alpha: 0.9),
                      base.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
