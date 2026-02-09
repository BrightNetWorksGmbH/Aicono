import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_building_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_floor_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/building_reports_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/trigger_report_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/report_detail_view.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/features/FloorPlan/presentation/pages/floor_plan_backup.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_plan_step.dart'
    show DottedBorderContainer;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert' show base64Decode;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart' as xml;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../../../core/routing/routeLists.dart';

class DashboardMainContent extends StatefulWidget {
  final String? verseId;
  final String? selectedReportId;

  const DashboardMainContent({super.key, this.verseId, this.selectedReportId});

  @override
  State<DashboardMainContent> createState() => _DashboardMainContentState();
}

class _DashboardMainContentState extends State<DashboardMainContent> {
  String? _userFirstName;
  String? _userName; // Full name for navigation

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final loginRepository = sl<LoginRepository>();
      final userResult = await loginRepository.getCurrentUser();

      userResult.fold(
        (failure) {
          // Use default if loading fails
          if (mounted) {
            setState(() {
              _userFirstName = 'User';
              _userName = 'User';
            });
          }
        },
        (user) {
          if (mounted && user != null) {
            setState(() {
              _userFirstName = user.firstName.isNotEmpty
                  ? user.firstName
                  : 'User';
              // Construct userName from firstName and lastName
              final firstName = user.firstName.isNotEmpty ? user.firstName : '';
              final lastName = user.lastName.isNotEmpty ? user.lastName : '';
              _userName = '$firstName $lastName'.trim();
              if (_userName!.isEmpty) {
                _userName = 'User';
              }
            });
          }
        },
      );
    } catch (e) {
      // Use default on error
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeSection(),

          const SizedBox(height: 24),

          // Selected Item Details (Site/Building/Floor/Room)
          _buildSelectedItemDetails(),

          const SizedBox(height: 32),

          // Trigger Manual Report Button
          _buildTriggerManualReportButton(),

          const SizedBox(height: 32),

          // "Was brauchst Du gerade?" Section
          _buildActionLinksSection(),
        ],
      ),
    );
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
                    DashboardSiteDetailsRequested(siteId: state.siteId),
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
                metricCards: [
                  _buildPropertyMetricCard(
                    label: 'Buildings',
                    value: '${d.buildingCount}',
                    icon: Icons.apartment,
                  ),
                  _buildPropertyMetricCard(
                    label: 'Rooms',
                    value: '${d.totalRooms}',
                    icon: Icons.door_front_door,
                  ),
                  _buildPropertyMetricCard(
                    label: 'Sensors',
                    value: '${d.totalSensors}',
                    icon: Icons.sensors,
                  ),
                  _buildPropertyMetricCard(
                    label: 'Floors',
                    value: '${d.totalFloors}',
                    icon: Icons.layers,
                  ),
                ],
              ),
              if (kpis != null) ...[
                const SizedBox(height: 32),
                _buildPropertyKpiSection(
                  title: 'Site KPIs',
                  subtitle:
                      'Aggregate energy performance and load metrics for the current period. ${kpis.unit}',
                  kpis: kpis,
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Buildings',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a building from the sidebar to view details.',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
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
                        : 'Total: ${bk.totalConsumption.toStringAsFixed(3)} ${bk.unit}';
                    return _buildPropertyListItem(
                      icon: Icons.apartment,
                      title: b.name,
                      subtitle: '${b.floorCount} floors · $subtitle',
                      trailing: '${b.sensorCount} sensors',
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
                  DashboardRoomDetailsRequested(roomId: state.roomId),
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPropertyOverviewSection(
            title: d.name,
            address: d.loxoneRoomId != null
                ? 'Loxone: ${d.loxoneRoomId!.name}'
                : null,
            onEdit: () {
              context.pushNamed(
                Routelists.editRoom,
                queryParameters: {'roomId': state.roomId},
              );
            },
            metricCards: [
              _buildPropertyMetricCard(
                label: 'Sensors',
                value: '${d.sensorCount}',
                icon: Icons.sensors,
              ),
            ],
          ),
          if (kpis != null) ...[
            const SizedBox(height: 32),
            _buildPropertyKpiSection(
              title: 'Room KPIs',
              subtitle:
                  'Energy performance and load metrics for the current period. ${kpis.unit}',
              kpis: kpis,
            ),
          ],
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
                  DashboardFloorDetailsRequested(floorId: state.floorId),
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPropertyOverviewSection(
            title: d.name,
            onEdit: () {
              context.pushNamed(
                Routelists.editFloor,
                queryParameters: {'floorId': state.floorId},
              );
            },
            metricCards: [
              _buildPropertyMetricCard(
                label: 'Rooms',
                value: '${d.roomCount}',
                icon: Icons.door_front_door,
              ),
              _buildPropertyMetricCard(
                label: 'Sensors',
                value: '${d.sensorCount}',
                icon: Icons.sensors,
              ),
            ],
          ),
          if (kpis != null) ...[
            const SizedBox(height: 32),
            _buildPropertyKpiSection(
              title: 'Floor KPIs',
              subtitle:
                  'Aggregate energy performance and load metrics for the current period. ${kpis.unit}',
              kpis: kpis,
            ),
          ],
          const SizedBox(height: 24),
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
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 400),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildFloorPlanImage(d.floorPlanLink!),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Rooms',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a room from the sidebar to view details.',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
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
                        icon: Icons.door_front_door,
                        title: room.name,
                        subtitle: null,
                        trailing: '${room.sensorCount} sensors',
                        iconColor: roomColor,
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

      final metricCards = <Widget>[
        _buildPropertyMetricCard(
          label: 'Floors',
          value: '${d.floorCount}',
          icon: Icons.layers,
        ),
        _buildPropertyMetricCard(
          label: 'Rooms',
          value: '${d.roomCount}',
          icon: Icons.door_front_door,
        ),
        _buildPropertyMetricCard(
          label: 'Sensors',
          value: '${d.sensorCount}',
          icon: Icons.sensors,
        ),
      ];
      if (d.buildingSize != null) {
        metricCards.add(
          _buildPropertyMetricCard(
            label: 'Size (m²)',
            value: '${d.buildingSize}',
            icon: Icons.square_foot,
          ),
        );
      }

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
            metricCards: metricCards,
          ),
          if (kpis != null) ...[
            const SizedBox(height: 32),
            _buildPropertyKpiSection(
              title: 'Building KPIs',
              subtitle:
                  'Aggregate energy performance and load metrics for the current period. ${kpis.unit}',
              kpis: kpis,
            ),
          ],
          const SizedBox(height: 24),
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
                const SizedBox(height: 4),
                Text(
                  'Select a floor from the sidebar to view details.',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
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
                        icon: Icons.layers,
                        title: floor.name,
                        subtitle: '${floor.roomCount} rooms',
                        trailing: sensorCount > 0 ? '$sensorCount sensors' : null,
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

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: child,
    );
  }

  static const Color _metricIconTeal = Color(0xFF00897B);

  Widget _buildPropertyListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailing,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? _metricIconTeal;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              color: effectiveColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: effectiveColor, size: 22),
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
                  const SizedBox(height: 4),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailing,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyMetricCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 4),
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
            child: Icon(icon, color: _metricIconTeal, size: 22),
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
                    const SizedBox(height: 4),
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
            if (onEdit != null)
              TextButton(
                onPressed: onEdit,
                child: Text(
                  'Edit',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            if (isNarrow) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: metricCards
                    .map(
                      (w) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: w,
                      ),
                    )
                    .toList(),
              );
            }
            return Row(
              children: [
                for (int i = 0; i < metricCards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: metricCards[i]),
                ],
              ],
            );
          },
        ),
      ],
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
          borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 4),
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
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            if (isNarrow) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: _buildKpiMetricCard(
                      label: 'Total',
                      value: kpis.totalConsumption.toStringAsFixed(3),
                      indicatorColor: const Color(0xFF64B5F6),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: _buildKpiMetricCard(
                      label: 'Peak',
                      value: kpis.peak.toStringAsFixed(3),
                      indicatorColor: const Color(0xFFFFB74D),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: _buildKpiMetricCard(
                      label: 'Average',
                      value: kpis.average.toStringAsFixed(3),
                      indicatorColor: const Color(0xFFFFEE58),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: _buildKpiMetricCard(
                      label: 'Base',
                      value: kpis.base.toStringAsFixed(3),
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
                    value: kpis.totalConsumption.toStringAsFixed(3),
                    indicatorColor: const Color(0xFF64B5F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiMetricCard(
                    label: 'Peak',
                    value: kpis.peak.toStringAsFixed(3),
                    indicatorColor: const Color(0xFFFFB74D),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiMetricCard(
                    label: 'Average',
                    value: kpis.average.toStringAsFixed(3),
                    indicatorColor: const Color(0xFFFFEE58),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiMetricCard(
                    label: 'Base',
                    value: kpis.base.toStringAsFixed(3),
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
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 8),
        _buildActionLink(
          text: 'dashboard.main_content.add_building'.tr(),
          onTap: () {
            // Get siteId from DashboardSiteDetailsBloc
            final siteDetailsState = context
                .read<DashboardSiteDetailsBloc>()
                .state;
            String? siteId;
            if (siteDetailsState is DashboardSiteDetailsLoading) {
              siteId = siteDetailsState.siteId;
            } else if (siteDetailsState is DashboardSiteDetailsSuccess) {
              siteId = siteDetailsState.siteId;
            } else if (siteDetailsState is DashboardSiteDetailsFailure) {
              siteId = siteDetailsState.siteId;
            }

            // If no siteId from details, try to get from sites list
            if (siteId == null) {
              final sitesState = context.read<DashboardSitesBloc>().state;
              if (sitesState is DashboardSitesSuccess &&
                  sitesState.sites.isNotEmpty) {
                siteId = sitesState.sites.first.id;
              }
            }

            // Navigate to add additional buildings page
            if (siteId != null && siteId.isNotEmpty) {
              context.pushNamed(
                Routelists.addAdditionalBuildings,
                queryParameters: {
                  if (_userName != null && _userName!.isNotEmpty)
                    'userName': _userName!,
                  if (widget.verseId != null && widget.verseId!.isNotEmpty)
                    'switchId': widget.verseId!,
                  'siteId': siteId,
                  'fromDashboard':
                      'true', // Flag to indicate navigation from dashboard
                },
              );
            } else {
              // Show error if no site is selected
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please select a site first to add a building.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        _buildActionLink(
          text: 'dashboard.main_content.add_room'.tr(),
          onTap: () {
            // TODO: Navigate to add room page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.main_content.add_room'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionLink(
          text: 'dashboard.main_content.add_branding'.tr(),
          onTap: () {
            // TODO: Navigate to branding page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.main_content.add_branding'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
          },
        ),
      ],
    );
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

  const FloorPlanEditorWrapper({
    required this.floorId,
    required this.floorName,
    this.initialFloorPlanUrl,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<FloorPlanEditorWrapper> createState() => _FloorPlanEditorWrapperState();
}

class _FloorPlanEditorWrapperState extends State<FloorPlanEditorWrapper> {
  @override
  Widget build(BuildContext context) {
    // Use the simplified floor plan editor that shows only canvas and room list
    return SimplifiedFloorPlanEditor(
      initialFloorPlanUrl: widget.initialFloorPlanUrl,
      onSave: widget.onSave,
      onCancel: widget.onCancel,
    );
  }
}

// Simplified Floor Plan Editor - Shows only canvas (with dotted border) and room list
// This extracts the canvas and room list UI from FloorPlanBackupPage
class SimplifiedFloorPlanEditor extends StatefulWidget {
  final String? initialFloorPlanUrl;
  final Function(String?) onSave;
  final VoidCallback onCancel;

  const SimplifiedFloorPlanEditor({
    this.initialFloorPlanUrl,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<SimplifiedFloorPlanEditor> createState() =>
      _SimplifiedFloorPlanEditorState();
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

class _SimplifiedFloorPlanEditorState extends State<SimplifiedFloorPlanEditor> {
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
    } catch (e) {
      debugPrint('Error parsing SVG: $e');
    }
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
                      controller: _roomControllers[room.id] ??=
                          TextEditingController(text: room.name),
                      decoration: const InputDecoration(
                        hintText: 'Room name / Label',
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
                          _saveState();
                          setState(() {
                            room.fillColor = color;
                          });
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
                  // Delete button
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[600],
                      size: 20,
                    ),
                    tooltip: 'Delete',
                    onPressed: () {
                      _saveState();
                      setState(() {
                        _roomControllers[room.id]?.dispose();
                        _roomControllers.remove(room.id);
                        doors.removeWhere((door) => door.roomId == room.id);
                        rooms.remove(room);
                        if (selectedRoom == room) {
                          selectedRoom = null;
                        }
                        _updateCanvasSize();
                      });
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

// Helper class for parsing SVG path commands
class _PathCommand {
  final String command;
  final List<double> coordinates;

  _PathCommand(this.command, this.coordinates);
}
