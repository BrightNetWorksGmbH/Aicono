import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

import 'dashboard_spacing.dart';

/// Welcome block with greeting and subtitle.
class DashboardWelcomeSection extends StatelessWidget {
  final String userFirstName;

  const DashboardWelcomeSection({
    super.key,
    required this.userFirstName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.main_content.greeting'.tr(
            namedArgs: {'name': userFirstName},
          ),
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: DashboardSpacing.titleSubtitle),
        Text(
          'dashboard.main_content.welcome_back'.tr(),
          style: AppTextStyles.titleMedium.copyWith(
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
