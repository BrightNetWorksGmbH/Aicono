import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/anomalies_detail_dialog.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/weekday_weekend_cylinder_chart.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_detail_bloc.dart';

/// Main view content when a report is selected. Shows report detail from API.
/// [recipients] come from the building report list and can be passed to show who receives this report.
class ReportDetailView extends StatelessWidget {
  final String? reportId;
  final List<ReportRecipientEntity> recipients;

  const ReportDetailView({
    super.key,
    this.reportId,
    this.recipients = const [],
  });

  static const double _sectionSpacing = 28;
  static const double _sectionGap =
      36; // Spacing between previous content and next title
  static const double _cardPadding = 24;
  static const double _chartHeight = 220;
  static const double _hourlyChartHeight = 200;
  static const int _maxBars = 10;

  @override
  Widget build(BuildContext context) {
    final currentReportId = reportId;
    final recipientsList = recipients;
    if (currentReportId == null || currentReportId.isEmpty) {
      return _buildEmptyState(context);
    }
    return BlocBuilder<ReportDetailBloc, ReportDetailState>(
      builder: (context, state) {
        if (state is ReportDetailLoading) {
          return _buildLoading(context);
        }
        if (state is ReportDetailFailure) {
          return _buildError(context, state.message);
        }
        if (state is ReportDetailSuccess) {
          if (state.detail.reporting.id == currentReportId) {
            return _buildDetail(context, state.detail, recipientsList);
          }
        }
        return _buildLoading(context);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'Select a report from the sidebar',
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading report...',
              style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red[400]),
            const SizedBox(height: 20),
            Text(
              message,
              style: AppTextStyles.titleSmall.copyWith(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    ReportDetailEntity detail,
    List<ReportRecipientEntity> recipients,
  ) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(building, reporting, timeRange),
          if (recipients.isNotEmpty) ...[
            const SizedBox(height: _sectionGap),
            _buildRecipientsSection(recipients),
          ],
          const SizedBox(height: _sectionGap),
          _buildKpis(reportData),
          const SizedBox(height: _sectionGap),
          _buildContents(contents),
          const SizedBox(height: _sectionGap),
          _buildChartsSection(contents),
          const SizedBox(height: _sectionGap),
          _buildTimeBasedAnalysisSection(contents),
          const SizedBox(height: _sectionGap),
          _buildHourlyPatternSection(contents),
          const SizedBox(height: _sectionGap),
          _buildPeriodComparison(contents),
          const SizedBox(height: _sectionGap),
          _buildBuildingComparison(contents),
          const SizedBox(height: _sectionGap),
          _buildAnomaliesSection(context, contents),
          const SizedBox(height: _sectionSpacing),
        ],
      ),
    );
  }

  Widget _buildPeriodComparison(Map<String, dynamic> contents) {
    final period = contents['PeriodComparison'];
    if (period is! Map) return const SizedBox.shrink();
    final current = period['current'] is Map ? period['current'] as Map : null;
    final previous = period['previous'] is Map
        ? period['previous'] as Map
        : null;
    final change = period['change'] is Map ? period['change'] as Map : null;
    if (current == null && previous == null) return const SizedBox.shrink();

    const headerBg = Color(0xFFE0F2F1); // Light teal
    const cellPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        _sectionWrapper(
          title: 'PeriodComparison',
          showBorder: false,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              border: TableBorder.all(color: Colors.grey[300]!),
              columnWidths: const {
                0: FlexColumnWidth(1.8),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                // Header row
                TableRow(
                  decoration: const BoxDecoration(color: headerBg),
                  children: [
                    _tableCell('', cellPadding, isHeader: true),
                    _tableCell(
                      'Consumption (kWh)',
                      cellPadding,
                      isHeader: true,
                    ),
                    _tableCell('Average Energy', cellPadding, isHeader: true),
                    _tableCell('Peak (kW)', cellPadding, isHeader: true),
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
                        _formatNum(current['consumption']),
                        cellPadding,
                      ),
                      _tableCell(
                        _formatNum(
                          current['averageEnergy'] ?? current['average'],
                        ),
                        cellPadding,
                      ),
                      _tableCell(_formatNum(current['peak']), cellPadding),
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
                        _formatNum(previous['consumption']),
                        cellPadding,
                      ),
                      _tableCell(
                        _formatNum(
                          previous['averageEnergy'] ?? previous['average'],
                        ),
                        cellPadding,
                      ),
                      _tableCell(_formatNum(previous['peak']), cellPadding),
                    ],
                  ),
                if (change != null)
                  TableRow(
                    children: [
                      _tableCell('Change', cellPadding, alignLeft: true),
                      _tableCell(
                        _formatNum(change['consumption']),
                        cellPadding,
                      ),
                      _tableCell(
                        _formatNum(
                          change['averageEnergy'] ?? change['average'],
                        ),
                        cellPadding,
                      ),
                      _tableCell(_formatNum(change['peak']), cellPadding),
                    ],
                  ),
              ],
            ),
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
    // Parse ISO date (e.g. 2026-01-27 or 2026-01-27T13:46:00.000Z)
    final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(startStr);
    final timeMatch = RegExp(r'T(\d{2}:\d{2})').firstMatch(startStr);
    final date = dateMatch?.group(1) ?? startStr.split('T').first;
    final time = timeMatch?.group(1);
    if (time != null) return '$date\n$time';
    return date;
  }

  String _formatNum(dynamic value) {
    if (value == null) return '–';
    if (value is num) return value.toStringAsFixed(3);
    return value.toString();
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

  Widget _buildBuildingComparison(Map<String, dynamic> contents) {
    final comp = contents['BuildingComparison'];
    if (comp is! Map || comp['available'] != true)
      return const SizedBox.shrink();
    final buildings = comp['buildings'];
    if (buildings is! List || buildings.isEmpty) return const SizedBox.shrink();

    final list = buildings.whereType<Map>().toList();
    if (list.isEmpty) return const SizedBox.shrink();

    const headerBg = Color(0xFFE0F2F1); // Light teal
    const cellPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        _sectionWrapper(
          title: 'Building Comparison',
          showBorder: false,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              border: TableBorder.all(color: Colors.grey[300]!),
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1),
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
                    _tableCell('Peak (kW)', cellPadding, isHeader: true),
                    _tableCell('EUI (kWh/m²)', cellPadding, isHeader: true),
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
                      _tableCell(_formatNum(b['consumption']), cellPadding),
                      _tableCell(
                        _formatNum(b['average'] ?? b['averageEnergy']),
                        cellPadding,
                      ),
                      _tableCell(_formatNum(b['peak']), cellPadding),
                      _tableCell(_formatNum(b['eui']), cellPadding),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnomaliesSection(
    BuildContext context,
    Map<String, dynamic> contents,
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
        const SizedBox(height: _sectionSpacing),
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
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
                  _buildAnomalyCard(total?.toString() ?? '0', 'Total'),
                  _buildAnomalyCard(
                    (bySeverity['High'] ?? 0).toString(),
                    'High',
                  ),
                  _buildAnomalyMinMaxCard(
                    minCount.toString(),
                    maxCount.toString(),
                  ),
                  _buildAnomalyCard(sensorCount.toString(), 'Sensor Count'),
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
        borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(10),
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

  Widget _buildTimeBasedAnalysisSection(Map<String, dynamic> contents) {
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
        const SizedBox(height: _sectionSpacing),
        Text(
          'TIMEBASEDANALYSIS',
          style: AppTextStyles.overline.copyWith(
            color: Colors.grey[800],
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dayNight != null)
                    Expanded(
                      child: _buildDayNightCard(dayNight, dayColor, nightColor),
                    ),
                  if (dayNight != null && weekdayWeekend != null)
                    const SizedBox(width: 16),
                  if (weekdayWeekend != null)
                    Expanded(
                      child: _buildWeekdayWeekendCard(
                        weekdayWeekend,
                        dayColor,
                        nightColor,
                      ),
                    ),
                ],
              );
            }
            return Column(
              children: [
                if (dayNight != null) ...[
                  _buildDayNightCard(dayNight, dayColor, nightColor),
                  const SizedBox(height: 16),
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

  Widget _buildDayNightCard(Map dayNight, Color dayColor, Color nightColor) {
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
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 20),
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
                  day.toStringAsFixed(2),
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: dayColor,
                  ),
                ),
                Text(
                  night.toStringAsFixed(2),
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: nightColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 20),
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

  Widget _buildHourlyPatternSection(Map<String, dynamic> contents) {
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

    // Round Y range to nearest 10 (e.g. 0-70)
    final yMax = (maxY * 1.1).clamp(10, double.infinity);
    final yMaxRounded = ((yMax / 10).ceil() * 10).toDouble();
    const chartGreen = Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        _sectionWrapper(
          title: 'Consumption by hour',
          showBorder: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'KWH',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                              v.toInt().toString(),
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
                                '${_formatChartValue(s.y)}KWH /${s.x.toInt()} hr',
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
                              // Bottom: very transparent
                              chartGreen.withValues(alpha: 0.10),
                              // Mid: medium transparency
                              chartGreen.withValues(alpha: 0.40),
                              // Top: around 0.75 opacity as requested
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
    double titleToContentSpacing = 10,
  }) {
    final padding = zeroHorizontalPadding
        ? const EdgeInsets.only(top: 8, bottom: 16)
        : EdgeInsets.all(showBorder ? _cardPadding : 16);
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
        SizedBox(height: titleToContentSpacing),
        Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: showBorder
                ? Border.all(color: Colors.grey[300]!, width: 1)
                : null,
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildHeader(
    ReportDetailBuildingEntity building,
    ReportDetailReportingEntity reporting,
    Map<String, dynamic>? timeRange,
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
          final formatter = DateFormat('MMM d, yyyy');
          periodLabel = '${formatter.format(start)} – ${formatter.format(end)}';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          building.name,
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
        if (building.address != null && building.address!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  building.address!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
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
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  // TODO: Open period change dialog/sheet
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
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientsSection(List<ReportRecipientEntity> recipients) {
    return _sectionWrapper(
      title: 'Recipients',
      child: Column(
        children: recipients.map((r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primary.withOpacity(0.12),
                  child: Text(
                    r.recipientName.isNotEmpty
                        ? r.recipientName.substring(0, 1).toUpperCase()
                        : '?',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.recipientName.isNotEmpty ? r.recipientName : '—',
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (r.recipientEmail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          r.recipientEmail,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpis(Map<String, dynamic> reportData) {
    final kpis = reportData['kpis'];
    if (kpis is! Map<String, dynamic>) return const SizedBox.shrink();

    final energy = kpis['energy'] is Map ? kpis['energy'] as Map : null;
    final power = kpis['power'] is Map ? kpis['power'] as Map : null;
    final quality = kpis['quality'] is Map ? kpis['quality'] as Map : null;
    if (energy == null && power == null && quality == null) {
      return const SizedBox.shrink();
    }

    return _sectionWrapper(
      title: 'Key Metrics',
      showBorder: false,
      zeroHorizontalPadding: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 4.5,
                children: [
                  if (energy != null) ...[
                    _kpiTile(
                      'Total Consumption',
                      energy['total_consumption']?.toString() ?? '–',
                      energy['unit']?.toString() ?? 'kWh',
                      Icons.bolt,
                    ),
                    _kpiTile(
                      'Average Energy',
                      energy['average']?.toString() ?? '–',
                      energy['unit']?.toString() ?? 'kWh',
                      Icons.trending_up,
                    ),
                  ],
                  if (power != null) ...[
                    _kpiTile(
                      'Peak-Load',
                      power['peak']?.toString() ?? '–',
                      power['unit']?.toString() ?? 'kW',
                      Icons.offline_bolt,
                    ),
                    _kpiTile(
                      'Average Power',
                      power['average']?.toString() ?? '–',
                      power['unit']?.toString() ?? 'kW',
                      Icons.speed,
                    ),
                  ],
                ],
              );
            },
          ),
          if (quality != null &&
              quality['average'] != null &&
              quality['warning'] != null) ...[
            const SizedBox(height: 10),
            _buildDataQualityKpiCard(quality),
          ],
        ],
      ),
    );
  }

  Widget _buildDataQualityKpiCard(Map quality) {
    final avg = quality['average']?.toString() ?? '0';
    final isWarning = quality['warning'] == true;
    final statusText = isWarning
        ? 'Needs attention'
        : 'Excellent, Data quality is good';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(10),
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

  Widget _buildChartsSection(Map<String, dynamic> contents) {
    final lineChart = _buildConsumptionAndAverageEnergyLineChart(contents);
    final peakLoadChart = _buildPeakLoadByRoomBarChart(contents);
    if (lineChart == null && peakLoadChart == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        Text(
          'OVERVIEW',
          style: AppTextStyles.overline.copyWith(
            color: Colors.grey[800],
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (lineChart != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(_cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
                const SizedBox(height: 20),
                SizedBox(height: _chartHeight, child: lineChart),
                const SizedBox(height: 16),
                _buildLineChartLegend(),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (peakLoadChart != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(_cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
                const SizedBox(height: 20),
                SizedBox(height: _chartHeight, child: peakLoadChart),
              ],
            ),
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
                borderRadius: BorderRadius.circular(2),
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
                borderRadius: BorderRadius.circular(2),
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
                  _formatChartValue(v),
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
                    '${(rooms[s.x.toInt()]['roomName'] ?? 'Room')}: ${_formatChartValue(s.y)}',
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

  Widget? _buildPeakLoadByRoomBarChart(Map<String, dynamic> contents) {
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
                  _formatChartValue(value),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
            showingTooltipIndicators: [],
          ),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  static String _formatChartValue(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v >= 1 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  static DateTime? _parseReportDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// Detail Metrics: overview by measurement type. Uses MeasurementTypeBreakdown
  /// plus EUI and PerCapita from contents when available.
  Widget _buildContents(Map<String, dynamic> contents) {
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

    // Include EUI and PerCapita from contents when available
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
      titleToContentSpacing: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: items.map((e) => _buildMeasurementTypeCard(e)).toList(),
          );
        },
      ),
    );
  }

  /// Field display order and label mapping for measurement type cards.
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

  Widget _buildMeasurementTypeCard(Map item) {
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
          ? val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2)
          : val.toString();
      metricRows.add((label: label, value: valueStr));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...metricRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
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
        ],
      ),
    );
  }
}
