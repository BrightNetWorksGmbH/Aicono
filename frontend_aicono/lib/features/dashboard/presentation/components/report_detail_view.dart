import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
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
  static const double _cardPadding = 24;
  static const double _chartHeight = 220;
  static const double _hourlyChartHeight = 200;
  static const int _maxBars = 8;
  static const int _maxAnomaliesShown = 8;

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
    final timeRange = reportData['timeRange'] is Map<String, dynamic>
        ? reportData['timeRange'] as Map<String, dynamic>
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(building, reporting, timeRange),
          if (recipients.isNotEmpty) ...[
            const SizedBox(height: _sectionSpacing),
            _buildRecipientsSection(recipients),
          ],
          const SizedBox(height: _sectionSpacing),
          _buildKpis(reportData),
          _buildDataQualityAndTemperature(contents),
          _buildChartsSection(contents),
          _buildHourlyPatternSection(contents),
          _buildPeriodComparison(contents),
          _buildBuildingComparison(contents),
          _buildAnomaliesSection(contents),
          const SizedBox(height: _sectionSpacing),
          _buildContents(contents),
        ],
      ),
    );
  }

  Widget _buildDataQualityAndTemperature(Map<String, dynamic> contents) {
    final dataQuality = contents['DataQualityReport'];
    final temp = contents['TemperatureAnalysis'];
    final eui = contents['EUI'];
    final perCapita = contents['PerCapitaConsumption'];
    final hasAny =
        dataQuality is Map ||
        (temp is Map && temp['available'] == true) ||
        (eui is Map && eui['available'] == true) ||
        (perCapita is Map && perCapita['available'] == true);
    if (!hasAny) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        Row(
          children: [
            Icon(Icons.insights, size: 20, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(
              'INSIGHTS',
              style: AppTextStyles.overline.copyWith(
                color: Colors.grey[600],
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            if (dataQuality is Map) _buildDataQualityCard(dataQuality),
            if (temp is Map &&
                temp['available'] == true &&
                temp['overall'] is Map)
              _buildTemperatureCard(temp['overall'] as Map),
            if (eui is Map && eui['available'] == true) _buildEuiCard(eui),
            if (perCapita is Map && perCapita['available'] == true)
              _buildPerCapitaCard(perCapita),
          ],
        ),
      ],
    );
  }

  Widget _buildEuiCard(Map eui) {
    final value = eui['eui']?.toString() ?? '—';
    final annualized = eui['annualizedEUI']?.toString();
    final unit = eui['unit']?.toString() ?? 'kWh/m²';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.square_foot, size: 28, color: AppTheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EUI',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '$value $unit',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (annualized != null)
                Text(
                  'Annualized: $annualized',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerCapitaCard(Map perCapita) {
    final value = perCapita['perCapita']?.toString() ?? '—';
    final unit = perCapita['unit']?.toString() ?? 'kWh/person';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 28, color: AppTheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Per capita',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '$value $unit',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataQualityCard(Map dataQuality) {
    final status = dataQuality['status']?.toString() ?? '—';
    final message = dataQuality['message']?.toString() ?? '';
    final avg = dataQuality['averageQuality'];
    final warning = dataQuality['qualityWarning'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning ? Colors.orange[300]! : Colors.green[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            warning ? Icons.warning_amber : Icons.check_circle_outline,
            size: 28,
            color: warning ? Colors.orange[700] : Colors.green[700],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data quality',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: warning ? Colors.orange[800] : Colors.green[800],
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (avg != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$avg%',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureCard(Map overall) {
    final avg = overall['average']?.toString() ?? '—';
    final min = overall['min']?.toString() ?? '—';
    final max = overall['max']?.toString() ?? '—';
    final unit = overall['unit']?.toString() ?? '°C';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.thermostat, size: 28, color: AppTheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Temperature',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Avg $avg $unit',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Min $min · Max $max $unit',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        _sectionWrapper(
          title: 'Period comparison',
          icon: Icons.compare_arrows,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (current != null)
                Expanded(
                  child: _periodTile(
                    'Current',
                    current['consumption']?.toString(),
                    current['consumptionUnit']?.toString(),
                    current['period'] is Map ? current['period'] as Map : null,
                  ),
                ),
              if (previous != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _periodTile(
                    'Previous',
                    previous['consumption']?.toString(),
                    previous['consumptionUnit']?.toString(),
                    previous['period'] is Map
                        ? previous['period'] as Map
                        : null,
                  ),
                ),
              ],
              if (change != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _periodTile(
                    'Change',
                    change['consumption']?.toString(),
                    change['consumptionUnit']?.toString(),
                    null,
                    isChange: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodTile(
    String label,
    String? value,
    String? unit,
    Map? period, {
    bool isChange = false,
  }) {
    String sub = '';
    if (period != null) {
      final start = period['start'] ?? period['startDate'];
      final end = period['end'] ?? period['endDate'];
      if (start != null && end != null) sub = '$start – $end';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${value ?? '–'} ${unit ?? ''}'.trim(),
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: isChange ? AppTheme.primary : null,
          ),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            sub,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[500]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildBuildingComparison(Map<String, dynamic> contents) {
    final comp = contents['BuildingComparison'];
    if (comp is! Map || comp['available'] != true)
      return const SizedBox.shrink();
    final buildings = comp['buildings'];
    if (buildings is! List || buildings.isEmpty) return const SizedBox.shrink();

    final list = buildings
        .whereType<Map>()
        .map(
          (b) => (
            (b['buildingName'] ?? b['building_name'] ?? '—').toString(),
            (b['consumption'] is num)
                ? (b['consumption'] as num).toDouble()
                : 0.0,
            (b['consumptionUnit'] ?? b['consumption_unit'] ?? 'kWh').toString(),
          ),
        )
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();

    final maxConsumption = list
        .map((e) => e.$2)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        _sectionWrapper(
          title: 'Building comparison',
          icon: Icons.apartment,
          child: Column(
            children: list.map((e) {
              final pct = maxConsumption > 0 ? (e.$2 / maxConsumption) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            e.$1,
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${e.$2.toStringAsFixed(2)} ${e.$3}',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primary.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAnomaliesSection(Map<String, dynamic> contents) {
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
    final showList = anomalies.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        _sectionWrapper(
          title: 'Anomalies',
          icon: Icons.warning_amber_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (total != null)
                    _anomalyChip('Total', total.toString(), Colors.grey[700]!),
                  ...bySeverity.entries.map((e) {
                    Color c = Colors.grey[600]!;
                    if (e.key == 'High') c = Colors.red[700]!;
                    if (e.key == 'Medium') c = Colors.orange[700]!;
                    if (e.key == 'Low') c = Colors.amber[700]!;
                    return Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _anomalyChip(
                        e.key.toString(),
                        e.value?.toString() ?? '0',
                        c,
                      ),
                    );
                  }),
                ],
              ),
              if (showList) ...[
                const SizedBox(height: 20),
                Text(
                  'Recent anomalies',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                ...anomalies
                    .take(_maxAnomaliesShown)
                    .map((a) => _buildAnomalyTile(a)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _anomalyChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyTile(Map a) {
    final ts = a['timestamp']?.toString() ?? '';
    final sensor = a['sensorName']?.toString() ?? '—';
    final rule = a['violatedRule']?.toString() ?? '';
    final severity = a['severity']?.toString() ?? '—';
    final value = a['value']?.toString() ?? '—';
    final status = a['status']?.toString() ?? '—';
    Color severityColor = Colors.grey[700]!;
    if (severity == 'High') severityColor = Colors.red[700]!;
    if (severity == 'Medium') severityColor = Colors.orange[700]!;
    if (severity == 'Low') severityColor = Colors.amber[700]!;

    String timeStr = ts;
    if (ts.length > 19) timeStr = ts.substring(0, 19).replaceFirst('T', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: severityColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  severity,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: severityColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                status,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sensor,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (rule.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              rule,
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (value != '—')
            Text(
              'Value: $value',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
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
    final spots = List.generate(
      24,
      (i) => FlSpot(i.toDouble(), byHour[i] ?? 0),
    );
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Consumption by hour',
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              if (timeData['dayNight'] is Map) ...[
                const SizedBox(height: 8),
                Text(
                  'Day ${timeData['dayNight']['day']?.toString() ?? '—'} · Night ${timeData['dayNight']['night']?.toString() ?? '—'} (Day ${timeData['dayNight']['dayPercentage'] ?? '—'}%)',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: _hourlyChartHeight,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 23,
                    minY: 0,
                    maxY: maxY * 1.15,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      verticalInterval: 4,
                      horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                      getDrawingHorizontalLine: (v) =>
                          FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                      getDrawingVerticalLine: (v) =>
                          FlLine(color: Colors.grey[100]!, strokeWidth: 1),
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
                          reservedSize: 28,
                          interval: 2,
                          getTitlesWidget: (v, m) => Text(
                            '${v.toInt()}h',
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
                        getTooltipItems: (touchedSpots) => touchedSpots
                            .map(
                              (s) => LineTooltipItem(
                                '${s.x.toInt()}h: ${_formatChartValue(s.y)}',
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
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AppTheme.primary,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: AppTheme.primary,
                                strokeWidth: 1.5,
                                strokeColor: Colors.white,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primary.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 300),
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
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 10),
            ],
            Text(
              title.toUpperCase(),
              style: AppTextStyles.overline.copyWith(
                color: Colors.grey[600],
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1),
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
    String timeRangeStr = '';
    if (timeRange != null) {
      final start = timeRange['start'] ?? timeRange['startDate'];
      final end = timeRange['end'] ?? timeRange['endDate'];
      if (start != null && end != null) {
        timeRangeStr = '$start – $end';
      }
    }
    return _sectionWrapper(
      title: 'Report',
      icon: Icons.assessment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            building.name,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_chip(reporting.name), _chip(reporting.interval)],
          ),
          if (timeRangeStr.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  timeRangeStr,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRecipientsSection(List<ReportRecipientEntity> recipients) {
    return _sectionWrapper(
      title: 'Recipients',
      icon: Icons.people_outline,
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
      title: 'Key metrics',
      icon: Icons.show_chart,
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        children: [
          if (energy != null) ...[
            _kpiTile(
              'Total consumption',
              energy['total_consumption']?.toString() ?? '–',
              energy['unit']?.toString() ?? '',
              Icons.bolt,
            ),
            _kpiTile(
              'Average',
              energy['average']?.toString() ?? '–',
              energy['unit']?.toString() ?? '',
              Icons.trending_up,
            ),
          ],
          if (power != null) ...[
            _kpiTile(
              'Peak',
              power['peak']?.toString() ?? '–',
              power['unit']?.toString() ?? '',
              Icons.offline_bolt,
            ),
            _kpiTile(
              'Average power',
              power['average']?.toString() ?? '–',
              power['unit']?.toString() ?? '',
              Icons.speed,
            ),
          ],
          if (quality != null &&
              quality['average'] != null &&
              quality['warning'] != null) ...[
            _kpiTile(
              'Data quality',
              '${quality['average']}%',
              quality['warning'] == true ? 'Warning' : 'OK',
              Icons.verified,
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiTile(String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: const BoxConstraints(minWidth: 140),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(Map<String, dynamic> contents) {
    final breakdownChart = _buildBreakdownBarChart(contents);
    final roomChart = _buildConsumptionByRoomChart(contents);
    if (breakdownChart == null && roomChart == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionSpacing),
        Row(
          children: [
            Icon(Icons.bar_chart, size: 20, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(
              'OVERVIEW',
              style: AppTextStyles.overline.copyWith(
                color: Colors.grey[600],
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (breakdownChart != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(_cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By measurement type',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(height: _chartHeight, child: breakdownChart),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (roomChart != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(_cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consumption by room (top $_maxBars)',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(height: _chartHeight, child: roomChart),
              ],
            ),
          ),
      ],
    );
  }

  static String _formatChartValue(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v >= 1 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  Widget? _buildBreakdownBarChart(Map<String, dynamic> contents) {
    final breakdownData = contents['MeasurementTypeBreakdown'];
    if (breakdownData is! Map || breakdownData['breakdown'] is! List) {
      return null;
    }
    final list = breakdownData['breakdown'] as List;
    if (list.isEmpty) return null;

    final items = list
        .whereType<Map>()
        .map(
          (e) => (
            (e['measurement_type'] ?? e['measurementType'] ?? '—').toString(),
            (e['total'] is num) ? (e['total'] as num).toDouble() : 0.0,
            (e['unit'] ?? '').toString(),
          ),
        )
        .where((e) => e.$2 > 0)
        .take(_maxBars)
        .toList();
    if (items.isEmpty) return null;

    final maxVal = items.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final primary = AppTheme.primary;
    final barColors = [
      primary,
      primary.withOpacity(0.88),
      primary.withOpacity(0.76),
      primary.withOpacity(0.64),
      primary.withOpacity(0.52),
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final i = group.x.toInt();
              if (i >= 0 && i < items.length) {
                return BarTooltipItem(
                  '${items[i].$1}\n',
                  AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '${items[i].$2.toStringAsFixed(2)} ${items[i].$3}'
                          .trim(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                );
              }
              return null;
            },
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipMargin: 8,
            tooltipRoundedRadius: 8,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < items.length) {
                  final label = items[i].$1;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      label,
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
              reservedSize: 36,
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
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
          drawVerticalLine: false,
          horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(items.length, (i) {
          final c = barColors[i % barColors.length];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: items[i].$2,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [c.withOpacity(0.85), c],
                ),
                width: 26,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxVal * 1.2,
                  color: Colors.grey[100]!,
                ),
              ),
            ],
            showingTooltipIndicators: [0],
          );
        }),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget? _buildConsumptionByRoomChart(Map<String, dynamic> contents) {
    final roomData = contents['ConsumptionByRoom'];
    if (roomData is! Map || roomData['rooms'] is! List) return null;
    final list = roomData['rooms'] as List;
    if (list.isEmpty) return null;

    final items =
        list
            .whereType<Map>()
            .map(
              (e) => (
                (e['roomName'] ?? e['room_name'] ?? '—').toString(),
                (e['consumption'] is num)
                    ? (e['consumption'] as num).toDouble()
                    : 0.0,
              ),
            )
            .where((e) => e.$2 > 0)
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    final top = items.take(_maxBars).toList();
    if (top.isEmpty) return null;

    final maxVal = top.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final barColor = AppTheme.primary;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(enabled: true),
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
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
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
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          top.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: top[i].$2,
                color: barColor.withOpacity(0.6 + (0.4 * (1 - i / top.length))),
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
            showingTooltipIndicators: [0],
          ),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildContents(Map<String, dynamic> contents) {
    if (contents.isEmpty) return const SizedBox.shrink();

    const skipKeys = {
      'MeasurementTypeBreakdown',
      'ConsumptionByRoom',
      'Anomalies',
      'PeriodComparison',
      'BuildingComparison',
      'DataQualityReport',
      'TimeBasedAnalysis',
      'TemperatureAnalysis',
    };
    final entries = contents.entries
        .where((e) => e.value != null && !skipKeys.contains(e.key))
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return _sectionWrapper(
      title: 'Report contents',
      icon: Icons.list_alt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _contentSection(_formatKey(e.key), e.value),
              ),
            )
            .toList(),
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => ' ${m.group(1)!.toLowerCase()}',
        )
        .trim()
        .split(' ')
        .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  Widget _contentSection(String title, dynamic data) {
    if (data is Map) {
      final map = data;
      // Skip keys ending with "Unit"; merge unit with the value key
      final entries = map.entries
          .where((e) => e.key is String && !e.key.toString().endsWith('Unit'))
          .take(10)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          ...entries.map((e) {
            final key = e.key.toString();
            final unitKey = '${key}Unit';
            final unit = map.containsKey(unitKey)
                ? map[unitKey]?.toString().trim()
                : null;
            final valueStr = e.value?.toString() ?? '—';
            final displayValue = (unit != null && unit.isNotEmpty)
                ? '$valueStr $unit'
                : valueStr;
            return Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                '${_formatKey(key)}: $displayValue',
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            );
          }),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            data.toString(),
            style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}
