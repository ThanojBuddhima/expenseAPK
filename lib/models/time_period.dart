enum TimePeriodGranularity { daily, weekly, monthly, yearly }

extension TimePeriodGranularityLabel on TimePeriodGranularity {
  String get label => switch (this) {
        TimePeriodGranularity.daily => 'Daily',
        TimePeriodGranularity.weekly => 'Weekly',
        TimePeriodGranularity.monthly => 'Monthly',
        TimePeriodGranularity.yearly => 'Yearly',
      };
}

class TimePeriod {
  const TimePeriod({
    required this.anchor,
    this.granularity = TimePeriodGranularity.monthly,
  });

  final DateTime anchor;
  final TimePeriodGranularity granularity;

  static const _monthNames = <String>[
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

  factory TimePeriod.currentMonth() {
    final now = DateTime.now();
    return TimePeriod(
      anchor: DateTime(now.year, now.month, now.day),
      granularity: TimePeriodGranularity.monthly,
    );
  }

  DateTime get _normalizedAnchor {
    switch (granularity) {
      case TimePeriodGranularity.daily:
        return DateTime(anchor.year, anchor.month, anchor.day);
      case TimePeriodGranularity.weekly:
        return _startOfWeek(anchor);
      case TimePeriodGranularity.monthly:
        return DateTime(anchor.year, anchor.month, 1);
      case TimePeriodGranularity.yearly:
        return DateTime(anchor.year, 1, 1);
    }
  }

  static DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime _endOfWeek(DateTime weekStart) {
    return weekStart.add(const Duration(days: 6));
  }

  bool contains(DateTime date) {
    final value = DateTime(date.year, date.month, date.day);
    switch (granularity) {
      case TimePeriodGranularity.daily:
        final day = _normalizedAnchor;
        return value.year == day.year &&
            value.month == day.month &&
            value.day == day.day;
      case TimePeriodGranularity.weekly:
        final start = _normalizedAnchor;
        final end = _endOfWeek(start);
        return !value.isBefore(start) && !value.isAfter(end);
      case TimePeriodGranularity.monthly:
        final month = _normalizedAnchor;
        return value.year == month.year && value.month == month.month;
      case TimePeriodGranularity.yearly:
        return value.year == _normalizedAnchor.year;
    }
  }

  String get displayLabel {
    switch (granularity) {
      case TimePeriodGranularity.daily:
        final day = _normalizedAnchor;
        return '${_monthNames[day.month - 1]} ${day.day}, ${day.year}';
      case TimePeriodGranularity.weekly:
        final start = _normalizedAnchor;
        final end = _endOfWeek(start);
        if (start.month == end.month) {
          return '${_monthNames[start.month - 1]} ${start.day}–${end.day}, ${start.year}';
        }
        if (start.year == end.year) {
          return '${_monthNames[start.month - 1]} ${start.day} – '
              '${_monthNames[end.month - 1]} ${end.day}, ${start.year}';
        }
        return '${_monthNames[start.month - 1]} ${start.day}, ${start.year} – '
            '${_monthNames[end.month - 1]} ${end.day}, ${end.year}';
      case TimePeriodGranularity.monthly:
        final month = _normalizedAnchor;
        return '${_monthNames[month.month - 1]} ${month.year}';
      case TimePeriodGranularity.yearly:
        return '${_normalizedAnchor.year}';
    }
  }

  TimePeriod previous() => _shift(-1);

  TimePeriod next() => _shift(1);

  TimePeriod copyWith({
    DateTime? anchor,
    TimePeriodGranularity? granularity,
  }) {
    return TimePeriod(
      anchor: anchor ?? this.anchor,
      granularity: granularity ?? this.granularity,
    );
  }

  TimePeriod withGranularity(TimePeriodGranularity value) {
    return copyWith(
      anchor: _normalizeForGranularity(anchor, value),
      granularity: value,
    );
  }

  TimePeriod withPickedDate(DateTime picked) {
    return copyWith(anchor: _normalizeForGranularity(picked, granularity));
  }

  TimePeriod _shift(int direction) {
    final normalized = _normalizedAnchor;
    switch (granularity) {
      case TimePeriodGranularity.daily:
        return copyWith(
          anchor: normalized.add(Duration(days: direction)),
        );
      case TimePeriodGranularity.weekly:
        return copyWith(
          anchor: normalized.add(Duration(days: 7 * direction)),
        );
      case TimePeriodGranularity.monthly:
        return copyWith(
          anchor: DateTime(normalized.year, normalized.month + direction, 1),
        );
      case TimePeriodGranularity.yearly:
        return copyWith(
          anchor: DateTime(normalized.year + direction, 1, 1),
        );
    }
  }

  static DateTime _normalizeForGranularity(
    DateTime date,
    TimePeriodGranularity value,
  ) {
    switch (value) {
      case TimePeriodGranularity.daily:
        return DateTime(date.year, date.month, date.day);
      case TimePeriodGranularity.weekly:
        return _startOfWeek(date);
      case TimePeriodGranularity.monthly:
        return DateTime(date.year, date.month, 1);
      case TimePeriodGranularity.yearly:
        return DateTime(date.year, 1, 1);
    }
  }
}
