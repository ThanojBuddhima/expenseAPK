import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/time_period.dart';

class PeriodNavigatorBar extends StatelessWidget {
  const PeriodNavigatorBar({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final TimePeriod period;
  final ValueChanged<TimePeriod> onChanged;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: period.anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      initialDatePickerMode: period.granularity == TimePeriodGranularity.yearly
          ? DatePickerMode.year
          : period.granularity == TimePeriodGranularity.monthly
              ? DatePickerMode.day
              : DatePickerMode.day,
      helpText: period.granularity == TimePeriodGranularity.yearly
          ? 'Select year'
          : period.granularity == TimePeriodGranularity.monthly
              ? 'Select month'
              : 'Select date',
    );

    if (picked != null) {
      onChanged(period.withPickedDate(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => onChanged(period.previous()),
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                ),
                Flexible(
                  child: InkWell(
                    onTap: () => _pickDate(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        period.displayLabel,
                        style: textStyle,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => onChanged(period.next()),
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                ),
              ],
            ),
          ),
          PopupMenuButton<TimePeriodGranularity>(
            tooltip: 'Period type',
            offset: const Offset(0, 36),
            onSelected: (value) => onChanged(period.withGranularity(value)),
            itemBuilder: (context) => TimePeriodGranularity.values
                .map(
                  (value) => PopupMenuItem(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    period.granularity.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
