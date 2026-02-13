import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/switch_role_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/switch_switching_dialog.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_item_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_view_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_building_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_floor_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_details_filter.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/report_sidebar_section.dart';

class DashboardSidebar extends StatefulWidget {
  const DashboardSidebar({
    super.key,
    this.showBackToDashboard = false,
    this.activeSection,
    this.isInDrawer = false,
    this.onLanguageChanged,
    this.onSwitchSelected,
    this.onReportSelected,
    this.onPropertySelected,
    this.showSwitchSwitcher = true,
    this.verseId,
    this.roles,
    this.dashboardFilter,
  });

  /// Show a "back to dashboard" link at the top when used outside the dashboard page
  final bool showBackToDashboard;

  /// Bold the active page in settings section: 'settings' | 'links' | 'statistics'
  final String? activeSection;

  /// Whether the sidebar is being used in a drawer (affects width)
  final bool isInDrawer;

  /// Callback for when language changes (to trigger dashboard rebuild)
  final VoidCallback? onLanguageChanged;

  /// Callback when user selects a different organization (bryteswitch). Parent should save selected ID and reload dashboard.
  final ValueChanged<String>? onSwitchSelected;

  /// Callback when user selects a report (reportId) or clears selection (null). Parent should show report detail in main content.
  final ValueChanged<String?>? onReportSelected;

  /// Callback when user selects a property (site, building, floor, or room). Parent can clear report selection so main content shows property detail.
  final VoidCallback? onPropertySelected;

  /// Whether to show the switch/organization switcher in the Companies section (default true).
  final bool showSwitchSwitcher;

  /// Optional current verse/switch ID from parent (e.g. dashboard). When provided, sidebar stays in sync when parent switches.
  final String? verseId;

  /// Optional roles (switches) from parent. When provided, uses these instead of loading from cache - ensures fresh data after profile/switch settings update.
  final List<SwitchRoleEntity>? roles;

  /// Optional date filter for dashboard property APIs (sites/buildings/floors/rooms). Same style as report (startDate/endDate).
  final DashboardDetailsFilter? dashboardFilter;

  @override
  State<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends State<DashboardSidebar> {
  String? currentVerseId;
  List<SwitchRoleEntity> _roles = [];
  String? _userName; // Full name for navigation

  @override
  void initState() {
    super.initState();
    _loadVerseId();
    _applyRoles(widget.roles);
    if (widget.roles == null) {
      _loadUserAndRoles();
    }
  }

  @override
  void didUpdateWidget(DashboardSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.verseId != oldWidget.verseId && widget.verseId != null) {
      setState(() => currentVerseId = widget.verseId);
    }
    if (widget.roles != oldWidget.roles) {
      _applyRoles(widget.roles);
      if (widget.roles == null) {
        _loadUserAndRoles();
      }
    }
  }

  void _applyRoles(List<SwitchRoleEntity>? roles) {
    if (roles == null) return;
    if (mounted) {
      setState(() => _roles = roles);
    }
  }

  void _loadVerseId() {
    final localStorage = sl<LocalStorage>();
    final savedVerseId = localStorage.getSelectedVerseId();
    setState(() {
      currentVerseId = savedVerseId;
    });
  }

  Future<void> _loadUserAndRoles() async {
    try {
      final loginRepository = sl<LoginRepository>();
      final userResult = await loginRepository.getCurrentUser();
      userResult.fold((_) {}, (user) {
        if (user != null && mounted) {
          setState(() {
            _roles = user.roles;
            // Keep currentVerseId in sync with saved
            currentVerseId = sl<LocalStorage>().getSelectedVerseId();
            // Construct userName from firstName and lastName
            final firstName = user.firstName.isNotEmpty ? user.firstName : '';
            final lastName = user.lastName.isNotEmpty ? user.lastName : '';
            _userName = '$firstName $lastName'.trim();
            if (_userName!.isEmpty) {
              _userName = 'User';
            }
          });
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isInDrawer ? null : 310,
      padding: EdgeInsets.all(widget.isInDrawer ? 16 : 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back to Dashboard button (when showBackToDashboard is true)
            if (widget.showBackToDashboard) ...[
              InkWell(
                onTap: () => context.pushNamed(Routelists.dashboard),
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Back to Dashboard',
                    style: AppTextStyles.titleSmall.copyWith(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Divider(height: 20, thickness: 1, color: Color(0x40000000)),
              const SizedBox(height: 8),
            ],
            // Deine Liegenschaften (Your Properties)
            _buildPropertiesSection(),

            const SizedBox(height: 16),

            // Deine Reportings (Your Reportings)
            _buildReportingsSection(),

            const SizedBox(height: 16),

            // Deine Unternehmen (Your Companies)
            _buildVerseSection(),

            const SizedBox(height: 16),

            // Settings Section
            _buildSettingsSection(),

            const SizedBox(height: 24),

            // Profile and Language options (for mobile/drawer)
            if (widget.isInDrawer) ...[
              _buildProfileSection(),
              const SizedBox(height: 16),
              _buildLanguageSection(),
              const SizedBox(height: 16),
            ],

            // Logout Button
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            // Clear selection when clicking on section title
            context.read<DashboardSiteDetailsBloc>().add(
              DashboardSiteDetailsReset(),
            );
            context.read<DashboardBuildingDetailsBloc>().add(
              DashboardBuildingDetailsReset(),
            );
            context.read<DashboardFloorDetailsBloc>().add(
              DashboardFloorDetailsReset(),
            );
            context.read<DashboardRoomDetailsBloc>().add(
              DashboardRoomDetailsReset(),
            );
          },
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            'dashboard.sidebar.properties'.tr(),
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Color(0x40000000)),
        BlocBuilder<DashboardSitesBloc, DashboardSitesState>(
          builder: (context, sitesState) {
            if (sitesState is DashboardSitesLoading ||
                sitesState is DashboardSitesInitial) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Loading sites...',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              );
            }

            if (sitesState is DashboardSitesFailure) {
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

            if (sitesState is DashboardSitesSuccess) {
              final siteDetailsState = context
                  .watch<DashboardSiteDetailsBloc>()
                  .state;
              final buildingDetailsState = context
                  .watch<DashboardBuildingDetailsBloc>()
                  .state;
              final floorDetailsState = context
                  .watch<DashboardFloorDetailsBloc>()
                  .state;
              context.watch<DashboardRoomDetailsBloc>().state;

              // Get selected IDs
              String? selectedSiteId;
              String? selectedBuildingId;
              String? selectedFloorId;

              if (siteDetailsState is DashboardSiteDetailsLoading ||
                  siteDetailsState is DashboardSiteDetailsSuccess ||
                  siteDetailsState is DashboardSiteDetailsFailure) {
                if (siteDetailsState is DashboardSiteDetailsLoading) {
                  selectedSiteId = siteDetailsState.siteId;
                } else if (siteDetailsState is DashboardSiteDetailsSuccess) {
                  selectedSiteId = siteDetailsState.siteId;
                } else if (siteDetailsState is DashboardSiteDetailsFailure) {
                  selectedSiteId = siteDetailsState.siteId;
                }
              }

              if (buildingDetailsState is DashboardBuildingDetailsLoading ||
                  buildingDetailsState is DashboardBuildingDetailsSuccess ||
                  buildingDetailsState is DashboardBuildingDetailsFailure) {
                if (buildingDetailsState is DashboardBuildingDetailsLoading) {
                  selectedBuildingId = buildingDetailsState.buildingId;
                } else if (buildingDetailsState
                    is DashboardBuildingDetailsSuccess) {
                  selectedBuildingId = buildingDetailsState.buildingId;
                } else if (buildingDetailsState
                    is DashboardBuildingDetailsFailure) {
                  selectedBuildingId = buildingDetailsState.buildingId;
                }
              }

              if (floorDetailsState is DashboardFloorDetailsLoading ||
                  floorDetailsState is DashboardFloorDetailsSuccess ||
                  floorDetailsState is DashboardFloorDetailsFailure) {
                if (floorDetailsState is DashboardFloorDetailsLoading) {
                  selectedFloorId = floorDetailsState.floorId;
                } else if (floorDetailsState is DashboardFloorDetailsSuccess) {
                  selectedFloorId = floorDetailsState.floorId;
                } else if (floorDetailsState is DashboardFloorDetailsFailure) {
                  selectedFloorId = floorDetailsState.floorId;
                }
              }

              // Compute add-button label from selection: nothing → Add site; site → Add building; building → Add floor; floor → Add room
              String propertyAddLabel;
              if (selectedFloorId != null) {
                propertyAddLabel = 'dashboard.sidebar.add_room'.tr();
              } else if (selectedBuildingId != null) {
                propertyAddLabel = 'dashboard.sidebar.add_floor'.tr();
              } else if (selectedSiteId != null) {
                propertyAddLabel = 'dashboard.sidebar.add_building'.tr();
              } else {
                propertyAddLabel = 'dashboard.sidebar.add_site'.tr();
              }

              // Build tree items
              final items = sitesState.sites.map((site) {
                List<TreeItemEntity> buildingChildren = [];

                // If site is selected (even if loading), show buildings when available
                if (selectedSiteId == site.id) {
                  if (siteDetailsState is DashboardSiteDetailsSuccess) {
                    final buildings = siteDetailsState.details.buildings;
                    buildingChildren = buildings.map((building) {
                      List<TreeItemEntity> floorChildren = [];

                      // If this building is selected and we have building details, show floors
                      if (selectedBuildingId == building.id &&
                          buildingDetailsState
                              is DashboardBuildingDetailsSuccess) {
                        final floors = buildingDetailsState.details.floors;
                        floorChildren = floors.map((floor) {
                          List<TreeItemEntity> roomChildren = [];

                          // If this floor is selected and we have floor details, show rooms
                          if (selectedFloorId == floor.id &&
                              floorDetailsState
                                  is DashboardFloorDetailsSuccess) {
                            final rooms = floorDetailsState.details.rooms;
                            roomChildren = rooms.map((room) {
                              return TreeItemEntity(
                                id: room.id,
                                name: room.name,
                                type: 'property',
                              );
                            }).toList();
                          } else if (selectedFloorId == floor.id &&
                              floorDetailsState
                                  is DashboardFloorDetailsLoading) {
                            // Show loading indicator or empty for loading state
                          } else if (floor.rooms.isNotEmpty) {
                            // Show rooms from site details if available
                            roomChildren = floor.rooms.map((room) {
                              return TreeItemEntity(
                                id: room.id,
                                name: room.name,
                                type: 'property',
                              );
                            }).toList();
                          }

                          return TreeItemEntity(
                            id: floor.id,
                            name: floor.name,
                            type: 'property',
                            children: roomChildren,
                          );
                        }).toList();
                      } else if (selectedBuildingId == building.id &&
                          buildingDetailsState
                              is DashboardBuildingDetailsLoading) {
                        // Show loading indicator or empty for loading state
                      } else if (building.floors.isNotEmpty) {
                        // Show floors from site details if available
                        floorChildren = building.floors.map((floor) {
                          final roomChildren = floor.rooms.map((room) {
                            return TreeItemEntity(
                              id: room.id,
                              name: room.name,
                              type: 'property',
                            );
                          }).toList();

                          return TreeItemEntity(
                            id: floor.id,
                            name: floor.name,
                            type: 'property',
                            children: roomChildren,
                          );
                        }).toList();
                      }

                      return TreeItemEntity(
                        id: building.id,
                        name: building.name,
                        type: 'property',
                        children: floorChildren,
                      );
                    }).toList();
                  } else if (siteDetailsState is DashboardSiteDetailsLoading) {
                    // While loading, show empty children so the site appears expandable
                    // This ensures the tree expands on first click
                    buildingChildren = [];
                  }
                }

                // Make site appear expandable if it has buildings
                // If site is selected and loading, show loading placeholder
                // This ensures it expands on first click
                final hasBuildings = site.buildingCount > 0;
                final isSelectedAndLoading =
                    selectedSiteId == site.id &&
                    siteDetailsState is DashboardSiteDetailsLoading;

                return TreeItemEntity(
                  id: site.id,
                  name: site.name,
                  type: 'property',
                  // If site has buildings and is selected/loading, show loading placeholder
                  // This makes it expandable on first click
                  // When details load, buildingChildren will be populated
                  children:
                      hasBuildings &&
                          buildingChildren.isEmpty &&
                          isSelectedAndLoading
                      ? [
                          TreeItemEntity(
                            id: '${site.id}_loading',
                            name: 'Loading...',
                            type: 'property',
                          ),
                        ]
                      : buildingChildren,
                );
              }).toList();

              return TreeViewWidget(
                items: items,
                autoExpandItemId: selectedSiteId,
                onItemTap: (item) {
                  // Check if it's a site
                  final isSite = sitesState.sites.any((s) => s.id == item.id);
                  if (isSite) {
                    widget.onPropertySelected?.call();
                    context.read<DashboardSiteDetailsBloc>().add(
                      DashboardSiteDetailsRequested(
                        siteId: item.id,
                        filter: widget.dashboardFilter,
                      ),
                    );
                    // Reset other selections
                    context.read<DashboardBuildingDetailsBloc>().add(
                      DashboardBuildingDetailsReset(),
                    );
                    context.read<DashboardFloorDetailsBloc>().add(
                      DashboardFloorDetailsReset(),
                    );
                    context.read<DashboardRoomDetailsBloc>().add(
                      DashboardRoomDetailsReset(),
                    );
                    return;
                  }

                  // Check if it's a building
                  if (siteDetailsState is DashboardSiteDetailsSuccess) {
                    final isBuilding = siteDetailsState.details.buildings.any(
                      (b) => b.id == item.id,
                    );
                    if (isBuilding) {
                      widget.onPropertySelected?.call();
                      context.read<DashboardBuildingDetailsBloc>().add(
                        DashboardBuildingDetailsRequested(
                          buildingId: item.id,
                          filter: widget.dashboardFilter,
                        ),
                      );
                      // Reset floor and room selections
                      context.read<DashboardFloorDetailsBloc>().add(
                        DashboardFloorDetailsReset(),
                      );
                      context.read<DashboardRoomDetailsBloc>().add(
                        DashboardRoomDetailsReset(),
                      );
                      return;
                    }

                    // Check if it's a floor
                    for (final building in siteDetailsState.details.buildings) {
                      final isFloor = building.floors.any(
                        (f) => f.id == item.id,
                      );
                      if (isFloor) {
                        widget.onPropertySelected?.call();
                        context.read<DashboardFloorDetailsBloc>().add(
                          DashboardFloorDetailsRequested(
                            floorId: item.id,
                            filter: widget.dashboardFilter,
                          ),
                        );
                        // Reset room selection
                        context.read<DashboardRoomDetailsBloc>().add(
                          DashboardRoomDetailsReset(),
                        );
                        return;
                      }
                    }

                    // Check if it's a room
                    for (final building in siteDetailsState.details.buildings) {
                      for (final floor in building.floors) {
                        final isRoom = floor.rooms.any((r) => r.id == item.id);
                        if (isRoom) {
                          widget.onPropertySelected?.call();
                          context.read<DashboardRoomDetailsBloc>().add(
                            DashboardRoomDetailsRequested(
                              roomId: item.id,
                              filter: widget.dashboardFilter,
                            ),
                          );
                          return;
                        }
                      }
                    }
                  }

                  // Also check building details state for floors/rooms
                  if (buildingDetailsState is DashboardBuildingDetailsSuccess) {
                    final isFloor = buildingDetailsState.details.floors.any(
                      (f) => f.id == item.id,
                    );
                    if (isFloor) {
                      widget.onPropertySelected?.call();
                      context.read<DashboardFloorDetailsBloc>().add(
                        DashboardFloorDetailsRequested(
                          floorId: item.id,
                          filter: widget.dashboardFilter,
                        ),
                      );
                      context.read<DashboardRoomDetailsBloc>().add(
                        DashboardRoomDetailsReset(),
                      );
                      return;
                    }

                    for (final floor in buildingDetailsState.details.floors) {
                      final isRoom = floor.rooms.any((r) => r.id == item.id);
                      if (isRoom) {
                        widget.onPropertySelected?.call();
                        context.read<DashboardRoomDetailsBloc>().add(
                          DashboardRoomDetailsRequested(
                            roomId: item.id,
                            filter: widget.dashboardFilter,
                          ),
                        );
                        return;
                      }
                    }
                  }

                  // Check floor details state for rooms
                  if (floorDetailsState is DashboardFloorDetailsSuccess) {
                    final isRoom = floorDetailsState.details.rooms.any(
                      (r) => r.id == item.id,
                    );
                    if (isRoom) {
                      widget.onPropertySelected?.call();
                      context.read<DashboardRoomDetailsBloc>().add(
                        DashboardRoomDetailsRequested(
                          roomId: item.id,
                          filter: widget.dashboardFilter,
                        ),
                      );
                      return;
                    }
                  }
                },
                onAddItem: () {
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
                  if (propertyAddLabel ==
                      'dashboard.sidebar.add_building'.tr()) {
                    // Navigate to add additional buildings page
                    if (siteId != null && siteId.isNotEmpty) {
                      context.pushNamed(
                        Routelists.addAdditionalBuildings,
                        queryParameters: {
                          if (_userName != null && _userName!.isNotEmpty)
                            'userName': _userName!,
                          if (widget.verseId != null &&
                              widget.verseId!.isNotEmpty)
                            'switchId': widget.verseId!,
                          'siteId': siteId,
                          'fromDashboard':
                              'true', // Flag to indicate navigation from dashboard
                        },
                      );
                    } else {
                      // Show error if siteId is not available
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please select a site first to add a building.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  } else if (propertyAddLabel ==
                      'dashboard.sidebar.add_floor'.tr()) {
                    // Get buildingId and siteId from DashboardBuildingDetailsBloc
                    final buildingDetailsState = context
                        .read<DashboardBuildingDetailsBloc>()
                        .state;
                    String? buildingId;

                    if (buildingDetailsState
                            is DashboardBuildingDetailsLoading ||
                        buildingDetailsState
                            is DashboardBuildingDetailsSuccess ||
                        buildingDetailsState
                            is DashboardBuildingDetailsFailure) {
                      if (buildingDetailsState
                          is DashboardBuildingDetailsLoading) {
                        buildingId = buildingDetailsState.buildingId;
                      } else if (buildingDetailsState
                          is DashboardBuildingDetailsSuccess) {
                        buildingId = buildingDetailsState.buildingId;
                      } else if (buildingDetailsState
                          is DashboardBuildingDetailsFailure) {
                        buildingId = buildingDetailsState.buildingId;
                      }
                    }

                    // If no buildingId from details, try to get from site details
                    if (buildingId == null) {
                      final siteDetailsState = context
                          .read<DashboardSiteDetailsBloc>()
                          .state;
                      if (siteDetailsState is DashboardSiteDetailsLoading ||
                          siteDetailsState is DashboardSiteDetailsSuccess ||
                          siteDetailsState is DashboardSiteDetailsFailure) {
                        if (siteDetailsState is DashboardSiteDetailsLoading) {
                          siteId = siteId ?? siteDetailsState.siteId;
                        } else if (siteDetailsState
                            is DashboardSiteDetailsSuccess) {
                          siteId = siteId ?? siteDetailsState.siteId;
                        } else if (siteDetailsState
                            is DashboardSiteDetailsFailure) {
                          siteId = siteId ?? siteDetailsState.siteId;
                        }
                      }
                    }

                    // Navigate to add floor name page
                    if (buildingId != null && siteId != null) {
                      context.pushNamed(
                        Routelists.buildingFloorManagement,
                        queryParameters: {
                          if (_userName != null && _userName!.isNotEmpty)
                            'userName': _userName!,
                          if (widget.verseId != null &&
                              widget.verseId!.isNotEmpty)
                            'switchId': widget.verseId!,
                          'siteId': siteId,
                          'buildingId': buildingId,
                          'fromDashboard': 'true',
                        },
                      );
                    } else {
                      // Show error if buildingId or siteId is not available
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please select a building first to add a floor.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  } else if (propertyAddLabel ==
                      'dashboard.sidebar.add_site'.tr()) {
                    // Navigate to add property page
                    context.pushNamed(
                      Routelists.addProperties,
                      queryParameters: {
                        'fromDashboard': 'true',
                        if (_userName != null && _userName!.isNotEmpty)
                          'userName': _userName!,
                        if (widget.verseId != null &&
                            widget.verseId!.isNotEmpty)
                          'switchId': widget.verseId!,
                      },
                    );
                  } else {
                    // TODO: Navigate to add site/building/floor/room based on selection
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          propertyAddLabel +
                              ' ' +
                              'dashboard.main_content.coming_soon'.tr(),
                        ),
                      ),
                    );
                  }
                },
                addItemLabel: propertyAddLabel,
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildReportingsSection() {
    final effectiveVerseId = widget.verseId ?? currentVerseId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            widget.onReportSelected?.call(null);
          },
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            'dashboard.sidebar.reportings'.tr(),
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Color(0x40000000)),
        ReportSidebarSection(
          bryteswitchId: effectiveVerseId,
          onReportSelected: widget.onReportSelected != null
              ? (id) => widget.onReportSelected!(id)
              : null,
        ),
      ],
    );
  }

  SwitchRoleEntity? _getCurrentRole(String? switchId) {
    if (switchId == null || _roles.isEmpty) return null;
    final match = _roles.where((r) => r.bryteswitchId == switchId);
    return match.isEmpty ? null : match.first;
  }

  void _showSwitchSwitchingDialog() {
    if (_roles.isEmpty || widget.onSwitchSelected == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SwitchSwitchingDialog(
        roles: _roles,
        currentSwitchId: currentVerseId,
        currentRole: _getCurrentRole(currentVerseId),
        onSwitchSelected: (bryteswitchId) {
          widget.onSwitchSelected!.call(bryteswitchId);
          setState(() {
            currentVerseId = bryteswitchId;
          });
        },
      ),
    );
  }

  Widget _buildVerseSection() {
    final effectiveVerseId = widget.verseId ?? currentVerseId;
    final currentRole = _getCurrentRole(effectiveVerseId);
    final showSwitcher =
        widget.showSwitchSwitcher &&
        _roles.isNotEmpty &&
        widget.onSwitchSelected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.sidebar.companies'.tr(),
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Color(0x40000000)),
        const SizedBox(height: 12),
        InkWell(
          onTap: showSwitcher ? _showSwitchSwitchingDialog : null,
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      color: Colors.white,
                    ),
                    child: Icon(
                      Icons.business,
                      color: AppTheme.primary,
                      size: 40,
                    ),
                  ),
                  if (currentRole != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        currentRole.organizationName.isNotEmpty
                            ? currentRole.organizationName
                            : currentRole.subDomain,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
              if (showSwitcher)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[100]!.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.swap_horiz,
                      color: AppTheme.primary,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            // Resolve switch/verse ID: prefer verseId from parent, then sidebar state, then LocalStorage
            var switchId = (widget.verseId != null && widget.verseId!.isNotEmpty)
                ? widget.verseId
                : (currentVerseId != null && currentVerseId!.isNotEmpty)
                    ? currentVerseId
                    : sl<LocalStorage>().getSelectedVerseId();
            if (switchId == null || switchId.isEmpty) {
              switchId = sl<LocalStorage>().getSelectedSwitchId();
            }
            if (switchId != null && switchId.isNotEmpty) {
              context.pushNamed(
                Routelists.switchSettings,
                queryParameters: {'switchId': switchId},
              );
            } else {
              context.pushNamed(Routelists.switchSettings);
            }
          },
          child: Text(
            'dashboard.sidebar.settings'.tr(),
            style: AppTextStyles.titleSmall.copyWith(
              color: Colors.black87,
              fontWeight: widget.activeSection == 'settings'
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Color(0x40000000)),
        InkWell(
          onTap: () {
            context.pushNamed(Routelists.profile);
          },
          child: Text(
            'dashboard.sidebar.profile'.tr(),
            style: AppTextStyles.titleSmall.copyWith(
              color: Colors.black87,
              fontWeight: widget.activeSection == 'profile'
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Color(0x40000000)),
        InkWell(
          onTap: () {
            // TODO: Navigate to Links page
          },
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            'dashboard.sidebar.links'.tr(),
            style: AppTextStyles.titleSmall.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Color(0x40000000)),
        InkWell(
          onTap: () {
            if (currentVerseId != null) {
              context.pushNamed(
                Routelists.statistics,
                queryParameters: {'verseId': currentVerseId ?? ''},
              );
            }
          },
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            'dashboard.sidebar.statistics'.tr(),
            style: AppTextStyles.titleSmall.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Color(0x40000000)),
        InkWell(
          onTap: () {
            final switchId = widget.verseId ?? currentVerseId;
            context.pushNamed(
              Routelists.inviteUser,
              queryParameters: {'switchId': switchId ?? ''},
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'dashboard.sidebar.add_user'.tr(),
              style: AppTextStyles.titleSmall.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return InkWell(
      onTap: _handleProfileTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 16, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              'dashboard.sidebar.profile'.tr(),
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.sidebar.language'.tr(),
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildLanguageOption(
          context: context,
          locale: const Locale('en'),
          label: 'dashboard.sidebar.english'.tr(),
          isSelected: context.locale.languageCode == 'en',
        ),
        const SizedBox(height: 4),
        _buildLanguageOption(
          context: context,
          locale: const Locale('de'),
          label: 'dashboard.sidebar.deutsch'.tr(),
          isSelected: context.locale.languageCode == 'de',
        ),
      ],
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required Locale locale,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        await context.setLocale(locale);
        if (!mounted) return;
        setState(() {});
        // Notify parent to rebuild dashboard content
        widget.onLanguageChanged?.call();
      },
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            if (isSelected)
              Icon(Icons.check, size: 16, color: AppTheme.primary)
            else
              const SizedBox(width: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: isSelected ? AppTheme.primary : Colors.black54,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleProfileTap() {
    context.pushNamed(Routelists.profile);
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: _handleLogout,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.logout, size: 16, color: Colors.red[600]),
            const SizedBox(width: 8),
            Text(
              'dashboard.sidebar.logout'.tr(),
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      final authService = sl<AuthService>();
      // Clear selected verse on logout proactively
      await sl<LocalStorage>().clearSelectedVerseId();
      await authService.logout();

      if (mounted) {
        // Navigate to login page
        context.goNamed(Routelists.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'dashboard.error.loading_dashboard'.tr(
                namedArgs: {'error': '$e'},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
