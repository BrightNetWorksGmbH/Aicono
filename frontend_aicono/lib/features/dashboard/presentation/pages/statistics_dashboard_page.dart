import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

/// Statistics / daily reporting dashboard UI.
/// Shown when user taps "Reporting Preview" on the dashboard main view.
/// Uses the same shell (background, top header, footer)
/// as the main dashboard page for visual consistency.
class StatisticsDashboardPage extends StatefulWidget {
  final String? verseId;
  final String? userName;

  const StatisticsDashboardPage({
    super.key,
    this.verseId,
    this.userName,
  });

  @override
  State<StatisticsDashboardPage> createState() =>
      _StatisticsDashboardPageState();
}

class _StatisticsDashboardPageState extends State<StatisticsDashboardPage> {
  static const Color _cardBackground = Color(0xFFE8F0E8);
  static const Color _accentGreen = Color(0xFF2E7D32);
  static const Color _accentBlue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final name = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!
        : 'Stephan';

    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Container(
          width: screenSize.width,
          color: AppTheme.primary,
          child: ListView(
            children: [
              // White card container matching dashboard shell
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Top header (same as dashboard)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: TopHeader(
                        onLanguageChanged: () {
                          // Just rebuild this page when language changes
                          setState(() {});
                        },
                        containerWidth: screenSize.width,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Page-specific reporting content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: _buildReportContent(context, name),
                    ),
                  ],
                ),
              ),
              // Global app footer, same as dashboard
              Container(
                color: AppTheme.primary,
                constraints: const BoxConstraints(maxWidth: 1920),
                child: AppFooter(
                  onLanguageChanged: () {
                    setState(() {});
                  },
                  containerWidth:
                      screenSize.width > 1920 ? 1920 : screenSize.width,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, String name) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeader(name),
            const SizedBox(height: 32),
            _buildExecutiveSummary(),
            const SizedBox(height: 24),
            _buildKeyFactsCard(context),
            const SizedBox(height: 24),
            _buildPeakLoadCard(context),
            const SizedBox(height: 24),
            _buildHandlungsempfehlung(context),
            const SizedBox(height: 48),
            _buildFooter(context, name),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'statistics_dashboard.dear_name'.tr(namedArgs: {'name': name}),
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'statistics_dashboard.daily_reporting'.tr(),
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildExecutiveSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'statistics_dashboard.executive_summary'.tr(),
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _summaryItem('statistics_dashboard.summary_resource_status'.tr()),
        _summaryItem('statistics_dashboard.summary_cost_targets'.tr()),
        _summaryItem('statistics_dashboard.summary_forecast_targets'.tr()),
        const SizedBox(height: 16),
        Divider(color: Colors.grey[300], height: 1),
      ],
    );
  }

  Widget _summaryItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: _accentGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyFactsCard(BuildContext context) {
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
                        _keyFactEnergy(),
                        const SizedBox(height: 20),
                        _keyFactCostChart(),
                        const SizedBox(height: 20),
                        _keyFactCo2Chart(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _keyFactEnergy()),
                        const SizedBox(width: 20),
                        Expanded(child: _keyFactCostChart()),
                        const SizedBox(width: 20),
                        Expanded(child: _keyFactCo2Chart()),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _keyFactEnergy() {
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
              '132480',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text('kWh', style: AppTextStyles.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.trending_down, color: _accentGreen, size: 18),
            const SizedBox(width: 4),
            Text(
              'statistics_dashboard.below_plan_2025'.tr(),
              style: AppTextStyles.bodySmall.copyWith(color: _accentGreen),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyFactCostChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'statistics_dashboard.consumption_costs_forecast'.tr(),
          style: AppTextStyles.titleSmall.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                6,
                (i) => Container(
                  width: 24,
                  height: 20 + (i % 3) * 12.0,
                  decoration: BoxDecoration(
                    color: _accentGreen.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          'statistics_dashboard.months_jan_jun'.tr(),
          style: AppTextStyles.labelSmall.copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _keyFactCo2Chart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'statistics_dashboard.co2_emission_forecast'.tr(),
          style: AppTextStyles.titleSmall.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 0.92,
                strokeWidth: 8,
                backgroundColor: _accentGreen.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(_accentBlue),
              ),
              Text(
                '-8%',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeakLoadCard(BuildContext context) {
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
            'statistics_dashboard.peak_load_analysis_title'.tr(),
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
                      children: [
                        _peakDonut(),
                        const SizedBox(height: 20),
                        _peakChartAndList(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 160, child: _peakDonut()),
                        const SizedBox(width: 24),
                        Expanded(child: _peakChartAndList()),
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'statistics_dashboard.peak_load_analysis_subtitle'.tr(),
            style: AppTextStyles.bodySmall.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _peakDonut() {
    return Column(
      children: [
        Text(
          'statistics_dashboard.production_peak'.tr(),
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 0.47,
                strokeWidth: 10,
                backgroundColor: const Color(0xFFFFC107).withOpacity(0.4),
                valueColor: const AlwaysStoppedAnimation<Color>(_accentBlue),
              ),
              Text(
                '47%',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'statistics_dashboard.last_peak_detail'.tr(),
          style: AppTextStyles.bodySmall.copyWith(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _peakChartAndList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 80,
          child: CustomPaint(
            size: const Size(double.infinity, 80),
            painter: _SimpleLineChartPainter(),
          ),
        ),
        const SizedBox(height: 12),
        _summaryItem('statistics_dashboard.peak_as_forecast'.tr()),
        _summaryItem('statistics_dashboard.according_to_calculation'.tr()),
        _summaryItem('statistics_dashboard.normalized_as_planned'.tr()),
      ],
    );
  }

  Widget _buildHandlungsempfehlung(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'statistics_dashboard.recommendation_title'.tr(),
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            return isNarrow
                ? Column(
                    children: [
                      _waterWarehouseCard(),
                      const SizedBox(height: 16),
                      _consumptionIncreaseCard(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _waterWarehouseCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _consumptionIncreaseCard()),
                    ],
                  );
          },
        ),
        const SizedBox(height: 16),
        _waterMeterDetailBox(),
        const SizedBox(height: 16),
        _summaryItem('statistics_dashboard.targets_covered'.tr()),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'statistics_dashboard.savings_potential'.tr(),
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'statistics_dashboard.device_malfunction_risk'.tr(),
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            PrimaryOutlineButton(
              label: 'statistics_dashboard.request_check'.tr(),
              width: 180,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            PrimaryOutlineButton(
              label: 'statistics_dashboard.observe_for_now'.tr(),
              width: 180,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: () {},
            child: Text(
              'statistics_dashboard.hide_anomaly_future'.tr(),
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.black54,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _waterWarehouseCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            'statistics_dashboard.water_warehouse'.tr(),
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.86,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFFFC107).withOpacity(0.4),
                  valueColor: const AlwaysStoppedAnimation<Color>(_accentBlue),
                ),
                Text(
                  '14%',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'statistics_dashboard.warehouse_water_increase'.tr(),
            style: AppTextStyles.bodySmall.copyWith(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _consumptionIncreaseCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            '14%',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: _accentBlue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accentGreen.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('statistics_dashboard.average'.tr(), style: AppTextStyles.labelSmall),
                  Text('20%', style: AppTextStyles.labelSmall),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accentGreen.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('statistics_dashboard.now'.tr(), style: AppTextStyles.labelSmall),
                  Text('24%', style: AppTextStyles.labelSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'statistics_dashboard.sudden_increase_since'.tr(),
            style: AppTextStyles.bodySmall.copyWith(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _waterMeterDetailBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[350]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.water_drop_outlined, size: 32, color: _accentBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'statistics_dashboard.water_meter_warehouse'.tr(),
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'statistics_dashboard.meter_number'.tr(),
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.black54),
                ),
                Text(
                  'statistics_dashboard.ground_floor_reception'.tr(),
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'statistics_dashboard.active'.tr(),
              style: AppTextStyles.labelSmall.copyWith(
                color: _accentGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'statistics_dashboard.thanks_goodbye'.tr(namedArgs: {'name': name}),
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {},
          child: Text(
            'statistics_dashboard.request_interval_change'.tr(),
            style: AppTextStyles.bodyMedium.copyWith(
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
}

class _SimpleLineChartPainter extends CustomPainter {
  static const _green = Color(0xFF2E7D32);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _green.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(0, h * 0.7);
    path.quadraticBezierTo(w * 0.25, h * 0.3, w * 0.5, h * 0.5);
    path.quadraticBezierTo(w * 0.75, h * 0.2, w, h * 0.4);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
