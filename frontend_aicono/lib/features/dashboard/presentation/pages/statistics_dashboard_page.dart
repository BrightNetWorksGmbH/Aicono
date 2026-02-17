import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/report_detail_content.dart';
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

  /// Recipient name passed from view-report page when user proceeds.
  final String? recipientName;

  const StatisticsDashboardPage({
    super.key,
    this.token,
    this.tokenInfo,
    this.verseId,
    this.userName,
    this.recipientName,
  });

  @override
  Widget build(BuildContext context) {
    final name = recipientName?.trim().isNotEmpty == true
        ? recipientName!
        : (tokenInfo?.recipient.name.trim().isNotEmpty == true
              ? tokenInfo!.recipient.name
              : (tokenInfo?.recipient.email.trim().isNotEmpty == true
                    ? tokenInfo!.recipient.email
                    : (userName?.trim().isNotEmpty == true
                          ? userName!
                          : 'Stephan')));

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

  String _getIntervalTranslationKey(String interval) {
    final lower = interval.toLowerCase();
    if (lower.contains('daily') || lower == 'day') {
      return 'statistics_dashboard.reporting_interval_daily';
    }
    if (lower.contains('weekly') || lower == 'week') {
      return 'statistics_dashboard.reporting_interval_weekly';
    }
    if (lower.contains('monthly') || lower == 'month') {
      return 'statistics_dashboard.reporting_interval_monthly';
    }
    return 'statistics_dashboard.reporting_interval_daily';
  }

  Widget _buildReportContent(BuildContext context, ReportDetailEntity report) {
    final intervalKey = _getIntervalTranslationKey(report.reporting.interval);
    final intervalLabel = intervalKey.tr();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(context, report, intervalLabel),
          const SizedBox(height: 28),
          ReportDetailContent(
            detail: report,
            recipients: const [],
            showDatePicker: false,
            dateFormatPattern: 'd MMM yyyy',
            periodWithoutBorder: true,
          ),
          if (token != null) ...[
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => context.go('/view-report?token=$token'),
                child: Text(
                  'statistics_dashboard.back_to_report'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(
    BuildContext context,
    ReportDetailEntity report,
    String intervalLabel,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 24),
            Text(
              'statistics_dashboard.dear_name'.tr(
                namedArgs: {'name': userName},
              ),
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'statistics_dashboard.reporting_label'.tr(
                namedArgs: {'interval': intervalLabel},
              ),
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            // Text(
            //   report.reporting.name,
            //   style: AppTextStyles.bodyLarge.copyWith(color: Colors.grey[700]),
            // ),
          ],
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
