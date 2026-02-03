import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

class DashboardMainContent extends StatefulWidget {
  final String? verseId;
  final String? selectedReportId;

  const DashboardMainContent({super.key, this.verseId, this.selectedReportId});

  @override
  State<DashboardMainContent> createState() => _DashboardMainContentState();
}

class _DashboardMainContentState extends State<DashboardMainContent> {
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
          // Use default if loading fails
          if (mounted) {
            setState(() {
              _userFirstName = 'User';
            });
          }
        },
        (user) {
          if (mounted && user != null) {
            setState(() {
              _userFirstName = user.firstName.isNotEmpty
                  ? user.firstName
                  : 'User';
            });
          }
        },
      );
    } catch (e) {
      // Use default on error
      if (mounted) {
        setState(() {
          _userFirstName = 'User';
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

  Widget _buildSiteDropdown(DashboardSitesSuccess sitesState) {
    final detailsState = context.watch<DashboardSiteDetailsBloc>().state;
    String? selectedSiteId;
    if (detailsState is DashboardSiteDetailsLoading) {
      selectedSiteId = detailsState.siteId;
    } else if (detailsState is DashboardSiteDetailsSuccess) {
      selectedSiteId = detailsState.siteId;
    } else if (detailsState is DashboardSiteDetailsFailure) {
      selectedSiteId = detailsState.siteId;
    }

    final value = selectedSiteId ?? sitesState.sites.first.id;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              labelText: 'Select site',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: sitesState.sites
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              context.read<DashboardSiteDetailsBloc>().add(
                DashboardSiteDetailsRequested(siteId: id),
              );
            },
          ),
        ),
      ],
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
              Text(
                d.name,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                d.address,
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _kpiTile(label: 'Buildings', value: '${d.buildingCount}'),
                  _kpiTile(label: 'Floors', value: '${d.totalFloors}'),
                  _kpiTile(label: 'Rooms', value: '${d.totalRooms}'),
                  _kpiTile(label: 'Sensors', value: '${d.totalSensors}'),
                ],
              ),
              const SizedBox(height: 16),
              if (kpis != null) ...[
                Text(
                  'KPIs (${kpis.unit})',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiTile(
                      label: 'Total',
                      value: kpis.totalConsumption.toStringAsFixed(3),
                    ),
                    _kpiTile(
                      label: 'Peak',
                      value: kpis.peak.toStringAsFixed(3),
                    ),
                    _kpiTile(
                      label: 'Base',
                      value: kpis.base.toStringAsFixed(3),
                    ),
                    _kpiTile(
                      label: 'Average',
                      value: kpis.average.toStringAsFixed(3),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Buildings',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
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
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.apartment,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  style: AppTextStyles.titleSmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${b.sensorCount} sensors',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
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
          Text(
            'Room Details',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(d.color.replaceFirst('#', '0xFF')),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (d.loxoneRoomId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Loxone: ${d.loxoneRoomId!.name}',
                              style: AppTextStyles.titleSmall.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiTile(label: 'Sensors', value: '${d.sensorCount}'),
                  ],
                ),
                if (kpis != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'KPIs (${kpis.unit})',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _kpiTile(
                        label: 'Total',
                        value: kpis.totalConsumption.toStringAsFixed(3),
                      ),
                      _kpiTile(
                        label: 'Peak',
                        value: kpis.peak.toStringAsFixed(3),
                      ),
                      _kpiTile(
                        label: 'Base',
                        value: kpis.base.toStringAsFixed(3),
                      ),
                      _kpiTile(
                        label: 'Average',
                        value: kpis.average.toStringAsFixed(3),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
          Text(
            'Floor Details',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiTile(label: 'Rooms', value: '${d.roomCount}'),
                    _kpiTile(label: 'Sensors', value: '${d.sensorCount}'),
                  ],
                ),
                if (kpis != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'KPIs (${kpis.unit})',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _kpiTile(
                        label: 'Total',
                        value: kpis.totalConsumption.toStringAsFixed(3),
                      ),
                      _kpiTile(
                        label: 'Peak',
                        value: kpis.peak.toStringAsFixed(3),
                      ),
                      _kpiTile(
                        label: 'Base',
                        value: kpis.base.toStringAsFixed(3),
                      ),
                      _kpiTile(
                        label: 'Average',
                        value: kpis.average.toStringAsFixed(3),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
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
                const SizedBox(height: 8),
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
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Color(
                                  int.parse(
                                    room.color.replaceFirst('#', '0xFF'),
                                  ),
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                room.name,
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              '${room.sensorCount} sensors',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Building Details',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (d.typeOfUse != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${d.typeOfUse}',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiTile(label: 'Floors', value: '${d.floorCount}'),
                    _kpiTile(label: 'Rooms', value: '${d.roomCount}'),
                    _kpiTile(label: 'Sensors', value: '${d.sensorCount}'),
                    if (d.buildingSize != null)
                      _kpiTile(label: 'Size', value: '${d.buildingSize} m²'),
                    if (d.yearOfConstruction != null)
                      _kpiTile(label: 'Year', value: '${d.yearOfConstruction}'),
                  ],
                ),
                if (kpis != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'KPIs (${kpis.unit})',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _kpiTile(
                        label: 'Total',
                        value: kpis.totalConsumption.toStringAsFixed(3),
                      ),
                      _kpiTile(
                        label: 'Peak',
                        value: kpis.peak.toStringAsFixed(3),
                      ),
                      _kpiTile(
                        label: 'Base',
                        value: kpis.base.toStringAsFixed(3),
                      ),
                      _kpiTile(
                        label: 'Average',
                        value: kpis.average.toStringAsFixed(3),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Floors',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
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
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.layers,
                              color: AppTheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    floor.name,
                                    style: AppTextStyles.titleSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${floor.roomCount} rooms',
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

  Widget _kpiTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
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
            width: 220,
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
                  width: 220,
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
            // TODO: Navigate to add building page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.main_content.add_building'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
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
