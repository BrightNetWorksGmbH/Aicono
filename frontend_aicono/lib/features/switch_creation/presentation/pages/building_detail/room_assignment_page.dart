import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/save_floor_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/save_floor_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';

class RoomAssignmentPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? floorPlanUrl;
  final List<Map<String, dynamic>>? rooms;
  final String? buildingId;
  final String? floorName;
  final int? numberOfFloors;
  final double? totalArea;
  final String? constructionYear;

  const RoomAssignmentPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.floorPlanUrl,
    this.rooms,
    this.buildingId,
    this.floorName,
    this.numberOfFloors,
    this.totalArea,
    this.constructionYear,
  });

  @override
  State<RoomAssignmentPage> createState() => _RoomAssignmentPageState();
}

class _RoomAssignmentPageState extends State<RoomAssignmentPage> {
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    // Create a copy of rooms to track assignments
    _rooms = (widget.rooms ?? [])
        .map((room) => Map<String, dynamic>.from(room))
        .toList();
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  Future<void> _navigateToDataSourceSelection(
    Map<String, dynamic> room,
    int roomIndex,
  ) async {
    final result = await context.pushNamed<String?>(
      Routelists.dataSourceSelection,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.buildingAddress != null)
          'buildingAddress': widget.buildingAddress!,
        if (widget.buildingName != null) 'buildingName': widget.buildingName!,
        if (widget.floorPlanUrl != null) 'floorPlanUrl': widget.floorPlanUrl!,
        'selectedRoom': room['name'] ?? 'Room',
        if (room['color'] != null) 'roomColor': room['color'].toString(),
        if (widget.buildingId != null) 'buildingId': widget.buildingId!,
      },
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
    if (widget.buildingId == null || widget.buildingId!.isEmpty) {
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
      SaveFloorSubmitted(buildingId: widget.buildingId!, request: request),
    );
  }

  void _handleSkip() {
    // Skip to next step
    if (context.canPop()) {
      context.pop();
    }
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
            context.goNamed(
              Routelists.buildingFloorManagement,
              queryParameters: {
                if (widget.buildingName != null)
                  'buildingName': widget.buildingName!,
                if (widget.buildingAddress != null)
                  'buildingAddress': widget.buildingAddress!,
                'numberOfFloors': (widget.numberOfFloors ?? 1).toString(),
                if (widget.totalArea != null)
                  'totalArea': widget.totalArea!.toString(),
                if (widget.constructionYear != null)
                  'constructionYear': widget.constructionYear!,
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
                              borderRadius: BorderRadius.circular(12),
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
                                  if (widget.userName != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Fast geschafft, ${widget.userName}!',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: 0.85,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF8B9A5B),
                                            ),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ],
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
                                            Text(
                                              'Gibt es einen Grundriss zum Gebäude?',
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.headlineSmall
                                                  .copyWith(
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black87,
                                                  ),
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
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
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
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
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
                                                            const Padding(
                                                              padding:
                                                                  EdgeInsets.only(
                                                                    right: 8,
                                                                  ),
                                                              child: Icon(
                                                                Icons
                                                                    .check_circle,
                                                                color: Colors
                                                                    .green,
                                                                size: 20,
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
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
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
                                            if (_allRoomsAssigned)
                                              Material(
                                                color: Colors.transparent,
                                                child: PrimaryOutlineButton(
                                                  label:
                                                      state is SaveFloorLoading
                                                      ? 'Speichern...'
                                                      : 'Das passt so',
                                                  width: 260,
                                                  onPressed:
                                                      state is SaveFloorLoading
                                                      ? null
                                                      : () => _handleSave(
                                                          context,
                                                        ),
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
