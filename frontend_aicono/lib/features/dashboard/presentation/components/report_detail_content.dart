import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/utils/locale_number_format.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/anomalies_detail_dialog.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/recipients_popup_dialog.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/weekday_weekend_cylinder_chart.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';

import '../../../../core/routing/routeLists.dart';

enum ReportMenuAction { edit, delete }

/// Shared report detail content widget. Displays full report UI from [ReportDetailEntity].
/// Used by ReportDetailView (dashboard) and StatisticsDashboardPage (token-based view).
class ReportDetailContent extends StatelessWidget {
  final ReportDetailEntity detail;
  final List<ReportRecipientEntity> recipients;
  final bool showDatePicker;
  final String? reportId;
  final void Function(DateTime start, DateTime end)? onDateRangeSelected;

  /// When provided, used for the period label (e.g. 'd MMM yyyy').
  /// When null, uses default 'MMM d, yyyy'.
  final String? dateFormatPattern;

  /// When true, shows period as plain text without border/container.
  final bool periodWithoutBorder;

  const ReportDetailContent({
    super.key,
    required this.detail,
    this.recipients = const [],
    this.showDatePicker = false,
    this.reportId,
    this.onDateRangeSelected,
    this.dateFormatPattern,
    this.periodWithoutBorder = false,
  });

  // Consistent spacing (aligned with dashboard_main_content)
  static const double _spacingBlock = 24.0;
  static const double _spacingSection = 24.0;
  static const double _spacingContent = 16.0;
  static const double _spacingTitleSubtitle = 8.0;
  static const double _spacingCardGap = 12.0;
  static const double _cardPadding = 16.0;
  static const double _chartHeight = 220;
  static const double _hourlyChartHeight = 200;
  static const int _maxBars = 10;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 0.0 : 20.0;

    final building = detail.building;
    final reporting = detail.reporting;
    final reportData = detail.reportData;
    final contents = reportData['contents'] is Map<String, dynamic>
        ? reportData['contents'] as Map<String, dynamic>
        : <String, dynamic>{};
    final timeRange =
        detail.timeRange ??
        (reportData['timeRange'] is Map<String, dynamic>
            ? reportData['timeRange'] as Map<String, dynamic>
            : null);

    final locale = context.locale;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: _spacingBlock,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, building, reporting, timeRange, recipients),
          const SizedBox(height: _spacingSection),
          _buildKpis(reportData, locale),
          const SizedBox(height: _spacingSection),
          _buildContents(contents, locale),
          const SizedBox(height: _spacingSection),
          _buildChartsSection(context, contents, locale),
          const SizedBox(height: _spacingSection),
          _buildTimeBasedAnalysisSection(contents, locale),
          const SizedBox(height: _spacingSection),
          _buildHourlyPatternSection(contents, locale),
          if (_shouldShowPeriodComparison(reporting, contents)) ...[
            const SizedBox(height: _spacingSection),
            _buildPeriodComparison(contents, locale),
          ],
          const SizedBox(height: _spacingSection),
          _buildBuildingComparison(contents, locale),
          const SizedBox(height: _spacingSection),
          _buildAnomaliesSection(context, contents, locale),
          const SizedBox(height: _spacingSection),
        ],
      ),
    );
  }

  bool _shouldShowPeriodComparison(
    ReportDetailReportingEntity reporting,
    Map<String, dynamic> contents,
  ) {
    if (!reporting.reportContents.contains('PeriodComparison')) return false;
    final period = contents['PeriodComparison'];
    if (period is! Map) return false;
    final current = period['current'] is Map ? period['current'] as Map : null;
    final previous = period['previous'] is Map
        ? period['previous'] as Map
        : null;
    return current != null || previous != null;
  }

  Widget _buildPeriodComparison(Map<String, dynamic> contents, Locale locale) {
    final period = contents['PeriodComparison'];
    if (period is! Map) return const SizedBox.shrink();
    final current = period['current'] is Map ? period['current'] as Map : null;
    final previous = period['previous'] is Map
        ? period['previous'] as Map
        : null;
    final change = period['change'] is Map ? period['change'] as Map : null;
    if (current == null && previous == null) return const SizedBox.shrink();

    const headerBg = Color(0xFFE0F2F1);
    const cellPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionWrapper(
          title: 'Period Comparison',
          showBorder: false,
          zeroHorizontalPadding: true,
          child: LayoutBuilder(
            builder: (context, layoutConstraints) {
              final tableWidth = layoutConstraints.maxWidth > 560
                  ? layoutConstraints.maxWidth
                  : 560.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tableWidth),
                  child: Container(
                    width: tableWidth,
                    decoration: const BoxDecoration(color: Colors.white),
                    clipBehavior: Clip.antiAlias,
                    child: Table(
                      border: TableBorder.all(color: Colors.grey[300]!),
                      columnWidths: {
                        0: const FixedColumnWidth(160),
                        1: const FixedColumnWidth(130),
                        2: const FixedColumnWidth(130),
                        3: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: headerBg),
                          children: [
                            _tableCell('', cellPadding, isHeader: true),
                            _tableCell(
                              'Consumption (kWh)',
                              cellPadding,
                              isHeader: true,
                            ),
                            _tableCell(
                              'Average Energy',
                              cellPadding,
                              isHeader: true,
                            ),
                            _tableCell(
                              'Peak (kW)',
                              cellPadding,
                              isHeader: true,
                            ),
                          ],
                        ),
                        if (current != null)
                          TableRow(
                            children: [
                              _tableCell(
                                _formatPeriod(current['period']),
                                cellPadding,
                                alignLeft: true,
                              ),
                              _tableCell(
                                _formatNum(locale, current['consumption']),
                                cellPadding,
                              ),
                              _tableCell(
                                _formatNum(
                                  locale,
                                  current['averageEnergy'] ??
                                      current['average'],
                                ),
                                cellPadding,
                              ),
                              _tableCell(
                                _formatNum(locale, current['peak']),
                                cellPadding,
                              ),
                            ],
                          ),
                        if (previous != null)
                          TableRow(
                            children: [
                              _tableCell(
                                _formatPeriod(previous['period']),
                                cellPadding,
                                alignLeft: true,
                              ),
                              _tableCell(
                                _formatNum(locale, previous['consumption']),
                                cellPadding,
                              ),
                              _tableCell(
                                _formatNum(
                                  locale,
                                  previous['averageEnergy'] ??
                                      previous['average'],
                                ),
                                cellPadding,
                              ),
                              _tableCell(
                                _formatNum(locale, previous['peak']),
                                cellPadding,
                              ),
                            ],
                          ),
                        if (change != null)
                          TableRow(
                            children: [
                              _tableCell(
                                'Change',
                                cellPadding,
                                alignLeft: true,
                              ),
                              _tableCell(
                                _formatNum(locale, change['consumption']),
                                cellPadding,
                              ),
                              _tableCell(
                                _formatNum(
                                  locale,
                                  change['averageEnergy'] ?? change['average'],
                                ),
                                cellPadding,
                              ),
                              _tableCell(
                                _formatNum(locale, change['peak']),
                                cellPadding,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatPeriod(dynamic period) {
    if (period is! Map) return '–';
    final start = period['start'] ?? period['startDate'];
    if (start == null) return '–';
    final startStr = start.toString();
    if (startStr.isEmpty) return '–';
    final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(startStr);
    final timeMatch = RegExp(r'T(\d{2}:\d{2})').firstMatch(startStr);
    final date = dateMatch?.group(1) ?? startStr.split('T').first;
    final time = timeMatch?.group(1);
    if (time != null) return '$date\n$time';
    return date;
  }

  String _formatNum(Locale locale, dynamic value) {
    return LocaleNumberFormat.formatDecimal(
      value,
      locale: locale,
      decimalDigits: 3,
      fallback: '–',
    );
  }

  Widget _tableCell(
    String text,
    EdgeInsets padding, {
    bool isHeader = false,
    bool alignLeft = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
        child: Text(
          text,
          style: isHeader
              ? AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                )
              : AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[800],
                  fontWeight: isBold ? FontWeight.w600 : null,
                ),
          textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBuildingComparison(
    Map<String, dynamic> contents,
    Locale locale,
  ) {
    final comp = contents['BuildingComparison'];
    if (comp is! Map || comp['available'] != true) {
      return const SizedBox.shrink();
    }
    final buildings = comp['buildings'];
    if (buildings is! List || buildings.isEmpty) return const SizedBox.shrink();

    final list = buildings.whereType<Map>().toList();
    if (list.isEmpty) return const SizedBox.shrink();

    const headerBg = Color(0xFFE0F2F1);
    const cellPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionWrapper(
          title: 'Building Comparison',
          showBorder: false,
          zeroHorizontalPadding: true,
          child: LayoutBuilder(
            builder: (context, layoutConstraints) {
              final tableWidth = layoutConstraints.maxWidth > 600
                  ? layoutConstraints.maxWidth
                  : 600.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tableWidth),
                  child: Container(
                    width: tableWidth,
                    decoration: const BoxDecoration(color: Colors.white),
                    clipBehavior: Clip.antiAlias,
                    child: Table(
                      border: TableBorder.all(color: Colors.grey[300]!),
                      columnWidths: {
                        0: const FixedColumnWidth(140),
                        1: const FixedColumnWidth(130),
                        2: const FixedColumnWidth(150),
                        3: const FixedColumnWidth(100),
                        4: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: headerBg),
                          children: [
                            _tableCell('', cellPadding, isHeader: true),
                            _tableCell(
                              'Consumption (kWh)',
                              cellPadding,
                              isHeader: true,
                            ),
                            _tableCell(
                              'Average Energy (kWh)',
                              cellPadding,
                              isHeader: true,
                            ),
                            _tableCell(
                              'Peak (kW)',
                              cellPadding,
                              isHeader: true,
                            ),
                            _tableCell(
                              'EUI (kWh/m²)',
                              cellPadding,
                              isHeader: true,
                            ),
                          ],
                        ),
                        ...list.map(
                          (b) => TableRow(
                            children: [
                              _tableCell(
                                (b['buildingName'] ?? b['building_name'] ?? '—')
                                    .toString(),
                                cellPadding,
                                alignLeft: true,
                                isBold: true,
                              ),
                              _tableCell(
                                _formatNum(locale, b['consumption']),
                                cellPadding,
                              ),
                              _tableCell(
                                _formatNum(
                                  locale,
                                  b['average'] ?? b['averageEnergy'],
                                ),
                                cellPadding,
                              ),
                              _tableCell(
                                _formatNum(locale, b['peak']),
                                cellPadding,
                              ),
                              _tableCell(
                                _formatNum(locale, b['eui']),
                                cellPadding,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnomaliesSection(
    BuildContext context,
    Map<String, dynamic> contents,
    Locale locale,
  ) {
    final anomaliesData = contents['Anomalies'];
    if (anomaliesData is! Map) return const SizedBox.shrink();

    final total = anomaliesData['total'];
    if (total == null && (anomaliesData['anomalies'] is! List)) {
      return const SizedBox.shrink();
    }

    final bySeverity = anomaliesData['bySeverity'] is Map
        ? anomaliesData['bySeverity'] as Map
        : <String, dynamic>{};
    final anomalies = anomaliesData['anomalies'] is List
        ? (anomaliesData['anomalies'] as List).whereType<Map>().toList()
        : <Map>[];

    int toInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    final highCount = toInt(bySeverity['High']);
    final mediumCount = toInt(bySeverity['Medium']);
    final lowCount = toInt(bySeverity['Low']);

    final severityValues = [highCount, mediumCount, lowCount];
    final minCount = severityValues.reduce((a, b) => a < b ? a : b);
    final maxCount = severityValues.reduce((a, b) => a > b ? a : b);

    final sensorCount = anomalies
        .map(
          (a) =>
              a['sensorName']?.toString() ?? a['sensor_id']?.toString() ?? '',
        )
        .where((s) => s.isNotEmpty)
        .toSet()
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ANOMALIES (SEVERITY)',
              style: AppTextStyles.overline.copyWith(
                color: Colors.grey[800],
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (anomalies.isNotEmpty)
              GestureDetector(
                onTap: () => AnomaliesDetailDialog.show(context, anomalies),
                child: Text(
                  'Detail View',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: _spacingCardGap),
        SizedBox(
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 500 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 4.5,
                children: [
                  _buildAnomalyCard(
                    LocaleNumberFormat.formatInt(
                      total,
                      locale: locale,
                      fallback: '0',
                    ),
                    'Total',
                  ),
                  _buildAnomalyCard(
                    LocaleNumberFormat.formatInt(
                      bySeverity['High'] ?? 0,
                      locale: locale,
                    ),
                    'High',
                  ),
                  _buildAnomalyMinMaxCard(
                    LocaleNumberFormat.formatInt(minCount, locale: locale),
                    LocaleNumberFormat.formatInt(maxCount, locale: locale),
                  ),
                  _buildAnomalyCard(
                    LocaleNumberFormat.formatInt(sensorCount, locale: locale),
                    'Sensor Count',
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnomalyCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyMinMaxCard(String minValue, String maxValue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  minValue,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Minimum',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 28, color: Colors.grey[300]),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maxValue,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Maximum',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBasedAnalysisSection(
    Map<String, dynamic> contents,
    Locale locale,
  ) {
    final timeData = contents['TimeBasedAnalysis'];
    if (timeData is! Map) return const SizedBox.shrink();

    final dayNight = timeData['dayNight'] is Map
        ? timeData['dayNight'] as Map
        : null;
    final weekdayWeekend = timeData['weekdayWeekend'] is Map
        ? timeData['weekdayWeekend'] as Map
        : null;

    if (dayNight == null && weekdayWeekend == null) {
      return const SizedBox.shrink();
    }

    const dayColor = Color(0xFF26A69A);
    const nightColor = Color(0xFF8BC34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIMEBASEDANALYSIS',
          style: AppTextStyles.overline.copyWith(
            color: Colors.grey[800],
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: _spacingCardGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dayNight != null)
                      Expanded(
                        child: _buildDayNightCard(
                          dayNight,
                          dayColor,
                          nightColor,
                          locale,
                        ),
                      ),
                    if (dayNight != null && weekdayWeekend != null)
                      const SizedBox(width: _spacingContent),
                    if (weekdayWeekend != null)
                      Expanded(
                        child: _buildWeekdayWeekendCard(
                          weekdayWeekend,
                          dayColor,
                          nightColor,
                        ),
                      ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                if (dayNight != null) ...[
                  _buildDayNightCard(dayNight, dayColor, nightColor, locale),
                  const SizedBox(height: _spacingContent),
                ],
                if (weekdayWeekend != null)
                  _buildWeekdayWeekendCard(
                    weekdayWeekend,
                    dayColor,
                    nightColor,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDayNightCard(
    Map dayNight,
    Color dayColor,
    Color nightColor,
    Locale locale,
  ) {
    final day = (dayNight['day'] is num)
        ? (dayNight['day'] as num).toDouble()
        : 0.0;
    final night = (dayNight['night'] is num)
        ? (dayNight['night'] as num).toDouble()
        : 0.0;
    final total = day + night;
    final dayPct = total > 0 ? (day / total * 100).round() : 0;
    final dayVal = day > 0 ? day : 0.01;
    final nightVal = night > 0 ? night : 0.01;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Text(
            'Day & Night Comparison (kWh)',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: _spacingContent),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: [
                      PieChartSectionData(
                        value: dayVal,
                        color: dayColor,
                        radius: 55,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: nightVal,
                        color: nightColor,
                        radius: 55,
                        showTitle: false,
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 300),
                ),
                Text(
                  '$dayPct%',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LocaleNumberFormat.formatNum(
                    day,
                    locale: locale,
                    decimalDigits: 2,
                  ),
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: dayColor,
                  ),
                ),
                Text(
                  LocaleNumberFormat.formatNum(
                    night,
                    locale: locale,
                    decimalDigits: 2,
                  ),
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: nightColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _spacingCardGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dayColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Day',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: nightColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Night',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayWeekendCard(
    Map weekdayWeekend,
    Color weekdayColor,
    Color weekendColor,
  ) {
    final weekday = (weekdayWeekend['weekday'] is num)
        ? (weekdayWeekend['weekday'] as num).toDouble()
        : 0.0;
    final weekend = (weekdayWeekend['weekend'] is num)
        ? (weekdayWeekend['weekend'] as num).toDouble()
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Text(
            'Weekday & Weekend\nComparison (kWh)',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: _spacingContent),
          WeekdayWeekendCylinderChart(
            weekendValue: weekend,
            weekdayValue: weekday,
            weekendColor: weekendColor,
            weekdayColor: weekdayColor,
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyPatternSection(
    Map<String, dynamic> contents,
    Locale locale,
  ) {
    final timeData = contents['TimeBasedAnalysis'];
    if (timeData is! Map) return const SizedBox.shrink();
    final hourly = timeData['hourlyPattern'];
    if (hourly is! List || hourly.isEmpty) return const SizedBox.shrink();

    final byHour = <int, double>{};
    for (final e in hourly.whereType<Map>()) {
      final hour = e['hour'] is int ? e['hour'] as int : 0;
      final c = (e['consumption'] is num)
          ? (e['consumption'] as num).toDouble()
          : 0.0;
      byHour[hour] = (byHour[hour] ?? 0) + c;
    }
    final maxHour = byHour.keys.isEmpty
        ? 23
        : byHour.keys.reduce((a, b) => a > b ? a : b);
    final hourCount = (maxHour > 23 ? maxHour + 1 : 24).clamp(24, 48);
    final spots = List.generate(
      hourCount,
      (i) => FlSpot(i.toDouble(), byHour[i] ?? 0),
    );
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) return const SizedBox.shrink();

    final yMax = (maxY * 1.1).clamp(10, double.infinity);
    final yMaxRounded = ((yMax / 10).ceil() * 10).toDouble();
    const chartGreen = Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionWrapper(
          title: 'Consumption by hour',
          showBorder: false,
          zeroHorizontalPadding: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'kWh',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _spacingTitleSubtitle),
              SizedBox(
                height: _hourlyChartHeight,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (hourCount - 1).toDouble(),
                    minY: 0,
                    maxY: yMaxRounded,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yMaxRounded / 7,
                      getDrawingHorizontalLine: (v) =>
                          FlLine(color: Colors.grey[300]!, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: yMaxRounded / 7,
                          getTitlesWidget: (v, m) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              LocaleNumberFormat.formatInt(
                                v.toInt(),
                                locale: locale,
                              ),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 2,
                          getTitlesWidget: (v, m) => Text(
                            '${v.toInt()}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: 8,
                        getTooltipColor: (_) => Colors.white,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        getTooltipItems: (touchedSpots) => touchedSpots
                            .map(
                              (s) => LineTooltipItem(
                                '${_formatChartValue(locale, s.y)}KWH /${s.x.toInt()} hr',
                                AppTextStyles.labelSmall.copyWith(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        color: chartGreen.withValues(alpha: 0.75),
                        barWidth: 2.5,
                        isStrokeCapRound: false,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              chartGreen.withValues(alpha: 0.10),
                              chartGreen.withValues(alpha: 0.40),
                              chartGreen.withValues(alpha: 0.75),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 300),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'hr',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionWrapper({
    required String title,
    required Widget child,
    bool showBorder = true,
    bool zeroHorizontalPadding = false,
    double? titleToContentSpacing,
  }) {
    final spacing = titleToContentSpacing ?? _spacingCardGap;
    return Builder(
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        final padding = zeroHorizontalPadding
            ? const EdgeInsets.only(top: _spacingTitleSubtitle, bottom: _spacingContent)
            : (isMobile
                  ? EdgeInsets.only(
                      top: showBorder ? _cardPadding : _spacingContent,
                      bottom: showBorder ? _cardPadding : _spacingContent,
                    )
                  : EdgeInsets.all(showBorder ? _cardPadding : _spacingContent));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: AppTextStyles.overline.copyWith(
                color: Colors.grey[800],
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing),
            Container(
              width: double.infinity,
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.zero,
                border: showBorder
                    ? Border.all(color: Colors.grey[300]!, width: 1)
                    : null,
              ),
              child: child,
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ReportDetailBuildingEntity building,
    ReportDetailReportingEntity reporting,
    Map<String, dynamic>? timeRange,
    List<ReportRecipientEntity> recipients,
  ) {
    String periodLabel = reporting.interval.isNotEmpty
        ? reporting.interval[0].toUpperCase() +
              reporting.interval.substring(1).toLowerCase()
        : 'Weekly';
    if (timeRange != null) {
      final startRaw = timeRange['start'] ?? timeRange['startDate'];
      final endRaw = timeRange['end'] ?? timeRange['endDate'];
      if (startRaw != null && endRaw != null) {
        final start = _parseReportDate(startRaw);
        final end = _parseReportDate(endRaw);
        if (start != null && end != null) {
          final pattern = dateFormatPattern ?? 'MMM d, yyyy';
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
    }

    final canChangeDate =
        showDatePicker &&
        reportId != null &&
        reportId!.isNotEmpty &&
        onDateRangeSelected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              building.name,
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Colors.black,
              ),
            ),
            PopupMenuButton<ReportMenuAction>(
              icon: const Icon(Icons.more_vert),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
              color: Colors.white,
              onSelected: (action) {
                switch (action) {
                  case ReportMenuAction.edit:
                    // Convert reporting and recipients to JSON strings
                    final reportingJson = jsonEncode({
                      'id': reporting.id,
                      'name': reporting.name,
                      'interval': reporting.interval,
                      'reportContents': reporting.reportContents,
                    });
                    final recipientsJson = jsonEncode(
                      recipients
                          .map(
                            (r) => {
                              'recipientId': r.recipientId,
                              'recipientName': r.recipientName,
                              'recipientEmail': r.recipientEmail,
                            },
                          )
                          .toList(),
                    );
                    context.pushNamed(
                      Routelists.dashboardReportSetup,
                      queryParameters: {
                        'buildingId': building.id,
                        'reporting': reportingJson,
                        'recipients': recipientsJson,
                      },
                    );
                    break;
                  case ReportMenuAction.delete:
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<ReportMenuAction>(
                  value: ReportMenuAction.edit,
                  child: Text('Edit'),
                ),
                const PopupMenuItem<ReportMenuAction>(
                  value: ReportMenuAction.delete,
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (building.address != null && building.address!.isNotEmpty) ...[
          const SizedBox(height: _spacingTitleSubtitle),
          SingleChildScrollView(
            child: Wrap(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  building.address!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: 24),
                if (recipients.isNotEmpty)
                  _buildRecipientsTrigger(
                    context,
                    recipients,
                    building,
                    reportId,
                  ),
              ],
            ),
          ),
        ],
        if (recipients.isNotEmpty &&
            (building.address == null || building.address!.isEmpty)) ...[
          const SizedBox(height: _spacingTitleSubtitle),
          _buildRecipientsTrigger(context, recipients, building, reportId),
        ],
        const SizedBox(height: _spacingContent),
        if (periodWithoutBorder)
          Text(
            periodLabel,
            style: AppTextStyles.labelMedium.copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          )
        else
          Container(
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
                  overflow: TextOverflow.ellipsis,
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
                      if (timeRange != null) {
                        final start = _parseReportDate(
                          timeRange['start'] ?? timeRange['startDate'],
                        );
                        final end = _parseReportDate(
                          timeRange['end'] ?? timeRange['endDate'],
                        );
                        if (start != null && end != null) {
                          initialRange = DateTimeRange(start: start, end: end);
                        }
                      }
                      final range = await showDialog<DateTimeRange>(
                        context: context,
                        barrierColor: Colors.black26,
                        builder: (context) => _ReportDateRangePickerDialog(
                          initialRange: initialRange,
                          firstDate: now.subtract(const Duration(days: 365)),
                          lastDate: now,
                        ),
                      );
                      if (range != null &&
                          context.mounted &&
                          onDateRangeSelected != null) {
                        onDateRangeSelected!(range.start, range.end);
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
          ),
        const SizedBox(height: _spacingSection),
        Divider(
          color: Colors.grey[300],
          thickness: 0.7,
          height: 0,
        ),
      ],
    );
  }

  Widget _buildRecipientsTrigger(
    BuildContext context,
    List<ReportRecipientEntity> recipients,
    ReportDetailBuildingEntity building,
    String? reportId,
  ) {
    return InkWell(
      onTap: () => RecipientsPopupDialog.show(
        context,
        recipients,
        building.id,
        reportId ?? '',
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View all recipients',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            height: 24,
            child: CircleAvatar(
              backgroundColor: const Color(0xFF2DD4BF),
              child: Text(
                '${recipients.length}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _kpiLargeScreenBreakpoint = 900;
  static const double _kpiLargeScreenRowHeight = 80;
  static const double _kpiLargeScreenSpacing = 10;

  Widget _buildKpis(Map<String, dynamic> reportData, Locale locale) {
    final kpis = reportData['kpis'];
    if (kpis is! Map<String, dynamic>) return const SizedBox.shrink();

    final energy = kpis['energy'] is Map ? kpis['energy'] as Map : null;
    final power = kpis['power'] is Map ? kpis['power'] as Map : null;
    final quality = kpis['quality'] is Map ? kpis['quality'] as Map : null;
    if (energy == null && power == null && quality == null) {
      return const SizedBox.shrink();
    }

    final hasQuality =
        quality != null &&
        quality['average'] != null &&
        quality['warning'] != null;

    return _sectionWrapper(
      title: 'Key Metrics',
      showBorder: false,
      zeroHorizontalPadding: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final useLargeLayout =
              width >= _kpiLargeScreenBreakpoint && hasQuality;

          if (useLargeLayout) {
            final gridHeight =
                2 * _kpiLargeScreenRowHeight + _kpiLargeScreenSpacing;
            final gridWidth = width * (2 / 3) - _kpiLargeScreenSpacing / 2;
            final cellWidth = (gridWidth - _kpiLargeScreenSpacing) / 2;
            final childAspectRatio = cellWidth / _kpiLargeScreenRowHeight;
            return SizedBox(
              height: gridHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: _kpiLargeScreenSpacing,
                      crossAxisSpacing: _kpiLargeScreenSpacing,
                      childAspectRatio: childAspectRatio,
                      children: [
                        if (energy != null) ...[
                          _kpiTile(
                            'Total Consumption',
                            LocaleNumberFormat.formatNum(
                              energy['total_consumption'],
                              locale: locale,
                              decimalDigits: 3,
                              fallback: '–',
                            ),
                            energy['unit']?.toString() ?? 'kWh',
                            Icons.bolt,
                          ),
                          _kpiTile(
                            'Average Energy',
                            LocaleNumberFormat.formatNum(
                              energy['average'],
                              locale: locale,
                              decimalDigits: 3,
                              fallback: '–',
                            ),
                            energy['unit']?.toString() ?? 'kWh',
                            Icons.trending_up,
                          ),
                        ],
                        if (power != null) ...[
                          _kpiTile(
                            'Peak-Load',
                            LocaleNumberFormat.formatNum(
                              power['peak'],
                              locale: locale,
                              decimalDigits: 3,
                              fallback: '–',
                            ),
                            power['unit']?.toString() ?? 'kW',
                            Icons.offline_bolt,
                          ),
                          _kpiTile(
                            'Average Power',
                            LocaleNumberFormat.formatNum(
                              power['average'],
                              locale: locale,
                              decimalDigits: 3,
                              fallback: '–',
                            ),
                            power['unit']?.toString() ?? 'kW',
                            Icons.speed,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: _kpiLargeScreenSpacing),
                  if (hasQuality)
                    Expanded(
                      flex: 1,
                      child: _buildDataQualityKpiCardLarge(quality, locale),
                    ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: width > 600 ? 2 : 1,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.6,
                children: [
                  if (energy != null) ...[
                    _kpiTile(
                      'Total Consumption',
                      LocaleNumberFormat.formatNum(
                        energy['total_consumption'],
                        locale: locale,
                        decimalDigits: 3,
                        fallback: '–',
                      ),
                      energy['unit']?.toString() ?? 'kWh',
                      Icons.bolt,
                    ),
                    _kpiTile(
                      'Average Energy',
                      LocaleNumberFormat.formatNum(
                        energy['average'],
                        locale: locale,
                        decimalDigits: 3,
                        fallback: '–',
                      ),
                      energy['unit']?.toString() ?? 'kWh',
                      Icons.trending_up,
                    ),
                  ],
                  if (power != null) ...[
                    _kpiTile(
                      'Peak-Load',
                      LocaleNumberFormat.formatNum(
                        power['peak'],
                        locale: locale,
                        decimalDigits: 3,
                        fallback: '–',
                      ),
                      power['unit']?.toString() ?? 'kW',
                      Icons.offline_bolt,
                    ),
                    _kpiTile(
                      'Average Power',
                      LocaleNumberFormat.formatNum(
                        power['average'],
                        locale: locale,
                        decimalDigits: 3,
                        fallback: '–',
                      ),
                      power['unit']?.toString() ?? 'kW',
                      Icons.speed,
                    ),
                  ],
                ],
              ),
              if (hasQuality) ...[
                const SizedBox(height: _spacingCardGap),
                _buildDataQualityKpiCard(quality, locale),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Data quality card for large screen: teal background, two sections, spans 2 rows.
  Widget _buildDataQualityKpiCardLarge(Map quality, Locale locale) {
    final avg = LocaleNumberFormat.formatNum(
      quality['average'],
      locale: locale,
      decimalDigits: 0,
      fallback: '0',
    );
    final isWarning = quality['warning'] == true;
    const tealBg = Color(0xFFE0F2F1);
    const tealBgWarning = Color(0xFFFFF3E0);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: isWarning ? tealBgWarning : tealBg,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$avg%',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Average Data Quality',
            style: AppTextStyles.labelMedium.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: _spacingSection),
          Text(
            isWarning ? 'Needs attention' : 'Excellent',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isWarning ? 'Data quality needs review' : 'Data quality is good',
            style: AppTextStyles.labelMedium.copyWith(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildDataQualityKpiCard(Map quality, Locale locale) {
    final avg = LocaleNumberFormat.formatNum(
      quality['average'],
      locale: locale,
      decimalDigits: 0,
      fallback: '0',
    );
    final isWarning = quality['warning'] == true;
    final statusText = isWarning
        ? 'Needs attention'
        : 'Excellent, Data quality is good';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isWarning ? Colors.orange[200]! : Colors.green[200]!,
          width: 1,
        ),
        color: isWarning ? Colors.orange[50] : Colors.green[50],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$avg%',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isWarning
                            ? Colors.orange[800]
                            : Colors.green[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '($statusText)',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: isWarning
                              ? Colors.orange[700]
                              : Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Average Data Quality',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 20,
            color: isWarning ? Colors.orange[600] : Colors.green[600],
          ),
        ],
      ),
    );
  }

  Widget _kpiTile(String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$label ($unit)',
            style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(
    BuildContext context,
    Map<String, dynamic> contents,
    Locale locale,
  ) {
    final lineChart = _buildConsumptionAndAverageEnergyLineChart(
      contents,
      locale,
    );
    final peakLoadChart = _buildPeakLoadByRoomBarChart(contents, locale);
    if (lineChart == null && peakLoadChart == null) {
      return const SizedBox.shrink();
    }
    const chartPadding = EdgeInsets.symmetric(
        horizontal: _spacingContent, vertical: _spacingSection);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OVERVIEW',
          style: AppTextStyles.overline.copyWith(
            color: Colors.grey[800],
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: _spacingContent),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1200;
            final chartWidth = isWide ? null : constraints.maxWidth;
            final lineChartWidget = lineChart != null
                ? Container(
                    padding: chartPadding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Average Energy and Consumption by room (kWh)',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: _spacingContent),
                        SizedBox(
                          width: chartWidth ?? double.infinity,
                          height: _chartHeight,
                          child: lineChart,
                        ),
                        const SizedBox(height: _spacingContent),
                        _buildLineChartLegend(),
                      ],
                    ),
                  )
                : null;
            final peakChartWidget = peakLoadChart != null
                ? Container(
                    padding: chartPadding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peak load by room (kW)',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: _spacingContent),
                        SizedBox(
                          width: chartWidth ?? double.infinity,
                          height: _chartHeight,
                          child: peakLoadChart,
                        ),
                      ],
                    ),
                  )
                : null;

            if (isWide && lineChartWidget != null && peakChartWidget != null) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: lineChartWidget),
                    const SizedBox(width: _spacingContent),
                    Expanded(child: peakChartWidget),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lineChartWidget != null) ...[
                  lineChartWidget,
                  const SizedBox(height: _spacingContent),
                ],
                if (peakChartWidget != null) peakChartWidget,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLineChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Consumption',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0),
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Average Energy',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _buildConsumptionAndAverageEnergyLineChart(
    Map<String, dynamic> contents,
    Locale locale,
  ) {
    final roomData = contents['ConsumptionByRoom'];
    if (roomData is! Map || roomData['rooms'] is! List) return null;
    final list = roomData['rooms'] as List;
    if (list.isEmpty) return null;

    final rooms = list.whereType<Map>().take(_maxBars).toList();
    final consumptionSpots = <FlSpot>[];
    final averageEnergySpots = <FlSpot>[];

    for (var i = 0; i < rooms.length; i++) {
      final r = rooms[i];
      final consumption = (r['consumption'] is num)
          ? (r['consumption'] as num).toDouble()
          : 0.0;
      final avgEnergy = (r['averageEnergy'] ?? r['average']) is num
          ? ((r['averageEnergy'] ?? r['average']) as num).toDouble()
          : 0.0;
      consumptionSpots.add(FlSpot(i.toDouble(), consumption));
      averageEnergySpots.add(FlSpot(i.toDouble(), avgEnergy));
    }

    final maxY = [
      ...consumptionSpots.map((s) => s.y),
      ...averageEnergySpots.map((s) => s.y),
    ].reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) return null;

    const consumptionColor = Color(0xFF4CAF50);
    const averageEnergyColor = Color(0xFF9C27B0);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (rooms.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval: 1,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.grey[200]!,
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
          getDrawingVerticalLine: (v) => FlLine(
            color: Colors.grey[100]!,
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY > 0 ? maxY / 4 : 1,
              getTitlesWidget: (v, m) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _formatChartValue(locale, v),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i >= 0 && i < rooms.length) {
                  final label =
                      (rooms[i]['roomName'] ?? rooms[i]['room_name'] ?? '—')
                          .toString();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      label.length > 12 ? '${label.substring(0, 12)}…' : label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey[400]!, width: 1),
            bottom: BorderSide(color: Colors.grey[400]!, width: 1),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) => touchedSpots
                .map(
                  (s) => LineTooltipItem(
                    '${(rooms[s.x.toInt()]['roomName'] ?? 'Room')}: ${_formatChartValue(locale, s.y)}',
                    AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: consumptionSpots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: consumptionColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: consumptionColor,
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: averageEnergySpots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: averageEnergyColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: averageEnergyColor,
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget? _buildPeakLoadByRoomBarChart(
    Map<String, dynamic> contents,
    Locale locale,
  ) {
    final roomData = contents['ConsumptionByRoom'];
    if (roomData is! Map || roomData['rooms'] is! List) return null;
    final list = roomData['rooms'] as List;
    if (list.isEmpty) return null;

    final rooms = list.whereType<Map>().take(_maxBars).toList();
    final top = rooms
        .map(
          (e) => (
            (e['roomName'] ?? e['room_name'] ?? '—').toString(),
            (e['peak'] is num) ? (e['peak'] as num).toDouble() : 0.0,
          ),
        )
        .toList();
    if (top.isEmpty) return null;

    final maxVal = top.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    const barColor = Color(0xFF8BC34A);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < top.length) {
                  final label = top[i].$1;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label.length > 12 ? '${label.substring(0, 12)}…' : label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 28,
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxVal > 0 ? maxVal / 4 : 1,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _formatChartValue(locale, value),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval: 1,
          horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: Colors.grey[100]!, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey[400]!, width: 1),
            bottom: BorderSide(color: Colors.grey[400]!, width: 1),
          ),
        ),
        barGroups: List.generate(
          top.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: top[i].$2,
                color: barColor,
                width: 20,
                borderRadius: BorderRadius.zero,
              ),
            ],
            showingTooltipIndicators: [],
          ),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  static String _formatChartValue(Locale locale, double v) {
    return LocaleNumberFormat.formatCompact(v, locale: locale);
  }

  static DateTime? _parseReportDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  Widget _buildContents(Map<String, dynamic> contents, Locale locale) {
    final breakdownData = contents['MeasurementTypeBreakdown'];
    List<Map> items = [];
    if (breakdownData is Map && breakdownData['breakdown'] is List) {
      items = (breakdownData['breakdown'] as List)
          .whereType<Map>()
          .where(
            (e) => (e['measurement_type'] ?? e['measurementType'] ?? '')
                .toString()
                .isNotEmpty,
          )
          .toList();
    }

    final eui = contents['EUI'];
    if (eui is Map && (eui['available'] == true || eui['eui'] != null)) {
      items.add({
        'measurement_type': 'EUI',
        'unit': eui['unit'] ?? 'kWh/m²',
        'eui': eui['eui'],
        'average': eui['annualizedEUI'],
      });
    }
    final perCapita = contents['PerCapitaConsumption'];
    if (perCapita is Map &&
        (perCapita['available'] == true || perCapita['perCapita'] != null)) {
      items.add({
        'measurement_type': 'Per-Capita',
        'unit': perCapita['unit'] ?? 'kWh/person',
        'perCapita': perCapita['perCapita'],
      });
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return _sectionWrapper(
      title: 'Detail Metrics',
      showBorder: false,
      zeroHorizontalPadding: true,
      titleToContentSpacing: _spacingTitleSubtitle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = _spacingCardGap;
          final isTwoColumns = constraints.maxWidth > 700;
          if (isTwoColumns) {
            final cardWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: items
                  .map(
                    (e) => SizedBox(
                      width: cardWidth,
                      child: _buildMeasurementTypeCard(e, locale),
                    ),
                  )
                  .toList(),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: spacing),
                    child: _buildMeasurementTypeCard(e, locale),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  static const _detailMetricFields = [
    ('total', 'Total'),
    ('average', 'Average'),
    ('maximum', 'Maximum'),
    ('max', 'Maximum'),
    ('minimum', 'Minimum'),
    ('min', 'Minimum'),
    ('eui', 'EUI'),
    ('perCapita', 'Per Capita'),
    ('per_capita', 'Per Capita'),
  ];

  Widget _buildMeasurementTypeCard(Map item, Locale locale) {
    final type = (item['measurement_type'] ?? item['measurementType'] ?? '—')
        .toString();
    final unit = (item['unit'] ?? '').toString();
    final title = unit.isNotEmpty ? '$type ($unit)' : type;

    final metricRows = <({String label, String value})>[];
    final seenLabels = <String>{};

    for (final (key, label) in _detailMetricFields) {
      if (seenLabels.contains(label)) continue;
      final val = item[key];
      if (val == null) continue;
      seenLabels.add(label);
      final valueStr = val is num
          ? LocaleNumberFormat.formatNum(
              val,
              locale: locale,
              decimalDigits: val.truncateToDouble() == val ? 0 : 2,
            )
          : val.toString();
      metricRows.add((label: label, value: valueStr));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: _spacingTitleSubtitle),
          ...metricRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    row.value,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (type == 'Per-Capita') const SizedBox(height: _spacingSection),
        ],
      ),
    );
  }
}

/// Compact date range picker dialog using table_calendar.
class _ReportDateRangePickerDialog extends StatefulWidget {
  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  const _ReportDateRangePickerDialog({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_ReportDateRangePickerDialog> createState() =>
      _ReportDateRangePickerDialogState();
}

class _ReportDateRangePickerDialogState
    extends State<_ReportDateRangePickerDialog> {
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
