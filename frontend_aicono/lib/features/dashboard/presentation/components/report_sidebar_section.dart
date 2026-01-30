import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_building_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_site_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_buildings_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/building_reports_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_item_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_view_widget.dart';

/// Sidebar section for Reports: Sites → Buildings → Reports.
/// Tapping a report calls [onReportSelected].
class ReportSidebarSection extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;

  const ReportSidebarSection({super.key, this.onReportSelected});

  @override
  State<ReportSidebarSection> createState() => _ReportSidebarSectionState();
}

class _ReportSidebarSectionState extends State<ReportSidebarSection> {
  String? _selectedSiteId;
  String? _selectedBuildingId;

  @override
  void initState() {
    super.initState();
    context.read<ReportSitesBloc>().add(ReportSitesRequested());
  }

  List<TreeItemEntity> _buildTreeItems({
    required List<ReportSiteEntity> sites,
    required String? buildingsSiteId,
    required List<ReportBuildingEntity> buildings,
    required String? reportsBuildingId,
    required List<ReportSummaryEntity> reports,
  }) {
    return sites.map((site) {
      final bool showBuildings = buildingsSiteId == site.id;
      List<TreeItemEntity> buildingChildren = [];
      if (showBuildings) {
        if (buildings.isEmpty) {
          buildingChildren = [
            TreeItemEntity(
              id: '_loading_site',
              name: 'Loading...',
              type: 'reporting',
            ),
          ];
        } else {
          buildingChildren = buildings.map((building) {
            final bool showReports = reportsBuildingId == building.id;
            List<TreeItemEntity> reportChildren = [];
            if (showReports) {
              if (reports.isEmpty) {
                reportChildren = [
                  TreeItemEntity(
                    id: '_loading_reports',
                    name: 'Loading...',
                    type: 'reporting',
                  ),
                ];
              } else {
                reportChildren = reports
                    .map(
                      (r) => TreeItemEntity(
                        id: r.reportId,
                        name: r.reportName,
                        type: 'reporting',
                      ),
                    )
                    .toList();
              }
            }
            return TreeItemEntity(
              id: building.id,
              name: building.name,
              type: 'reporting',
              children: reportChildren,
            );
          }).toList();
        }
      }
      return TreeItemEntity(
        id: site.id,
        name: site.name,
        type: 'reporting',
        children: buildingChildren,
      );
    }).toList();
  }

  void _handleItemTap(TreeItemEntity item) {
    if (item.id.startsWith('_loading')) return;

    final reportSitesState = context.read<ReportSitesBloc>().state;
    final reportBuildingsState = context.read<ReportBuildingsBloc>().state;
    final buildingReportsState = context.read<BuildingReportsBloc>().state;

    final bool isSite =
        reportSitesState is ReportSitesSuccess &&
        reportSitesState.sites.any((s) => s.id == item.id);
    final bool isBuilding =
        reportBuildingsState is ReportBuildingsSuccess &&
        reportBuildingsState.buildings.any((b) => b.id == item.id);
    final bool isReport =
        buildingReportsState is BuildingReportsSuccess &&
        buildingReportsState.reports.any((r) => r.reportId == item.id);

    if (isSite) {
      setState(() {
        _selectedSiteId = item.id;
        _selectedBuildingId = null;
      });
      context.read<ReportBuildingsBloc>().add(
        ReportBuildingsRequested(item.id),
      );
      context.read<BuildingReportsBloc>().add(BuildingReportsReset());
      return;
    }
    if (isBuilding) {
      setState(() => _selectedBuildingId = item.id);
      context.read<BuildingReportsBloc>().add(
        BuildingReportsRequested(item.id),
      );
      return;
    }
    if (isReport && widget.onReportSelected != null) {
      widget.onReportSelected!(item.id);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportSitesBloc, ReportSitesState>(
      builder: (context, sitesState) {
        return BlocBuilder<ReportBuildingsBloc, ReportBuildingsState>(
          builder: (context, buildingsState) {
            return BlocBuilder<BuildingReportsBloc, BuildingReportsState>(
              builder: (context, reportsState) {
                List<ReportSiteEntity> sites = [];
                if (sitesState is ReportSitesSuccess) {
                  sites = sitesState.sites;
                }
                List<ReportBuildingEntity> buildings = [];
                String? buildingsSiteId;
                if (buildingsState is ReportBuildingsSuccess) {
                  buildings = buildingsState.buildings;
                  buildingsSiteId = buildingsState.siteId;
                } else if (buildingsState is ReportBuildingsLoading) {
                  buildingsSiteId = buildingsState.siteId;
                }
                List<ReportSummaryEntity> reports = [];
                String? reportsBuildingId;
                if (reportsState is BuildingReportsSuccess) {
                  reports = reportsState.reports;
                  reportsBuildingId = reportsState.buildingId;
                } else if (reportsState is BuildingReportsLoading) {
                  reportsBuildingId = reportsState.buildingId;
                }

                if (sitesState is ReportSitesLoading && sites.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Loading report sites...',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }
                if (sitesState is ReportSitesFailure) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      sitesState.message,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: Colors.red[600],
                      ),
                    ),
                  );
                }

                final items = _buildTreeItems(
                  sites: sites,
                  buildingsSiteId: buildingsSiteId ?? _selectedSiteId,
                  buildings: buildings,
                  reportsBuildingId: reportsBuildingId ?? _selectedBuildingId,
                  reports: reports,
                );

                return TreeViewWidget(
                  items: items,
                  autoExpandItemId: _selectedSiteId,
                  onItemTap: _handleItemTap,
                  onAddItem: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'dashboard.sidebar.add_reporting'.tr() +
                              ' ' +
                              'dashboard.main_content.coming_soon'.tr(),
                        ),
                      ),
                    );
                  },
                  addItemLabel: 'dashboard.sidebar.add_reporting'.tr(),
                );
              },
            );
          },
        );
      },
    );
  }
}
