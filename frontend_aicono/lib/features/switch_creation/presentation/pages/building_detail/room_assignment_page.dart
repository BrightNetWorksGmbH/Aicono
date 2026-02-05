import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/save_floor_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/save_floor_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_loxone_rooms_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';

import '../../../../../core/storage/local_storage.dart';
import '../../../../../core/widgets/page_header_row.dart';

class RoomAssignmentPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? floorPlanUrl;
  final List<Map<String, dynamic>>? rooms;
  final String? floorName;
  final int? numberOfFloors;
  final double? totalArea;
  final String? constructionYear;
  final String siteId;
  final String buildingId;
  const RoomAssignmentPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.floorPlanUrl,
    this.rooms,
    this.floorName,
    this.numberOfFloors,
    this.totalArea,
    this.constructionYear,
    required this.siteId,
    required this.buildingId,
  });

  @override
  State<RoomAssignmentPage> createState() => _RoomAssignmentPageState();
}

class _RoomAssignmentPageState extends State<RoomAssignmentPage> {
  List<Map<String, dynamic>> _rooms = [];
  int? _cachedNumberOfFloors;

  @override
  void initState() {
    super.initState();
    // Create a copy of rooms to track assignments
    _rooms = (widget.rooms ?? [])
        .map((room) => Map<String, dynamic>.from(room))
        .toList();
    // Cache numberOfFloors from widget to preserve it
    _cachedNumberOfFloors = widget.numberOfFloors;
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  Future<void> _navigateToDataSourceSelection(
    Map<String, dynamic> room,
    int roomIndex,
  ) async {
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => BlocProvider(
        create: (_) => sl<GetLoxoneRoomsBloc>(),
        child: _DataSourceSelectionDialog(
          selectedRoom: room['name'] ?? 'Room',
          roomColor: room['color'] != null
              ? (int.tryParse(room['color'].toString()) != null
                    ? Color(int.tryParse(room['color'].toString())!)
                    : const Color(0xFFFFEB3B))
              : const Color(0xFFFFEB3B),
          buildingId: widget.buildingId,
        ),
      ),
    );

    // Update room with selected loxone_room_id when coming back
    if (result != null && mounted) {
      setState(() {
        _rooms[roomIndex]['loxone_room_id'] = result;
      });
    }
  }

  bool get _allRoomsAssigned {
    return _rooms.isNotEmpty &&
        _rooms.every((room) => room['loxone_room_id'] != null);
  }

  void _handleSave(BuildContext blocContext) {
    final propertyCubit = sl<PropertySetupCubit>();
    final localStorage = sl<LocalStorage>();
    final storedBuildingId = widget.buildingId.isNotEmpty
        ? widget.buildingId
        : localStorage.getSelectedBuildingId() ??
              propertyCubit.state.buildingId;

    if (storedBuildingId == null || storedBuildingId.isEmpty) {
      ScaffoldMessenger.of(blocContext).showSnackBar(
        const SnackBar(
          content: Text('Building ID is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.floorPlanUrl == null || widget.floorPlanUrl!.isEmpty) {
      ScaffoldMessenger.of(blocContext).showSnackBar(
        const SnackBar(
          content: Text('Floor plan URL is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Convert color to hex format
    final floorRooms = _rooms.map((room) {
      String colorHex = '#FF5733'; // Default color
      if (room['color'] != null) {
        try {
          final colorValue = room['color'].toString();
          // Check if it's already a hex string
          if (colorValue.startsWith('#')) {
            colorHex = colorValue;
          } else {
            // Try to parse as int and convert to hex
            final colorInt = int.tryParse(colorValue);
            if (colorInt != null) {
              // Convert Color int (0xFFRRGGBB) to hex string (#RRGGBB)
              final hexString = colorInt.toRadixString(16).padLeft(8, '0');
              if (hexString.length >= 8) {
                colorHex = '#${hexString.substring(2).toUpperCase()}';
              }
            }
          }
        } catch (e) {
          // Use default
        }
      }

      return FloorRoom(
        name: room['name'] ?? 'Room',
        color: colorHex,
        loxoneRoomId: room['loxone_room_id'] ?? '',
      );
    }).toList();

    final request = SaveFloorRequest(
      name: widget.floorName ?? 'Ground Floor',
      floorPlanLink: widget.floorPlanUrl!,
      rooms: floorRooms,
    );

    blocContext.read<SaveFloorBloc>().add(
      SaveFloorSubmitted(buildingId: storedBuildingId, request: request),
    );
  }

  void _handleSkip() {
    // Skip to next step
    context.pushNamed(
      Routelists.buildingFloorManagement,
      queryParameters: {
        'buildingName': widget.buildingName,
        'buildingAddress': widget.buildingAddress,
        'numberOfFloors': widget.numberOfFloors.toString(),
        'buildingId': widget.buildingId.isNotEmpty
            ? widget.buildingId
            : Uri.parse(
                GoRouterState.of(context).uri.toString(),
              ).queryParameters['buildingId'],
        'siteId': widget.siteId.isNotEmpty
            ? widget.siteId
            : Uri.parse(
                GoRouterState.of(context).uri.toString(),
              ).queryParameters['siteId'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocProvider(
      create: (_) => sl<SaveFloorBloc>(),
      child: BlocListener<SaveFloorBloc, SaveFloorState>(
        listener: (context, state) {
          if (state is SaveFloorSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Floor plan saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            // Navigate back to building floor management page (floor list step)
            // Use goNamed to ensure we have the correct parameters and state
            // This allows users to select another floor and repeat the process (A>B>C>D back to A)
            final propertyCubit = sl<PropertySetupCubit>();
            final localStorage = sl<LocalStorage>();
            final storedBuildingId = widget.buildingId.isNotEmpty
                ? widget.buildingId
                : localStorage.getSelectedBuildingId() ??
                      propertyCubit.state.buildingId;

            // Ensure numberOfFloors is preserved - use cached value, widget value, route params, or fetch from API
            // This is critical to show all floors (e.g., 4 floors, not just 1)
            final currentState = GoRouterState.of(context);
            int numberOfFloors =
                _cachedNumberOfFloors ??
                widget.numberOfFloors ??
                int.tryParse(
                  currentState.uri.queryParameters['numberOfFloors'] ?? '',
                ) ??
                1;

            // If we still don't have a valid numberOfFloors and we have buildingId, try to fetch it
            if (numberOfFloors == 1 &&
                storedBuildingId != null &&
                storedBuildingId.isNotEmpty) {
              // Try to get from building data (async, but we'll use fallback)
              // For now, use the stored value or check if we can get it from the navigation history
              // The buildingFloorManagement page should have passed it, so check route params
              final routeParams = currentState.uri.queryParameters;
              if (routeParams.containsKey('numberOfFloors')) {
                numberOfFloors =
                    int.tryParse(routeParams['numberOfFloors'] ?? '') ??
                    numberOfFloors;
              }
            }

            // Navigate directly to building floor management with all correct parameters
            // This replaces the current route and ensures correct state
            context.goNamed(
              Routelists.buildingFloorManagement,
              queryParameters: {
                if (widget.buildingName != null)
                  'buildingName': widget.buildingName!,
                if (widget.buildingAddress != null)
                  'buildingAddress': widget.buildingAddress!,
                'numberOfFloors': numberOfFloors
                    .toString(), // Use preserved value
                'numberOfRooms': numberOfFloors
                    .toString(), // Use same value for rooms
                if (widget.totalArea != null)
                  'totalArea': widget.totalArea!.toString(),
                if (widget.constructionYear != null)
                  'constructionYear': widget.constructionYear!,
                if (storedBuildingId != null && storedBuildingId.isNotEmpty)
                  'buildingId': storedBuildingId,
                'siteId': widget.siteId.isNotEmpty
                    ? widget.siteId
                    : Uri.parse(
                        GoRouterState.of(context).uri.toString(),
                      ).queryParameters['siteId'],
                // Pass floorName to mark the floor as completed
                if (widget.floorName != null && widget.floorName!.isNotEmpty)
                  'completedFloorName': widget.floorName!,
              },
            );
          } else if (state is SaveFloorFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<SaveFloorBloc, SaveFloorState>(
          builder: (context, state) {
            return Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: SingleChildScrollView(
                  child: Container(
                    width: screenSize.width,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Container(
                            height: (screenSize.height * 0.95) + 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 20),
                                  Material(
                                    color: Colors.transparent,
                                    child: TopHeader(
                                      onLanguageChanged: _handleLanguageChanged,
                                      containerWidth: screenSize.width > 500
                                          ? 500
                                          : screenSize.width * 0.98,
                                      userInitial: widget.userName?[0]
                                          .toUpperCase(),
                                      verseInitial: null,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.zero,
                                      child: LinearProgressIndicator(
                                        value: 0.9,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              const Color(
                                                0xFF8B9A5B,
                                              ), // Muted green color
                                            ),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 50),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: SizedBox(
                                        width: screenSize.width < 600
                                            ? screenSize.width * 0.95
                                            : screenSize.width < 1200
                                            ? screenSize.width * 0.5
                                            : screenSize.width * 0.6,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            PageHeaderRow(
                                              title:
                                                  'Gibt es einen Grundriss zum Gebäude?',
                                              showBackButton: true,
                                              onBack: () {
                                                Navigator.pop(context);
                                              },
                                            ),
                                            const SizedBox(height: 32),
                                            // Room List
                                            if (_rooms.isNotEmpty)
                                              ..._rooms.asMap().entries.map((
                                                entry,
                                              ) {
                                                final index = entry.key;
                                                final room = entry.value;

                                                // Use room color from data if available, otherwise use default colors
                                                Color roomColor;
                                                if (room['color'] != null) {
                                                  try {
                                                    final colorValue =
                                                        int.tryParse(
                                                          room['color']
                                                              .toString(),
                                                        );
                                                    roomColor =
                                                        colorValue != null
                                                        ? Color(colorValue)
                                                        : _getDefaultRoomColor(
                                                            index,
                                                          );
                                                  } catch (e) {
                                                    roomColor =
                                                        _getDefaultRoomColor(
                                                          index,
                                                        );
                                                  }
                                                } else {
                                                  roomColor =
                                                      _getDefaultRoomColor(
                                                        index,
                                                      );
                                                }

                                                final isAssigned =
                                                    room['loxone_room_id'] !=
                                                    null;
                                                return Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () =>
                                                        _navigateToDataSourceSelection(
                                                          room,
                                                          index,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.zero,
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            bottom: 12,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 18,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: isAssigned
                                                              ? Colors.green
                                                              : const Color(
                                                                  0xFF8B9A5B,
                                                                ),
                                                          width: 2,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.zero,
                                                        color: isAssigned
                                                            ? Colors
                                                                  .green
                                                                  .shade50
                                                            : Colors
                                                                  .transparent,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            '+ ${room['name'] ?? 'Room ${index + 1}'}',
                                                            style: AppTextStyles
                                                                .bodyMedium
                                                                .copyWith(
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                          ),
                                                          const Spacer(),
                                                          if (isAssigned)
                                                            Padding(
                                                              padding:
                                                                  EdgeInsets.only(
                                                                    right: 8,
                                                                  ),
                                                              child: Image.asset(
                                                                'assets/images/check.png',
                                                                width: 16,
                                                                height: 16,
                                                              ),
                                                            ),
                                                          Container(
                                                            width: 24,
                                                            height: 24,
                                                            decoration: BoxDecoration(
                                                              color: roomColor,
                                                              border: Border.all(
                                                                color: Colors
                                                                    .black54,
                                                                width: 1,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            const SizedBox(height: 24),
                                            // Tip
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              // decoration: BoxDecoration(
                                              //   color: Colors.grey.shade50,
                                              //   borderRadius: BorderRadius.zero,
                                              // ),
                                              child: Text(
                                                'Tipp: Bitte ordne jedem Raum die passenden Messpunkte zu. Wenn du dir unsicher bist, kannst du diesen Schritt auch später über das Dashboard abschließen.',
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                      color: Colors.black54,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            const SizedBox(height: 32),
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: _handleSkip,
                                                child: Text(
                                                  'Schritt überspringen',
                                                  style: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                        color: Colors.black87,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            // if (_allRoomsAssigned)
                                            Material(
                                              color: Colors.transparent,
                                              child: PrimaryOutlineButton(
                                                enabled: _allRoomsAssigned,
                                                label: state is SaveFloorLoading
                                                    ? 'Speichern...'
                                                    : 'Das passt so',
                                                width: 260,
                                                onPressed:
                                                    state is SaveFloorLoading
                                                    ? null
                                                    : () =>
                                                          _handleSave(context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AppFooter(
                          onLanguageChanged: _handleLanguageChanged,
                          containerWidth: screenSize.width,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getDefaultRoomColor(int index) {
    final roomColors = [
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
    ];
    return roomColors[index % roomColors.length];
  }
}

// Dialog widget that mimics DataSourceSelectionPage UI
class _DataSourceSelectionDialog extends StatefulWidget {
  final String selectedRoom;
  final Color roomColor;
  final String? buildingId;

  const _DataSourceSelectionDialog({
    required this.selectedRoom,
    required this.roomColor,
    this.buildingId,
  });

  @override
  State<_DataSourceSelectionDialog> createState() =>
      _DataSourceSelectionDialogState();
}

class _DataSourceSelectionDialogState
    extends State<_DataSourceSelectionDialog> {
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
    // Pass back the selected loxone room ID when closing
    if (_selectedSource != null) {
      Navigator.of(context).pop(_selectedSource);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleSkip() {
    // Skip - don't assign a room
    Navigator.of(context).pop();
  }

  void _toggleSource(String source) {
    setState(() {
      // Only allow one selection at a time (radio button behavior)
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
          // Fetch rooms when buildingId is available and we haven't fetched yet
          if (!_hasFetched &&
              widget.buildingId != null &&
              widget.buildingId!.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                blocContext.read<GetLoxoneRoomsBloc>().add(
                  GetLoxoneRoomsSubmitted(buildingId: widget.buildingId!),
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
                                'Woher kommen die Messdaten im Raum?',
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
                                '+ ${widget.selectedRoom}',
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
                                // Search Field - only show when rooms are loaded
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
                                        hintText: 'Suchen...',
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
                                        'Keine Ergebnisse gefunden',
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
                                      'Fehler beim Laden der Datenquellen: ${state.message}',
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
                                      'Keine Datenquellen verfügbar',
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
                            label: 'Das passt so',
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
        // onTap: () => _toggleSource(key),
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
                onChanged: (value) =>
                    _toggleSource(key), // Let InkWell handle the tap
              ),
              // Checkbox(
              //   value: isSelected,
              //   onChanged: null, // Let InkWell handle the tap
              //   activeColor: const Color(0xFF8B9A5B),
              // ),
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
