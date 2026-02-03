import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_token_info_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_view_bloc.dart';

/// Statistics / daily reporting dashboard UI.
/// When [token] is provided (from view-report flow), fetches and displays real report data.
/// [tokenInfo] is passed from view-report page when user proceeds; used for recipient name etc.
/// Uses clean architecture: Bloc + UseCase + Repository.
class StatisticsDashboardPage extends StatelessWidget {
  final String? token;
  final ReportTokenInfoEntity? tokenInfo;
  final String? verseId;
  final String? userName;

  const StatisticsDashboardPage({
    super.key,
    this.token,
    this.tokenInfo,
    this.verseId,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final name = tokenInfo?.recipient.name.trim().isNotEmpty == true
        ? tokenInfo!.recipient.name
        : (tokenInfo?.recipient.email.trim().isNotEmpty == true
              ? tokenInfo!.recipient.email
              : (userName?.trim().isNotEmpty == true ? userName! : 'Stephan'));

    if (token != null && token!.isNotEmpty) {
      return BlocProvider(
        create: (context) =>
            sl<ReportViewBloc>()..add(ReportViewRequested(token!)),
        child: _StatisticsDashboardContent(
          token: token!,
          tokenInfo: tokenInfo,
          userName: name,
        ),
      );
    }

    return _StatisticsDashboardContent(
      token: null,
      tokenInfo: null,
      userName: name,
    );
  }
}

class _StatisticsDashboardContent extends StatelessWidget {
  final String? token;
  final ReportTokenInfoEntity? tokenInfo;
  final String userName;

  const _StatisticsDashboardContent({
    this.token,
    this.tokenInfo,
    required this.userName,
  });

  static const Color _cardBackground = Color(0xFFE8F0E8);
  static const Color _accentBlue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Container(
          width: screenSize.width,
          color: AppTheme.primary,
          child: ListView(
            children: [
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: TopHeader(
                        onLanguageChanged: () {},
                        containerWidth: screenSize.width,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: token != null
                          ? _buildTokenBasedContent(context)
                          : _buildPlaceholderContent(context),
                    ),
                  ],
                ),
              ),
              Container(
                color: AppTheme.primary,
                constraints: const BoxConstraints(maxWidth: 1920),
                child: AppFooter(
                  onLanguageChanged: () {},
                  containerWidth: screenSize.width > 1920
                      ? 1920
                      : screenSize.width,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenBasedContent(BuildContext context) {
    return BlocBuilder<ReportViewBloc, ReportViewState>(
      builder: (context, state) {
        if (state is ReportViewLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (state is ReportViewFailure) {
          return _buildErrorContent(context, state.message);
        }
        if (state is ReportViewSuccess) {
          return _buildReportContent(context, state.report);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorContent(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            PrimaryOutlineButton(
              label: 'common.retry'.tr(),
              onPressed: () {
                context.read<ReportViewBloc>().add(ReportViewRequested(token!));
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/view-report?token=$token'),
              child: Text('statistics_dashboard.back_to_report'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, ReportDetailEntity report) {
    final reportData = report.reportData;
    final kpis = reportData['kpis'] as Map<String, dynamic>? ?? {};
    final contents = reportData['contents'] as Map<String, dynamic>? ?? {};
    final timeRange = report.timeRange ?? reportData['timeRange'];

    final energyKpi = kpis['energy'] as Map<String, dynamic>? ?? {};
    final powerKpi = kpis['power'] as Map<String, dynamic>? ?? {};
    final totalConsumption =
        contents['TotalConsumption'] as Map<String, dynamic>?;
    final consumptionByRoom =
        contents['ConsumptionByRoom'] as Map<String, dynamic>?;
    final rooms =
        (consumptionByRoom?['rooms'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    final totalConsumptionVal =
        (totalConsumption?['totalConsumption'] ??
                energyKpi['total_consumption'])
            as num? ??
        0;
    final peakPower =
        (totalConsumption?['peak'] ?? powerKpi['peak']) as num? ?? 0;
    final avgPower =
        (totalConsumption?['averagePower'] ?? powerKpi['average']) as num? ?? 0;
    final unit =
        (totalConsumption?['totalConsumptionUnit'] ?? energyKpi['unit'])
            as String? ??
        'kWh';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeader(report.building.name, report.reporting.name),
            const SizedBox(height: 32),
            _buildTimeRangeInfo(timeRange),
            const SizedBox(height: 24),
            _buildKeyFactsCard(
              totalConsumption: totalConsumptionVal,
              peakPower: peakPower,
              avgPower: avgPower,
              unit: unit,
            ),
            const SizedBox(height: 24),
            if (rooms.isNotEmpty) ...[
              _buildConsumptionByRoomCard(rooms),
              const SizedBox(height: 24),
            ],
            _buildFooter(context, report.building.name),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String buildingName, String reportName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'statistics_dashboard.dear_name'.tr(namedArgs: {'name': userName}),
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          reportName,
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          buildingName,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTimeRangeInfo(Map<String, dynamic>? timeRange) {
    if (timeRange == null) return const SizedBox.shrink();
    final start = timeRange['startDate'] ?? timeRange['start'] ?? '';
    final end = timeRange['endDate'] ?? timeRange['end'] ?? '';
    final interval = timeRange['interval'] ?? '';
    if (start.toString().isEmpty) return const SizedBox.shrink();

    String formatDate(String? s) {
      if (s == null || s.toString().isEmpty) return '';
      try {
        final dt = DateTime.tryParse(s.toString());
        return dt != null ? '${dt.day}.${dt.month}.${dt.year}' : s.toString();
      } catch (_) {
        return s.toString();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            '${formatDate(start.toString())} – ${formatDate(end.toString())}${interval.toString().isNotEmpty ? ' ($interval)' : ''}',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyFactsCard({
    required num totalConsumption,
    required num peakPower,
    required num avgPower,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'statistics_dashboard.key_facts_title'.tr(),
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              return isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _keyFactEnergy(totalConsumption, unit),
                        const SizedBox(height: 20),
                        _keyFactPeak(peakPower),
                        const SizedBox(height: 20),
                        _keyFactAverage(avgPower, unit),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _keyFactEnergy(totalConsumption, unit)),
                        const SizedBox(width: 20),
                        Expanded(child: _keyFactPeak(peakPower)),
                        const SizedBox(width: 20),
                        Expanded(child: _keyFactAverage(avgPower, unit)),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _keyFactEnergy(num total, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'statistics_dashboard.energy_consumption_current'.tr(),
          style: AppTextStyles.titleSmall.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2),
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text(unit, style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _keyFactPeak(num peak) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'statistics_dashboard.peak_load'.tr(),
          style: AppTextStyles.titleSmall.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              peak.toStringAsFixed(2),
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text('kW', style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _keyFactAverage(num avg, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'statistics_dashboard.average'.tr(),
          style: AppTextStyles.titleSmall.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              avg.toStringAsFixed(2),
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text(unit, style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildConsumptionByRoomCard(List<Map<String, dynamic>> rooms) {
    final roomsWithConsumption = rooms
        .where((r) => ((r['consumption'] ?? 0) as num) > 0)
        .toList();
    if (roomsWithConsumption.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'statistics_dashboard.consumption_by_room'.tr(),
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...roomsWithConsumption.take(10).map((r) {
            final name = (r['roomName'] ?? r['roomId'] ?? '').toString();
            final consumption = (r['consumption'] ?? 0) as num;
            final unit = (r['consumptionUnit'] ?? 'kWh').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${consumption.toStringAsFixed(2)} $unit',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, String buildingName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'statistics_dashboard.thanks_goodbye'.tr(
            namedArgs: {'name': userName},
          ),
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (token != null)
          TextButton(
            onPressed: () => context.go('/view-report?token=$token'),
            child: Text(
              'statistics_dashboard.back_to_report'.tr(),
              style: const TextStyle(
                color: _accentBlue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'statistics_dashboard.report_created'.tr(),
          style: AppTextStyles.bodySmall.copyWith(color: Colors.black45),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'statistics_dashboard.report_disclaimer'.tr(),
          style: AppTextStyles.bodySmall.copyWith(color: Colors.black45),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPlaceholderContent(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'statistics_dashboard.dear_name'.tr(
                namedArgs: {'name': userName},
              ),
              style: AppTextStyles.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'statistics_dashboard.no_report_token'.tr(),
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text('statistics_dashboard.go_to_login'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
