import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    // Placeholder recipient/company – replace with decoded token or API later
    const recipientName = 'Stephan';
    const fullName = 'Stephan Tomat';
    const companyName = 'BrightNetWorks GmbH';

    return Scaffold(
      backgroundColor: const Color(0xFF37474F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _viewReportTeal, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          _buildLogo(),
                          const SizedBox(height: 32),
                          _buildGreeting(recipientName),
                          const SizedBox(height: 20),
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
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        onPressed: () => _onClose(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
      'Lieber $recipientName,\nDu bist fast da.',
      style: AppTextStyles.headlineSmall.copyWith(
        color: Colors.grey[800],
        fontWeight: FontWeight.bold,
        height: 1.35,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDisclaimer(String fullName, String companyName) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.grey[800],
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'Dieses Reporting ist '),
          TextSpan(
            text: 'ausschließlich',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          TextSpan(
            text:
                ' für $fullName,\nCEO der $companyName, bestimmt. Der Zugriff ist personalisiert und kann nur aus seiner Inbox heraus aktiviert werden. Bitte schließen Sie dieses Fenster sofort, wenn Sie nicht $fullName sind.',
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxSection(String recipientName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: () => setState(() => _confirmed = !_confirmed),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _viewReportTeal, width: 2),
              color: _confirmed ? _viewReportTeal : Colors.transparent,
            ),
            child: _confirmed
                ? const Icon(Icons.check, size: 20, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Lieber $recipientName, klicke auf die Box, um juristisch verbindlich Deine Identität gemäß § 126 BGB (elektronische Willenserklärung) zu bestätigen und das Reporting zu öffnen.',
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
      child: OutlinedButton(
        onPressed: enabled ? () => _onProceed(context) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: enabled ? _viewReportTeal : Colors.grey,
          side: BorderSide(
            color: enabled ? _viewReportTeal : Colors.grey[400]!,
            width: 2,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Alles klar, lass uns loslegen!',
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: enabled ? _viewReportTeal : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLegal() {
    return Text(
      'Durch das Öffnen dieses Dokuments bestätigst Du gemäß § 126 BGB, dass Du die autorisierte Empfängerperson bist und diese elektronische Übermittlung als rechtsverbindlich anerkennst. Die Weitergabe oder Vervielfältigung des Inhalts ist ohne ausdrückliche Zustimmung der BrightNetWorks GmbH untersagt.',
      style: AppTextStyles.labelSmall.copyWith(
        color: Colors.grey[600],
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  void _onClose(BuildContext context) {
    // Dismiss or go back; when not in app flow, can go to login or external close
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  void _onProceed(BuildContext context) {
    // Token is available as widget.token for later integration (e.g. validate and open report)
    // For now just keep on same page or navigate to login/dashboard as placeholder
    // TODO: validate token and open report content
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Token wird verarbeitet (Integration folgt). Token-Länge: ${widget.token.length}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
