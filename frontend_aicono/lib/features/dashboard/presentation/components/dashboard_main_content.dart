import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/utils/locale_number_format.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_details_filter.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/weekday_weekend_cylinder_chart.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/anomalies_detail_dialog.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/switch_role_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_building_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_floor_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/building_reports_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/report_detail_view.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_building_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';

import '../../../../core/routing/routeLists.dart';
import 'dashboard_main_content_widgets/dashboard_main_content_widgets.dart';

class DashboardMainContent extends StatefulWidget {
  final String? verseId;
  final User? user;
  final String? selectedReportId;
  final DashboardDetailsFilter? dashboardFilter;
  final void Function(DateTime start, DateTime end)?
  onDashboardDateRangeChanged;

  const DashboardMainContent({
    super.key,
    this.verseId,
    this.user,
    this.selectedReportId,
    this.dashboardFilter,
    this.onDashboardDateRangeChanged,
  });

  @override
  State<DashboardMainContent> createState() => _DashboardMainContentState();
}

class _DashboardMainContentState extends State<DashboardMainContent> {
  String? _userFirstName;
  String? _userName; // Full name for navigation
  List<SwitchRoleEntity> _switches = [];

  // Consistent spacing constants for the dashboard UI
  static const double _spacingBlock = 24.0; // Between main content blocks
  static const double _spacingSection = 24.0; // Between sections within a block
  static const double _spacingContent = 16.0; // After header, before content
  static const double _spacingTitleSubtitle = 8.0; // Between title and subtitle
  static const double _spacingTight = 4.0; // Value to label in metric cards
  static const double _spacingCardGap = 12.0; // Between cards, list items
  static const Color _metricIconTeal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _applyUser(widget.user);
    if (widget.user == null) {
      _loadUserData();
    }
  }

  @override
  void didUpdateWidget(DashboardMainContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _applyUser(widget.user);
      if (widget.user == null) {
        _loadUserData();
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _applyUser(User? user) {
    if (user == null) return;
    if (mounted) {
      setState(() {
        _userFirstName = user.firstName.isNotEmpty ? user.firstName : 'User';
        final firstName = user.firstName.isNotEmpty ? user.firstName : '';
        final lastName = user.lastName.isNotEmpty ? user.lastName : '';
        _userName = '$firstName $lastName'.trim();
        if (_userName!.isEmpty) {
          _userName = 'User';
        }
        _switches = user.roles;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final loginRepository = sl<LoginRepository>();
      final userResult = await loginRepository.getCurrentUser();

      userResult.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _userFirstName = 'User';
              _userName = 'User';
              _switches = [];
            });
          }
        },
        (user) {
          if (mounted && user != null) {
            _applyUser(user);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _userFirstName = 'User';
          _userName = 'User';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedReportId != null &&
        widget.selectedReportId!.isNotEmpty) {
      return BlocBuilder<BuildingReportsBloc, BuildingReportsState>(
        builder: (context, reportsState) {
          List<ReportRecipientEntity> recipients = [];
          if (reportsState is BuildingReportsSuccess) {
            final matches = reportsState.reports
                .where((r) => r.reportId == widget.selectedReportId)
                .toList();
            if (matches.isNotEmpty) {
              recipients = matches.first.recipients;
            }
          }
          return ReportDetailView(
            reportId: widget.selectedReportId,
            recipients: recipients,
          );
        },
      );
    }

    return BlocBuilder<DashboardSiteDetailsBloc, DashboardSiteDetailsState>(
      builder: (context, siteState) {
        return BlocBuilder<
          DashboardBuildingDetailsBloc,
          DashboardBuildingDetailsState
        >(
          builder: (context, buildingState) {
            return BlocBuilder<
              DashboardFloorDetailsBloc,
              DashboardFloorDetailsState
            >(
              builder: (context, floorState) {
                return BlocBuilder<
                  DashboardRoomDetailsBloc,
                  DashboardRoomDetailsState
                >(
                  builder: (context, roomState) {
                    final hasPropertySelection = _hasPropertySelection(
                      siteState,
                      buildingState,
                      floorState,
                      roomState,
                    );
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!hasPropertySelection) ...[
                            DashboardWelcomeSection(
                              userFirstName: _userFirstName ?? 'User',
                            ),
                            SizedBox(height: _spacingBlock),
                          ],
                          // Selected Item Details (Site/Building/Floor/Room)
                          _buildSelectedItemDetails(),
                          SizedBox(height: _spacingBlock),
                          // Trigger Manual Report Button
                          const DashboardTriggerManualReportButton(),
                          SizedBox(height: _spacingBlock),
                          // "Was brauchst Du gerade?" Section
                          DashboardActionLinksSection(
                            onEnterMeasurementData: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'dashboard.main_content.enter_measurement_data'
                                            .tr() +
                                        ' ' +
                                        'dashboard.main_content.coming_soon'
                                            .tr(),
                                  ),
                                ),
                              );
                            },
                            onAddBuilding: _showSiteSelectionDialog,
                            onAddSite: _showSwitchSelectionDialog,
                            onAddBranding: () {
                              final switchId =
                                  widget.verseId ??
                                  sl<LocalStorage>().getSelectedVerseId();
                              if (switchId != null && switchId.isNotEmpty) {
                                context.pushNamed(
                                  Routelists.switchSettings,
                                  queryParameters: {'switchId': switchId},
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'switch_settings.no_switch_selected'.tr(),
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static String _toIso8601Param(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    return '${d.toIso8601String().split('.')[0]}Z';
  }

  void _refetchCurrentDetailWithDateRange(
    BuildContext context,
    DateTime start,
    DateTime end,
  ) {
    final filter = DashboardDetailsFilter(
      startDate: _toIso8601Param(start),
      endDate: _toIso8601Param(end),
    );
    final roomState = context.read<DashboardRoomDetailsBloc>().state;
    final floorState = context.read<DashboardFloorDetailsBloc>().state;
    final buildingState = context.read<DashboardBuildingDetailsBloc>().state;
    final siteState = context.read<DashboardSiteDetailsBloc>().state;
    if (roomState is DashboardRoomDetailsSuccess) {
      context.read<DashboardRoomDetailsBloc>().add(
        DashboardRoomDetailsRequested(roomId: roomState.roomId, filter: filter),
      );
      return;
    }
    if (floorState is DashboardFloorDetailsSuccess) {
      context.read<DashboardFloorDetailsBloc>().add(
        DashboardFloorDetailsRequested(
          floorId: floorState.floorId,
          filter: filter,
        ),
      );
      return;
    }
    if (buildingState is DashboardBuildingDetailsSuccess) {
      context.read<DashboardBuildingDetailsBloc>().add(
        DashboardBuildingDetailsRequested(
          buildingId: buildingState.buildingId,
          filter: filter,
        ),
      );
      return;
    }
    if (siteState is DashboardSiteDetailsSuccess) {
      context.read<DashboardSiteDetailsBloc>().add(
        DashboardSiteDetailsRequested(siteId: siteState.siteId, filter: filter),
      );
    }
  }

  void _onDateRangeChanged(BuildContext context, DateTime start, DateTime end) {
    widget.onDashboardDateRangeChanged?.call(start, end);
    _refetchCurrentDetailWithDateRange(context, start, end);
  }

  bool _hasPropertySelection(
    DashboardSiteDetailsState siteState,
    DashboardBuildingDetailsState buildingState,
    DashboardFloorDetailsState floorState,
    DashboardRoomDetailsState roomState,
  ) {
    return siteState is DashboardSiteDetailsLoading ||
        siteState is DashboardSiteDetailsSuccess ||
        siteState is DashboardSiteDetailsFailure ||
        buildingState is DashboardBuildingDetailsLoading ||
        buildingState is DashboardBuildingDetailsSuccess ||
        buildingState is DashboardBuildingDetailsFailure ||
        floorState is DashboardFloorDetailsLoading ||
        floorState is DashboardFloorDetailsSuccess ||
        floorState is DashboardFloorDetailsFailure ||
        roomState is DashboardRoomDetailsLoading ||
        roomState is DashboardRoomDetailsSuccess ||
        roomState is DashboardRoomDetailsFailure;
  }

  Widget _buildSelectedItemDetails() {
    return BlocBuilder<DashboardRoomDetailsBloc, DashboardRoomDetailsState>(
      builder: (context, roomState) {
        // Priority 1: Room details
        if (roomState is DashboardRoomDetailsLoading ||
            roomState is DashboardRoomDetailsSuccess ||
            roomState is DashboardRoomDetailsFailure) {
          return _buildRoomDetails(roomState);
        }

        // Check floor details
        return BlocBuilder<
          DashboardFloorDetailsBloc,
          DashboardFloorDetailsState
        >(
          builder: (context, floorState) {
            // Priority 2: Floor details
            if (floorState is DashboardFloorDetailsLoading ||
                floorState is DashboardFloorDetailsSuccess ||
                floorState is DashboardFloorDetailsFailure) {
              return _buildFloorDetails(floorState);
            }

            // Check building details
            return BlocBuilder<
              DashboardBuildingDetailsBloc,
              DashboardBuildingDetailsState
            >(
              builder: (context, buildingState) {
                // Priority 3: Building details
                if (buildingState is DashboardBuildingDetailsLoading ||
                    buildingState is DashboardBuildingDetailsSuccess ||
                    buildingState is DashboardBuildingDetailsFailure) {
                  return _buildBuildingDetails(buildingState);
                }

                // Check site details
                return BlocBuilder<
                  DashboardSiteDetailsBloc,
                  DashboardSiteDetailsState
                >(
                  builder: (context, siteState) {
                    // Priority 4: Site details
                    if (siteState is DashboardSiteDetailsLoading ||
                        siteState is DashboardSiteDetailsSuccess ||
                        siteState is DashboardSiteDetailsFailure) {
                      return _buildSiteDetails();
                    }

                    // Default: show sites loading/error or empty state
                    return BlocBuilder<DashboardSitesBloc, DashboardSitesState>(
                      builder: (context, sitesState) {
                        if (sitesState is DashboardSitesInitial ||
                            sitesState is DashboardSitesLoading) {
                          return buildDashboardCard(
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading sites...',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (sitesState is DashboardSitesFailure) {
                          return buildDashboardCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[600],
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    sitesState.message,
                                    style: AppTextStyles.titleSmall.copyWith(
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: () {
                                    context.read<DashboardSitesBloc>().add(
                                      DashboardSitesRequested(
                                        bryteswitchId: widget.verseId,
                                      ),
                                    );
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        }

                        if (sitesState is DashboardSitesSuccess) {
                          if (sitesState.sites.isEmpty) {
                            return buildDashboardCard(
                              child: Text(
                                'No sites found.',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: Colors.grey[700],
                                ),
                              ),
                            );
                          }

                          return buildDashboardCard(
                            child: Text(
                              'Select an item from the sidebar to view details.',
                              style: AppTextStyles.titleSmall.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSiteDetails() {
    return BlocBuilder<DashboardSiteDetailsBloc, DashboardSiteDetailsState>(
      builder: (context, state) {
        if (state is DashboardSiteDetailsInitial) {
          return Text(
            'Select a site to view details.',
            style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
          );
        }

        if (state is DashboardSiteDetailsLoading) {
          return Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading site details...',
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ],
          );
        }

        if (state is DashboardSiteDetailsFailure) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Colors.red[600], size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.message,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.red[700],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  context.read<DashboardSiteDetailsBloc>().add(
                    DashboardSiteDetailsRequested(
                      siteId: state.siteId,
                      filter: widget.dashboardFilter,
                    ),
                  );
                },
                child: const Text('Retry'),
              ),
            ],
          );
        }

        if (state is DashboardSiteDetailsSuccess) {
          final d = state.details;
          final kpis = d.kpis;
          final locale = context.locale;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardPropertyOverviewSection(
                title: d.name,
                address: d.address,
                onEdit: () {
                  context.pushNamed(
                    Routelists.editSite,
                    queryParameters: {'siteId': state.siteId},
                  );
                },
                onDelete: () async {
                  await _handleDeleteSite(state.siteId);
                },
                metricCards: [
                  buildPropertyMetricCard(
                    label: 'Buildings',
                    value: LocaleNumberFormat.formatInt(
                      d.buildingCount,
                      locale: locale,
                    ),
                    icon: buildDashboardSvgIcon(
                      assetBuilding,
                      color: _metricIconTeal,
                    ),
                  ),
                  buildPropertyMetricCard(
                    label: 'Rooms',
                    value: LocaleNumberFormat.formatInt(
                      d.totalRooms,
                      locale: locale,
                    ),
                    icon: buildDashboardSvgIcon(
                      assetRoom,
                      color: _metricIconTeal,
                    ),
                  ),
                  buildPropertyMetricCard(
                    label: 'Sensors',
                    value: LocaleNumberFormat.formatInt(
                      d.totalSensors,
                      locale: locale,
                    ),
                    icon: buildDashboardSvgIcon(
                      assetSensor,
                      color: _metricIconTeal,
                      size: 20,
                    ),
                  ),
                  buildPropertyMetricCard(
                    label: 'Floors',
                    value: LocaleNumberFormat.formatInt(
                      d.totalFloors,
                      locale: locale,
                    ),
                    icon: buildDashboardSvgIcon(
                      assetFloor,
                      color: _metricIconTeal,
                    ),
                  ),
                ],
                filter: DashboardPeriodHeader(
                  timeRange: d.timeRange,
                  onDateRangeChanged: widget.onDashboardDateRangeChanged != null
                      ? (s, e) => _onDateRangeChanged(context, s, e)
                      : null,
                ),
              ),
              if (kpis != null) ...[
                SizedBox(height: _spacingSection),
                DashboardPropertyKpiSection(
                  title: 'Site KPIs',
                  subtitle:
                      'Aggregate energy performance and load metrics for the current period. ${kpis.unit}',
                  kpis: kpis,
                  locale: locale,
                ),
              ],
              SizedBox(height: _spacingSection),
              Text(
                'Buildings',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: _spacingTitleSubtitle),
              Text(
                'Select a building from the sidebar to view details.',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: _spacingContent),
              if (d.buildings.isEmpty)
                Text(
                  'No buildings for this site yet.',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.grey[700],
                  ),
                )
              else
                Column(
                  children: d.buildings.map((b) {
                    final bk = b.kpis;
                    final subtitle = bk == null
                        ? 'No KPI data'
                        : 'Total: ${LocaleNumberFormat.formatDecimal(bk.totalConsumption, locale: locale)} ${bk.unit}';
                    return DashboardPropertyListItem(
                      icon: buildDashboardSvgIcon(
                        assetBuilding,
                        color: _metricIconTeal,
                      ),
                      title: b.name,
                      subtitle:
                          '${LocaleNumberFormat.formatInt(b.floorCount, locale: locale)} floors · $subtitle',
                      trailing:
                          '${LocaleNumberFormat.formatInt(b.sensorCount, locale: locale)} sensors',
                      onEdit: () {
                        context.pushNamed(
                          Routelists.editBuilding,
                          queryParameters: {'buildingId': b.id},
                        );
                      },
                      onDelete: () => _handleDeleteBuilding(b.id),
                    );
                  }).toList(),
                ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRoomDetails(DashboardRoomDetailsState state) {
    if (state is DashboardRoomDetailsLoading) {
      return buildDashboardCard(
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading room details...',
              style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    if (state is DashboardRoomDetailsFailure) {
      return buildDashboardCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.message,
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.red[700],
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                context.read<DashboardRoomDetailsBloc>().add(
                  DashboardRoomDetailsRequested(
                    roomId: state.roomId,
                    filter: widget.dashboardFilter,
                  ),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state is DashboardRoomDetailsSuccess) {
      final d = state.details;
      final kpis = d.kpis;
      final locale = context.locale;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardPropertyOverviewSection(
            title: d.name,
            address: d.loxoneRoomId != null
                ? 'Loxone: ${d.loxoneRoomId!.name}'
                : null,
            // onEdit: () {
            //   context.pushNamed(
            //     Routelists.editRoom,
            //     queryParameters: {'roomId': state.roomId},
            //   );
            // },
            // onDelete: () async {
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     SnackBar(
            //       content: Text(
            //         'Delete functionality is available when you edit the floor',
            //       ),
            //       backgroundColor: Colors.red,
            //     ),
            //   );
            //   // await _handleDeleteRoom(state.roomId);
            // },
            metricCards: [
              buildPropertyMetricCard(
                label: 'Sensors',
                value: LocaleNumberFormat.formatInt(
                  d.sensorCount,
                  locale: locale,
                ),
                icon: buildDashboardSvgIcon(
                  assetSensor,
                  color: _metricIconTeal,
                  size: 20,
                ),
              ),
            ],
            filter: DashboardPeriodHeader(
              timeRange: d.timeRange,
              onDateRangeChanged: widget.onDashboardDateRangeChanged != null
                  ? (s, e) => _onDateRangeChanged(context, s, e)
                  : null,
            ),
          ),
          if (kpis != null) ...[
            SizedBox(height: _spacingSection),
            DashboardPropertyKpiSection(
              title: 'Room KPIs',
              subtitle:
                  'Energy performance and load metrics for the current period. ${kpis.unit}',
              kpis: kpis,
              locale: locale,
            ),
          ],
          SizedBox(height: _spacingSection),
          RoomRealtimeSensorsSection(roomId: state.roomId, sensors: d.sensors),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFloorDetails(DashboardFloorDetailsState state) {
    if (state is DashboardFloorDetailsLoading) {
      return buildDashboardCard(
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading floor details...',
              style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    if (state is DashboardFloorDetailsFailure) {
      return buildDashboardCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.message,
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.red[700],
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                context.read<DashboardFloorDetailsBloc>().add(
                  DashboardFloorDetailsRequested(
                    floorId: state.floorId,
                    filter: widget.dashboardFilter,
                  ),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state is DashboardFloorDetailsSuccess) {
      final d = state.details;
      final kpis = d.kpis;
      final locale = context.locale;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardPropertyOverviewSection(
            title: d.name,
            filter: DashboardPeriodHeader(
              timeRange: d.timeRange,
              onDateRangeChanged: widget.onDashboardDateRangeChanged != null
                  ? (s, e) => _onDateRangeChanged(context, s, e)
                  : null,
            ),
            onEdit: () {
              context.pushNamed(
                Routelists.editFloor,
                queryParameters: {'floorId': state.floorId},
              );
            },
            onDelete: () async {
              await _handleDeleteFloor(state.floorId);
            },
            metricCards: [
              buildPropertyMetricCard(
                label: 'Rooms',
                value: LocaleNumberFormat.formatInt(
                  d.roomCount,
                  locale: locale,
                ),
                icon: buildDashboardSvgIcon(assetRoom, color: _metricIconTeal),
              ),
              buildPropertyMetricCard(
                label: 'Sensors',
                value: LocaleNumberFormat.formatInt(
                  d.sensorCount,
                  locale: locale,
                ),
                icon: buildDashboardSvgIcon(
                  assetSensor,
                  color: _metricIconTeal,
                  size: 20,
                ),
              ),
            ],
          ),
          if (kpis != null) ...[
            SizedBox(height: _spacingSection),
            DashboardPropertyKpiSection(
              title: 'Floor KPIs',
              subtitle:
                  'Aggregate energy performance and load metrics for the current period. ${kpis.unit}',
              kpis: kpis,
              locale: locale,
            ),
          ],
          SizedBox(height: _spacingSection),
          buildDashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Floor Plan Image
                if (d.floorPlanLink != null && d.floorPlanLink!.isNotEmpty) ...[
                  Text(
                    'Floor Plan',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: _spacingTitleSubtitle),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 400),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: DashboardFloorPlanImage(
                        imageUrl: d.floorPlanLink!,
                      ),
                    ),
                  ),
                  SizedBox(height: _spacingContent),
                ],
                Text(
                  'Rooms',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: _spacingTitleSubtitle),
                Text(
                  'Select a room from the sidebar to view details.',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: _spacingContent),
                if (d.rooms.isEmpty)
                  Text(
                    'No rooms on this floor.',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Colors.grey[700],
                    ),
                  )
                else
                  Column(
                    children: d.rooms.map((room) {
                      Color? roomColor;
                      try {
                        roomColor = Color(
                          int.parse(room.color.replaceFirst('#', '0xFF')),
                        );
                      } catch (_) {}
                      return DashboardPropertyListItem(
                        icon: buildDashboardSvgIcon(
                          assetRoom,
                          color: roomColor ?? _metricIconTeal,
                        ),
                        title: room.name,
                        trailing:
                            '${LocaleNumberFormat.formatInt(room.sensorCount, locale: locale)} sensors',
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBuildingDetails(DashboardBuildingDetailsState state) {
    if (state is DashboardBuildingDetailsLoading) {
      return buildDashboardCard(
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading building details...',
              style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    if (state is DashboardBuildingDetailsFailure) {
      return buildDashboardCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.message,
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.red[700],
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                context.read<DashboardBuildingDetailsBloc>().add(
                  DashboardBuildingDetailsRequested(
                    buildingId: state.buildingId,
                    filter: widget.dashboardFilter,
                  ),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state is DashboardBuildingDetailsSuccess) {
      final d = state.details;
      final kpis = d.kpis;
      final locale = context.locale;
      final analytics = d.analytics;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardPropertyOverviewSection(
            title: d.name,
            address: d.typeOfUse,
            onEdit: () {
              context.pushNamed(
                Routelists.editBuilding,
                queryParameters: {'buildingId': state.buildingId},
              );
            },
            onDelete: () async {
              await _handleDeleteBuilding(state.buildingId);
            },
            metricCards: buildBuildingDetailsMetricCards(d, locale),
            filter: DashboardPeriodHeader(
              timeRange: d.timeRange,
              onDateRangeChanged: widget.onDashboardDateRangeChanged != null
                  ? (s, e) => _onDateRangeChanged(context, s, e)
                  : null,
            ),
          ),
          if (kpis != null) ...[
            SizedBox(height: _spacingSection),
            DashboardPropertyKpiSection(
              title: 'Building KPIs',
              subtitle:
                  'Aggregate energy performance and load metrics for the current period. ${kpis.unit}',
              kpis: kpis,
              locale: locale,
            ),
          ],
          if ((analytics != null &&
                  (analytics.eui != null || analytics.perCapita != null)) ||
              (kpis != null && kpis.breakdown.isNotEmpty)) ...[
            SizedBox(height: _spacingSection),
            buildBuildingDetailMetricsSection(analytics, kpis, locale),
          ],
          if (kpis != null) ...[
            SizedBox(height: _spacingSection),
            DashboardPropertyDataQualitySummary(kpis: kpis, locale: locale),
          ],
          if (d.analyticsRaw != null && d.analyticsRaw!.isNotEmpty) ...[
            SizedBox(height: _spacingSection),
            buildBuildingBenchmarkSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            buildBuildingInefficientUsageSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            buildBuildingTemperatureSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            buildBuildingComparisonSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            buildBuildingTimeBasedAnalysisSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            buildBuildingHourlyPatternSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            buildBuildingAnomaliesSection(context, d.analyticsRaw!, locale),
          ],
          SizedBox(height: _spacingSection),
          buildDashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Floors',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: _spacingTitleSubtitle),
                Text(
                  'Select a floor from the sidebar to view details.',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: _spacingContent),
                if (d.floors.isEmpty)
                  Text(
                    'No floors in this building yet.',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Colors.grey[700],
                    ),
                  )
                else
                  Column(
                    children: d.floors.map((floor) {
                      final sensorCount = floor.rooms.fold<int>(
                        0,
                        (sum, r) => sum + r.sensorCount,
                      );
                      return DashboardPropertyListItem(
                        icon: buildDashboardSvgIcon(
                          assetFloor,
                          color: _metricIconTeal,
                        ),
                        title: floor.name,
                        subtitle:
                            '${LocaleNumberFormat.formatInt(floor.roomCount, locale: locale)} rooms',
                        trailing: sensorCount > 0
                            ? '${LocaleNumberFormat.formatInt(sensorCount, locale: locale)} sensors'
                            : null,
                        onEdit: () {
                          context.pushNamed(
                            Routelists.editFloor,
                            queryParameters: {'floorId': floor.id},
                          );
                        },
                        onDelete: () => _handleDeleteFloor(floor.id),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _handleDeleteBuilding(String buildingId) async {
    final shouldDelete = await _showDeleteBuildingConfirmationDialog();
    if (shouldDelete != true || !mounted) return;

    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.delete('/api/v1/buildings/$buildingId');

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        final siteId = _getCurrentSiteIdFromState();
        if (siteId != null && siteId.isNotEmpty) {
          context.read<DashboardSiteDetailsBloc>().add(
            DashboardSiteDetailsRequested(
              siteId: siteId,
              filter: widget.dashboardFilter,
            ),
          );
        }
        context.read<DashboardSitesBloc>().add(
          DashboardSitesRequested(bryteswitchId: widget.verseId),
        );
        context.read<DashboardBuildingDetailsBloc>().add(
          DashboardBuildingDetailsReset(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Building deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete building: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting building: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool?> _showDeleteSiteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          backgroundColor: Colors.white,
          title: const Text('Delete Site'),
          content: const Text(
            'Are you sure you want to delete this site? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _handleDeleteRoom(String roomId) async {
    final shouldDelete = await _showDeleteRoomConfirmationDialog();
    if (shouldDelete != true || !mounted) return false;

    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.delete('/api/v1/floors/rooms/$roomId');
      if (!mounted) return false;
      if (response.statusCode == 200 || response.statusCode == 204) {
        context.read<DashboardFloorDetailsBloc>().add(
          DashboardFloorDetailsReset(),
        );
        context.read<DashboardRoomDetailsBloc>().add(
          DashboardRoomDetailsReset(),
        );
        context.read<DashboardBuildingDetailsBloc>().add(
          DashboardBuildingDetailsReset(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting room: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<bool?> _showDeleteRoomConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          backgroundColor: Colors.white,
          title: const Text('Delete Room'),
          content: const Text(
            'Are you sure you want to delete this room? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _handleDeleteFloor(String floorId) async {
    final shouldDelete = await _showDeleteFloorConfirmationDialog();
    if (shouldDelete != true || !mounted) return false;

    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.delete('/api/v1/floors/$floorId');
      if (!mounted) return false;
      if (response.statusCode == 200 || response.statusCode == 204) {
        // context.read<DashboardFloorsBloc>().add(
        //   DashboardFloorsRequested(bryteswitchId: widget.verseId),
        // );
        context.read<DashboardFloorDetailsBloc>().add(
          DashboardFloorDetailsReset(),
        );
        context.read<DashboardBuildingDetailsBloc>().add(
          DashboardBuildingDetailsReset(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floor deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete floor: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting floor: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool?> _showDeleteFloorConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          backgroundColor: Colors.white,
          title: const Text('Delete Floor'),
          content: const Text(
            'Are you sure you want to delete this floor? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _handleDeleteSite(String siteId) async {
    final shouldDelete = await _showDeleteSiteConfirmationDialog();
    if (shouldDelete != true || !mounted) return false;

    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.delete('/api/v1/sites/$siteId');

      if (!mounted) return false;
      if (response.statusCode == 200 || response.statusCode == 204) {
        context.read<DashboardSitesBloc>().add(
          DashboardSitesRequested(bryteswitchId: widget.verseId),
        );
        context.read<DashboardSiteDetailsBloc>().add(
          DashboardSiteDetailsReset(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete site: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting site: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool?> _showDeleteBuildingConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          backgroundColor: Colors.white,
          title: const Text('Delete Building'),
          content: const Text(
            'Are you sure you want to delete this building? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String? _getCurrentSiteIdFromState() {
    final siteDetailsState = context.read<DashboardSiteDetailsBloc>().state;
    if (siteDetailsState is DashboardSiteDetailsLoading) {
      return siteDetailsState.siteId;
    } else if (siteDetailsState is DashboardSiteDetailsSuccess) {
      return siteDetailsState.siteId;
    } else if (siteDetailsState is DashboardSiteDetailsFailure) {
      return siteDetailsState.siteId;
    }
    return null;
  }

  Future<void> _showSiteSelectionDialog() async {
    final sitesState = context.read<DashboardSitesBloc>().state;

    if (sitesState is! DashboardSitesSuccess || sitesState.sites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No sites available. Please create a site first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedSite = await showDialog<dynamic>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select a Site',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sitesState.sites.length,
                    itemBuilder: (context, index) {
                      final site = sitesState.sites[index];
                      return InkWell(
                        onTap: () => Navigator.of(dialogContext).pop(site),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black54, width: 2),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.business,
                                color: Colors.black87,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      site.name,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (site.address.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        site.address,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedSite != null && selectedSite.id != null) {
      // Navigate to add additional buildings page with selected siteId
      if (mounted) {
        context.pushNamed(
          Routelists.addAdditionalBuildings,
          queryParameters: {
            if (_userName != null && _userName!.isNotEmpty)
              'userName': _userName!,
            if (widget.verseId != null && widget.verseId!.isNotEmpty)
              'switchId': widget.verseId!,
            'siteId': selectedSite.id,
            'fromDashboard': 'true',
          },
        );
      }
    }
  }

  Future<void> _showSwitchSelectionDialog() async {
    if (_switches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No switches available. Please contact support.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedSwitch = await showDialog<SwitchRoleEntity>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select a Switch',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _switches.length,
                    itemBuilder: (context, index) {
                      final switchRole = _switches[index];
                      final switchName = switchRole.organizationName.isNotEmpty
                          ? switchRole.organizationName
                          : (switchRole.subDomain.isNotEmpty
                                ? switchRole.subDomain
                                : switchRole.bryteswitchId);

                      return InkWell(
                        onTap: () =>
                            Navigator.of(dialogContext).pop(switchRole),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black54, width: 2),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.business,
                                color: Colors.black87,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      switchName,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (switchRole.subDomain.isNotEmpty &&
                                        switchRole
                                            .organizationName
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        switchRole.subDomain,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedSwitch != null) {
      // Navigate to add properties page with selected switchId
      if (mounted) {
        context.pushNamed(
          Routelists.addProperties,
          queryParameters: {
            if (_userName != null && _userName!.isNotEmpty)
              'userName': _userName!,
            'switchId': selectedSwitch.bryteswitchId,
            'isSingleProperty': 'false',
            'fromDashboard': 'true',
          },
        );
      }
    }
  }
}
