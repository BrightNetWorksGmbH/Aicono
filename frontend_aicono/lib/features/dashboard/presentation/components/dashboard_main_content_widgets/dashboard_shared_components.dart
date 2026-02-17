import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend_aicono/core/utils/locale_number_format.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

import 'dashboard_spacing.dart';

// Asset paths for property/sensor icons (re-exported for callers that need them)
const String assetBuilding = 'assets/images/Building.svg';
const String assetFloor = 'assets/images/Floor.svg';
const String assetRoom = 'assets/images/Room.svg';
const String assetSensor = 'assets/images/Sensor.svg';

Widget buildDashboardSvgIcon(String asset, {Color? color, double size = 22}) {
  return Center(
    child: SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    ),
  );
}

Widget buildDashboardCard({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.zero,
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: child,
  );
}

const Color _metricIconTeal = Color(0xFF00897B);

Widget buildPropertyMetricCard({
  required String label,
  required String value,
  required Widget icon,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.zero,
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 22,
                ),
              ),
              SizedBox(height: DashboardSpacing.tight),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _metricIconTeal.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: icon,
        ),
      ],
    ),
  );
}

Widget buildKpiMetricCard({
  required String label,
  required String value,
  required Color indicatorColor,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.zero,
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 22,
                ),
              ),
              SizedBox(height: DashboardSpacing.tight),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  );
}

Widget buildAnalyticsMetricCard({
  required String title,
  required List<({String label, String value})> rows,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.zero,
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: DashboardSpacing.titleSubtitle),
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: DashboardSpacing.tight),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rows[i].label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                rows[i].value,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

String formatDashboardNum(Locale locale, dynamic value) {
  return LocaleNumberFormat.formatDecimal(
    value,
    locale: locale,
    decimalDigits: 3,
    fallback: '–',
  );
}

Widget buildBreakdownRow(String label, dynamic value, Locale locale) {
  final valueStr = value is num
      ? LocaleNumberFormat.formatNum(value, locale: locale, decimalDigits: 3)
      : value?.toString() ?? '–';
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(color: Colors.grey[600]),
        ),
        Text(
          valueStr,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    ),
  );
}

Widget dashboardTableCell(
  String text,
  EdgeInsets padding, {
  bool isHeader = false,
  bool alignLeft = false,
  bool isBold = false,
}) {
  return Padding(
    padding: padding,
    child: Align(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        style: isHeader
            ? AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              )
            : AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[800],
                fontWeight: isBold ? FontWeight.w600 : null,
              ),
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
      ),
    ),
  );
}
