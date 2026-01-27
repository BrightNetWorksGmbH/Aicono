import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:go_router/go_router.dart';

/// Simple UI-only confirmation page after sending an invite.
class CompleteUserInvitePage extends StatelessWidget {
  final String? invitedUserName;
  final String? inviterName;

  const CompleteUserInvitePage({
    super.key,
    this.invitedUserName,
    this.inviterName,
  });

  static void _dummyOnChanged(bool? _) {}

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final effectiveInvited = invitedUserName?.isNotEmpty == true
        ? invitedUserName!
        : 'Stephan Tomat';
    final effectiveInviter =
        inviterName?.isNotEmpty == true ? inviterName! : 'Dirk';

    void handleLanguageChanged() {
      // No-op: page is stateless, but footer/top header expect a callback.
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Container(
            width: screenSize.width,
            color: AppTheme.primary,
            child: ListView(
              padding: const EdgeInsets.all(12.0),
              children: [
                // White card with confirmation content
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        TopHeader(
                          onLanguageChanged: handleLanguageChanged,
                          containerWidth: screenSize.width > 500
                              ? 500
                              : screenSize.width * 0.98,
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: screenSize.width < 600
                              ? screenSize.width * 0.95
                              : screenSize.width < 1200
                                  ? screenSize.width * 0.5
                                  : screenSize.width * 0.6,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () => context.pop(),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),
                              Text(
                                'Lieber $effectiveInviter,',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$effectiveInvited hat\nDeine Einladung erhalten.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  XCheckBox(
                                    value: true,
                                    onChanged: _dummyOnChanged,
                                  ),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Du wirst informiert, sobald er diese angenommen hat.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              PrimaryOutlineButton(
                                label: 'zum Dashboard',
                                width: 220,
                                onPressed: () {
                                  context.goNamed(Routelists.dashboard);
                                },
                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Footer on primary background (like dashboard)
                Container(
                  color: AppTheme.primary,
                  child: AppFooter(
                    onLanguageChanged: handleLanguageChanged,
                    containerWidth: screenSize.width > 500
                        ? 500
                        : screenSize.width,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

