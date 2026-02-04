import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:go_router/go_router.dart';

/// Confirmation page after sending an invite.
/// Shows authenticated user's name and uses translations.
class CompleteUserInvitePage extends StatefulWidget {
  final String? invitedUserName;
  final String? inviterName;

  const CompleteUserInvitePage({
    super.key,
    this.invitedUserName,
    this.inviterName,
  });

  @override
  State<CompleteUserInvitePage> createState() => _CompleteUserInvitePageState();
}

class _CompleteUserInvitePageState extends State<CompleteUserInvitePage> {
  String? _userFirstName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final loginRepository = sl<LoginRepository>();
      final userResult = await loginRepository.getCurrentUser();

      userResult.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _userFirstName = 'invite_user.complete.inviter_fallback'.tr();
            });
          }
        },
        (user) {
          if (mounted && user != null) {
            setState(() {
              _userFirstName = user.firstName.isNotEmpty
                  ? user.firstName
                  : 'invite_user.complete.inviter_fallback'.tr();
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _userFirstName = 'invite_user.complete.inviter_fallback'.tr();
        });
      }
    }
  }

  static void _dummyOnChanged(bool? _) {}

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final effectiveInvited = widget.invitedUserName?.isNotEmpty == true
        ? widget.invitedUserName!
        : 'invite_user.complete.invited_user_fallback'.tr();
    final effectiveInviter = widget.inviterName?.isNotEmpty == true
        ? widget.inviterName!
        : (_userFirstName ?? 'invite_user.complete.inviter_fallback'.tr());

    void handleLanguageChanged() {
      setState(() {});
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
                                'invite_user.complete.greeting'.tr(
                                  namedArgs: {'name': effectiveInviter},
                                ),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'invite_user.complete.invitation_received'.tr(
                                  namedArgs: {'invitedName': effectiveInvited},
                                ),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  XCheckBox(
                                    value: true,
                                    onChanged: _dummyOnChanged,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'invite_user.complete.notification_hint'
                                          .tr(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              PrimaryOutlineButton(
                                label: 'invite_user.complete.to_dashboard'.tr(),
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
