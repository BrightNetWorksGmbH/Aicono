import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/utils/locale_number_format.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_building_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/anomalies_detail_dialog.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/weekday_weekend_cylinder_chart.dart';

import 'dashboard_shared_components.dart';
import 'dashboard_spacing.dart';

const Color _metricIconTeal = Color(0xFF00897B);

String _formatBuildingChartValue(Locale locale, double v) {
  return LocaleNumberFormat.formatCompact(v, locale: locale);
}

List<Widget> buildBuildingDetailsMetricCards(
  DashboardBuildingDetails d,
  Locale locale,
) {
  final metricCards = <Widget>[
    buildPropertyMetricCard(
      label: 'Floors',
      value: LocaleNumberFormat.formatInt(d.floorCount, locale: locale),
      icon: buildDashboardSvgIcon(assetFloor, color: _metricIconTeal),
    ),
    buildPropertyMetricCard(
      label: 'Rooms',
      value: LocaleNumberFormat.formatInt(d.roomCount, locale: locale),
      icon: buildDashboardSvgIcon(assetRoom, color: _metricIconTeal),
    ),
    buildPropertyMetricCard(
      label: 'Sensors',
      value: LocaleNumberFormat.formatInt(d.sensorCount, locale: locale),
      icon: buildDashboardSvgIcon(assetSensor, color: _metricIconTeal, size: 20),
    ),
  ];
  if (d.buildingSize != null) {
    metricCards.add(
      buildPropertyMetricCard(
        label: 'Size (m²)',
        value: LocaleNumberFormat.formatNum(
          d.buildingSize,
          locale: locale,
          decimalDigits: 2,
        ),
        icon: buildDashboardSvgIcon(assetBuilding, color: _metricIconTeal),
      ),
    );
  }
  return metricCards;
}

Widget buildBuildingDetailMetricsSection(
  DashboardBuildingAnalytics? analytics,
  DashboardKpis? kpis,
  Locale locale,
) {
  final cards = <Widget>[];

  if (analytics != null) {
    final eui = analytics.eui;
    if (eui != null && eui.available) {
      cards.add(
        buildAnalyticsMetricCard(
          title: 'EUI (${eui.unit})',
          rows: [
            (
              label: 'EUI',
              value: LocaleNumberFormat.formatDecimal(
                eui.eui,
                locale: locale,
                decimalDigits: 2,
              ),
            ),
            (
              label: 'Annualized',
              value: LocaleNumberFormat.formatDecimal(
                eui.annualizedEui,
                locale: locale,
                decimalDigits: 2,
              ),
            ),
          ],
        ),
      );
    }

    final perCapita = analytics.perCapita;
    if (perCapita != null && perCapita.available) {
      final rows = <({String label, String value})>[
        (
          label: 'Per Capita',
          value: LocaleNumberFormat.formatDecimal(
            perCapita.perCapita,
            locale: locale,
            decimalDigits: 2,
          ),
        ),
      ];
      if (perCapita.numPeople != null && perCapita.numPeople! > 0) {
        rows.add((
          label: 'People',
          value: LocaleNumberFormat.formatInt(perCapita.numPeople!, locale: locale),
        ));
      }
      cards.add(
        buildAnalyticsMetricCard(
          title: 'Per Capita (${perCapita.unit})',
          rows: rows,
        ),
      );
    }
  }

  if (kpis != null && kpis.breakdown.isNotEmpty) {
    for (final item in kpis.breakdown) {
      final title = item.unit.isNotEmpty
          ? '${item.measurementType} (${item.unit})'
          : item.measurementType;
      cards.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              SizedBox(height: DashboardSpacing.titleSubtitle),
              buildBreakdownRow('Total', item.total, locale),
              buildBreakdownRow('Average', item.average, locale),
              buildBreakdownRow('Min', item.min, locale),
              buildBreakdownRow('Max', item.max, locale),
              if (item.count > 0)
                buildBreakdownRow('Count', item.count, locale),
            ],
          ),
        ),
      );
    }
  }

  if (cards.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Detail Metrics',
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: DashboardSpacing.cardGap),
      LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;
          final spacing = DashboardSpacing.cardGap;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  cards[i],
                ],
              ],
            );
          }
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: cards
                .map(
                  (c) => SizedBox(
                    width: (constraints.maxWidth - spacing) / 2,
                    child: c,
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

Widget buildBuildingComparisonSection(
  Map<String, dynamic> analyticsRaw,
  Locale locale,
) {
  final comp = analyticsRaw['buildingComparison'] ?? analyticsRaw['BuildingComparison'];
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
      Text(
        'Building Comparison',
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: DashboardSpacing.cardGap),
      LayoutBuilder(
        builder: (context, constraints) {
          final fullWidth = constraints.maxWidth;
          return Container(
            width: fullWidth,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.white,
            ),
            child: Table(
              border: TableBorder.all(color: Colors.grey[300]!),
              columnWidths: {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(0.8),
                4: FlexColumnWidth(0.8),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: headerBg),
                  children: [
                    dashboardTableCell('Building', cellPadding, isHeader: true, alignLeft: true),
                    dashboardTableCell('Consumption (kWh)', cellPadding, isHeader: true),
                    dashboardTableCell('Average (kWh)', cellPadding, isHeader: true),
                    dashboardTableCell('Peak (kW)', cellPadding, isHeader: true),
                    dashboardTableCell('EUI (kWh/m²)', cellPadding, isHeader: true),
                  ],
                ),
                ...list.map(
                  (b) => TableRow(
                    children: [
                      dashboardTableCell(
                        (b['buildingName'] ?? b['building_name'] ?? '—').toString(),
                        cellPadding,
                        alignLeft: true,
                        isBold: true,
                      ),
                      dashboardTableCell(formatDashboardNum(locale, b['consumption']), cellPadding),
                      dashboardTableCell(
                        formatDashboardNum(locale, b['average'] ?? b['averageEnergy']),
                        cellPadding,
                      ),
                      dashboardTableCell(formatDashboardNum(locale, b['peak']), cellPadding),
                      dashboardTableCell(formatDashboardNum(locale, b['eui']), cellPadding),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

Widget buildBuildingBenchmarkSection(
  Map<String, dynamic> analyticsRaw,
  Locale locale,
) {
  final benchmark = analyticsRaw['benchmark'];
  if (benchmark is! Map) return const SizedBox.shrink();
  final available = benchmark['available'] == true;
  final message = (benchmark['message'] ?? '').toString();
  if (available && message.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Benchmark',
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: DashboardSpacing.cardGap),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.grey[300]!),
          color: Colors.white,
        ),
        child: Text(
          message.isNotEmpty ? message : 'No benchmark data available.',
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[700]),
        ),
      ),
    ],
  );
}

Widget buildBuildingInefficientUsageSection(
  Map<String, dynamic> analyticsRaw,
  Locale locale,
) {
  final data = analyticsRaw['inefficientUsage'];
  if (data is! Map) return const SizedBox.shrink();
  final baseLoad = data['baseLoad'];
  final averageLoad = data['averageLoad'];
  final ratio = data['baseToAverageRatio'];
  final message = (data['message'] ?? '').toString();
  final baseUnit = (data['baseLoadUnit'] ?? 'kWh').toString();
  final avgUnit = (data['averageLoadUnit'] ?? 'kWh').toString();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Inefficient usage',
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: DashboardSpacing.cardGap),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.grey[300]!),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (baseLoad != null)
              buildBreakdownRow('Base load', '$baseLoad $baseUnit', locale),
            if (averageLoad != null)
              buildBreakdownRow('Average load', '$averageLoad $avgUnit', locale),
            if (ratio != null)
              buildBreakdownRow('Base to average ratio', ratio, locale),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[700])),
            ],
          ],
        ),
      ),
    ],
  );
}

Widget buildBuildingTemperatureSection(
  Map<String, dynamic> analyticsRaw,
  Locale locale,
) {
  final data = analyticsRaw['temperatureAnalysis'];
  if (data is! Map || data['available'] != true) return const SizedBox.shrink();
  final overall = data['overall'];
  if (overall is! Map) return const SizedBox.shrink();
  final average = overall['average'];
  final min = overall['min'];
  final max = overall['max'];
  final unit = (overall['unit'] ?? '°C').toString();
  final totalSensors = data['totalSensors'];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Temperature analysis',
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: DashboardSpacing.cardGap),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.grey[300]!),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (average != null)
              buildBreakdownRow(
                'Average ($unit)',
                LocaleNumberFormat.formatNum(average, locale: locale, decimalDigits: 2),
                locale,
              ),
            if (min != null)
              buildBreakdownRow(
                'Min ($unit)',
                LocaleNumberFormat.formatNum(min, locale: locale, decimalDigits: 2),
                locale,
              ),
            if (max != null)
              buildBreakdownRow(
                'Max ($unit)',
                LocaleNumberFormat.formatNum(max, locale: locale, decimalDigits: 2),
                locale,
              ),
            if (totalSensors != null)
              buildBreakdownRow('Sensors', totalSensors, locale),
          ],
        ),
      ),
    ],
  );
}

Widget buildBuildingHourlyPatternSection(
  Map<String, dynamic> analyticsRaw,
  Locale locale,
) {
  const chartHeight = 200.0;
  final timeData = analyticsRaw['timeBasedAnalysis'] ?? analyticsRaw['TimeBasedAnalysis'];
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
  final maxHour = byHour.keys.isEmpty ? 23 : byHour.keys.reduce((a, b) => a > b ? a : b);
  final hourCount = (maxHour > 23 ? maxHour + 1 : 24).clamp(24, 48);
  final spots = List.generate(hourCount, (i) => FlSpot(i.toDouble(), byHour[i] ?? 0));
  final maxY = spots.isEmpty ? 0.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
  if (maxY <= 0) return const SizedBox.shrink();

  final yMax = (maxY * 1.1).clamp(10.0, double.infinity);
  final yMaxRounded = ((yMax / 10).ceil() * 10).toDouble();
  const chartGreen = Color(0xFF2E7D32);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Consumption by hour',
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: DashboardSpacing.cardGap),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.grey[300]!),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'kWh',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: chartHeight,
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
                            LocaleNumberFormat.formatInt(v.toInt(), locale: locale),
                            style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
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
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipColor: (_) => Colors.white,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map(
                            (s) => LineTooltipItem(
                              '${_formatBuildingChartValue(locale, s.y)} kWh / ${s.x.toInt()} hr',
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

Widget buildBuildingTimeBasedAnalysisSection(
  Map<String, dynamic> analyticsRaw,
  Locale locale,
) {
  final timeData = analyticsRaw['timeBasedAnalysis'] ?? analyticsRaw['TimeBasedAnalysis'];
  if (timeData is! Map) return const SizedBox.shrink();
  final dayNight = timeData['dayNight'] is Map ? timeData['dayNight'] as Map : null;
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
        'Time-based analysis',
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: DashboardSpacing.cardGap),
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
                      child: buildBuildingDayNightCard(
                        dayNight,
                        dayColor,
                        nightColor,
                        locale,
                      ),
                    ),
                  if (dayNight != null && weekdayWeekend != null)
                    const SizedBox(width: 16),
                  if (weekdayWeekend != null)
                    Expanded(
                      child: buildBuildingWeekdayWeekendCard(
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
                buildBuildingDayNightCard(
                  dayNight,
                  dayColor,
                  nightColor,
                  locale,
                ),
                const SizedBox(height: 16),
              ],
              if (weekdayWeekend != null)
                buildBuildingWeekdayWeekendCard(
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

Widget buildBuildingDayNightCard(
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
          'Day & Night (kWh)',
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
                LocaleNumberFormat.formatNum(day, locale: locale, decimalDigits: 2),
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: dayColor,
                ),
              ),
              Text(
                LocaleNumberFormat.formatNum(night, locale: locale, decimalDigits: 2),
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
                  decoration: BoxDecoration(color: dayColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('Day', style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700])),
              ],
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: nightColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('Night', style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700])),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildBuildingWeekdayWeekendCard(
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
          'Weekday & Weekend (kWh)',
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

Widget buildBuildingAnomaliesSection(
  BuildContext context,
  Map<String, dynamic> analyticsRaw,
  Locale locale,
) {
  final anomaliesData = analyticsRaw['anomalies'] ?? analyticsRaw['Anomalies'];
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
            'Anomalies (severity)',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
      SizedBox(height: DashboardSpacing.cardGap),
      LayoutBuilder(
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
              buildBuildingAnomalyCard(
                LocaleNumberFormat.formatInt(total, locale: locale, fallback: '0'),
                'Total',
              ),
              buildBuildingAnomalyCard(
                LocaleNumberFormat.formatInt(bySeverity['High'] ?? 0, locale: locale),
                'High',
              ),
              buildBuildingAnomalyMinMaxCard(
                LocaleNumberFormat.formatInt(minCount, locale: locale),
                LocaleNumberFormat.formatInt(maxCount, locale: locale),
              ),
              buildBuildingAnomalyCard(
                LocaleNumberFormat.formatInt(sensorCount, locale: locale),
                'Sensor Count',
              ),
            ],
          );
        },
      ),
    ],
  );
}

Widget buildBuildingAnomalyCard(String value, String label) {
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

Widget buildBuildingAnomalyMinMaxCard(String minValue, String maxValue) {
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
              Text(minValue, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[900])),
              const SizedBox(height: 2),
              Text('Minimum', style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600])),
            ],
          ),
        ),
        Container(width: 1, height: 28, color: Colors.grey[300]),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(maxValue, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[900])),
              const SizedBox(height: 2),
              Text('Maximum', style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    ),
  );
}
