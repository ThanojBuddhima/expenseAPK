import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/expense.dart';

class SpendingTrendChart extends StatelessWidget {
  const SpendingTrendChart({
    super.key,
    required this.expenses,
    required this.showExpense,
  });

  final List<Expense> expenses;
  final bool showExpense;

  @override
  Widget build(BuildContext context) {
    final spots = _buildMonthlySpots();
    if (spots.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No trend data for this period')),
      );
    }

    final color = showExpense ? AppColors.expenseTint : AppColors.incomeTint;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).dividerColor,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _monthLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _monthLabels[index],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  List<FlSpot> _buildMonthlySpots() {
    final totals = List<double>.filled(12, 0);
    for (final expense in expenses) {
      final matches = showExpense ? expense.isExpense : expense.isIncome;
      if (!matches) {
        continue;
      }
      totals[expense.date.month - 1] += expense.amount;
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < 12; i++) {
      if (totals[i] > 0) {
        spots.add(FlSpot(i.toDouble(), totals[i]));
      }
    }
    return spots;
  }
}
