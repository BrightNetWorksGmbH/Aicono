import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_loxone_rooms_bloc.dart';

import '../../../../core/widgets/top_part_widget.dart';

// Color palette matching floor_plan_backup.dart
const List<Color> _colorPalette = [
  Color(0xFFFFB74D), // Light orange
  Color(0xFFE57373), // Red
  Color(0xFFBA68C8), // Purple
  Color(0xFF64B5F6), // Blue
  Color(0xFF81C784), // Green
];

class EditSensorThrasholdPage extends StatefulWidget {
  final String roomId;
  final String? buildingId; // Optional, can be passed or fetched from floor

  const EditSensorThrasholdPage({
    super.key,
    required this.roomId,
    this.buildingId,
  });

  @override
  State<EditSensorThrasholdPage> createState() =>
      _EditSensorThrasholdPageState();
}

class _EditSensorThrasholdPageState extends State<EditSensorThrasholdPage> {
  final TextEditingController _roomNameController = TextEditingController();
  Color _selectedColor = _colorPalette[0];
  String? _selectedLoxoneRoomId;
  String? _selectedLoxoneRoomName;
  String? _buildingId;
  bool _isLoading = false;
  List<SensorData> _sensors = [];
  final Map<String, bool> _editingSensors = {};
  final Map<String, TextEditingController> _minControllers = {};
  final Map<String, TextEditingController> _maxControllers = {};
  final Map<String, bool> _savingSensors = {};
  bool _isLoadingSensors = false;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
    _fetchSensorsFromAPI();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    for (final controller in _minControllers.values) {
      controller.dispose();
    }
    for (final controller in _maxControllers.values) {
      controller.dispose();
    }
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
          final buildingId = floorData['building_id']?.toString();
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

  Future<void> _fetchSensorsFromAPI() async {
    setState(() {
      _isLoadingSensors = true;
    });

    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.get(
        '/api/v1/sensors/local-room/${widget.roomId}',
      );

      if (mounted) {
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          List<dynamic> sensorsList = [];

          // Handle different response structures
          if (data is List) {
            sensorsList = data;
          } else if (data is Map<String, dynamic>) {
            if (data['success'] == true && data['data'] != null) {
              if (data['data'] is List) {
                sensorsList = data['data'] as List;
              } else if (data['data'] is Map<String, dynamic>) {
                // If data is a single object, wrap it in a list
                sensorsList = [data['data']];
              }
            } else if (data['sensors'] != null && data['sensors'] is List) {
              sensorsList = data['sensors'] as List;
            } else if (data['results'] != null && data['results'] is List) {
              sensorsList = data['results'] as List;
            }
          }

          _loadSensorsFromRoomDetails(sensorsList);
        } else {
          debugPrint('Failed to fetch sensors: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error fetching sensors from API: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sensors: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSensors = false;
        });
      }
    }
  }

  void _loadSensorsFromRoomDetails(List<dynamic> sensorsList) {
    setState(() {
      _sensors = sensorsList.map((sensor) {
        final sensorId =
            sensor['_id']?.toString() ??
            sensor['id']?.toString() ??
            UniqueKey().toString();
        final sensorName =
            sensor['name']?.toString() ??
            sensor['sensorName']?.toString() ??
            'Unknown Sensor';
        final minValue =
            sensor['threshold_min']?.toString() ??
            sensor['minValue']?.toString() ??
            '';
        final maxValue =
            sensor['threshold_max']?.toString() ??
            sensor['maxValue']?.toString() ??
            '';

        // Initialize controllers if not already initialized
        if (!_minControllers.containsKey(sensorId)) {
          _minControllers[sensorId] = TextEditingController(text: minValue);
        }
        if (!_maxControllers.containsKey(sensorId)) {
          _maxControllers[sensorId] = TextEditingController(text: maxValue);
        }

        return SensorData(
          id: sensorId,
          name: sensorName,
          minValue: minValue,
          maxValue: maxValue,
        );
      }).toList();
    });
  }

  void _toggleEditSensor(String sensorId) {
    setState(() {
      _editingSensors[sensorId] = !(_editingSensors[sensorId] ?? false);
    });
  }

  Future<void> _saveSensorValues(String sensorId) async {
    final minController = _minControllers[sensorId];
    final maxController = _maxControllers[sensorId];

    if (minController == null || maxController == null) {
      return;
    }

    final minValue = minController.text.trim();
    final maxValue = maxController.text.trim();

    // Validate that values are numbers if provided
    if (minValue.isNotEmpty && double.tryParse(minValue) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Min value must be a valid number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (maxValue.isNotEmpty && double.tryParse(maxValue) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Max value must be a valid number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _savingSensors[sensorId] = true;
    });

    try {
      final dioClient = sl<DioClient>();

      // Build sensor update object for bulk update
      final sensorUpdate = <String, dynamic>{'sensorId': sensorId};

      if (minValue.isNotEmpty) {
        sensorUpdate['threshold_min'] = double.parse(minValue);
      }
      if (maxValue.isNotEmpty) {
        sensorUpdate['threshold_max'] = double.parse(maxValue);
      }

      // Use bulk update endpoint
      final requestBody = <String, dynamic>{
        'sensors': [sensorUpdate],
      };

      final response = await dioClient.put(
        '/api/v1/sensors/bulk-update',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sensor values updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Update local state
          setState(() {
            final sensorIndex = _sensors.indexWhere((s) => s.id == sensorId);
            if (sensorIndex != -1) {
              _sensors[sensorIndex] = SensorData(
                id: sensorId,
                name: _sensors[sensorIndex].name,
                minValue: minValue,
                maxValue: maxValue,
              );
            }
            _editingSensors[sensorId] = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update sensor: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating sensor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingSensors[sensorId] = false;
        });
      }
    }
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
        'color':
            '#${_selectedColor.value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}',
      };

      if (_selectedLoxoneRoomId != null && _selectedLoxoneRoomId!.isNotEmpty) {
        requestBody['loxone_room_id'] = _selectedLoxoneRoomId;
      }

      final response = await dioClient.patch(
        '/api/v1/floors/rooms/${widget.roomId}',
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
              content: Text('Failed to update room: ${response.statusCode}'),
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

  Future<void> _handleSaveSensors() async {
    setState(() {
      _isLoadingSensors = true;
    });

    try {
      // Collect all sensors that have at least one value (min or max)
      final List<Map<String, dynamic>> sensorsToUpdate = [];

      for (final sensor in _sensors) {
        final sensorId = sensor.id;
        final minController = _minControllers[sensorId];
        final maxController = _maxControllers[sensorId];

        if (minController == null || maxController == null) {
          continue;
        }

        final minValue = minController.text.trim();
        final maxValue = maxController.text.trim();

        // Skip if both values are empty
        if (minValue.isEmpty && maxValue.isEmpty) {
          continue;
        }

        // Validate that values are numbers if provided
        if (minValue.isNotEmpty && double.tryParse(minValue) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Min value for ${sensor.name} must be a valid number',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoadingSensors = false;
          });
          return;
        }

        if (maxValue.isNotEmpty && double.tryParse(maxValue) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Max value for ${sensor.name} must be a valid number',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoadingSensors = false;
          });
          return;
        }

        // Build sensor update object
        final sensorUpdate = <String, dynamic>{'sensorId': sensorId};

        // Only include threshold_min if it has a value
        if (minValue.isNotEmpty) {
          sensorUpdate['threshold_min'] = double.parse(minValue);
        }

        // Only include threshold_max if it has a value
        if (maxValue.isNotEmpty) {
          sensorUpdate['threshold_max'] = double.parse(maxValue);
        }

        sensorsToUpdate.add(sensorUpdate);
      }

      // If no sensors to update, show message and return
      if (sensorsToUpdate.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No sensor values to update'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _isLoadingSensors = false;
          });
        }
        return;
      }

      // Send bulk update request
      final dioClient = sl<DioClient>();
      final requestBody = <String, dynamic>{'sensors': sensorsToUpdate};

      final response = await dioClient.put(
        '/api/v1/sensors/bulk-update',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sensor values updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh room details to get updated sensor values
          context.read<DashboardRoomDetailsBloc>().add(
            DashboardRoomDetailsRequested(roomId: widget.roomId),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update sensors: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating sensors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSensors = false;
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
              _selectedColor = Color(int.parse('FF$colorHex', radix: 16));
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

          // Sensors are now loaded from API endpoint in _fetchSensorsFromAPI()
          // No need to load from room details anymore
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
                  child: SingleChildScrollView(
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
                                Material(
                                  color: Colors.transparent,
                                  child: TopHeader(
                                    onLanguageChanged: _handleLanguageChanged,
                                    containerWidth: screenSize.width > 500
                                        ? 500
                                        : screenSize.width * 0.98,
                                    // userInitial: widget.userName?[0].toUpperCase(),
                                    verseInitial: null,
                                  ),
                                ),
                                const SizedBox(height: 16),
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
                                            'Update Sensor Threshold',
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
                                  'Update sensor threshold information',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // // Loxone Room Selection
                                // SizedBox(
                                //   width: screenSize.width < 600
                                //       ? screenSize.width * 0.95
                                //       : screenSize.width < 1200
                                //       ? screenSize.width * 0.5
                                //       : screenSize.width * 0.6,
                                //   child: Column(
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       const Text(
                                //         'Loxone Room',
                                //         style: TextStyle(
                                //           fontSize: 18,
                                //           fontWeight: FontWeight.bold,
                                //         ),
                                //       ),
                                //       const SizedBox(height: 16),
                                //       InkWell(
                                //         onTap: _showLoxoneRoomSelector,
                                //         child: Container(
                                //           padding: const EdgeInsets.symmetric(
                                //             horizontal: 16,
                                //             vertical: 18,
                                //           ),
                                //           decoration: BoxDecoration(
                                //             border: Border.all(
                                //               color: Colors.black54,
                                //               width: 2,
                                //             ),
                                //             borderRadius: BorderRadius.zero,
                                //           ),
                                //           child: Row(
                                //             children: [
                                //               if (_selectedLoxoneRoomName !=
                                //                   null) ...[
                                //                 Text(
                                //                   _selectedLoxoneRoomName!,
                                //                   style: AppTextStyles
                                //                       .bodyMedium
                                //                       .copyWith(
                                //                         color: Colors.black87,
                                //                       ),
                                //                 ),
                                //               ] else ...[
                                //                 Text(
                                //                   'Select Loxone room',
                                //                   style: AppTextStyles
                                //                       .bodyMedium
                                //                       .copyWith(
                                //                         color: Colors.grey,
                                //                       ),
                                //                 ),
                                //               ],
                                //               const Spacer(),
                                //               Icon(
                                //                 Icons.arrow_forward_ios,
                                //                 size: 16,
                                //                 color: Colors.black54,
                                //               ),
                                //             ],
                                //           ),
                                //         ),
                                //       ),

                                //     ],
                                //   ),
                                // ),
                                // const SizedBox(height: 24),
                                // Color Selection
                                // SizedBox(
                                //   width: screenSize.width < 600
                                //       ? screenSize.width * 0.95
                                //       : screenSize.width < 1200
                                //       ? screenSize.width * 0.5
                                //       : screenSize.width * 0.6,
                                //   child: Column(
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       const Text(
                                //         'Room Color',
                                //         style: TextStyle(
                                //           fontSize: 18,
                                //           fontWeight: FontWeight.bold,
                                //         ),
                                //       ),
                                //       const SizedBox(height: 16),
                                //       Row(
                                //         mainAxisAlignment:
                                //             MainAxisAlignment.start,
                                //         children: _colorPalette.map((color) {
                                //           final isSelected =
                                //               _selectedColor == color;
                                //           return GestureDetector(
                                //             onTap: () {
                                //               setState(() {
                                //                 _selectedColor = color;
                                //               });
                                //             },
                                //             child: Container(
                                //               margin:
                                //                   const EdgeInsets.symmetric(
                                //                     horizontal: 8,
                                //                   ),
                                //               width: 40,
                                //               height: 40,
                                //               decoration: BoxDecoration(
                                //                 color: color,
                                //                 shape: BoxShape.circle,
                                //                 border: Border.all(
                                //                   color: isSelected
                                //                       ? Colors.black
                                //                       : Colors.grey.shade400,
                                //                   width: isSelected ? 3 : 1,
                                //                 ),
                                //               ),
                                //               child: isSelected
                                //                   ? Icon(
                                //                       Icons.check,
                                //                       color: Colors.white,
                                //                       size: 20,
                                //                     )
                                //                   : null,
                                //             ),
                                //           );
                                //         }).toList(),
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                // const SizedBox(height: 24),
                                // Save button
                                // _isLoading
                                //     ? const Center(
                                //         child: CircularProgressIndicator(),
                                //       )
                                //     : PrimaryOutlineButton(
                                //         onPressed: _handleSave,
                                //         label: 'Update Loxone Room',
                                //         width: 260,
                                //       ),
                                // const SizedBox(height: 32),
                                // Sensors Section
                                if (_sensors.isNotEmpty) ...[
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Sensors',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ..._sensors.map((sensor) {
                                          final isEditing =
                                              _editingSensors[sensor.id] ??
                                              false;
                                          final isSaving =
                                              _savingSensors[sensor.id] ??
                                              false;

                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.black54,
                                                width: 2,
                                              ),
                                              borderRadius: BorderRadius.zero,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.sensors,
                                                        color: Colors.black87,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          sensor.name,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // if (isEditing) ...[
                                                //   const Divider(height: 1),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: TextFormField(
                                                              controller:
                                                                  _minControllers[sensor
                                                                      .id],
                                                              keyboardType:
                                                                  const TextInputType.numberWithOptions(
                                                                    decimal:
                                                                        true,
                                                                  ),
                                                              decoration: InputDecoration(
                                                                hintText:
                                                                    'Enter minimum value',
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        0,
                                                                      ),
                                                                ),
                                                                prefixIcon: Icon(
                                                                  Icons
                                                                      .trending_down,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          Expanded(
                                                            child: TextFormField(
                                                              controller:
                                                                  _maxControllers[sensor
                                                                      .id],
                                                              keyboardType:
                                                                  const TextInputType.numberWithOptions(
                                                                    decimal:
                                                                        true,
                                                                  ),
                                                              decoration: InputDecoration(
                                                                hintText:
                                                                    'Enter maximum value',
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        0,
                                                                      ),
                                                                ),
                                                                prefixIcon: Icon(
                                                                  Icons
                                                                      .trending_up,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // ] else ...[
                                                //   if (sensor
                                                //           .minValue
                                                //           .isNotEmpty ||
                                                //       sensor
                                                //           .maxValue
                                                //           .isNotEmpty)
                                                //     Padding(
                                                //       padding:
                                                //           const EdgeInsets.only(
                                                //             left: 16,
                                                //             right: 16,
                                                //             bottom: 16,
                                                //           ),
                                                //       child: Row(
                                                //         children: [
                                                //           if (sensor
                                                //               .minValue
                                                //               .isNotEmpty) ...[
                                                //             Icon(
                                                //               Icons
                                                //                   .trending_down,
                                                //               size: 16,
                                                //               color: Colors
                                                //                   .grey[600],
                                                //             ),
                                                //             const SizedBox(
                                                //               width: 4,
                                                //             ),
                                                //             Text(
                                                //               'Min: ${sensor.minValue}',
                                                //               style: TextStyle(
                                                //                 fontSize: 14,
                                                //                 color: Colors
                                                //                     .grey[600],
                                                //               ),
                                                //             ),
                                                //           ],
                                                //           if (sensor
                                                //                   .minValue
                                                //                   .isNotEmpty &&
                                                //               sensor
                                                //                   .maxValue
                                                //                   .isNotEmpty)
                                                //             const SizedBox(
                                                //               width: 16,
                                                //             ),
                                                //           if (sensor
                                                //               .maxValue
                                                //               .isNotEmpty) ...[
                                                //             Icon(
                                                //               Icons.trending_up,
                                                //               size: 16,
                                                //               color: Colors
                                                //                   .grey[600],
                                                //             ),
                                                //             const SizedBox(
                                                //               width: 4,
                                                //             ),
                                                //             Text(
                                                //               'Max: ${sensor.maxValue}',
                                                //               style: TextStyle(
                                                //                 fontSize: 14,
                                                //                 color: Colors
                                                //                     .grey[600],
                                                //               ),
                                                //             ),
                                                //           ],
                                                //         ],
                                                //       ),
                                                //     ),
                                                // ],
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                                // Save button
                                _isLoadingSensors
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : PrimaryOutlineButton(
                                        onPressed: _handleSaveSensors,
                                        label: 'Save Sensors thresholds',
                                        width: 260,
                                      ),
                              ],
                            ),
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

class SensorData {
  final String id;
  final String name;
  final String minValue;
  final String maxValue;

  SensorData({
    required this.id,
    required this.name,
    required this.minValue,
    required this.maxValue,
  });
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
