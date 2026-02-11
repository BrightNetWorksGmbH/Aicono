import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:frontend_aicono/core/constant.dart';

/// Date range picker dialog for dashboard (same style as report detail).
/// Returns [DateTimeRange] when user taps Apply, null when Cancel.
class DashboardDateRangePickerDialog extends StatefulWidget {
  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  const DashboardDateRangePickerDialog({
    super.key,
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  static Future<DateTimeRange?> show(
    BuildContext context, {
    required DateTimeRange initialRange,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final now = DateTime.now();
    return showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => DashboardDateRangePickerDialog(
        initialRange: initialRange,
        firstDate: firstDate ?? now.subtract(const Duration(days: 365)),
        lastDate: lastDate ?? now,
      ),
    );
  }

  @override
  State<DashboardDateRangePickerDialog> createState() =>
      _DashboardDateRangePickerDialogState();
}

class _DashboardDateRangePickerDialogState
    extends State<DashboardDateRangePickerDialog> {
  late DateTime _focusedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialRange.start;
    _rangeStart = widget.initialRange.start;
    _rangeEnd = widget.initialRange.end;
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = focusedDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TableCalendar(
                firstDay: widget.firstDate,
                lastDay: widget.lastDate,
                focusedDay: _focusedDay,
                rangeStartDay: _rangeStart,
                rangeEndDay: _rangeEnd,
                rangeSelectionMode: RangeSelectionMode.enforced,
                onRangeSelected: _onRangeSelected,
                onPageChanged: (day) => setState(() => _focusedDay = day),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  rangeHighlightColor: AppTheme.primary.withValues(alpha: 0.2),
                  rangeStartDecoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  rangeEndDecoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: const Icon(Icons.chevron_left),
                  rightChevronIcon: const Icon(Icons.chevron_right),
                  headerPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontWeight: FontWeight.w600),
                  weekendStyle: TextStyle(fontWeight: FontWeight.w600),
                ),
                rowHeight: 40,
                daysOfWeekHeight: 24,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _rangeStart != null
                        ? () {
                            final start = _rangeStart!;
                            final end = _rangeEnd ?? start;
                            Navigator.of(context).pop(
                              DateTimeRange(
                                start: start.isBefore(end) ? start : end,
                                end: start.isBefore(end) ? end : start,
                              ),
                            );
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
