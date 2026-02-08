import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_loxone_rooms_bloc.dart';

// Color palette matching floor_plan_backup.dart
const List<Color> _colorPalette = [
  Color(0xFFFFB74D), // Light orange
  Color(0xFFE57373), // Red
  Color(0xFFBA68C8), // Purple
  Color(0xFF64B5F6), // Blue
  Color(0xFF81C784), // Green
];

class EditRoomPage extends StatefulWidget {
  final String roomId;
  final String? buildingId; // Optional, can be passed or fetched from floor

  const EditRoomPage({
    super.key,
    required this.roomId,
    this.buildingId,
  });

  @override
  State<EditRoomPage> createState() => _EditRoomPageState();
}

class _EditRoomPageState extends State<EditRoomPage> {
  final TextEditingController _roomNameController = TextEditingController();
  Color _selectedColor = _colorPalette[0];
  String? _selectedLoxoneRoomId;
  String? _selectedLoxoneRoomName;
  String? _buildingId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  void _loadRoomData() {
    // Request room details to get current values
    context.read<DashboardRoomDetailsBloc>().add(
      DashboardRoomDetailsRequested(roomId: widget.roomId),
    );
  }

  Future<void> _fetchBuildingIdFromFloor(String floorId) async {
    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.get('/api/v1/floors/$floorId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final floorData = data['data'] as Map<String, dynamic>;
          final buildingId = floorData['buildingId']?.toString();
          if (buildingId != null && buildingId.isNotEmpty) {
            setState(() {
              _buildingId = buildingId;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching building ID from floor: $e');
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  Future<void> _showLoxoneRoomSelector() async {
    final buildingId = widget.buildingId ?? _buildingId;
    if (buildingId == null || buildingId.isEmpty) {
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
          selectedRoomName: _selectedLoxoneRoomName ?? _roomNameController.text,
          roomColor: _selectedColor,
          buildingId: buildingId,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLoxoneRoomId = result;
        // We'll need to fetch the room name separately or get it from the dialog
      });
    }
  }

  Future<void> _handleSave() async {
    final roomName = _roomNameController.text.trim();

    if (roomName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room name is required'),
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
      final requestBody = <String, dynamic>{
        'name': roomName,
        'color': '#${_selectedColor.value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}',
      };

      if (_selectedLoxoneRoomId != null && _selectedLoxoneRoomId!.isNotEmpty) {
        requestBody['loxone_room_id'] = _selectedLoxoneRoomId;
      }

      final response = await dioClient.patch(
        '/api/v1/rooms/${widget.roomId}',
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
          // Refresh room details
          context.read<DashboardRoomDetailsBloc>().add(
            DashboardRoomDetailsRequested(roomId: widget.roomId),
          );
          // Navigate back
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update room: ${response.statusCode}',
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
            content: Text('Error updating room: $e'),
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
    final screenSize = MediaQuery.of(context).size;
    return BlocListener<DashboardRoomDetailsBloc, DashboardRoomDetailsState>(
      listener: (context, state) {
        if (state is DashboardRoomDetailsSuccess) {
          // Initialize fields with current values
          _roomNameController.text = state.details.name;
          
          // Parse color from hex string
          final colorHex = state.details.color.replaceFirst('#', '');
          if (colorHex.isNotEmpty) {
            try {
              _selectedColor = Color(
                int.parse('FF$colorHex', radix: 16),
              );
            } catch (e) {
              debugPrint('Error parsing color: $e');
            }
          }

          // Set Loxone room info
          if (state.details.loxoneRoomId != null) {
            _selectedLoxoneRoomId = state.details.loxoneRoomId!.id;
            _selectedLoxoneRoomName = state.details.loxoneRoomId!.name;
          }

          // Fetch building ID from floor if not provided
          if (widget.buildingId == null && state.details.floorId.isNotEmpty) {
            _fetchBuildingIdFromFloor(state.details.floorId);
          } else if (widget.buildingId != null) {
            _buildingId = widget.buildingId;
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width,
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
                Container(
                  width: double.infinity,
                  height: screenSize.height * .9,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    width: screenSize.width < 600
                        ? screenSize.width * 0.95
                        : screenSize.width < 1200
                        ? screenSize.width * 0.5
                        : screenSize.width * 0.6,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        child: SizedBox(
                          width: screenSize.width < 600
                              ? screenSize.width * 0.95
                              : screenSize.width < 1200
                              ? screenSize.width * 0.5
                              : screenSize.width * 0.6,
                          child: Column(
                            children: [
                              SizedBox(
                                width: screenSize.width < 600
                                    ? screenSize.width * 0.95
                                    : screenSize.width < 1200
                                    ? screenSize.width * 0.5
                                    : screenSize.width * 0.6,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () => context.pop(),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Center(
                                        child: Text(
                                          'Edit Room',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Update room information',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Room name field
                              SizedBox(
                                width: screenSize.width < 600
                                    ? screenSize.width * 0.95
                                    : screenSize.width < 1200
                                    ? screenSize.width * 0.5
                                    : screenSize.width * 0.6,
                                child: TextFormField(
                                  controller: _roomNameController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter room name',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(0),
                                    ),
                                    prefixIcon: Icon(Icons.room),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Room name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Loxone Room Selection
                              SizedBox(
                                width: screenSize.width < 600
                                    ? screenSize.width * 0.95
                                    : screenSize.width < 1200
                                    ? screenSize.width * 0.5
                                    : screenSize.width * 0.6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Loxone Room',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    InkWell(
                                      onTap: _showLoxoneRoomSelector,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.black54,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.zero,
                                        ),
                                        child: Row(
                                          children: [
                                            if (_selectedLoxoneRoomName != null) ...[
                                              Text(
                                                _selectedLoxoneRoomName!,
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ] else ...[
                                              Text(
                                                'Select Loxone room',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
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
                              const SizedBox(height: 32),
                              // Color Selection
                              SizedBox(
                                width: screenSize.width < 600
                                    ? screenSize.width * 0.95
                                    : screenSize.width < 1200
                                    ? screenSize.width * 0.5
                                    : screenSize.width * 0.6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Room Color',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: _colorPalette.map((color) {
                                        final isSelected = _selectedColor == color;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedColor = color;
                                            });
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.black
                                                    : Colors.grey.shade400,
                                                width: isSelected ? 3 : 1,
                                              ),
                                            ),
                                            child: isSelected
                                                ? Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 20,
                                                  )
                                                : null,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Save button
                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : PrimaryOutlineButton(
                                      onPressed: _handleSave,
                                      label: 'Save Changes',
                                      width: 260,
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AppFooter(
                  onLanguageChanged: _handleLanguageChanged,
                  containerWidth: MediaQuery.of(context).size.width,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dialog widget for Loxone room selection (similar to room_assignment_page.dart)
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
      Navigator.of(context).pop(_selectedSource);
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
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
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

