import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

import 'dashboard_spacing.dart';

/// Single action link (underlined text) used in the "What do you need?" section.
class DashboardActionLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const DashboardActionLink({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: AppTextStyles.titleSmall.copyWith(
            color: AppTheme.primary,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

/// "What do you need?" section with links: Enter measurement data, Add building, Add site, Add branding.
class DashboardActionLinksSection extends StatelessWidget {
  final VoidCallback onEnterMeasurementData;
  final VoidCallback onAddBuilding;
  final VoidCallback onAddSite;
  final VoidCallback onAddBranding;

  const DashboardActionLinksSection({
    super.key,
    required this.onEnterMeasurementData,
    required this.onAddBuilding,
    required this.onAddSite,
    required this.onAddBranding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'dashboard.main_content.what_do_you_need'.tr(),
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.search, size: 20, color: Colors.grey[600]),
          ],
        ),
        SizedBox(height: DashboardSpacing.content),
        DashboardActionLink(
          text: 'dashboard.main_content.enter_measurement_data'.tr(),
          onTap: onEnterMeasurementData,
        ),
        SizedBox(height: DashboardSpacing.titleSubtitle),
        DashboardActionLink(
          text: 'dashboard.main_content.add_building'.tr(),
          onTap: onAddBuilding,
        ),
        SizedBox(height: DashboardSpacing.titleSubtitle),
        DashboardActionLink(
          text: 'dashboard.main_content.add_site'.tr(),
          onTap: onAddSite,
        ),
        SizedBox(height: DashboardSpacing.titleSubtitle),
        DashboardActionLink(
          text: 'dashboard.main_content.add_branding'.tr(),
          onTap: onAddBranding,
        ),
      ],
    );
  }
}
