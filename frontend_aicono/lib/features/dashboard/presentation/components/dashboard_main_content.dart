import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/utils/locale_number_format.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_details_filter.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/dashboard_date_range_picker_dialog.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/weekday_weekend_cylinder_chart.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/anomalies_detail_dialog.dart';
import 'package:frontend_aicono/core/services/token_service.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
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
import 'package:frontend_aicono/features/dashboard/presentation/bloc/trigger_report_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_loxone_rooms_bloc.dart';
import 'package:frontend_aicono/features/realtime/domain/entities/realtime_connection_state.dart';
import 'package:frontend_aicono/features/realtime/presentation/bloc/realtime_sensor_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/report_detail_view.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_building_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/features/FloorPlan/presentation/pages/floor_plan_backup.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_plan_step.dart'
    show DottedBorderContainer;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert' show base64Decode, base64Encode;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart' as xml;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../../../core/routing/routeLists.dart';

// Asset paths for property/sensor icons
const String _assetBuilding = 'assets/images/Building.svg';
const String _assetFloor = 'assets/images/Floor.svg';
const String _assetRoom = 'assets/images/Room.svg';
const String _assetSensor = 'assets/images/Sensor.svg';

Widget _buildSvgIcon(String asset, {Color? color, double size = 22}) {
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

enum _PropertyOverviewMenuAction { edit, delete }

class DashboardMainContent extends StatefulWidget {
  final String? verseId;
  final User? user;
  final String? selectedReportId;
  final DashboardDetailsFilter? dashboardFilter;
  final void Function(DateTime start, DateTime end)? onDashboardDateRangeChanged;

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
                            _buildWelcomeSection(),
                            SizedBox(height: _spacingBlock),
                          ],
                          // Selected Item Details (Site/Building/Floor/Room)
                          _buildSelectedItemDetails(),
                          SizedBox(height: _spacingBlock),
                          // Trigger Manual Report Button
                          _buildTriggerManualReportButton(),
                          SizedBox(height: _spacingBlock),
                          // "Was brauchst Du gerade?" Section
                          _buildActionLinksSection(),
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
        DashboardSiteDetailsRequested(
          siteId: siteState.siteId,
          filter: filter,
        ),
      );
    }
  }

  Widget _buildDashboardPeriodHeader(
    BuildContext context,
    DashboardTimeRange? timeRange,
  ) {
    String periodLabel = 'Current period';
    if (timeRange != null &&
        timeRange.start.isNotEmpty &&
        timeRange.end.isNotEmpty) {
      final start = DateTime.tryParse(timeRange.start);
      final end = DateTime.tryParse(timeRange.end);
      if (start != null && end != null) {
        const pattern = 'MMM d, yyyy';
        final formatter = DateFormat(pattern);
        final isSameDay =
            start.year == end.year &&
            start.month == end.month &&
            start.day == end.day;
        periodLabel = isSameDay
            ? formatter.format(start)
            : '${formatter.format(start)} – ${formatter.format(end)}';
      }
    }
    final canChangeDate = widget.onDashboardDateRangeChanged != null;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: const Color(0xFF4A6B5A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              periodLabel,
              style: AppTextStyles.labelMedium.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            if (canChangeDate) ...[
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  DateTimeRange initialRange = DateTimeRange(
                    start: now.subtract(const Duration(days: 7)),
                    end: now,
                  );
                  if (timeRange != null &&
                      timeRange.start.isNotEmpty &&
                      timeRange.end.isNotEmpty) {
                    final start = DateTime.tryParse(timeRange.start);
                    final end = DateTime.tryParse(timeRange.end);
                    if (start != null && end != null) {
                      initialRange = DateTimeRange(start: start, end: end);
                    }
                  }
                  final range = await DashboardDateRangePickerDialog.show(
                    context,
                    initialRange: initialRange,
                  );
                  if (range != null &&
                      context.mounted &&
                      widget.onDashboardDateRangeChanged != null) {
                    widget.onDashboardDateRangeChanged!(range.start, range.end);
                    _refetchCurrentDetailWithDateRange(
                      context,
                      range.start,
                      range.end,
                    );
                  }
                },
                child: Text(
                  'Change',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
    );
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
                          return _buildCard(
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
                          return _buildCard(
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
                            return _buildCard(
                              child: Text(
                                'No sites found.',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: Colors.grey[700],
                                ),
                              ),
                            );
                          }

                          return _buildCard(
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
              _buildPropertyOverviewSection(
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
                  _buildPropertyMetricCard(
                    label: 'Buildings',
                    value: LocaleNumberFormat.formatInt(d.buildingCount, locale: locale),
                    icon: _buildSvgIcon(_assetBuilding, color: _metricIconTeal),
                  ),
                  _buildPropertyMetricCard(
                    label: 'Rooms',
                    value: LocaleNumberFormat.formatInt(d.totalRooms, locale: locale),
                    icon: _buildSvgIcon(_assetRoom, color: _metricIconTeal),
                  ),
                  _buildPropertyMetricCard(
                    label: 'Sensors',
                    value: LocaleNumberFormat.formatInt(d.totalSensors, locale: locale),
                    icon: _buildSvgIcon(_assetSensor, color: _metricIconTeal),
                  ),
                  _buildPropertyMetricCard(
                    label: 'Floors',
                    value: LocaleNumberFormat.formatInt(d.totalFloors, locale: locale),
                    icon: _buildSvgIcon(_assetFloor, color: _metricIconTeal),
                  ),
                ],
                filter: _buildDashboardPeriodHeader(context, d.timeRange),
              ),
              if (kpis != null) ...[
                SizedBox(height: _spacingSection),
                _buildPropertyKpiSection(
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
                    return _buildPropertyListItem(
                      icon: _buildSvgIcon(
                        _assetBuilding,
                        color: _metricIconTeal,
                      ),
                      title: b.name,
                      subtitle:
                          '${LocaleNumberFormat.formatInt(b.floorCount, locale: locale)} floors · $subtitle',
                      trailing:
                          '${LocaleNumberFormat.formatInt(b.sensorCount, locale: locale)} sensors',
                      buildingId: b.id,
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
      return _buildCard(
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
      return _buildCard(
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
          _buildPropertyOverviewSection(
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
              _buildPropertyMetricCard(
                label: 'Sensors',
                value: LocaleNumberFormat.formatInt(d.sensorCount, locale: locale),
                icon: _buildSvgIcon(_assetSensor, color: _metricIconTeal),
              ),
            ],
            filter: _buildDashboardPeriodHeader(context, d.timeRange),
          ),
          if (kpis != null) ...[
            SizedBox(height: _spacingSection),
            _buildPropertyKpiSection(
              title: 'Room KPIs',
              subtitle:
                  'Energy performance and load metrics for the current period. ${kpis.unit}',
              kpis: kpis,
              locale: locale,
            ),
          ],
          SizedBox(height: _spacingSection),
          _RoomRealtimeSensorsSection(roomId: state.roomId, sensors: d.sensors),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFloorDetails(DashboardFloorDetailsState state) {
    if (state is DashboardFloorDetailsLoading) {
      return _buildCard(
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
      return _buildCard(
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
          _buildPropertyOverviewSection(
            title: d.name,
            filter: _buildDashboardPeriodHeader(context, d.timeRange),
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
              _buildPropertyMetricCard(
                label: 'Rooms',
                value: LocaleNumberFormat.formatInt(d.roomCount, locale: locale),
                icon: _buildSvgIcon(_assetRoom, color: _metricIconTeal),
              ),
              _buildPropertyMetricCard(
                label: 'Sensors',
                value: LocaleNumberFormat.formatInt(d.sensorCount, locale: locale),
                icon: _buildSvgIcon(_assetSensor, color: _metricIconTeal),
              ),
            ],
          ),
          if (kpis != null) ...[
            SizedBox(height: _spacingSection),
            _buildPropertyKpiSection(
              title: 'Floor KPIs',
              subtitle:
                  'Aggregate energy performance and load metrics for the current period. ${kpis.unit}',
              kpis: kpis,
              locale: locale,
            ),
          ],
          SizedBox(height: _spacingSection),
          _buildCard(
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
                      child: _buildFloorPlanImage(d.floorPlanLink!),
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
                      return _buildPropertyListItem(
                        icon: _buildSvgIcon(
                          _assetRoom,
                          color: roomColor ?? _metricIconTeal,
                        ),
                        title: room.name,
                        subtitle: null,
                        trailing:
                            '${LocaleNumberFormat.formatInt(room.sensorCount, locale: locale)} sensors',
                        iconColor: roomColor,
                        roomId: room.id,
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
      return _buildCard(
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
      return _buildCard(
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
          _buildPropertyOverviewSection(
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
            metricCards: _buildBuildingDetailsMetricCards(d, locale),
            filter: _buildDashboardPeriodHeader(context, d.timeRange),
          ),
          if (kpis != null) ...[
            SizedBox(height: _spacingSection),
            _buildPropertyKpiSection(
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
            _buildBuildingDetailMetricsSection(analytics, kpis, locale),
          ],
          if (kpis != null) ...[
            SizedBox(height: _spacingSection),
            _buildPropertyDataQualitySummary(kpis, locale),
          ],
          if (d.analyticsRaw != null && d.analyticsRaw!.isNotEmpty) ...[
            SizedBox(height: _spacingSection),
            _buildBuildingBenchmarkSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            _buildBuildingInefficientUsageSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            _buildBuildingTemperatureSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            _buildBuildingComparisonSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            _buildBuildingTimeBasedAnalysisSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            _buildBuildingHourlyPatternSection(d.analyticsRaw!, locale),
            SizedBox(height: _spacingSection),
            _buildBuildingAnomaliesSection(context, d.analyticsRaw!, locale),
          ],
          SizedBox(height: _spacingSection),
          _buildCard(
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
                      return _buildPropertyListItem(
                        icon: _buildSvgIcon(
                          _assetFloor,
                          color: _metricIconTeal,
                        ),
                        title: floor.name,
                        subtitle:
                            '${LocaleNumberFormat.formatInt(floor.roomCount, locale: locale)} rooms',
                        trailing: sensorCount > 0
                            ? '${LocaleNumberFormat.formatInt(sensorCount, locale: locale)} sensors'
                            : null,
                        floorId: floor.id,
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

  List<Widget> _buildBuildingDetailsMetricCards(
    DashboardBuildingDetails d,
    Locale locale,
  ) {
    final metricCards = <Widget>[
        _buildPropertyMetricCard(
          label: 'Floors',
          value: LocaleNumberFormat.formatInt(d.floorCount, locale: locale),
          icon: _buildSvgIcon(_assetFloor, color: _metricIconTeal),
        ),
        _buildPropertyMetricCard(
          label: 'Rooms',
          value: LocaleNumberFormat.formatInt(d.roomCount, locale: locale),
          icon: _buildSvgIcon(_assetRoom, color: _metricIconTeal),
        ),
        _buildPropertyMetricCard(
          label: 'Sensors',
          value: LocaleNumberFormat.formatInt(d.sensorCount, locale: locale),
          icon: _buildSvgIcon(_assetSensor, color: _metricIconTeal),
        ),
      ];
    if (d.buildingSize != null) {
      metricCards.add(
        _buildPropertyMetricCard(
          label: 'Size (m²)',
          value: LocaleNumberFormat.formatNum(
            d.buildingSize,
            locale: locale,
            decimalDigits: 2,
          ),
          icon: _buildSvgIcon(_assetBuilding, color: _metricIconTeal),
        ),
      );
    }
    return metricCards;
  }

  Widget _buildCard({required Widget child}) {
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

  static const Color _metricIconTeal = Color(0xFF00897B);

  Widget _buildPropertyListItem({
    required Widget icon,
    required String title,
    String? subtitle,
    String? trailing,
    Color? iconColor,
    String? buildingId,
    String? floorId,
    String? siteId,
    String? roomId,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: _spacingCardGap),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _metricIconTeal.withOpacity(0.12),
              borderRadius: BorderRadius.zero,
            ),
            child: icon,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  SizedBox(height: _spacingTight),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null && trailing.isNotEmpty)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    trailing,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (buildingId != null && buildingId.isNotEmpty) ...[
                  IconButton(
                    onPressed: () {
                      context.pushNamed(
                        Routelists.editBuilding,
                        queryParameters: {'buildingId': buildingId},
                      );
                    },
                    icon: Icon(Icons.edit),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      await _handleDeleteBuilding(buildingId);
                    },
                    icon: const Icon(Icons.delete),
                  ),
                ] else if (floorId != null && floorId.isNotEmpty) ...[
                  IconButton(
                    onPressed: () {
                      context.pushNamed(
                        Routelists.editFloor,
                        queryParameters: {'floorId': floorId},
                      );
                    },
                    icon: Icon(Icons.edit),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      await _handleDeleteFloor(floorId);
                    },
                    icon: const Icon(Icons.delete),
                  ),
                ] else if (siteId != null && siteId.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      context.pushNamed(
                        Routelists.editSite,
                        queryParameters: {'siteId': siteId},
                      );
                    },
                    icon: Icon(Icons.edit),
                  ),

                // else if (roomId != null && roomId.isNotEmpty) ...[
                //   IconButton(
                //     onPressed: () {
                //       // Get buildingId from floor details if available
                //       ScaffoldMessenger.of(context).showSnackBar(
                //         SnackBar(
                //           content: Text(
                //             'Edit functionality is available when you edit the floor',
                //           ),
                //           backgroundColor: Colors.red,
                //         ),
                //       );
                //       // final floorDetailsState = context
                //       //     .read<DashboardFloorDetailsBloc>()
                //       //     .state;
                //       // String? buildingId;
                //       // if (floorDetailsState is DashboardFloorDetailsSuccess) {
                //       //   buildingId = floorDetailsState.details.buildingId;
                //       // }
                //       // context.pushNamed(
                //       //   Routelists.editRoom,
                //       //   queryParameters: {
                //       //     'roomId': roomId,
                //       //     if (buildingId != null && buildingId.isNotEmpty)
                //       //       'buildingId': buildingId,
                //       //   },
                //       // );
                //     },
                //     icon: Icon(Icons.edit),
                //   ),
                //   // const SizedBox(width: 8),
                //   // IconButton(
                //   //   onPressed: () async {
                //   //     // await _handleDeleteRoom(roomId);
                //   //   },
                //   //   icon: const Icon(Icons.delete),
                //   // ),
                // ],
              ],
            ),
        ],
      ),
    );
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

  Widget _buildPropertyMetricCard({
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
                SizedBox(height: _spacingTight),
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

  Widget _buildPropertyOverviewSection({
    required String title,
    String? address,
    required List<Widget> metricCards,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    Widget? filter,
  }) {
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
                  if (address != null && address.isNotEmpty) ...[
                    SizedBox(height: _spacingTitleSubtitle),
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
                            address,
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
              PopupMenuButton<_PropertyOverviewMenuAction>(
                icon: const Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                color: Colors.white,
                onSelected: (action) {
                  switch (action) {
                    case _PropertyOverviewMenuAction.edit:
                      if (onEdit != null) onEdit();
                      break;
                    case _PropertyOverviewMenuAction.delete:
                      if (onDelete != null) onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem<_PropertyOverviewMenuAction>(
                      value: _PropertyOverviewMenuAction.edit,
                      child: Text('Edit'),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem<_PropertyOverviewMenuAction>(
                      value: _PropertyOverviewMenuAction.delete,
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
          SizedBox(height: _spacingContent),
          filter,
          SizedBox(height: _spacingContent),
          Divider(
            color: Colors.grey[300],
            thickness: 0.7,
            height: 0,
          ),
        ],
        SizedBox(height: _spacingContent),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            if (isNarrow) {
              return Wrap(
                spacing: _spacingCardGap,
                runSpacing: _spacingCardGap,
                children: metricCards
                    .map(
                      (w) => SizedBox(
                        width: (constraints.maxWidth - _spacingCardGap) / 2,
                        child: w,
                      ),
                    )
                    .toList(),
              );
            }
            return Row(
              children: [
                for (int i = 0; i < metricCards.length; i++) ...[
                  if (i > 0) SizedBox(width: _spacingCardGap),
                  Expanded(child: metricCards[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPropertyDataQualitySummary(dynamic kpis, Locale locale) {
    // kpis is expected to be DashboardKpis, but keep dynamic for flexibility.
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
    final Color borderColor = warning
        ? Colors.orange[200]!
        : Colors.green[200]!;
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

  Widget _buildKpiMetricCard({
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
                SizedBox(height: _spacingTight),
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

  Widget _buildPropertyKpiSection({
    required String title,
    required String subtitle,
    required dynamic kpis,
    required Locale locale,
  }) {
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
        SizedBox(height: _spacingTitleSubtitle),
        Text(
          subtitle,
          style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
        ),
        SizedBox(height: _spacingContent),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            if (isNarrow) {
              return Wrap(
                spacing: _spacingCardGap,
                runSpacing: _spacingCardGap,
                children: [
                  SizedBox(
                    width: (constraints.maxWidth - _spacingCardGap) / 2,
                    child: _buildKpiMetricCard(
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
                    child: _buildKpiMetricCard(
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
                    child: _buildKpiMetricCard(
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
                    child: _buildKpiMetricCard(
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
                  child: _buildKpiMetricCard(
                    label: 'Total',
                    value: LocaleNumberFormat.formatDecimal(
                      kpis.totalConsumption,
                      locale: locale,
                    ),
                    indicatorColor: const Color(0xFF64B5F6),
                  ),
                ),
                SizedBox(width: _spacingCardGap),
                Expanded(
                  child: _buildKpiMetricCard(
                    label: 'Peak',
                    value: LocaleNumberFormat.formatDecimal(
                      kpis.peak,
                      locale: locale,
                    ),
                    indicatorColor: const Color(0xFFFFB74D),
                  ),
                ),
                SizedBox(width: _spacingCardGap),
                Expanded(
                  child: _buildKpiMetricCard(
                    label: 'Average',
                    value: LocaleNumberFormat.formatDecimal(
                      kpis.average,
                      locale: locale,
                    ),
                    indicatorColor: const Color(0xFFFFEE58),
                  ),
                ),
                SizedBox(width: _spacingCardGap),
                Expanded(
                  child: _buildKpiMetricCard(
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

  /// Detail Metrics: EUI, Per Capita, and measurement breakdown in one section.
  Widget _buildBuildingDetailMetricsSection(
    DashboardBuildingAnalytics? analytics,
    DashboardKpis? kpis,
    Locale locale,
  ) {
    final cards = <Widget>[];

    if (analytics != null) {
      final eui = analytics.eui;
      if (eui != null && eui.available) {
        cards.add(
          _buildAnalyticsMetricCard(
            title: 'EUI (${eui.unit})',
            rows: [
              (
                label: 'EUI',
                value: LocaleNumberFormat.formatDecimal(
                  eui.eui,
                  locale: locale,
                  decimalDigits: 2,
                ),
              ),
              (
                label: 'Annualized',
                value: LocaleNumberFormat.formatDecimal(
                  eui.annualizedEui,
                  locale: locale,
                  decimalDigits: 2,
                ),
              ),
            ],
          ),
        );
      }

      final perCapita = analytics.perCapita;
      if (perCapita != null && perCapita.available) {
        final rows = <({String label, String value})>[
          (
            label: 'Per Capita',
            value: LocaleNumberFormat.formatDecimal(
              perCapita.perCapita,
              locale: locale,
              decimalDigits: 2,
            ),
          ),
        ];
        if (perCapita.numPeople != null && perCapita.numPeople! > 0) {
          rows.add((
            label: 'People',
            value: LocaleNumberFormat.formatInt(perCapita.numPeople!, locale: locale),
          ));
        }
        cards.add(
          _buildAnalyticsMetricCard(
            title: 'Per Capita (${perCapita.unit})',
            rows: rows,
          ),
        );
      }
    }

    if (kpis != null && kpis.breakdown.isNotEmpty) {
      for (final item in kpis.breakdown) {
        final title = item.unit.isNotEmpty
            ? '${item.measurementType} (${item.unit})'
            : item.measurementType;
        cards.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: _spacingTitleSubtitle),
                _buildBreakdownRow('Total', item.total, locale),
                _buildBreakdownRow('Average', item.average, locale),
                _buildBreakdownRow('Min', item.min, locale),
                _buildBreakdownRow('Max', item.max, locale),
                if (item.count > 0)
                  _buildBreakdownRow('Count', item.count, locale),
              ],
            ),
          ),
        );
      }
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detail Metrics',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: _spacingCardGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            final spacing = _spacingCardGap;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) SizedBox(height: spacing),
                    cards[i],
                  ],
                ],
              );
            }
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: cards
                  .map(
                    (c) => SizedBox(
                      width: (constraints.maxWidth - spacing) / 2,
                      child: c,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  static String _formatDashboardNum(Locale locale, dynamic value) {
    return LocaleNumberFormat.formatDecimal(
      value,
      locale: locale,
      decimalDigits: 3,
      fallback: '–',
    );
  }

  static Widget _dashboardTableCell(
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

  Widget _buildBuildingComparisonSection(
    Map<String, dynamic> analyticsRaw,
    Locale locale,
  ) {
    final comp = analyticsRaw['buildingComparison'] ?? analyticsRaw['BuildingComparison'];
    if (comp is! Map || comp['available'] != true) {
      return const SizedBox.shrink();
    }
    final buildings = comp['buildings'];
    if (buildings is! List || buildings.isEmpty) return const SizedBox.shrink();
    final list = buildings.whereType<Map>().toList();
    if (list.isEmpty) return const SizedBox.shrink();

    const headerBg = Color(0xFFE0F2F1);
    const cellPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Building Comparison',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: _spacingCardGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final fullWidth = constraints.maxWidth;
            return Container(
              width: fullWidth,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.white,
              ),
              child: Table(
                border: TableBorder.all(color: Colors.grey[300]!),
                columnWidths: {
                  0: FlexColumnWidth(1.5),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(0.8),
                  4: FlexColumnWidth(0.8),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: headerBg),
                    children: [
                      _dashboardTableCell('Building', cellPadding, isHeader: true, alignLeft: true),
                      _dashboardTableCell('Consumption (kWh)', cellPadding, isHeader: true),
                      _dashboardTableCell('Average (kWh)', cellPadding, isHeader: true),
                      _dashboardTableCell('Peak (kW)', cellPadding, isHeader: true),
                      _dashboardTableCell('EUI (kWh/m²)', cellPadding, isHeader: true),
                    ],
                  ),
                  ...list.map(
                    (b) => TableRow(
                      children: [
                        _dashboardTableCell(
                          (b['buildingName'] ?? b['building_name'] ?? '—').toString(),
                          cellPadding,
                          alignLeft: true,
                          isBold: true,
                        ),
                        _dashboardTableCell(_formatDashboardNum(locale, b['consumption']), cellPadding),
                        _dashboardTableCell(
                          _formatDashboardNum(locale, b['average'] ?? b['averageEnergy']),
                          cellPadding,
                        ),
                        _dashboardTableCell(_formatDashboardNum(locale, b['peak']), cellPadding),
                        _dashboardTableCell(_formatDashboardNum(locale, b['eui']), cellPadding),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, dynamic value, Locale locale) {
    final valueStr = value is num
        ? LocaleNumberFormat.formatNum(value, locale: locale, decimalDigits: 3)
        : value?.toString() ?? '–';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelMedium.copyWith(color: Colors.grey[600])),
          Text(valueStr, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildBuildingBenchmarkSection(
    Map<String, dynamic> analyticsRaw,
    Locale locale,
  ) {
    final benchmark = analyticsRaw['benchmark'];
    if (benchmark is! Map) return const SizedBox.shrink();
    final available = benchmark['available'] == true;
    final message = (benchmark['message'] ?? '').toString();
    if (available && message.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Benchmark',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: _spacingCardGap),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.white,
          ),
          child: Text(
            message.isNotEmpty ? message : 'No benchmark data available.',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingInefficientUsageSection(
    Map<String, dynamic> analyticsRaw,
    Locale locale,
  ) {
    final data = analyticsRaw['inefficientUsage'];
    if (data is! Map) return const SizedBox.shrink();
    final baseLoad = data['baseLoad'];
    final averageLoad = data['averageLoad'];
    final ratio = data['baseToAverageRatio'];
    final message = (data['message'] ?? '').toString();
    final baseUnit = (data['baseLoadUnit'] ?? 'kWh').toString();
    final avgUnit = (data['averageLoadUnit'] ?? 'kWh').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inefficient usage',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: _spacingCardGap),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (baseLoad != null)
                _buildBreakdownRow('Base load', '$baseLoad $baseUnit', locale),
              if (averageLoad != null)
                _buildBreakdownRow('Average load', '$averageLoad $avgUnit', locale),
              if (ratio != null)
                _buildBreakdownRow('Base to average ratio', ratio, locale),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(message, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[700])),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingTemperatureSection(
    Map<String, dynamic> analyticsRaw,
    Locale locale,
  ) {
    final data = analyticsRaw['temperatureAnalysis'];
    if (data is! Map || data['available'] != true) return const SizedBox.shrink();
    final overall = data['overall'];
    if (overall is! Map) return const SizedBox.shrink();
    final average = overall['average'];
    final min = overall['min'];
    final max = overall['max'];
    final unit = (overall['unit'] ?? '°C').toString();
    final totalSensors = data['totalSensors'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Temperature analysis',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: _spacingCardGap),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (average != null)
                _buildBreakdownRow(
                  'Average ($unit)',
                  LocaleNumberFormat.formatNum(average, locale: locale, decimalDigits: 2),
                  locale,
                ),
              if (min != null)
                _buildBreakdownRow(
                  'Min ($unit)',
                  LocaleNumberFormat.formatNum(min, locale: locale, decimalDigits: 2),
                  locale,
                ),
              if (max != null)
                _buildBreakdownRow(
                  'Max ($unit)',
                  LocaleNumberFormat.formatNum(max, locale: locale, decimalDigits: 2),
                  locale,
                ),
              if (totalSensors != null)
                _buildBreakdownRow('Sensors', totalSensors, locale),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatBuildingChartValue(Locale locale, double v) {
    return LocaleNumberFormat.formatCompact(v, locale: locale);
  }

  Widget _buildBuildingHourlyPatternSection(
    Map<String, dynamic> analyticsRaw,
    Locale locale,
  ) {
    const chartHeight = 200.0;
    final timeData = analyticsRaw['timeBasedAnalysis'] ?? analyticsRaw['TimeBasedAnalysis'];
    if (timeData is! Map) return const SizedBox.shrink();
    final hourly = timeData['hourlyPattern'];
    if (hourly is! List || hourly.isEmpty) return const SizedBox.shrink();

    final byHour = <int, double>{};
    for (final e in hourly.whereType<Map>()) {
      final hour = e['hour'] is int ? e['hour'] as int : 0;
      final c = (e['consumption'] is num)
          ? (e['consumption'] as num).toDouble()
          : 0.0;
      byHour[hour] = (byHour[hour] ?? 0) + c;
    }
    final maxHour = byHour.keys.isEmpty ? 23 : byHour.keys.reduce((a, b) => a > b ? a : b);
    final hourCount = (maxHour > 23 ? maxHour + 1 : 24).clamp(24, 48);
    final spots = List.generate(hourCount, (i) => FlSpot(i.toDouble(), byHour[i] ?? 0));
    final maxY = spots.isEmpty ? 0.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) return const SizedBox.shrink();

    final yMax = (maxY * 1.1).clamp(10.0, double.infinity);
    final yMaxRounded = ((yMax / 10).ceil() * 10).toDouble();
    const chartGreen = Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consumption by hour',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: _spacingCardGap),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'kWh',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: chartHeight,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (hourCount - 1).toDouble(),
                    minY: 0,
                    maxY: yMaxRounded,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yMaxRounded / 7,
                      getDrawingHorizontalLine: (v) =>
                          FlLine(color: Colors.grey[300]!, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: yMaxRounded / 7,
                          getTitlesWidget: (v, m) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              LocaleNumberFormat.formatInt(v.toInt(), locale: locale),
                              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 2,
                          getTitlesWidget: (v, m) => Text(
                            '${v.toInt()}',
                            style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: 8,
                        getTooltipColor: (_) => Colors.white,
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        getTooltipItems: (touchedSpots) => touchedSpots
                            .map(
                              (s) => LineTooltipItem(
                                '${_formatBuildingChartValue(locale, s.y)} kWh / ${s.x.toInt()} hr',
                                AppTextStyles.labelSmall.copyWith(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        color: chartGreen.withValues(alpha: 0.75),
                        barWidth: 2.5,
                        isStrokeCapRound: false,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              chartGreen.withValues(alpha: 0.10),
                              chartGreen.withValues(alpha: 0.40),
                              chartGreen.withValues(alpha: 0.75),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 300),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'hr',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingTimeBasedAnalysisSection(
    Map<String, dynamic> analyticsRaw,
    Locale locale,
  ) {
    final timeData = analyticsRaw['timeBasedAnalysis'] ?? analyticsRaw['TimeBasedAnalysis'];
    if (timeData is! Map) return const SizedBox.shrink();
    final dayNight = timeData['dayNight'] is Map ? timeData['dayNight'] as Map : null;
    final weekdayWeekend = timeData['weekdayWeekend'] is Map
        ? timeData['weekdayWeekend'] as Map
        : null;
    if (dayNight == null && weekdayWeekend == null) {
      return const SizedBox.shrink();
    }
    const dayColor = Color(0xFF26A69A);
    const nightColor = Color(0xFF8BC34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time-based analysis',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: _spacingCardGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dayNight != null)
                      Expanded(
                        child: _buildBuildingDayNightCard(
                          dayNight,
                          dayColor,
                          nightColor,
                          locale,
                        ),
                      ),
                    if (dayNight != null && weekdayWeekend != null)
                      const SizedBox(width: 16),
                    if (weekdayWeekend != null)
                      Expanded(
                        child: _buildBuildingWeekdayWeekendCard(
                          weekdayWeekend,
                          dayColor,
                          nightColor,
                        ),
                      ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                if (dayNight != null) ...[
                  _buildBuildingDayNightCard(
                    dayNight,
                    dayColor,
                    nightColor,
                    locale,
                  ),
                  const SizedBox(height: 16),
                ],
                if (weekdayWeekend != null)
                  _buildBuildingWeekdayWeekendCard(
                    weekdayWeekend,
                    dayColor,
                    nightColor,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBuildingDayNightCard(
    Map dayNight,
    Color dayColor,
    Color nightColor,
    Locale locale,
  ) {
    final day = (dayNight['day'] is num)
        ? (dayNight['day'] as num).toDouble()
        : 0.0;
    final night = (dayNight['night'] is num)
        ? (dayNight['night'] as num).toDouble()
        : 0.0;
    final total = day + night;
    final dayPct = total > 0 ? (day / total * 100).round() : 0;
    final dayVal = day > 0 ? day : 0.01;
    final nightVal = night > 0 ? night : 0.01;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Text(
            'Day & Night (kWh)',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: [
                      PieChartSectionData(
                        value: dayVal,
                        color: dayColor,
                        radius: 55,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: nightVal,
                        color: nightColor,
                        radius: 55,
                        showTitle: false,
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 300),
                ),
                Text(
                  '$dayPct%',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LocaleNumberFormat.formatNum(day, locale: locale, decimalDigits: 2),
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: dayColor,
                  ),
                ),
                Text(
                  LocaleNumberFormat.formatNum(night, locale: locale, decimalDigits: 2),
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: nightColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: dayColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('Day', style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700])),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: nightColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('Night', style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingWeekdayWeekendCard(
    Map weekdayWeekend,
    Color weekdayColor,
    Color weekendColor,
  ) {
    final weekday = (weekdayWeekend['weekday'] is num)
        ? (weekdayWeekend['weekday'] as num).toDouble()
        : 0.0;
    final weekend = (weekdayWeekend['weekend'] is num)
        ? (weekdayWeekend['weekend'] as num).toDouble()
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Text(
            'Weekday & Weekend (kWh)',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          WeekdayWeekendCylinderChart(
            weekendValue: weekend,
            weekdayValue: weekday,
            weekendColor: weekendColor,
            weekdayColor: weekdayColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingAnomaliesSection(
    BuildContext context,
    Map<String, dynamic> analyticsRaw,
    Locale locale,
  ) {
    final anomaliesData = analyticsRaw['anomalies'] ?? analyticsRaw['Anomalies'];
    if (anomaliesData is! Map) return const SizedBox.shrink();
    final total = anomaliesData['total'];
    if (total == null && (anomaliesData['anomalies'] is! List)) {
      return const SizedBox.shrink();
    }
    final bySeverity = anomaliesData['bySeverity'] is Map
        ? anomaliesData['bySeverity'] as Map
        : <String, dynamic>{};
    final anomalies = anomaliesData['anomalies'] is List
        ? (anomaliesData['anomalies'] as List).whereType<Map>().toList()
        : <Map>[];

    int toInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }
    final highCount = toInt(bySeverity['High']);
    final mediumCount = toInt(bySeverity['Medium']);
    final lowCount = toInt(bySeverity['Low']);
    final severityValues = [highCount, mediumCount, lowCount];
    final minCount = severityValues.reduce((a, b) => a < b ? a : b);
    final maxCount = severityValues.reduce((a, b) => a > b ? a : b);
    final sensorCount = anomalies
        .map(
          (a) =>
              a['sensorName']?.toString() ?? a['sensor_id']?.toString() ?? '',
        )
        .where((s) => s.isNotEmpty)
        .toSet()
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Anomalies (severity)',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            if (anomalies.isNotEmpty)
              GestureDetector(
                onTap: () => AnomaliesDetailDialog.show(context, anomalies),
                child: Text(
                  'Detail View',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: _spacingCardGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 500 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 4.5,
              children: [
                _buildBuildingAnomalyCard(
                  LocaleNumberFormat.formatInt(total, locale: locale, fallback: '0'),
                  'Total',
                ),
                _buildBuildingAnomalyCard(
                  LocaleNumberFormat.formatInt(bySeverity['High'] ?? 0, locale: locale),
                  'High',
                ),
                _buildBuildingAnomalyMinMaxCard(
                  LocaleNumberFormat.formatInt(minCount, locale: locale),
                  LocaleNumberFormat.formatInt(maxCount, locale: locale),
                ),
                _buildBuildingAnomalyCard(
                  LocaleNumberFormat.formatInt(sensorCount, locale: locale),
                  'Sensor Count',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBuildingAnomalyCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingAnomalyMinMaxCard(String minValue, String maxValue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(minValue, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[900])),
                const SizedBox(height: 2),
                Text('Minimum', style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600])),
              ],
            ),
          ),
          Container(width: 1, height: 28, color: Colors.grey[300]),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(maxValue, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[900])),
                const SizedBox(height: 2),
                Text('Maximum', style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetricCard({
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
          SizedBox(height: _spacingTitleSubtitle),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: _spacingTight),
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

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.main_content.greeting'.tr(
            namedArgs: {'name': _userFirstName ?? 'User'},
          ),
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: _spacingTitleSubtitle),
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

  Widget _buildTriggerManualReportButton() {
    return BlocConsumer<TriggerReportBloc, TriggerReportState>(
      listener: (context, state) {
        if (state is TriggerReportSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.response.message.isNotEmpty
                    ? state.response.message
                    : 'dashboard.main_content.trigger_report_success'.tr(),
              ),
              backgroundColor: Colors.green[700],
            ),
          );
        }
        if (state is TriggerReportFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is TriggerReportLoading;
        return Center(
          child: SizedBox(
            width: 270,
            height: 40,
            child: Material(
              color: Colors.white,
              child: InkWell(
                onTap: isLoading
                    ? null
                    : () {
                        context.read<TriggerReportBloc>().add(
                          const TriggerReportRequested('Daily'),
                        );
                      },
                child: Container(
                  width: 270,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isLoading
                          ? Colors.grey.shade400
                          : const Color(0xFF636F57),
                      width: 4,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'dashboard.main_content.trigger_report_loading'
                                    .tr(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'dashboard.main_content.trigger_manual_report'.tr(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionLinksSection() {
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
        SizedBox(height: _spacingContent),
        _buildActionLink(
          text: 'dashboard.main_content.enter_measurement_data'.tr(),
          onTap: () {
            // TODO: Navigate to enter measurement data page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.main_content.enter_measurement_data'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
          },
        ),
        SizedBox(height: _spacingTitleSubtitle),
        _buildActionLink(
          text: 'dashboard.main_content.add_building'.tr(),
          onTap: () {
            _showSiteSelectionDialog();
          },
        ),
        SizedBox(height: _spacingTitleSubtitle),
        _buildActionLink(
          text: 'dashboard.main_content.add_site'.tr(),
          onTap: () {
            _showSwitchSelectionDialog();
          },
        ),
        SizedBox(height: _spacingTitleSubtitle),
        _buildActionLink(
          text: 'dashboard.main_content.add_branding'.tr(),
          onTap: () {
            final switchId = widget.verseId ?? sl<LocalStorage>().getSelectedVerseId();
            if (switchId != null && switchId.isNotEmpty) {
              context.pushNamed(
                Routelists.switchSettings,
                queryParameters: {'switchId': switchId},
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('switch_settings.no_switch_selected'.tr()),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        ),
      ],
    );
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

  Widget _buildActionLink({required String text, required VoidCallback onTap}) {
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

  Widget _buildFloorPlanImage(String imageUrl) {
    // Check if the image is SVG by file extension
    final lowerUrl = imageUrl.toLowerCase();
    final isSvg = lowerUrl.endsWith('.svg');

    if (isSvg) {
      // Render SVG image
      return SvgPicture.network(
        imageUrl,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => Container(
          height: 200,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      );
    } else {
      // Render raster image (PNG, JPG, etc.)
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.grey[400], size: 48),
                const SizedBox(height: 8),
                Text(
                  'Failed to load floor plan',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }
}

// Building Edit Button Widget
class _BuildingEditButton extends StatefulWidget {
  final String buildingId;
  final TextEditingController buildingNameController;
  final TextEditingController buildingTypeController;
  final TextEditingController numberOfFloorsController;
  final TextEditingController totalAreaController;
  final TextEditingController constructionYearController;
  final TextEditingController loxoneUserController;
  final TextEditingController loxonePassController;
  final TextEditingController loxoneExternalAddressController;
  final TextEditingController loxonePortController;
  final TextEditingController loxoneSerialNumberController;
  final VoidCallback onSuccess;

  const _BuildingEditButton({
    required this.buildingId,
    required this.buildingNameController,
    required this.buildingTypeController,
    required this.numberOfFloorsController,
    required this.totalAreaController,
    required this.constructionYearController,
    required this.loxoneUserController,
    required this.loxonePassController,
    required this.loxoneExternalAddressController,
    required this.loxonePortController,
    required this.loxoneSerialNumberController,
    required this.onSuccess,
  });

  @override
  State<_BuildingEditButton> createState() => _BuildingEditButtonState();
}

class _BuildingEditButtonState extends State<_BuildingEditButton> {
  bool _isLoading = false;

  Future<void> _handleSave() async {
    final buildingName = widget.buildingNameController.text.trim();

    if (buildingName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Building name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dioClient = sl<DioClient>();
      final requestBody = <String, dynamic>{'name': buildingName};

      // Add building type if provided
      if (widget.buildingTypeController.text.trim().isNotEmpty) {
        requestBody['type_of_use'] = widget.buildingTypeController.text.trim();
      }

      // Add number of floors if provided
      if (widget.numberOfFloorsController.text.trim().isNotEmpty) {
        final numFloors = int.tryParse(
          widget.numberOfFloorsController.text.trim(),
        );
        if (numFloors != null) {
          requestBody['num_floors'] = numFloors;
        }
      }

      // Add total area if provided
      if (widget.totalAreaController.text.trim().isNotEmpty) {
        final totalArea = double.tryParse(
          widget.totalAreaController.text.trim(),
        );
        if (totalArea != null) {
          requestBody['building_size'] = totalArea.toInt();
        }
      }

      // Add construction year if provided
      if (widget.constructionYearController.text.trim().isNotEmpty) {
        final year = int.tryParse(
          widget.constructionYearController.text.trim(),
        );
        if (year != null) {
          requestBody['year_of_construction'] = year;
        }
      }

      // Add Loxone connection data
      requestBody['miniserver_user'] = widget.loxoneUserController.text.trim();
      requestBody['miniserver_pass'] = widget.loxonePassController.text.trim();
      requestBody['miniserver_external_address'] = widget
          .loxoneExternalAddressController
          .text
          .trim();
      final port = int.tryParse(widget.loxonePortController.text.trim()) ?? 443;
      requestBody['miniserver_port'] = port;
      requestBody['miniserver_serial'] = widget
          .loxoneSerialNumberController
          .text
          .trim();

      final response = await dioClient.patch(
        '/api/v1/buildings/${widget.buildingId}',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Building updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update building: ${response.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating building: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : PrimaryOutlineButton(
            label: 'Save Changes',
            width: 260,
            onPressed: _handleSave,
          );
  }
}

// Floor Plan Editor Wrapper Widget - Shows only canvas and room list
class FloorPlanEditorWrapper extends StatefulWidget {
  final String floorId;
  final String floorName;
  final String? initialFloorPlanUrl;
  final Function(String?) onSave;
  final VoidCallback onCancel;
  final GlobalKey<SimplifiedFloorPlanEditorState>? editorKey;

  const FloorPlanEditorWrapper({
    required this.floorId,
    required this.floorName,
    this.initialFloorPlanUrl,
    required this.onSave,
    required this.onCancel,
    this.editorKey,
  });

  @override
  State<FloorPlanEditorWrapper> createState() => _FloorPlanEditorWrapperState();
}

class _FloorPlanEditorWrapperState extends State<FloorPlanEditorWrapper> {
  @override
  Widget build(BuildContext context) {
    // Use the simplified floor plan editor that shows only canvas and room list
    return SimplifiedFloorPlanEditor(
      key: widget.editorKey,
      floorId: widget.floorId,
      initialFloorPlanUrl: widget.initialFloorPlanUrl,
      onSave: widget.onSave,
      onCancel: widget.onCancel,
    );
  }
}

// Simplified Floor Plan Editor - Shows only canvas (with dotted border) and room list
// This extracts the canvas and room list UI from FloorPlanBackupPage
class SimplifiedFloorPlanEditor extends StatefulWidget {
  final String floorId;
  final String? initialFloorPlanUrl;
  final Function(String?) onSave;
  final VoidCallback onCancel;

  const SimplifiedFloorPlanEditor({
    super.key,
    required this.floorId,
    this.initialFloorPlanUrl,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<SimplifiedFloorPlanEditor> createState() =>
      SimplifiedFloorPlanEditorState();
}

// Reuse enums and classes from floor_plan_backup.dart
enum DrawingMode { none, rectangle, polygon }

enum _ShapeTool { polygon, rectangle, triangle, circle }

enum ResizeHandle { topLeft, topRight, bottomLeft, bottomRight }

/// State snapshot for undo/redo functionality
class _FloorPlanState {
  final List<Room> rooms;
  final List<Door> doors;
  final int roomCounter;

  _FloorPlanState({
    required this.rooms,
    required this.doors,
    required this.roomCounter,
  });

  // Deep copy constructor
  _FloorPlanState copy() {
    return _FloorPlanState(
      rooms: rooms
          .map(
            (room) => Room(
              id: room.id,
              path: Path.from(room.path),
              doorOpenings: room.doorOpenings.map((p) => Path.from(p)).toList(),
              fillColor: room.fillColor,
              name: room.name,
            ),
          )
          .toList(),
      doors: doors
          .map(
            (door) => Door(
              id: door.id,
              path: Path.from(door.path),
              rotation: door.rotation,
              roomId: door.roomId,
              edge: door.edge,
            ),
          )
          .toList(),
      roomCounter: roomCounter,
    );
  }
}

class SimplifiedFloorPlanEditorState extends State<SimplifiedFloorPlanEditor> {
  // Floor plan state - reuse from FloorPlanBackupPage
  final List<Room> rooms = [];
  final List<Door> doors = [];
  Room? selectedRoom;
  Door? selectedDoor;

  Path? drawingPath;
  bool pencilMode = false;
  bool doorPlacementMode = false;
  bool polygonMode = false;
  _ShapeTool? _selectedShapeTool;

  // Drawing mode for rectangle/polygon creation
  DrawingMode _drawingMode = DrawingMode.none;

  // Rectangle creation state
  Offset? _rectangleStart;
  Rect? _currentRectangle;

  List<Offset> _polygonPoints = [];
  Offset? _polygonPreviewPosition;

  Offset? lastPanPosition;
  ResizeHandle? activeHandle;
  Rect? startBounds;

  Color? selectedColor;
  int _roomCounter = 1;
  Size _canvasSize = const Size(4000, 4000);
  final TransformationController _transformationController =
      TransformationController();
  Size? _viewportSize;

  // Background image from SVG URL
  Uint8List? _backgroundImageBytes;
  double? _backgroundImageWidth;
  double? _backgroundImageHeight;

  // Undo/Redo history
  final List<_FloorPlanState> _history = [];
  int _historyIndex = -1;
  static const int _maxHistorySize = 50;

  bool _showShapeOptions = false;
  final Map<String, TextEditingController> _roomControllers = {};

  // Backend room tracking: maps room.id to backend room ID
  final Map<String, String> _backendRoomIds = {};
  final Map<String, String?> _loxoneRoomIds =
      {}; // Maps room.id to loxone_room_id
  final DioClient _dioClient = sl<DioClient>();
  bool _isLoadingBackendRooms = false;
  String? _buildingId; // Store buildingId from floor data

  // Color palette
  static const List<Color> colorPalette = [
    Color(0xFFFFB74D), // Light orange
    Color(0xFFE57373), // Red
    Color(0xFFBA68C8), // Purple
    Color(0xFF64B5F6), // Blue
    Color(0xFF81C784), // Green
  ];

  @override
  void initState() {
    super.initState();
    _saveState();
    if (widget.initialFloorPlanUrl != null &&
        widget.initialFloorPlanUrl!.isNotEmpty) {
      _loadFloorPlanFromUrl();
    }
    // Fetch rooms from backend
    _fetchRoomsFromBackend();
  }

  // Public method to generate SVG - can be called from parent
  Future<String> generateSVG() async {
    // Use background image dimensions if available, otherwise calculate from rooms
    double width;
    double height;

    if (_backgroundImageBytes != null &&
        _backgroundImageWidth != null &&
        _backgroundImageHeight != null) {
      width = _backgroundImageWidth!;
      height = _backgroundImageHeight!;
    } else {
      // Calculate overall bounds from rooms
      Rect? overallBounds;
      for (final room in rooms) {
        final bounds = room.path.getBounds();
        overallBounds = overallBounds == null
            ? bounds
            : overallBounds.expandToInclude(bounds);
      }

      if (overallBounds == null) {
        overallBounds = const Rect.fromLTWH(0, 0, 2000, 2000);
      }

      final padding = 50.0;
      width = overallBounds.width + (padding * 2);
      height = overallBounds.height + (padding * 2);
    }

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${width.toStringAsFixed(0)}" '
      'height="${height.toStringAsFixed(0)}" '
      'viewBox="0 0 $width $height">',
    );

    // Background - use image if available, otherwise use color
    if (_backgroundImageBytes != null) {
      // Convert image to base64
      final base64Image = base64Encode(_backgroundImageBytes!);

      // Determine image type
      String imageType = 'png';
      if (_backgroundImageBytes!.length >= 2) {
        if (_backgroundImageBytes![0] == 0xFF &&
            _backgroundImageBytes![1] == 0xD8) {
          imageType = 'jpeg';
        } else if (_backgroundImageBytes![0] == 0x89 &&
            _backgroundImageBytes![1] == 0x50) {
          imageType = 'png';
        }
      }

      // Add background image
      buffer.writeln(
        '  <image x="0" y="0" width="$width" height="$height" '
        'href="data:image/$imageType;base64,$base64Image" '
        'preserveAspectRatio="none"/>',
      );
    } else {
      // Default background color
      buffer.writeln(
        '  <rect x="0" y="0" width="$width" height="$height" fill="#E3F2FD"/>',
      );
    }

    // Draw rooms
    for (final room in rooms) {
      final pathData = _pathToSvgPathData(room.path);
      final fillColorHex = _colorToHex(room.fillColor);
      buffer.writeln(
        '  <path d="$pathData" fill="$fillColorHex" fill-opacity="0.3" stroke="#424242" stroke-width="3"/>',
      );

      // Room name and area
      final bounds = room.path.getBounds();
      final center = bounds.center;
      buffer.writeln(
        '  <text x="${center.dx}" y="${center.dy - 8}" '
        'text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000000">${room.name}</text>',
      );
      final area = _calculateArea(room.path);
      buffer.writeln(
        '  <text x="${center.dx}" y="${center.dy + 12}" '
        'text-anchor="middle" font-family="Arial" font-size="14" fill="#000000">${area.toStringAsFixed(2)} m²</text>',
      );
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  // Helper methods for SVG generation
  String _pathToSvgPathData(Path path) {
    final metrics = path.computeMetrics();
    final buffer = StringBuffer();
    bool isFirst = true;

    for (final metric in metrics) {
      final length = metric.length;
      final sampleCount = math.max(10, (length / 10).ceil());
      final step = length / sampleCount;

      for (int i = 0; i <= sampleCount; i++) {
        final distance = i * step;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          final point = tangent.position;
          if (isFirst) {
            buffer.write(
              'M ${point.dx.toStringAsFixed(2)} ${point.dy.toStringAsFixed(2)} ',
            );
            isFirst = false;
          } else {
            buffer.write(
              'L ${point.dx.toStringAsFixed(2)} ${point.dy.toStringAsFixed(2)} ',
            );
          }
        }
      }

      // Close the path if it's closed
      if (path.getBounds().isEmpty == false) {
        final firstTangent = metric.getTangentForOffset(0);
        final lastTangent = metric.getTangentForOffset(length);
        if (firstTangent != null && lastTangent != null) {
          final firstPoint = firstTangent.position;
          final lastPoint = lastTangent.position;
          if ((firstPoint - lastPoint).distance < 1.0) {
            buffer.write('Z ');
          }
        }
      }
    }

    return buffer.toString().trim();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}';
  }

  double _calculateArea(Path path) {
    final bounds = path.getBounds();
    return (bounds.width * bounds.height) / 10000; // Convert to m²
  }

  @override
  void dispose() {
    for (final controller in _roomControllers.values) {
      controller.dispose();
    }
    _roomControllers.clear();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadFloorPlanFromUrl() async {
    if (widget.initialFloorPlanUrl == null ||
        widget.initialFloorPlanUrl!.isEmpty) {
      return;
    }

    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.get(widget.initialFloorPlanUrl!);

      if (response.statusCode == 200 && mounted) {
        String svgContent;
        if (response.data is String) {
          svgContent = response.data as String;
        } else {
          svgContent = response.data.toString();
        }

        // Try to load as background image first
        // If it's an SVG, we can display it directly
        // For now, parse it to load rooms
        _loadFromSVG(svgContent);
      }
    } catch (e) {
      debugPrint('Error loading floor plan from URL: $e');
    }
  }

  void _loadFromSVG(String svgContent) {
    try {
      final document = xml.XmlDocument.parse(svgContent);
      final newRooms = <Room>[];
      final newDoors = <Door>[];

      // Check if there's an image element (background image)
      final imageElements = document.findAllElements('image');
      if (imageElements.isNotEmpty) {
        // Try to load background image from base64 or URL
        final imageElement = imageElements.first;
        final href =
            imageElement.getAttribute('xlink:href') ??
            imageElement.getAttribute('href');
        if (href != null && href.startsWith('data:image')) {
          // Extract base64 image
          final base64String = href.split(',')[1];
          final imageBytes = base64Decode(base64String);
          // Decode to get dimensions
          _decodeImageDimensions(imageBytes);
        }
      }

      // Find all path elements (rooms)
      final pathElements = document.findAllElements('path');
      int roomIndex = 1;

      for (final pathElement in pathElements) {
        final pathData = pathElement.getAttribute('d');
        if (pathData == null || pathData.isEmpty) continue;

        final fill = pathElement.getAttribute('fill');
        if (fill != null && fill != 'none') {
          final roomPath = _parseSVGPath(pathData);
          final fillColor = _hexToColor(fill);

          String roomName = 'Room $roomIndex';
          roomIndex++;

          newRooms.add(
            Room(
              id: UniqueKey().toString(),
              path: roomPath,
              fillColor: fillColor ?? colorPalette[0],
              name: roomName,
            ),
          );
        }
      }

      // Find text elements for room names
      final textElements = document.findAllElements('text');
      final textItems = <Map<String, dynamic>>[];
      for (final textElement in textElements) {
        final text = textElement.text.trim();
        if (text.isEmpty) continue;

        final x = double.tryParse(textElement.getAttribute('x') ?? '') ?? 0;
        final y = double.tryParse(textElement.getAttribute('y') ?? '') ?? 0;

        final normalizedText = text
            .toLowerCase()
            .replaceAll('mâ²', 'm²')
            .replaceAll('mÂ²', 'm²')
            .replaceAll('m2', 'm²');
        final isAreaText = RegExp(
          r'^\d+\.?\d*\s*m²\s*$',
          caseSensitive: false,
        ).hasMatch(normalizedText);

        textItems.add({
          'text': text,
          'position': Offset(x, y),
          'isArea': isAreaText,
        });
      }

      // Match non-area text elements to rooms
      for (final textItem in textItems) {
        if (textItem['isArea'] == true) continue;

        final text = textItem['text'] as String;
        final textPos = textItem['position'] as Offset;

        if (newRooms.isEmpty) continue;

        Room? nearestRoom;
        double minDistance = double.infinity;
        int nearestIndex = -1;

        for (int i = 0; i < newRooms.length; i++) {
          final room = newRooms[i];
          final bounds = room.path.getBounds();
          final center = bounds.center;
          final distance = (center - textPos).distance;

          final yOffset = textPos.dy - center.dy;
          final adjustedDistance = distance + (yOffset > 0 ? 50 : 0);

          if (adjustedDistance < minDistance) {
            minDistance = adjustedDistance;
            nearestRoom = room;
            nearestIndex = i;
          }
        }

        if (nearestRoom != null && nearestIndex != -1 && minDistance < 150) {
          final normalizedText = text
              .toLowerCase()
              .replaceAll('mâ²', 'm²')
              .replaceAll('mÂ²', 'm²')
              .replaceAll('m2', 'm²');
          final looksLikeArea = RegExp(
            r'^\d+\.?\d*\s*m²\s*$',
            caseSensitive: false,
          ).hasMatch(normalizedText);

          if (looksLikeArea) continue;

          if (nearestRoom.name.startsWith('Room ') ||
              (textPos.dy < nearestRoom.path.getBounds().center.dy)) {
            newRooms[nearestIndex] = Room(
              id: nearestRoom.id,
              path: nearestRoom.path,
              doorOpenings: nearestRoom.doorOpenings,
              fillColor: nearestRoom.fillColor,
              name: text,
            );
          }
        }
      }

      setState(() {
        for (final controller in _roomControllers.values) {
          controller.dispose();
        }
        _roomControllers.clear();

        rooms.clear();
        doors.clear();
        rooms.addAll(newRooms);
        doors.addAll(newDoors);
        for (final room in newRooms) {
          _roomControllers[room.id] = TextEditingController(text: room.name);
        }
        selectedRoom = null;
        selectedDoor = null;
        _roomCounter = roomIndex;
        _updateCanvasSize();
      });

      // After loading SVG, fetch and match backend rooms
      _fetchRoomsFromBackend();
    } catch (e) {
      debugPrint('Error parsing SVG: $e');
    }
  }

  Future<void> _fetchRoomsFromBackend() async {
    if (_isLoadingBackendRooms) return;

    setState(() {
      _isLoadingBackendRooms = true;
    });

    try {
      final response = await _dioClient.get('/api/v1/floors/${widget.floorId}');

      if (response.statusCode == 200 && response.data != null && mounted) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final floorData = data['data'] as Map<String, dynamic>;

          // Store buildingId from floor data
          if (floorData['building_id'] != null) {
            _buildingId = floorData['building_id'].toString();
          }

          // Get rooms from floor data
          List<dynamic> backendRooms = [];
          if (floorData['rooms'] != null && floorData['rooms'] is List) {
            backendRooms = floorData['rooms'] as List;
          }

          // Match backend rooms with SVG rooms by name
          if (rooms.isNotEmpty) {
            _matchBackendRoomsWithSVGRooms(backendRooms);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching rooms from backend: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBackendRooms = false;
        });
      }
    }
  }

  void _matchBackendRoomsWithSVGRooms(List<dynamic> backendRooms) {
    setState(() {
      for (var backendRoom in backendRooms) {
        final backendRoomId =
            backendRoom['_id']?.toString() ??
            backendRoom['id']?.toString() ??
            '';
        final backendRoomName = backendRoom['name']?.toString() ?? '';
        final loxoneRoomId = backendRoom['loxone_room_id']?.toString();

        if (backendRoomId.isEmpty || backendRoomName.isEmpty) continue;

        // Find matching room by name (case-insensitive)
        // Match against the room name from SVG, not backend name
        final matchingRoomIndex = rooms.indexWhere(
          (room) =>
              room.name.toLowerCase().trim() ==
              backendRoomName.toLowerCase().trim(),
        );

        if (matchingRoomIndex != -1) {
          final room = rooms[matchingRoomIndex];

          // Don't update the SVG room - keep it as is
          // Just store backend room ID mapping for edit/delete operations
          _backendRoomIds[room.id] = backendRoomId;
          if (loxoneRoomId != null && loxoneRoomId.isNotEmpty) {
            _loxoneRoomIds[room.id] = loxoneRoomId;
          }

          // Keep the SVG room name and color as they are
          // Don't update controller with backend name
        }
      }
    });
  }

  Future<void> _decodeImageDimensions(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      setState(() {
        _backgroundImageBytes = imageBytes;
        _backgroundImageWidth = image.width.toDouble();
        _backgroundImageHeight = image.height.toDouble();
        _updateCanvasSize();
      });

      image.dispose();
    } catch (e) {
      debugPrint('Error decoding image: $e');
    }
  }

  Path _parseSVGPath(String pathData) {
    final path = Path();
    final commands = _parsePathCommands(pathData);

    double currentX = 0;
    double currentY = 0;

    for (final cmd in commands) {
      switch (cmd.command.toUpperCase()) {
        case 'M':
          if (cmd.coordinates.length >= 2) {
            currentX = cmd.coordinates[0];
            currentY = cmd.coordinates[1];
            path.moveTo(currentX, currentY);
          }
          break;
        case 'L':
          if (cmd.coordinates.length >= 2) {
            currentX = cmd.coordinates[0];
            currentY = cmd.coordinates[1];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'H':
          if (cmd.coordinates.isNotEmpty) {
            currentX = cmd.coordinates[0];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'V':
          if (cmd.coordinates.isNotEmpty) {
            currentY = cmd.coordinates[0];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'C':
          if (cmd.coordinates.length >= 6) {
            path.cubicTo(
              cmd.coordinates[0],
              cmd.coordinates[1],
              cmd.coordinates[2],
              cmd.coordinates[3],
              cmd.coordinates[4],
              cmd.coordinates[5],
            );
            currentX = cmd.coordinates[4];
            currentY = cmd.coordinates[5];
          }
          break;
        case 'Q':
          if (cmd.coordinates.length >= 4) {
            path.quadraticBezierTo(
              cmd.coordinates[0],
              cmd.coordinates[1],
              cmd.coordinates[2],
              cmd.coordinates[3],
            );
            currentX = cmd.coordinates[2];
            currentY = cmd.coordinates[3];
          }
          break;
        case 'Z':
        case 'z':
          path.close();
          break;
      }
    }

    return path;
  }

  List<_PathCommand> _parsePathCommands(String pathData) {
    final commands = <_PathCommand>[];
    final regex = RegExp(r'([MmLlHhVvCcQqZz])\s*([-\d.e]+(?:\s+[-\d.e]+)*)?');

    for (final match in regex.allMatches(pathData)) {
      final command = match.group(1)!;
      final coordsStr = match.group(2);

      List<double> coordinates = [];
      if (coordsStr != null) {
        coordinates = coordsStr
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((s) => double.tryParse(s.trim()) ?? 0)
            .toList();
      }

      commands.add(_PathCommand(command, coordinates));
    }

    return commands;
  }

  Color? _hexToColor(String hex) {
    try {
      hex = hex.trim();
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return null;
    }
  }

  void _showEditRoomDialog(Room room) {
    final backendRoomId = _backendRoomIds[room.id];
    if (backendRoomId == null) return;

    final nameController = TextEditingController(text: room.name);
    Color selectedColor = room.fillColor;
    bool isLoading = false;
    String? selectedLoxoneRoomId = _loxoneRoomIds[room.id];
    String? selectedLoxoneRoomName;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Function to show Loxone room selector
          Future<void> showLoxoneRoomSelector() async {
            if (_buildingId == null || _buildingId!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Building ID is required to select Loxone room',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            final result = await showDialog<Map<String, String>?>(
              context: context,
              barrierDismissible: true,
              builder: (loxoneDialogContext) => BlocProvider(
                create: (_) => sl<GetLoxoneRoomsBloc>(),
                child: _LoxoneRoomSelectionDialog(
                  selectedRoomName: nameController.text,
                  roomColor: selectedColor,
                  buildingId: _buildingId!,
                ),
              ),
            );

            if (result != null && mounted) {
              setDialogState(() {
                selectedLoxoneRoomId = result['id'];
                selectedLoxoneRoomName = result['name'];
              });
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            title: const Text('Edit Room'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room name field
                  const Text(
                    'Room Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'Room Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Color selection
                  const Text(
                    'Color:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colorPalette.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.grey,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Loxone Room Selection
                  const Text(
                    'Loxone Room',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: showLoxoneRoomSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black54, width: 2),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Row(
                        children: [
                          if (selectedLoxoneRoomName != null) ...[
                            Text(
                              selectedLoxoneRoomName!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Select Loxone room',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              StatefulBuilder(
                builder: (context, setButtonState) => isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PrimaryOutlineButton(
                        label: "Save",
                        width: 100,
                        onPressed: isLoading
                            ? null
                            : () async {
                                setButtonState(() {
                                  isLoading = true;
                                });

                                try {
                                  await _updateRoomInBackend(
                                    backendRoomId,
                                    nameController.text.trim(),
                                    selectedColor,
                                    loxoneRoomId: selectedLoxoneRoomId,
                                  );

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    setState(() {
                                      // Update room in local state
                                      final roomIndex = rooms.indexWhere(
                                        (r) => r.id == room.id,
                                      );
                                      if (roomIndex != -1) {
                                        rooms[roomIndex] = Room(
                                          id: room.id,
                                          path: room.path,
                                          doorOpenings: room.doorOpenings,
                                          fillColor: selectedColor,
                                          name: nameController.text.trim(),
                                        );
                                        if (_roomControllers.containsKey(
                                          room.id,
                                        )) {
                                          _roomControllers[room.id]!.text =
                                              nameController.text.trim();
                                        }
                                        // Update Loxone room ID mapping
                                        if (selectedLoxoneRoomId != null) {
                                          _loxoneRoomIds[room.id] =
                                              selectedLoxoneRoomId;
                                        }
                                      }
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error updating room: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setButtonState(() {
                                      isLoading = false;
                                    });
                                  }
                                }
                              },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateRoomInBackend(
    String backendRoomId,
    String name,
    Color color, {
    String? loxoneRoomId,
  }) async {
    try {
      final requestBody = {
        'name': name,
        'color': _colorToHex(color),
        if (loxoneRoomId != null) 'loxone_room_id': loxoneRoomId,
      };

      final response = await _dioClient.dio.patch(
        '/api/v1/floors/rooms/$backendRoomId',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to update room: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error updating room: $e');
      rethrow;
    }
  }

  Future<void> _showLinkToLoxoneDialog(Room room) async {
    if (_buildingId == null || _buildingId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Building ID is required to select Loxone room'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => BlocProvider(
        create: (_) => sl<GetLoxoneRoomsBloc>(),
        child: _LoxoneRoomSelectionDialog(
          selectedRoomName: room.name,
          roomColor: room.fillColor,
          buildingId: _buildingId!,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _loxoneRoomIds[room.id] = result;
      });

      // Update room in backend with loxone_room_id
      final backendRoomId = _backendRoomIds[room.id];
      if (backendRoomId != null) {
        _updateRoomLoxoneIdInBackend(backendRoomId, result);
      }
    }
  }

  Future<void> _updateRoomLoxoneIdInBackend(
    String backendRoomId,
    String loxoneRoomId,
  ) async {
    try {
      final requestBody = {'loxone_room_id': loxoneRoomId};

      final response = await _dioClient.dio.patch(
        '/api/v1/floors/rooms/$backendRoomId',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room linked to Loxone successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to link room: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error linking room to Loxone: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error linking room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoomFromBackend(Room room) async {
    final backendRoomId = _backendRoomIds[room.id];
    if (backendRoomId == null) return;

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete "${room.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final response = await _dioClient.dio.delete(
        '/api/v1/floors/rooms/$backendRoomId',
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          setState(() {
            _roomControllers[room.id]?.dispose();
            _roomControllers.remove(room.id);
            _backendRoomIds.remove(room.id);
            _loxoneRoomIds.remove(room.id);
            doors.removeWhere((door) => door.roomId == room.id);
            rooms.remove(room);
            if (selectedRoom == room) {
              selectedRoom = null;
            }
            _updateCanvasSize();
          });
        } else {
          throw Exception('Failed to delete room: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createRoomInBackend(
    Room room, {
    bool showSuccessMessage = true,
  }) async {
    // Check if room already exists in backend
    if (_backendRoomIds.containsKey(room.id)) {
      return; // Already exists, skip
    }

    try {
      final requestBody = {
        'name': room.name,
        'color': _colorToHex(room.fillColor),
        if (_loxoneRoomIds[room.id] != null)
          'loxone_room_id': _loxoneRoomIds[room.id],
      };

      final response = await _dioClient.dio.post(
        '/api/v1/floors/${widget.floorId}/rooms',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = response.data;
          String? newBackendRoomId;

          if (responseData is Map<String, dynamic>) {
            if (responseData['data'] != null) {
              final roomData = responseData['data'] as Map<String, dynamic>;
              newBackendRoomId =
                  roomData['_id']?.toString() ?? roomData['id']?.toString();
            } else {
              newBackendRoomId =
                  responseData['_id']?.toString() ??
                  responseData['id']?.toString();
            }
          }

          if (newBackendRoomId != null && newBackendRoomId.isNotEmpty) {
            setState(() {
              _backendRoomIds[room.id] = newBackendRoomId!;
            });
          }

          if (showSuccessMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Room created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Failed to create room: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error creating room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  /// Public method to create all new rooms in the backend
  /// Called when saving the floor plan
  Future<void> createNewRoomsInBackend() async {
    final newRooms = rooms
        .where((room) => !_backendRoomIds.containsKey(room.id))
        .toList();

    if (newRooms.isEmpty) {
      return; // No new rooms to create
    }

    int successCount = 0;
    int failureCount = 0;

    for (final room in newRooms) {
      try {
        // Don't show individual success messages when creating multiple rooms
        await _createRoomInBackend(room, showSuccessMessage: false);
        successCount++;
      } catch (e) {
        debugPrint('Failed to create room ${room.name}: $e');
        failureCount++;
        // Continue with other rooms even if one fails
      }
    }

    // Show summary message
    if (mounted) {
      if (failureCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount > 1
                  ? '$successCount rooms created successfully'
                  : 'Room created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Created $successCount room(s), failed to create $failureCount room(s)',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _updateCanvasSize() {
    if (_backgroundImageBytes != null &&
        _backgroundImageWidth != null &&
        _backgroundImageHeight != null) {
      _canvasSize = Size(_backgroundImageWidth!, _backgroundImageHeight!);
      return;
    }

    if (rooms.isEmpty && doors.isEmpty) {
      _canvasSize = const Size(4000, 4000);
      return;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final room in rooms) {
      final bounds = room.path.getBounds();
      minX = math.min(minX, bounds.left);
      minY = math.min(minY, bounds.top);
      maxX = math.max(maxX, bounds.right);
      maxY = math.max(maxY, bounds.bottom);
    }

    for (final door in doors) {
      final bounds = door.path.getBounds();
      minX = math.min(minX, bounds.left);
      minY = math.min(minY, bounds.top);
      maxX = math.max(maxX, bounds.right);
      maxY = math.max(maxY, bounds.bottom);
    }

    const padding = 200.0;
    final width = (maxX - minX + padding * 2).clamp(2000.0, 20000.0);
    final height = (maxY - minY + padding * 2).clamp(2000.0, 20000.0);

    _canvasSize = Size(math.max(width, 4000), math.max(height, 4000));
  }

  void _saveState() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    final state = _FloorPlanState(
      rooms: rooms
          .map(
            (room) => Room(
              id: room.id,
              path: Path.from(room.path),
              doorOpenings: room.doorOpenings.map((p) => Path.from(p)).toList(),
              fillColor: room.fillColor,
              name: room.name,
            ),
          )
          .toList(),
      doors: doors
          .map(
            (door) => Door(
              id: door.id,
              path: Path.from(door.path),
              rotation: door.rotation,
              roomId: door.roomId,
              edge: door.edge,
            ),
          )
          .toList(),
      roomCounter: _roomCounter,
    );

    _history.add(state);
    _historyIndex = _history.length - 1;

    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void _restoreState(_FloorPlanState state) {
    for (final controller in _roomControllers.values) {
      controller.dispose();
    }
    _roomControllers.clear();

    rooms.clear();
    doors.clear();

    for (final room in state.rooms) {
      final restoredRoom = Room(
        id: room.id,
        path: Path.from(room.path),
        doorOpenings: room.doorOpenings.map((p) => Path.from(p)).toList(),
        fillColor: room.fillColor,
        name: room.name,
      );
      rooms.add(restoredRoom);
      _roomControllers[restoredRoom.id] = TextEditingController(
        text: restoredRoom.name,
      );
    }

    for (final door in state.doors) {
      doors.add(
        Door(
          id: door.id,
          path: Path.from(door.path),
          rotation: door.rotation,
          roomId: door.roomId,
          edge: door.edge,
        ),
      );
    }

    _roomCounter = state.roomCounter;
    selectedRoom = null;
    selectedDoor = null;
    _updateCanvasSize();
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _restoreState(_history[_historyIndex]);
      setState(() {});
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _restoreState(_history[_historyIndex]);
      setState(() {});
    }
  }

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex < _history.length - 1;

  // Shape creation methods (reuse from FloorPlanBackupPage)
  // Helper to check if background image exists
  bool get _hasBackgroundImage =>
      _backgroundImageBytes != null ||
      (widget.initialFloorPlanUrl != null &&
          widget.initialFloorPlanUrl!.isNotEmpty);

  Path createRectangle(Offset o, {double width = 100, double height = 75}) {
    return Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + width, o.dy)
      ..lineTo(o.dx + width, o.dy + height)
      ..lineTo(o.dx, o.dy + height)
      ..close();
  }

  // Create rectangle from two points (for drawing mode)
  Path createRectangleFromPoints(Offset start, Offset end) {
    final rect = Rect.fromPoints(start, end);
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  Path createTriangle(Offset o, {double width = 100, double height = 90}) {
    return Path()
      ..moveTo(o.dx + (width / 2), o.dy)
      ..lineTo(o.dx + width, o.dy + height)
      ..lineTo(o.dx, o.dy + height)
      ..close();
  }

  Path createCircle(Offset center, {double radius = 50}) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  void _addShapeToCanvas(Path Function() shapeCreator) {
    _saveState();
    setState(() {
      final newPath = shapeCreator();
      final newRoom = Room(
        id: UniqueKey().toString(),
        path: newPath,
        fillColor: selectedColor ?? colorPalette[0],
        name: 'Room $_roomCounter',
      );
      rooms.add(newRoom);
      _roomControllers[newRoom.id] = TextEditingController(text: newRoom.name);
      _roomCounter++;
      _updateCanvasSize();
    });
  }

  void selectRoom(Offset pos) {
    if (polygonMode) return;

    for (final d in doors.reversed) {
      if (d.path.contains(pos)) {
        setState(() {
          selectedDoor = d;
          selectedRoom = null;
          activeHandle = null;
        });
        return;
      }
    }

    for (final r in rooms.reversed) {
      if (r.path.contains(pos)) {
        setState(() {
          selectedRoom = r;
          selectedDoor = null;
          activeHandle = null;
        });
        return;
      }
    }
    setState(() {
      selectedRoom = null;
      selectedDoor = null;
      activeHandle = null;
    });
  }

  void moveSelected(Offset delta) {
    if (selectedRoom != null) {
      setState(() {
        selectedRoom!.path = selectedRoom!.path.shift(delta);
        for (var i = 0; i < selectedRoom!.doorOpenings.length; i++) {
          selectedRoom!.doorOpenings[i] = selectedRoom!.doorOpenings[i].shift(
            delta,
          );
        }
        for (final door in doors) {
          if (door.roomId == selectedRoom!.id) {
            door.path = door.path.shift(delta);
          }
        }
      });
    } else if (selectedDoor != null) {
      setState(() {
        selectedDoor!.path = selectedDoor!.path.shift(delta);
      });
    }
  }

  ResizeHandle? hitTestHandle(Offset pos, Rect bounds) {
    const size = 12.0;
    final handles = {
      ResizeHandle.topLeft: Rect.fromLTWH(
        bounds.left - size,
        bounds.top - size,
        size * 2,
        size * 2,
      ),
      ResizeHandle.topRight: Rect.fromLTWH(
        bounds.right - size,
        bounds.top - size,
        size * 2,
        size * 2,
      ),
      ResizeHandle.bottomLeft: Rect.fromLTWH(
        bounds.left - size,
        bounds.bottom - size,
        size * 2,
        size * 2,
      ),
      ResizeHandle.bottomRight: Rect.fromLTWH(
        bounds.right - size,
        bounds.bottom - size,
        size * 2,
        size * 2,
      ),
    };

    for (final e in handles.entries) {
      if (e.value.contains(pos)) return e.key;
    }
    return null;
  }

  Path scalePath(Path path, double sx, double sy, Offset anchor) {
    final matrix = Matrix4.identity()
      ..translate(anchor.dx, anchor.dy)
      ..scale(sx, sy)
      ..translate(-anchor.dx, -anchor.dy);
    return path.transform(matrix.storage);
  }

  void resizeRoom(Offset delta) {
    if (selectedRoom == null || activeHandle == null || startBounds == null)
      return;

    final bounds = startBounds!;

    double sx = 1, sy = 1;
    Offset anchor = bounds.center;

    if (activeHandle == ResizeHandle.bottomRight) {
      sx = (bounds.width + delta.dx) / bounds.width;
      sy = (bounds.height + delta.dy) / bounds.height;
      anchor = bounds.topLeft;
    } else if (activeHandle == ResizeHandle.topLeft) {
      sx = (bounds.width - delta.dx) / bounds.width;
      sy = (bounds.height - delta.dy) / bounds.height;
      anchor = bounds.bottomRight;
    } else if (activeHandle == ResizeHandle.topRight) {
      sx = (bounds.width + delta.dx) / bounds.width;
      sy = (bounds.height - delta.dy) / bounds.height;
      anchor = bounds.bottomLeft;
    } else if (activeHandle == ResizeHandle.bottomLeft) {
      sx = (bounds.width - delta.dx) / bounds.width;
      sy = (bounds.height + delta.dy) / bounds.height;
      anchor = bounds.topRight;
    }

    if (sx > 0.2 && sy > 0.2) {
      selectedRoom!.path = scalePath(selectedRoom!.path, sx, sy, anchor);

      for (var i = 0; i < selectedRoom!.doorOpenings.length; i++) {
        selectedRoom!.doorOpenings[i] = scalePath(
          selectedRoom!.doorOpenings[i],
          sx,
          sy,
          anchor,
        );
      }

      for (final door in doors) {
        if (door.roomId == selectedRoom!.id) {
          door.path = scalePath(door.path, sx, sy, anchor);
        }
      }
    }

    setState(() {});
  }

  void _handlePolygonClick(Offset position) {
    if (_polygonPoints.isNotEmpty) {
      final firstPoint = _polygonPoints[0];
      final distance = (position - firstPoint).distance;
      if (distance < 15.0 && _polygonPoints.length >= 2) {
        _createRoomFromPolygon();
        return;
      }
    }

    setState(() {
      _polygonPoints.add(position);
      _polygonPreviewPosition = null;
    });
  }

  void _createRoomFromPolygon() {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Polygon must have at least 3 points'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final path = Path();
    path.moveTo(_polygonPoints[0].dx, _polygonPoints[0].dy);
    for (int i = 1; i < _polygonPoints.length; i++) {
      path.lineTo(_polygonPoints[i].dx, _polygonPoints[i].dy);
    }
    path.close();

    _saveState();
    final roomId = UniqueKey().toString();
    final roomName = 'Room $_roomCounter';

    setState(() {
      rooms.add(
        Room(
          id: roomId,
          path: path,
          fillColor: selectedColor ?? colorPalette[0],
          name: roomName,
        ),
      );
      _roomCounter++;
      _polygonPoints.clear();
      _polygonPreviewPosition = null;
      polygonMode = false;
      _showShapeOptions = false;
      _roomControllers[roomId] = TextEditingController(text: roomName);
      _updateCanvasSize();
    });
  }

  void _cancelPolygon() {
    setState(() {
      _polygonPoints.clear();
      _polygonPreviewPosition = null;
      polygonMode = false;
      _drawingMode = DrawingMode.none;
    });
  }

  void _createRoomFromRectangle(Rect rect) {
    if (rect.isEmpty || rect.width < 10 || rect.height < 10) return;

    _saveState();
    final path = createRectangleFromPoints(rect.topLeft, rect.bottomRight);
    final roomId = UniqueKey().toString();
    final roomName = 'Room $_roomCounter';

    setState(() {
      rooms.add(
        Room(
          id: roomId,
          path: path,
          fillColor: selectedColor ?? colorPalette[0],
          name: roomName,
        ),
      );
      _roomCounter++;
      selectedRoom = rooms.last;
      _currentRectangle = null;
      _rectangleStart = null;
      _updateCanvasSize();
      // Create controller for new room
      _roomControllers[roomId] = TextEditingController(text: roomName);
    });
  }

  Widget _shapeOptionButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(0),
        ),
        child: SvgPicture.asset(
          icon,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.1,
          maxScale: 4,
          child: Stack(
            children: [
              // Background SVG image if available
              if (widget.initialFloorPlanUrl != null &&
                  widget.initialFloorPlanUrl!.isNotEmpty &&
                  _backgroundImageBytes == null)
                Positioned.fill(
                  child: SvgPicture.network(
                    widget.initialFloorPlanUrl!,
                    fit: BoxFit.contain,
                    placeholderBuilder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              // Background image from bytes
              if (_backgroundImageBytes != null &&
                  _backgroundImageWidth != null &&
                  _backgroundImageHeight != null)
                Positioned(
                  left: 0,
                  top: 0,
                  width: _backgroundImageWidth,
                  height: _backgroundImageHeight,
                  child: Image.memory(
                    _backgroundImageBytes!,
                    fit: BoxFit.none,
                    alignment: Alignment.topLeft,
                  ),
                ),
              // Canvas with rooms and doors
              GestureDetector(
                onTapDown: (d) {
                  if (_drawingMode == DrawingMode.polygon || polygonMode) {
                    _handlePolygonClick(d.localPosition);
                  } else if (_drawingMode == DrawingMode.rectangle) {
                    // Rectangle drawing will be handled in onPanStart
                  } else if (!pencilMode) {
                    selectRoom(d.localPosition);
                  }
                },
                onPanStart: (d) {
                  lastPanPosition = d.localPosition;
                  if (_drawingMode == DrawingMode.rectangle) {
                    // Start rectangle drawing
                    setState(() {
                      _rectangleStart = d.localPosition;
                      _currentRectangle = Rect.fromPoints(
                        d.localPosition,
                        d.localPosition,
                      );
                    });
                  } else if (pencilMode) {
                    drawingPath = Path()
                      ..moveTo(d.localPosition.dx, d.localPosition.dy);
                  } else if (polygonMode ||
                      _drawingMode == DrawingMode.polygon) {
                    setState(() {
                      _polygonPreviewPosition = d.localPosition;
                    });
                  } else {
                    final bounds = selectedRoom?.path.getBounds();
                    if (bounds != null) {
                      activeHandle = hitTestHandle(d.localPosition, bounds);
                      startBounds = bounds;
                    }
                  }
                },
                onPanUpdate: (d) {
                  if (_drawingMode == DrawingMode.rectangle &&
                      _rectangleStart != null) {
                    // Update rectangle preview
                    setState(() {
                      _currentRectangle = Rect.fromPoints(
                        _rectangleStart!,
                        d.localPosition,
                      );
                    });
                  } else if (pencilMode) {
                    setState(() {
                      drawingPath!.lineTo(
                        d.localPosition.dx,
                        d.localPosition.dy,
                      );
                    });
                  } else if (polygonMode ||
                      _drawingMode == DrawingMode.polygon) {
                    setState(() {
                      _polygonPreviewPosition = d.localPosition;
                    });
                  } else if (activeHandle != null) {
                    resizeRoom(d.delta);
                  } else if (selectedRoom != null || selectedDoor != null) {
                    moveSelected(d.delta);
                  }
                },
                onPanEnd: (d) {
                  if (_drawingMode == DrawingMode.rectangle &&
                      _currentRectangle != null) {
                    // Create room from rectangle
                    _createRoomFromRectangle(_currentRectangle!);
                    setState(() {
                      _rectangleStart = null;
                      _currentRectangle = null;
                      _drawingMode = DrawingMode.none;
                    });
                  } else {
                    final hadActiveOperation =
                        activeHandle != null ||
                        (selectedRoom != null && lastPanPosition != null) ||
                        (selectedDoor != null && lastPanPosition != null);
                    if (!pencilMode && hadActiveOperation) {
                      _saveState();
                    }
                    activeHandle = null;
                    startBounds = null;
                    lastPanPosition = null;
                    if (pencilMode && drawingPath != null) {
                      setState(() {
                        final closedPath = Path.from(drawingPath!)..close();
                        final newRoom = Room(
                          id: UniqueKey().toString(),
                          path: closedPath,
                          fillColor: selectedColor ?? colorPalette[0],
                          name: 'Room $_roomCounter',
                        );
                        rooms.add(newRoom);
                        _roomControllers[newRoom.id] = TextEditingController(
                          text: newRoom.name,
                        );
                        _roomCounter++;
                        drawingPath = null;
                        _updateCanvasSize();
                      });
                    }
                  }
                },
                child: CustomPaint(
                  size: _canvasSize,
                  painter: FloorPainter(
                    rooms: rooms,
                    doors: doors,
                    selectedRoom: selectedRoom,
                    selectedDoor: selectedDoor,
                    previewPath: drawingPath,
                    hasBackgroundImage:
                        _backgroundImageBytes != null ||
                        (widget.initialFloorPlanUrl != null &&
                            widget.initialFloorPlanUrl!.isNotEmpty),
                    polygonPoints: _polygonPoints,
                    polygonPreviewPosition: _polygonPreviewPosition,
                    polygonColor: selectedColor ?? colorPalette[0],
                    currentRectangle: _currentRectangle,
                    rectangleColor: selectedColor ?? colorPalette[0],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Canvas Area with dotted border (from floor_plan_backup.dart lines 1169-1222)
        DottedBorderContainer(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child:
                      (rooms.isEmpty &&
                          _backgroundImageBytes == null &&
                          widget.initialFloorPlanUrl == null &&
                          !polygonMode &&
                          !pencilMode)
                      ? const Center()
                      : _buildCanvas(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Shape Options (shown when Add Room is clicked)
        if (_showShapeOptions) _shapeOptionsBar(),
        // Polygon completion buttons
        if (polygonMode && _polygonPoints.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16, top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_polygonPoints.length >= 3)
                  ElevatedButton.icon(
                    onPressed: _createRoomFromPolygon,
                    icon: const Icon(Icons.check),
                    label: const Text('Complete Polygon'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (_polygonPoints.length >= 3) const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _cancelPolygon,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        // Add Room Button
        InkWell(
          onTap: () {
            setState(() {
              _showShapeOptions = !_showShapeOptions;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '+ Add Room',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Room List with TextField and Color Palette (from floor_plan_backup.dart lines 1311-1456)
        if (rooms.isNotEmpty)
          ...rooms.map((room) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(0),
                border: Border.all(
                  color: selectedRoom == room ? Colors.blue : Colors.grey[300]!,
                  width: selectedRoom == room ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // TextField for room name
                  Expanded(
                    child: TextField(
                      key: ValueKey(room.id),
                      readOnly: _backendRoomIds.containsKey(room.id),
                      controller: _roomControllers[room.id] ??=
                          TextEditingController(text: room.name),
                      decoration: const InputDecoration(
                        hintText: 'Room name',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          room.name = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Color palette
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: colorPalette.map((color) {
                      final isSelected = room.fillColor == color;
                      return GestureDetector(
                        onTap: () {
                          if (!_backendRoomIds.containsKey(room.id)) {
                            _saveState();
                            setState(() {
                              room.fillColor = color;
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey[400]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.clear,
                                  size: 12,
                                  color: Colors.black,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 8),
                  // Edit button (only for rooms with backend ID)
                  (_backendRoomIds.containsKey(room.id))
                      ? IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Colors.blue[600],
                            size: 20,
                          ),
                          tooltip: 'Edit',
                          onPressed: () {
                            _showEditRoomDialog(room);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.link_outlined,
                            color: Colors.blue[600],
                            size: 20,
                          ),
                          tooltip: 'Link to Loxone',
                          onPressed: () {
                            _showLinkToLoxoneDialog(room);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                  const SizedBox(width: 4),
                  // Delete button
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[600],
                      size: 20,
                    ),
                    tooltip: 'Delete',
                    onPressed: () {
                      if (_backendRoomIds.containsKey(room.id)) {
                        // Delete from backend
                        _deleteRoomFromBackend(room);
                      } else {
                        // Just remove from local state
                        _saveState();
                        setState(() {
                          _roomControllers[room.id]?.dispose();
                          _roomControllers.remove(room.id);
                          _backendRoomIds.remove(room.id);
                          _loxoneRoomIds.remove(room.id);
                          doors.removeWhere((door) => door.roomId == room.id);
                          rooms.remove(room);
                          if (selectedRoom == room) {
                            selectedRoom = null;
                          }
                          _updateCanvasSize();
                        });
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _shapeOptionsBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(),
          Row(
            children: [
              _shapeOptionButton(
                icon: 'assets/images/Pen.svg',
                label: "Polygon",
                onTap: () {
                  setState(() {
                    _selectedShapeTool = _ShapeTool.polygon;
                    if (_hasBackgroundImage) {
                      // Use drawing mode when background image exists
                      if (_drawingMode == DrawingMode.polygon) {
                        _drawingMode = DrawingMode.none;
                        polygonMode = false;
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      } else {
                        _drawingMode = DrawingMode.polygon;
                        polygonMode = true;
                        pencilMode = false;
                        drawingPath = null;
                        doorPlacementMode = false;
                        _rectangleStart = null;
                        _currentRectangle = null;
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      }
                    } else {
                      // Toggle polygon mode (original behavior)
                      polygonMode = !polygonMode;
                      if (polygonMode) {
                        pencilMode = false;
                        drawingPath = null;
                        doorPlacementMode = false;
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      } else {
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      }
                    }
                    selectedRoom = null;
                  });
                },
                isSelected:
                    polygonMode ||
                    _drawingMode == DrawingMode.polygon ||
                    _selectedShapeTool == _ShapeTool.polygon,
              ),
              _shapeOptionButton(
                icon: 'assets/images/Rectangle.svg',
                label: "Rectangle",
                onTap: () {
                  if (_hasBackgroundImage) {
                    // Use drawing mode when background image exists
                    setState(() {
                      _selectedShapeTool = _ShapeTool.rectangle;
                      if (_drawingMode == DrawingMode.rectangle) {
                        _drawingMode = DrawingMode.none;
                      } else {
                        _drawingMode = DrawingMode.rectangle;
                        polygonMode = false;
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      }
                      _rectangleStart = null;
                      _currentRectangle = null;
                      selectedRoom = null;
                    });
                  } else {
                    // Create immediately when no background image
                    setState(() {
                      _selectedShapeTool = _ShapeTool.rectangle;
                      polygonMode = false;
                      _drawingMode = DrawingMode.none;
                    });
                    _addShapeToCanvas(
                      () => createRectangle(const Offset(200, 200)),
                    );
                  }
                },
                isSelected:
                    _drawingMode == DrawingMode.rectangle ||
                    _selectedShapeTool == _ShapeTool.rectangle,
              ),
              _shapeOptionButton(
                icon: 'assets/images/Triangle.svg',
                label: "Triangle",
                onTap: () {
                  setState(() {
                    _selectedShapeTool = _ShapeTool.triangle;
                    polygonMode = false;
                    _drawingMode = DrawingMode.none;
                    _polygonPoints.clear();
                    _polygonPreviewPosition = null;
                  });
                  _addShapeToCanvas(
                    () => createTriangle(const Offset(200, 200)),
                  );
                },
                isSelected: _selectedShapeTool == _ShapeTool.triangle,
              ),
              _shapeOptionButton(
                icon: 'assets/images/Ellipse.svg',
                label: "Circle",
                onTap: () {
                  setState(() {
                    _selectedShapeTool = _ShapeTool.circle;
                    polygonMode = false;
                    _drawingMode = DrawingMode.none;
                    _polygonPoints.clear();
                    _polygonPreviewPosition = null;
                  });
                  _addShapeToCanvas(
                    () => createCircle(const Offset(200, 200), radius: 50),
                  );
                },
                isSelected: _selectedShapeTool == _ShapeTool.circle,
              ),
              const SizedBox(width: 8),
            ],
          ),
          // Undo/Redo buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: _canUndo ? _undo : null,
                child: SvgPicture.asset(
                  'assets/images/Undo.svg',
                  color: _canUndo ? Colors.black87 : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _canRedo ? _redo : null,
                child: SvgPicture.asset(
                  'assets/images/Redo.svg',
                  color: _canRedo ? Colors.black87 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget that connects to WebSocket and displays live sensor values for a room.
class _RoomRealtimeSensorsSection extends StatefulWidget {
  final String roomId;
  final List<dynamic> sensors;

  const _RoomRealtimeSensorsSection({
    required this.roomId,
    required this.sensors,
  });

  @override
  State<_RoomRealtimeSensorsSection> createState() =>
      _RoomRealtimeSensorsSectionState();
}

class _RoomRealtimeSensorsSectionState
    extends State<_RoomRealtimeSensorsSection> {
  @override
  void initState() {
    super.initState();
    _connectAndSubscribe();
  }

  @override
  void dispose() {
    context.read<RealtimeSensorBloc>().add(
      const RealtimeSensorDisconnectRequested(),
    );
    super.dispose();
  }

  Future<void> _connectAndSubscribe() async {
    final token = await sl<TokenService>().getAccessToken();
    if (token == null || token.isEmpty) return;
    context.read<RealtimeSensorBloc>().add(
      RealtimeSensorConnectRequested(token),
    );
    context.read<RealtimeSensorBloc>().add(
      RealtimeSensorSubscribeToRoom(widget.roomId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RealtimeSensorBloc, RealtimeSensorState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                  onPressed: () {
                    context.pushNamed(
                      Routelists.editRoom,
                      queryParameters: {'roomId': widget.roomId},
                    );
                  },
                  child: Text(
                    'Configure sensors in the room',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live room sensors',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Streaming real-time values from all connected sensors in this room.',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ConnectionStatusIndicator(status: state.status),
                ],
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.red[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          context.read<RealtimeSensorBloc>().add(
                            const RealtimeSensorReconnectRequested(),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (widget.sensors.isEmpty)
                Text(
                  'No sensors in this room.',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.grey[700],
                  ),
                )
              else
                ...widget.sensors.map((s) {
                  final sensorId = (s is Map) ? s['_id']?.toString() : null;
                  final name = (s is Map)
                      ? s['name']?.toString() ?? 'Sensor'
                      : 'Sensor';
                  final realtimeValue = sensorId != null
                      ? state.getSensorValue(sensorId)
                      : null;
                  final formattedValue = realtimeValue != null
                      ? '${LocaleNumberFormat.formatNum(
                          realtimeValue.value,
                          locale: context.locale,
                          decimalDigits: 3,
                          fallback: '–',
                        )}${realtimeValue.unit.isNotEmpty ? ' ${realtimeValue.unit}' : ''}'
                      : '—';
                  final hasLiveValue = realtimeValue != null;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: hasLiveValue
                            ? const Color(0xFF22C55E).withOpacity(0.4)
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildSvgIcon(
                          _assetSensor,
                          color: hasLiveValue
                              ? const Color(0xFF38BDF8)
                              : Colors.grey[600],
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formattedValue,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: hasLiveValue
                                ? const Color(0xFF22C55E)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionStatusIndicator extends StatelessWidget {
  final RealtimeConnectionStatus status;

  const _ConnectionStatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case RealtimeConnectionStatus.connected:
      case RealtimeConnectionStatus.subscribed:
        color = const Color(0xFF22C55E);
        label = 'Live';
        break;
      case RealtimeConnectionStatus.connecting:
      case RealtimeConnectionStatus.reconnecting:
        color = const Color(0xFFFBBF24);
        label = 'Connecting...';
        break;
      case RealtimeConnectionStatus.error:
        color = const Color(0xFFFB7185);
        label = 'Disconnected';
        break;
      default:
        color = Colors.grey[500]!;
        label = 'Offline';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                if (status == RealtimeConnectionStatus.connected ||
                    status == RealtimeConnectionStatus.subscribed)
                  BoxShadow(
                    color: color.withOpacity(0.7),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog widget for Loxone room selection
class _LoxoneRoomSelectionDialog extends StatefulWidget {
  final String selectedRoomName;
  final Color roomColor;
  final String buildingId;

  const _LoxoneRoomSelectionDialog({
    required this.selectedRoomName,
    required this.roomColor,
    required this.buildingId,
  });

  @override
  State<_LoxoneRoomSelectionDialog> createState() =>
      _LoxoneRoomSelectionDialogState();
}

class _LoxoneRoomSelectionDialogState
    extends State<_LoxoneRoomSelectionDialog> {
  String? _selectedSource;
  bool _hasFetched = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<dynamic> _filterRooms(List<dynamic> rooms, String query) {
    if (query.isEmpty) {
      return rooms;
    }
    return rooms.where((room) {
      final roomName = room.name?.toString().toLowerCase() ?? '';
      return roomName.contains(query);
    }).toList();
  }

  void _handleContinue() {
    if (_selectedSource != null) {
      // Find the room name from the rooms list
      String? roomName;
      if (context.read<GetLoxoneRoomsBloc>().state is GetLoxoneRoomsSuccess) {
        final state =
            context.read<GetLoxoneRoomsBloc>().state as GetLoxoneRoomsSuccess;
        final selectedRoom = state.rooms.firstWhere(
          (room) => room.id == _selectedSource,
          orElse: () => state.rooms.first,
        );
        roomName = selectedRoom.name;
      }
      Navigator.of(
        context,
      ).pop({'id': _selectedSource!, 'name': roomName ?? ''});
    } else {
      Navigator.of(context).pop();
    }
  }

  void _toggleSource(String source) {
    setState(() {
      _selectedSource = _selectedSource == source ? null : source;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocListener<GetLoxoneRoomsBloc, GetLoxoneRoomsState>(
      listener: (context, state) {
        if (state is GetLoxoneRoomsFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Builder(
        builder: (blocContext) {
          if (!_hasFetched && widget.buildingId.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                blocContext.read<GetLoxoneRoomsBloc>().add(
                  GetLoxoneRoomsSubmitted(buildingId: widget.buildingId),
                );
                _hasFetched = true;
              }
            });
          }

          return BlocBuilder<GetLoxoneRoomsBloc, GetLoxoneRoomsState>(
            builder: (context, state) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(16),
                child: Container(
                  width: screenSize.width < 600
                      ? screenSize.width
                      : screenSize.width < 1200
                      ? screenSize.width * 0.5
                      : screenSize.width * 0.5,
                  constraints: BoxConstraints(
                    maxHeight: screenSize.height * 0.9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title Row with Close Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Select Loxone Room',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Room Input Field
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black54, width: 2),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '+ ${widget.selectedRoomName}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: widget.roomColor,
                                  border: Border.all(
                                    color: Colors.black54,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Scrollable Data Source Options
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // Search Field
                                if (state is GetLoxoneRoomsSuccess &&
                                    state.rooms.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black54,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: _onSearchChanged,
                                      decoration: InputDecoration(
                                        hintText: 'Search...',
                                        hintStyle: AppTextStyles.bodyMedium
                                            .copyWith(color: Colors.grey),
                                        border: InputBorder.none,
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          color: Colors.black54,
                                        ),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  color: Colors.black54,
                                                ),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  _onSearchChanged('');
                                                },
                                              )
                                            : null,
                                      ),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                if (state is GetLoxoneRoomsLoading)
                                  const Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(),
                                  )
                                else if (state is GetLoxoneRoomsSuccess) ...[
                                  if (_filterRooms(
                                    state.rooms,
                                    _searchQuery,
                                  ).isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'No results found',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    ..._filterRooms(
                                      state.rooms,
                                      _searchQuery,
                                    ).map((room) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: _buildCheckboxOption(
                                          room.id,
                                          room.name,
                                        ),
                                      );
                                    }).toList(),
                                ] else if (state is GetLoxoneRoomsFailure)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Error loading rooms: ${state.message}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.red,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No rooms available',
                                      style: AppTextStyles.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Material(
                          color: Colors.transparent,
                          child: PrimaryOutlineButton(
                            label: 'Select',
                            width: 260,
                            onPressed: _handleContinue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCheckboxOption(String key, String label) {
    final isSelected = _selectedSource == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleSource(key),
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54, width: 1),
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            children: [
              XCheckBox(
                value: isSelected,
                onChanged: (value) => _toggleSource(key),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper class for parsing SVG path commands
class _PathCommand {
  final String command;
  final List<double> coordinates;

  _PathCommand(this.command, this.coordinates);
}
