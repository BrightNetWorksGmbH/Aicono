import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/utils/locale_number_format.dart';

import 'dashboard_spacing.dart';
import 'dashboard_shared_components.dart';

enum PropertyOverviewMenuAction { edit, delete }

/// Overview block: title, optional address, optional edit/delete menu, optional filter, metric cards grid.
class DashboardPropertyOverviewSection extends StatelessWidget {
  final String title;
  final String? address;
  final List<Widget> metricCards;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget? filter;

  const DashboardPropertyOverviewSection({
    super.key,
    required this.title,
    this.address,
    required this.metricCards,
    this.onEdit,
    this.onDelete,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (address != null && address!.isNotEmpty) ...[
                    SizedBox(height: DashboardSpacing.titleSubtitle),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address!,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<PropertyOverviewMenuAction>(
                icon: const Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                color: Colors.white,
                onSelected: (action) {
                  switch (action) {
                    case PropertyOverviewMenuAction.edit:
                      onEdit?.call();
                      break;
                    case PropertyOverviewMenuAction.delete:
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem<PropertyOverviewMenuAction>(
                      value: PropertyOverviewMenuAction.edit,
                      child: Text('Edit'),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem<PropertyOverviewMenuAction>(
                      value: PropertyOverviewMenuAction.delete,
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (filter != null) ...[
          SizedBox(height: DashboardSpacing.content),
          filter!,
          SizedBox(height: DashboardSpacing.content),
          Divider(
            color: Colors.grey[300],
            thickness: 0.7,
            height: 0,
          ),
        ],
        SizedBox(height: DashboardSpacing.content),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            if (isNarrow) {
              return Wrap(
                spacing: DashboardSpacing.cardGap,
                runSpacing: DashboardSpacing.cardGap,
                children: metricCards
                    .map(
                      (w) => SizedBox(
                        width: (constraints.maxWidth - DashboardSpacing.cardGap) / 2,
                        child: w,
                      ),
                    )
                    .toList(),
              );
            }
            return Row(
              children: [
                for (int i = 0; i < metricCards.length; i++) ...[
                  if (i > 0) SizedBox(width: DashboardSpacing.cardGap),
                  Expanded(child: metricCards[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Data quality summary bar (percentage + status message).
class DashboardPropertyDataQualitySummary extends StatelessWidget {
  final dynamic kpis;
  final Locale locale;

  const DashboardPropertyDataQualitySummary({
    super.key,
    required this.kpis,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final int quality = (kpis.averageQuality is int)
        ? kpis.averageQuality as int
        : int.tryParse('${kpis.averageQuality}') ?? 0;
    final bool warning = kpis.dataQualityWarning == true;
    final String qualityStr =
        LocaleNumberFormat.formatInt(quality, locale: locale);

    final String statusLabel = warning ? 'Needs attention' : 'Excellent';
    final String message = warning
        ? 'Data quality needs review'
        : 'Data quality is good';

    final Color bgColor = warning ? Colors.orange[50]! : Colors.green[50]!;
    final Color borderColor =
        warning ? Colors.orange[200]! : Colors.green[200]!;
    final Color iconColor = warning ? Colors.orange[700]! : Colors.green[700]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$qualityStr% data quality · $statusLabel',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// KPI section: title, subtitle, and 4 cards (Total, Peak, Average, Base).
class DashboardPropertyKpiSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final dynamic kpis;
  final Locale locale;

  const DashboardPropertyKpiSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.kpis,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    if (kpis == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: DashboardSpacing.titleSubtitle),
        Text(
          subtitle,
          style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
        ),
        SizedBox(height: DashboardSpacing.content),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            if (isNarrow) {
              return Wrap(
                spacing: DashboardSpacing.cardGap,
                runSpacing: DashboardSpacing.cardGap,
                children: [
                  SizedBox(
                    width: (constraints.maxWidth - DashboardSpacing.cardGap) / 2,
                    child: buildKpiMetricCard(
                      label: 'Total',
                      value: LocaleNumberFormat.formatDecimal(
                        kpis.totalConsumption,
                        locale: locale,
                      ),
                      indicatorColor: const Color(0xFF64B5F6),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: buildKpiMetricCard(
                      label: 'Peak',
                      value: LocaleNumberFormat.formatDecimal(
                        kpis.peak,
                        locale: locale,
                      ),
                      indicatorColor: const Color(0xFFFFB74D),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: buildKpiMetricCard(
                      label: 'Average',
                      value: LocaleNumberFormat.formatDecimal(
                        kpis.average,
                        locale: locale,
                      ),
                      indicatorColor: const Color(0xFFFFEE58),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: buildKpiMetricCard(
                      label: 'Base',
                      value: LocaleNumberFormat.formatDecimal(
                        kpis.base,
                        locale: locale,
                      ),
                      indicatorColor: Colors.grey[400]!,
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: buildKpiMetricCard(
                    label: 'Total',
                    value: LocaleNumberFormat.formatDecimal(
                      kpis.totalConsumption,
                      locale: locale,
                    ),
                    indicatorColor: const Color(0xFF64B5F6),
                  ),
                ),
                SizedBox(width: DashboardSpacing.cardGap),
                Expanded(
                  child: buildKpiMetricCard(
                    label: 'Peak',
                    value: LocaleNumberFormat.formatDecimal(
                      kpis.peak,
                      locale: locale,
                    ),
                    indicatorColor: const Color(0xFFFFB74D),
                  ),
                ),
                SizedBox(width: DashboardSpacing.cardGap),
                Expanded(
                  child: buildKpiMetricCard(
                    label: 'Average',
                    value: LocaleNumberFormat.formatDecimal(
                      kpis.average,
                      locale: locale,
                    ),
                    indicatorColor: const Color(0xFFFFEE58),
                  ),
                ),
                SizedBox(width: DashboardSpacing.cardGap),
                Expanded(
                  child: buildKpiMetricCard(
                    label: 'Base',
                    value: LocaleNumberFormat.formatDecimal(
                      kpis.base,
                      locale: locale,
                    ),
                    indicatorColor: Colors.grey[400]!,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
