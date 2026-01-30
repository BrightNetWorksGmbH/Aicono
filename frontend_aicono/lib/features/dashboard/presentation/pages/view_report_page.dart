import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';

/// Teal accent used for the report access confirmation card (matches design).
const Color _viewReportTeal = Color(0xFF009688);

/// Report access confirmation page shown when user opens report link from email.
/// Path: /view-report?token=...
/// Token is read from URL for later integration (validation, opening report).
class ViewReportPage extends StatefulWidget {
  final String token;

  const ViewReportPage({super.key, required this.token});

  @override
  State<ViewReportPage> createState() => _ViewReportPageState();
}

class _ViewReportPageState extends State<ViewReportPage> {
  bool _confirmed = false;

  void _handleLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder recipient/company – replace with decoded token or API later
    const recipientName = 'Stephan';
    const fullName = 'Stephan Tomat';
    const companyName = 'BrightNetWorks GmbH';

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
                      // border: Border.all(color: _viewReportTeal, width: 3),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildLogo(),
                                const SizedBox(height: 32),
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
                                _buildCtaButton(),
                                const SizedBox(height: 28),
                                _buildFooterLegal(),
                              ],
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

  Widget _buildLogo() {
    return Column(
      children: [
        Icon(Icons.trending_up, size: 40, color: Colors.black87),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: 'BRIGHT ',
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            children: [
              TextSpan(
                text: 'NETWORKS',
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
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

  Widget _buildCtaButton() {
    final enabled = _confirmed;
    return SizedBox(
      width: double.infinity,
      child: PrimaryOutlineButton(
        label: 'view_report.button_text'.tr(),
        enabled: enabled,
        onPressed: enabled ? () => _onProceed(context) : null,
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

  void _onProceed(BuildContext context) {
    if (context.mounted) {
      context.pushNamed(
        Routelists.statistics,
        queryParameters: {'token': widget.token},
      );
    }
  }
}
