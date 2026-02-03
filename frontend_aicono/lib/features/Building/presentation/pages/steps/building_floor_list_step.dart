import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/widgets/page_header_row.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_floors_entity.dart';
import 'package:google_places_api_flutter/google_places_api_flutter.dart';
import 'package:dio/dio.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/primary_outline_button.dart';

class BuildingFloorListStep extends StatefulWidget {
  final BuildingEntity building;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final Function(int floorNumber, String floorName) onEditFloor;
  final Set<int> completedFloors;
  final List<FloorDetail> fetchedFloors;
  final bool isLoadingFloors;

  const BuildingFloorListStep({
    super.key,
    required this.building,
    required this.onNext,
    this.onSkip,
    this.onBack,
    required this.onEditFloor,
    this.completedFloors = const {},
    this.fetchedFloors = const [],
    this.isLoadingFloors = false,
  });

  @override
  State<BuildingFloorListStep> createState() => _BuildingFloorListStepState();
}

class _BuildingFloorListStepState extends State<BuildingFloorListStep> {
  late Set<int> _completedFloors;
  final Map<int, TextEditingController> _floorNameControllers = {};
  final Dio _dio = Dio();

  // TODO: Replace with your Google Places API key
  // You should store this securely, e.g., in environment variables or secure storage
  static const String _googlePlacesApiKey =
      'AIzaSyD80OmYALzbGTF3k9s_6UbAIrdhvEdQXV4';

  @override
  void initState() {
    super.initState();
    _completedFloors = Set<int>.from(widget.completedFloors);
    _initializeFloorNames();
  }

  void _initializeFloorNames() {
    final totalFloors = widget.building.numberOfFloors ?? 1;

    // Dispose existing controllers first to prevent memory leaks
    for (final controller in _floorNameControllers.values) {
      controller.dispose();
    }
    _floorNameControllers.clear();

    // Create a map of floor numbers to floor details from backend
    final Map<int, FloorDetail> floorMap = {};
    if (widget.fetchedFloors.isNotEmpty) {
      for (final floor in widget.fetchedFloors) {
        final floorName = floor.name.toLowerCase();
        int? floorNumber;

        // Extract floor number from name
        if (floorName.contains('ground') || floorName.contains('floor 0')) {
          floorNumber = 1;
        } else {
          final match = RegExp(r'(\d+)').firstMatch(floorName);
          if (match != null) {
            floorNumber = int.tryParse(match.group(1) ?? '');
          }
        }

        if (floorNumber != null && floorNumber <= totalFloors) {
          // If multiple floors have same number, keep the one with floor_plan_link
          if (!floorMap.containsKey(floorNumber) ||
              (floor.floorPlanLink != null &&
                  floor.floorPlanLink!.isNotEmpty)) {
            floorMap[floorNumber] = floor;
          }
        }
      }
    }

    // Initialize controllers with existing names or default values
    for (int i = 1; i <= totalFloors; i++) {
      final floorDetail = floorMap[i];
      final defaultName = floorDetail?.name ?? 'Etage $i';
      _floorNameControllers[i] = TextEditingController(text: defaultName);
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _floorNameControllers.values) {
      controller.dispose();
    }
    _dio.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(BuildingFloorListStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completedFloors != oldWidget.completedFloors) {
      setState(() {
        _completedFloors = Set<int>.from(widget.completedFloors);
      });
    }
    // Update controllers if fetched floors changed or total floors changed
    if (widget.fetchedFloors != oldWidget.fetchedFloors ||
        widget.building.numberOfFloors != oldWidget.building.numberOfFloors) {
      setState(() {
        _initializeFloorNames();
      });
    }
  }

  int get _totalFloors {
    return widget.building.numberOfFloors ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: screenSize.width < 600
                  ? screenSize.width * 0.95
                  : screenSize.width < 1200
                  ? screenSize.width * 0.5
                  : screenSize.width * 0.6,
            ),
            child: Container(
              width: screenSize.width < 600
                  ? screenSize.width * 0.95
                  : screenSize.width < 1200
                  ? screenSize.width * 0.5
                  : screenSize.width * 0.6,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                // crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back button
                  SizedBox(
                    width: screenSize.width < 600
                        ? screenSize.width * 0.95
                        : screenSize.width < 1200
                        ? screenSize.width * 0.5
                        : screenSize.width * 0.6,
                    child: PageHeaderRow(
                      title: 'Etagen verwalten',
                      showBackButton: widget.onBack != null,
                      onBack: widget.onBack,
                    ),
                  ),

                  const SizedBox(height: 32),
                  // Loading state
                  if (widget.isLoadingFloors)
                    const Center(child: CircularProgressIndicator())
                  // Floor list - show fetched floors if available, otherwise show default list
                  else if (widget.fetchedFloors.isNotEmpty)
                    ..._buildFloorsFromBackend(screenSize)
                  else if (_totalFloors > 0)
                    ...List.generate(_totalFloors, (index) {
                      final floorNumber = index + 1;
                      final isCompleted = _completedFloors.contains(
                        floorNumber,
                      );
                      return _buildFloorItem(
                        floorNumber: floorNumber,
                        floorName: 'Etage $floorNumber',
                        isCompleted: isCompleted,
                        screenSize: screenSize,
                      );
                    })
                  else
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Center(
                        child: Text(
                          'Keine Etagen definiert',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (widget.onSkip != null)
                    // Skip step link
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onSkip,
                        child: Text(
                          'Schritt überspringen',
                          style: AppTextStyles.bodyMedium.copyWith(
                            decoration: TextDecoration.underline,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // if (_completedFloors.length == _totalFloors &&
                  //     _totalFloors > 0)
                  Material(
                    color: Colors.transparent,
                    child: PrimaryOutlineButton(
                      label: 'Das passt so',
                      width: 260,
                      onPressed: widget.onNext,
                    ),
                  ),

                  // if (widget.onSkip != null)
                  //   InkWell(
                  //     onTap: widget.onSkip,
                  //     child: Padding(
                  //       padding: const EdgeInsets.symmetric(vertical: 12),
                  //       child: Center(
                  //         child: Text(
                  //           'Schritt überspringen',
                  //           style: TextStyle(
                  //             color: Colors.grey[600],
                  //             fontSize: 14,
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // const SizedBox(height: 8),
                  // // Next button (only show if all floors are completed)
                  // if (_completedFloors.length == _totalFloors &&
                  //     _totalFloors > 0)
                  //   ElevatedButton(
                  //     onPressed: widget.onNext,
                  //     style: ElevatedButton.styleFrom(
                  //       padding: const EdgeInsets.symmetric(vertical: 16),
                  //       backgroundColor: Colors.blue[700],
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //     ),
                  //     child: const Text(
                  //       'Weiter',
                  //       style: TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 16,
                  //         fontWeight: FontWeight.w500,
                  //       ),
                  //     ),
                  //   ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Method to mark a floor as completed (can be called from parent)
  void markFloorCompleted(int floorNumber) {
    setState(() {
      _completedFloors.add(floorNumber);
    });
  }

  // Method to check if a floor is completed
  bool isFloorCompleted(int floorNumber) {
    return _completedFloors.contains(floorNumber);
  }

  // Build floors from backend data
  List<Widget> _buildFloorsFromBackend(Size screenSize) {
    final List<Widget> floorWidgets = [];

    // Create a map of floor numbers to floor details
    final Map<int, FloorDetail> floorMap = {};
    for (final floor in widget.fetchedFloors) {
      final floorName = floor.name.toLowerCase();
      int? floorNumber;

      // Extract floor number from name
      if (floorName.contains('ground') || floorName.contains('floor 0')) {
        floorNumber = 1;
      } else {
        final match = RegExp(r'(\d+)').firstMatch(floorName);
        if (match != null) {
          floorNumber = int.tryParse(match.group(1) ?? '');
        }
      }

      if (floorNumber != null && floorNumber <= _totalFloors) {
        // If multiple floors have same number, keep the one with floor_plan_link
        if (!floorMap.containsKey(floorNumber) ||
            (floor.floorPlanLink != null && floor.floorPlanLink!.isNotEmpty)) {
          floorMap[floorNumber] = floor;
        }
      }
    }

    // Generate floor list based on total floors
    for (int i = 1; i <= _totalFloors; i++) {
      final floorDetail = floorMap[i];
      final floorName = floorDetail?.name ?? 'Etage $i';
      final isCompleted =
          floorDetail != null &&
          floorDetail.floorPlanLink != null &&
          floorDetail.floorPlanLink!.isNotEmpty;

      floorWidgets.add(
        _buildFloorItem(
          floorNumber: i,
          floorName: floorName,
          isCompleted: isCompleted,
          screenSize: screenSize,
        ),
      );
    }

    return floorWidgets;
  }

  Widget _buildFloorItem({
    required int floorNumber,
    required String floorName,
    required bool isCompleted,
    required Size screenSize,
  }) {
    // Ensure controller exists, create if it doesn't (shouldn't happen after init)
    if (!_floorNameControllers.containsKey(floorNumber)) {
      _floorNameControllers[floorNumber] = TextEditingController(
        text: floorName,
      );
    }
    final controller = _floorNameControllers[floorNumber]!;

    return Container(
      width: screenSize.width < 600
          ? screenSize.width * 0.95
          : screenSize.width < 1200
          ? screenSize.width * 0.5
          : screenSize.width * 0.6,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(0),
        border: Border.all(
          color: isCompleted ? Colors.green : Colors.grey[300]!,
          width: isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Floor number/name with editable text field
            Expanded(
              child: Row(
                children: [
                  if (isCompleted)
                    Image.asset(
                      'assets/images/check.png',
                      width: 20,
                      height: 20,
                    ),
                  if (isCompleted) const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isCompleted ? Colors.green[700] : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: InputBorder.none,
                        // border: OutlineInputBorder(
                        //   borderRadius: BorderRadius.zero,
                        //   borderSide: BorderSide(
                        //     color: Colors.grey[300]!,
                        //     width: 1,
                        //   ),
                        // ),
                        // enabledBorder: OutlineInputBorder(
                        //   borderRadius: BorderRadius.zero,
                        //   // borderSide: BorderSide(
                        //   //   color: Colors.grey[300]!,
                        //   //   width: 1,
                        //   // ),
                        // ),
                        // focusedBorder: OutlineInputBorder(
                        //   borderRadius: BorderRadius.zero,
                        //   // borderSide: BorderSide(
                        //   //   color: isCompleted ? Colors.green : Colors.black87,
                        //   //   width: 2,
                        //   // ),
                        // ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  // if (isCompleted) ...[
                  //   const SizedBox(width: 8),
                  //   Text(
                  //     '(Abgeschlossen)',
                  //     style: TextStyle(
                  //       fontSize: 14,
                  //       color: Colors.green[600],
                  //       fontStyle: FontStyle.italic,
                  //     ),
                  //   ),
                  // ],
                ],
              ),
            ),
            // TextButton(
            //   onPressed: () {
            //     _showPlaceSearchDialog(floorNumber);
            //   },
            //   child: const Text(
            //     'Places',
            //     style: TextStyle(
            //       decoration: TextDecoration.underline,
            //       color: Colors.black87,
            //       fontSize: 14,
            //       fontWeight: FontWeight.w500,
            //     ),
            //   ),
            // ),
            // Edit button
            TextButton(
              onPressed: () {
                final currentFloorName = controller.text.trim().isNotEmpty
                    ? controller.text.trim()
                    : floorName;
                widget.onEditFloor(floorNumber, currentFloorName);
              },
              child: Text(
                isCompleted ? 'Bearbeiten' : 'Hinzufügen',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceSearchDialog(int floorNumber) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Search Places - Floor $floorNumber',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // PlaceSearchField widget
              Expanded(
                child: PlaceSearchField(
                  apiKey: _googlePlacesApiKey,
                  isLatLongRequired: true,
                  // Optional: Add CORS proxy URL for web if needed
                  webCorsProxyUrl: "https://cors-anywhere.herokuapp.com",
                  onPlaceSelected: (placeId, latLng) async {
                    developer.log('Place ID: $placeId');
                    developer.log('Latitude and Longitude: $latLng');

                    // Get place details to get the name
                    try {
                      // Use the new Places API (New) REST endpoint to get place details
                      final response = await _dio.get(
                        'https://places.googleapis.com/v1/places/$placeId',
                        options: Options(
                          headers: {
                            'Content-Type': 'application/json',
                            'X-Goog-Api-Key': _googlePlacesApiKey,
                            'X-Goog-FieldMask':
                                'id,displayName,formattedAddress',
                          },
                        ),
                      );

                      if (response.statusCode == 200 &&
                          response.data != null &&
                          mounted) {
                        final place = response.data;

                        // Handle displayName which can be an object with 'text' property or a string
                        final displayName = place['displayName'];
                        final displayNameText = displayName is Map
                            ? (displayName['text'] ?? displayName.toString())
                            : (displayName?.toString() ?? '');

                        // Update the floor name with the place name
                        final placeName = displayNameText.isNotEmpty
                            ? displayNameText
                            : (place['formattedAddress'] ?? '');

                        if (_floorNameControllers.containsKey(floorNumber)) {
                          _floorNameControllers[floorNumber]!.text = placeName;
                          // Call onEditFloor to save the change
                          widget.onEditFloor(floorNumber, placeName);
                        }

                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      developer.log('Error getting place details: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error loading place details: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  decorationBuilder: (context, child) {
                    return Material(
                      type: MaterialType.card,
                      elevation: 4,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: child,
                    );
                  },
                  itemBuilder: (context, prediction) => ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(
                      prediction.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
