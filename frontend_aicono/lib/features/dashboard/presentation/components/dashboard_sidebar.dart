import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_item_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_view_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_building_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_floor_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';

class DashboardSidebar extends StatefulWidget {
  const DashboardSidebar({
    super.key,
    this.showBackToDashboard = false,
    this.activeSection,
    this.isInDrawer = false,
    this.onLanguageChanged,
  });

  /// Show a "back to dashboard" link at the top when used outside the dashboard page
  final bool showBackToDashboard;

  /// Bold the active page in settings section: 'settings' | 'links' | 'statistics'
  final String? activeSection;

  /// Whether the sidebar is being used in a drawer (affects width)
  final bool isInDrawer;

  /// Callback for when language changes (to trigger dashboard rebuild)
  final VoidCallback? onLanguageChanged;

  @override
  State<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends State<DashboardSidebar> {
  String? currentVerseId;
  List<TreeItemEntity> _reportings = [];

  @override
  void initState() {
    super.initState();
    _loadVerseId();
    _loadSampleReportings();
  }

  void _loadVerseId() {
    final localStorage = sl<LocalStorage>();
    final savedVerseId = localStorage.getSelectedVerseId();
    setState(() {
      currentVerseId = savedVerseId;
    });
  }

  void _loadSampleReportings() {
    // Keep dummy reportings for now (backend endpoints not provided yet)
    setState(() {
      _reportings = [
        TreeItemEntity(
          id: 'rep1',
          name: 'CFO Reporting Münster',
          type: 'reporting',
          children: [
            TreeItemEntity(id: 'rep1_q1', name: 'Q1 2024', type: 'reporting'),
            TreeItemEntity(id: 'rep1_q2', name: 'Q2 2024', type: 'reporting'),
          ],
        ),
      ];
    });
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
              const Divider(
                height: 20,
                thickness: 1,
                color: Color(0x40000000),
              ),
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
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
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
              final siteDetailsState = context.watch<DashboardSiteDetailsBloc>().state;
              final buildingDetailsState = context.watch<DashboardBuildingDetailsBloc>().state;
              final floorDetailsState = context.watch<DashboardFloorDetailsBloc>().state;
              final roomDetailsState = context.watch<DashboardRoomDetailsBloc>().state;

              // Get selected IDs
              String? selectedSiteId;
              String? selectedBuildingId;
              String? selectedFloorId;
              String? selectedRoomId;

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
                } else if (buildingDetailsState is DashboardBuildingDetailsSuccess) {
                  selectedBuildingId = buildingDetailsState.buildingId;
                } else if (buildingDetailsState is DashboardBuildingDetailsFailure) {
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

              if (roomDetailsState is DashboardRoomDetailsLoading ||
                  roomDetailsState is DashboardRoomDetailsSuccess ||
                  roomDetailsState is DashboardRoomDetailsFailure) {
                if (roomDetailsState is DashboardRoomDetailsLoading) {
                  selectedRoomId = roomDetailsState.roomId;
                } else if (roomDetailsState is DashboardRoomDetailsSuccess) {
                  selectedRoomId = roomDetailsState.roomId;
                } else if (roomDetailsState is DashboardRoomDetailsFailure) {
                  selectedRoomId = roomDetailsState.roomId;
                }
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
                        buildingDetailsState is DashboardBuildingDetailsSuccess) {
                      final floors = buildingDetailsState.details.floors;
                      floorChildren = floors.map((floor) {
                        List<TreeItemEntity> roomChildren = [];

                        // If this floor is selected and we have floor details, show rooms
                        if (selectedFloorId == floor.id &&
                            floorDetailsState is DashboardFloorDetailsSuccess) {
                          final rooms = floorDetailsState.details.rooms;
                          roomChildren = rooms.map((room) {
                            return TreeItemEntity(
                              id: room.id,
                              name: room.name,
                              type: 'property',
                            );
                          }).toList();
                        } else if (selectedFloorId == floor.id &&
                            floorDetailsState is DashboardFloorDetailsLoading) {
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
                        buildingDetailsState is DashboardBuildingDetailsLoading) {
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
                final isSelectedAndLoading = selectedSiteId == site.id &&
                    siteDetailsState is DashboardSiteDetailsLoading;
                
                return TreeItemEntity(
                  id: site.id,
                  name: site.name,
                  type: 'property',
                  // If site has buildings and is selected/loading, show loading placeholder
                  // This makes it expandable on first click
                  // When details load, buildingChildren will be populated
                  children: hasBuildings && buildingChildren.isEmpty && isSelectedAndLoading
                      ? [TreeItemEntity(id: '${site.id}_loading', name: 'Loading...', type: 'property')]
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
                    context.read<DashboardSiteDetailsBloc>().add(
                          DashboardSiteDetailsRequested(siteId: item.id),
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
                    final isBuilding = siteDetailsState.details.buildings
                        .any((b) => b.id == item.id);
                    if (isBuilding) {
                      context.read<DashboardBuildingDetailsBloc>().add(
                            DashboardBuildingDetailsRequested(buildingId: item.id),
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
                      final isFloor = building.floors.any((f) => f.id == item.id);
                      if (isFloor) {
                        context.read<DashboardFloorDetailsBloc>().add(
                              DashboardFloorDetailsRequested(floorId: item.id),
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
                          context.read<DashboardRoomDetailsBloc>().add(
                                DashboardRoomDetailsRequested(roomId: item.id),
                              );
                          return;
                        }
                      }
                    }
                  }

                  // Also check building details state for floors/rooms
                  if (buildingDetailsState is DashboardBuildingDetailsSuccess) {
                    final isFloor = buildingDetailsState.details.floors
                        .any((f) => f.id == item.id);
                    if (isFloor) {
                      context.read<DashboardFloorDetailsBloc>().add(
                            DashboardFloorDetailsRequested(floorId: item.id),
                          );
                      context.read<DashboardRoomDetailsBloc>().add(
                            DashboardRoomDetailsReset(),
                          );
                      return;
                    }

                    for (final floor in buildingDetailsState.details.floors) {
                      final isRoom = floor.rooms.any((r) => r.id == item.id);
                      if (isRoom) {
                        context.read<DashboardRoomDetailsBloc>().add(
                              DashboardRoomDetailsRequested(roomId: item.id),
                            );
                        return;
                      }
                    }
                  }

                  // Check floor details state for rooms
                  if (floorDetailsState is DashboardFloorDetailsSuccess) {
                    final isRoom = floorDetailsState.details.rooms
                        .any((r) => r.id == item.id);
                    if (isRoom) {
                      context.read<DashboardRoomDetailsBloc>().add(
                            DashboardRoomDetailsRequested(roomId: item.id),
                          );
                      return;
                    }
                  }
                },
                onAddItem: () {
                  // TODO: Navigate to add location page
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'dashboard.sidebar.add_location'.tr() +
                            ' ' +
                            'dashboard.main_content.coming_soon'.tr(),
                      ),
                    ),
                  );
                },
                addItemLabel: 'dashboard.sidebar.add_location'.tr(),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildReportingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            // Clear selection when clicking on section title
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
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        TreeViewWidget(
          items: _reportings,
          onItemTap: (item) {
            // Handle item tap
          },
          onAddItem: () {
            // TODO: Navigate to add reporting page
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
        ),
      ],
    );
  }

  Widget _buildVerseSection() {
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
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        const SizedBox(height: 12),
        // Company logo placeholder
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
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            context.pushNamed(Routelists.switchSettings);
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
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
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
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        InkWell(
          onTap: () {
            if (currentVerseId != null) {
              context.pushNamed(
                Routelists.statistics,
                pathParameters: {
                  'verseId': currentVerseId ?? '',
                },
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
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        InkWell(
          onTap: () {
            if (currentVerseId != null) {
              context.pushNamed(
                Routelists.inviteUser,
                extra: {
                  'verseId': currentVerseId,
                },
              );
            }
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
    try {
      context.pushNamed(Routelists.profile, extra: {'verseId': currentVerseId});
    } catch (_) {
      // fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'dashboard.sidebar.profile'.tr() +
                ' ' +
                'dashboard.main_content.coming_soon'.tr(),
          ),
        ),
      );
    }
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
