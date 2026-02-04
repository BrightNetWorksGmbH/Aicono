import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';

class JoinSwitchAlmostComponent extends StatelessWidget {
  final InvitationEntity invitation;
  final VoidCallback onJoinPressed;
  final bool joining;

  const JoinSwitchAlmostComponent({
    super.key,
    required this.invitation,
    required this.onJoinPressed,
    this.joining = false,
  });

  @override
  Widget build(BuildContext context) {
    final orgName = invitation.organizationName?.isNotEmpty == true
        ? invitation.organizationName!
        : 'Bryteswitch';

    final inviterDisplay =
        (invitation.invitedByName != null &&
            invitation.invitedByName!.trim().isNotEmpty)
        ? invitation.invitedByName!.trim()
        : (invitation.invitedByEmail != null &&
              invitation.invitedByEmail!.trim().isNotEmpty)
        ? invitation.invitedByEmail!.trim()
        : '';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Text(
            'join_invite.almost.headline'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineMedium.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'join_invite.almost.invited_to_switch'.tr(
              namedArgs: {'organization': orgName},
            ),
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (invitation.firstName.isNotEmpty || invitation.lastName.isNotEmpty)
            Text(
              'join_invite.almost.welcome_user'.tr(
                namedArgs: {
                  'name': '${invitation.firstName} ${invitation.lastName}'
                      .trim(),
                },
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          const SizedBox(height: 8),
          if (inviterDisplay.isNotEmpty)
            Text(
              'join_invite.almost.invited_by'.tr(
                namedArgs: {'name': inviterDisplay},
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[700]),
            ),
          const SizedBox(height: 24),
          // Text(
          //   'join_invite.almost.role_title'.tr(),
          //   style: AppTextStyles.titleSmall.copyWith(
          //     fontWeight: FontWeight.w700,
          //   ),
          // ),
          const SizedBox(height: 8),
          // Text(
          //   invitation.position.isNotEmpty
          //       ? invitation.position
          //       : 'join_invite.almost.role_fallback'.tr(
          //           namedArgs: {'roleId': invitation.roleId},
          //         ),
          //   style: AppTextStyles.bodySmall,
          // ),
          const SizedBox(height: 12),
          Text(
            'join_invite.almost.permissions_hint'.tr(),
            style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 32),
          PrimaryOutlineButton(
            label: 'join_invite.almost.join_button'.tr(),
            loading: joining,
            enabled: !joining,
            width: double.infinity,
            onPressed: joining ? null : onJoinPressed,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
