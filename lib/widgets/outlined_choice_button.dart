import 'package:flutter/material.dart';

import '../app_theme.dart';

class OutlinedChoiceButton extends StatelessWidget {
  const OutlinedChoiceButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
    this.icon,
    this.subtitle,
    this.compact = false,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 20.0 : AppTheme.cardRadius;
    final accent = AppColors.readableAccent(color);
    final labelStyle = TextStyle(
      fontSize: compact ? 13 : 14,
      fontWeight: FontWeight.w600,
      color: accent,
    );

    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: isSelected ? accent : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: subtitle != null ? 18 : (compact ? 8 : 14),
            horizontal: compact ? 14 : 16,
          ),
          child: subtitle != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: labelStyle),
                    const SizedBox(height: 10),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                )
              : icon != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Text(label, style: labelStyle),
                      ],
                    )
                  : Center(
                      child: Text(
                        label,
                        style: labelStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
        ),
      ),
    );
  }
}
