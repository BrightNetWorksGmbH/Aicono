import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/report_detail_content.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_detail_bloc.dart';

/// Main view content when a report is selected. Shows report detail from API.
/// [recipients] come from the building report list and can be passed to show who receives this report.
class ReportDetailView extends StatelessWidget {
  final String? reportId;
  final List<ReportRecipientEntity> recipients;

  static const double _spacingBlock = 24.0;

  const ReportDetailView({
    super.key,
    this.reportId,
    this.recipients = const [],
  });

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
            return SingleChildScrollView(
              child: ReportDetailContent(
                detail: state.detail,
                recipients: recipientsList,
                showDatePicker: true,
                reportId: currentReportId,
                onDateRangeSelected: (start, end) {
                  context.read<ReportDetailBloc>().add(
                    ReportDetailRequested(
                      currentReportId,
                      startDate: start,
                      endDate: end,
                    ),
                  );
                },
              ),
            );
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
            SizedBox(height: _spacingBlock),
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
            SizedBox(height: _spacingBlock),
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
            SizedBox(height: _spacingBlock),
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
}
