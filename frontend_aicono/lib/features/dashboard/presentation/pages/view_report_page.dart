import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_token_info_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_token_info_bloc.dart';

/// Report access confirmation page shown when user opens report link from email.
/// Path: /view-report?token=...
/// Fetches token info (recipient, building, reporting) and displays real data.
/// Uses clean architecture: Bloc + UseCase + Repository.
class ViewReportPage extends StatelessWidget {
  final String token;

  const ViewReportPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          sl<ReportTokenInfoBloc>()..add(ReportTokenInfoRequested(token)),
      child: _ViewReportContent(token: token),
    );
  }
}

class _ViewReportContent extends StatefulWidget {
  final String token;

  const _ViewReportContent({required this.token});

  @override
  State<_ViewReportContent> createState() => _ViewReportContentState();
}

class _ViewReportContentState extends State<_ViewReportContent> {
  bool _confirmed = false;

  void _handleLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: screenSize.width,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          TopHeader(
                            onLanguageChanged: _handleLanguageChanged,
                            containerWidth: screenSize.width,
                          ),
                          const SizedBox(height: 36),
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child:
                                BlocBuilder<
                                  ReportTokenInfoBloc,
                                  ReportTokenInfoState
                                >(
                                  builder: (context, state) {
                                    if (state is ReportTokenInfoLoading) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 48.0,
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    if (state is ReportTokenInfoFailure) {
                                      return _buildErrorContent(
                                        context,
                                        state.message,
                                      );
                                    }
                                    if (state is ReportTokenInfoSuccess) {
                                      return _buildSuccessContent(
                                        context,
                                        state.info,
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AppFooter(
                  onLanguageChanged: _handleLanguageChanged,
                  containerWidth: screenSize.width,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent(BuildContext context, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[800]),
        ),
        const SizedBox(height: 24),
        PrimaryOutlineButton(
          label: 'common.retry'.tr(),
          onPressed: () {
            context.read<ReportTokenInfoBloc>().add(
              ReportTokenInfoRequested(widget.token),
            );
          },
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => _onClose(context),
          child: Text(
            'common.close'.tr(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey[700],
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent(
    BuildContext context,
    ReportTokenInfoEntity info,
  ) {
    final recipientName = info.recipient.name.trim().isNotEmpty
        ? info.recipient.name
        : info.recipient.email;
    final fullName = info.recipient.name;
    final companyName = info.building.name.trim().isNotEmpty
        ? info.building.name
        : 'view_report.company_fallback'.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 60),
        _buildGreeting(recipientName),
        const SizedBox(height: 36),
        GestureDetector(
          onTap: () => _onClose(context),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [Icon(Icons.close)],
          ),
        ),
        const SizedBox(height: 36),
        _buildDisclaimer(fullName, companyName),
        const SizedBox(height: 24),
        _buildCheckboxSection(recipientName),
        const SizedBox(height: 28),
        _buildCtaButton(context, info),
        const SizedBox(height: 28),
        _buildFooterLegal(),
        SizedBox(height: 60),
      ],
    );
  }

  Widget _buildGreeting(String recipientName) {
    return Text(
      'view_report.greeting'.tr(namedArgs: {'name': recipientName}),
      style: AppTextStyles.headlineSmall.copyWith(
        color: Colors.grey[800],
        fontWeight: FontWeight.bold,
        height: 1.35,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDisclaimer(String fullName, String companyName) {
    final lead = 'view_report.disclaimer_lead'.tr();
    final emphasis = 'view_report.disclaimer_emphasis'.tr();
    final body = 'view_report.disclaimer_body'.tr(
      namedArgs: {'fullName': fullName, 'companyName': companyName},
    );
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.grey[800],
          height: 1.5,
        ),
        children: [
          TextSpan(text: lead),
          TextSpan(
            text: emphasis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          TextSpan(text: body),
        ],
      ),
    );
  }

  Widget _buildCheckboxSection(String recipientName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        XCheckBox(
          value: _confirmed,
          onChanged: (value) => setState(() => _confirmed = value ?? false),
        ),
        const SizedBox(height: 12),
        Text(
          'view_report.checkbox_hint'.tr(namedArgs: {'name': recipientName}),
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.grey[700],
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCtaButton(BuildContext context, ReportTokenInfoEntity info) {
    final enabled = _confirmed;
    return SizedBox(
      width: double.infinity,
      child: PrimaryOutlineButton(
        label: 'view_report.button_text'.tr(),
        enabled: enabled,
        onPressed: enabled ? () => _onProceed(context, info) : null,
      ),
    );
  }

  Widget _buildFooterLegal() {
    return Text(
      'view_report.footer_legal'.tr(),
      style: AppTextStyles.labelSmall.copyWith(
        color: Colors.grey[600],
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  void _onClose(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  void _onProceed(BuildContext context, ReportTokenInfoEntity tokenInfo) {
    if (context.mounted) {
      final recipientName = tokenInfo.recipient.name.trim().isNotEmpty
          ? tokenInfo.recipient.name
          : tokenInfo.recipient.email.trim().isNotEmpty
          ? tokenInfo.recipient.email
          : '';
      context.pushNamed(
        Routelists.statistics,
        queryParameters: {
          'token': widget.token,
          'recipientName': recipientName,
        },
        extra: tokenInfo,
      );
    }
  }
}
