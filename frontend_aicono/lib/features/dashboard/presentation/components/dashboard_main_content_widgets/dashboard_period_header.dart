import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/dashboard_date_range_picker_dialog.dart';

/// Header showing the current dashboard period and optional "Change" to pick dates.
class DashboardPeriodHeader extends StatelessWidget {
  final DashboardTimeRange? timeRange;
  final void Function(DateTime start, DateTime end)? onDateRangeChanged;

  const DashboardPeriodHeader({
    super.key,
    this.timeRange,
    this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    String periodLabel = 'Current period';
    if (timeRange != null &&
        timeRange!.start.isNotEmpty &&
        timeRange!.end.isNotEmpty) {
      final start = DateTime.tryParse(timeRange!.start);
      final end = DateTime.tryParse(timeRange!.end);
      if (start != null && end != null) {
        const pattern = 'MMM d, yyyy';
        final formatter = DateFormat(pattern);
        final isSameDay =
            start.year == end.year &&
            start.month == end.month &&
            start.day == end.day;
        periodLabel = isSameDay
            ? formatter.format(start)
            : '${formatter.format(start)} – ${formatter.format(end)}';
      }
    }
    final canChangeDate = onDateRangeChanged != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0xFF4A6B5A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            periodLabel,
            style: AppTextStyles.labelMedium.copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canChangeDate) ...[
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                DateTimeRange initialRange = DateTimeRange(
                  start: now.subtract(const Duration(days: 7)),
                  end: now,
                );
                if (timeRange != null &&
                    timeRange!.start.isNotEmpty &&
                    timeRange!.end.isNotEmpty) {
                  final start = DateTime.tryParse(timeRange!.start);
                  final end = DateTime.tryParse(timeRange!.end);
                  if (start != null && end != null) {
                    initialRange = DateTimeRange(start: start, end: end);
                  }
                }
                final range = await DashboardDateRangePickerDialog.show(
                  context,
                  initialRange: initialRange,
                );
                if (range != null &&
                    context.mounted &&
                    onDateRangeChanged != null) {
                  onDateRangeChanged!(range.start, range.end);
                }
              },
              child: Text(
                'Change',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
