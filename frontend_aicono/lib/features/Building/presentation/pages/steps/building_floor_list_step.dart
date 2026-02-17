import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/widgets/page_header_row.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_floors_entity.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:dio/dio.dart';

import '../../../../../core/routing/routeLists.dart';
import '../../../../../core/storage/local_storage.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/primary_outline_button.dart';
import '../../../../../core/network/dio_client.dart';
import '../../../../../core/injection_container.dart';
import '../../../../switch_creation/presentation/bloc/property_setup_cubit.dart';

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
  final DioClient _dioClient = sl<DioClient>();

  // Local state for floors fetched from backend
  List<FloorDetail> _localFetchedFloors = [];
  bool _isLoadingFloors = false;
  int? _numFloorsFromBackend; // Store num_floors from building data response

  // TODO: Replace with your Google Places API key
  // You should store this securely, e.g., in environment variables or secure storage
  static const String _googlePlacesApiKey =
      'AIzaSyD80OmYALzbGTF3k9s_6UbAIrdhvEdQXV4';

  @override
  void initState() {
    super.initState();
    _completedFloors = Set<int>.from(widget.completedFloors);
    // Use fetched floors from widget if available, otherwise fetch from backend
    if (widget.fetchedFloors.isNotEmpty) {
      _localFetchedFloors = List.from(widget.fetchedFloors);
      _initializeFloorNames();
    } else {
      // Fetch floors from backend if building has an ID
      _fetchFloorsFromBackend();
    }
  }

  Future<void> _fetchFloorsFromBackend() async {
    // Get buildingId from building entity
    final buildingId =
        widget.building.id ??
        Uri.parse(
          GoRouterState.of(context).uri.toString(),
        ).queryParameters['buildingId'];
    if (buildingId == null || buildingId.isEmpty) {
      // No building ID, initialize with default floors
      _initializeFloorNames();
      return;
    }

    setState(() {
      _isLoadingFloors = true;
    });

    try {
      // First, fetch building data to get num_floors
      try {
        final buildingResponse = await _dioClient.get(
          '/api/v1/buildings/$buildingId',
        );

        if (buildingResponse.statusCode == 200 &&
            buildingResponse.data != null) {
          final buildingData = buildingResponse.data;
          // Extract num_floors from building data
          if (buildingData is Map<String, dynamic>) {
            final data = buildingData['data'] ?? buildingData;
            if (data is Map<String, dynamic>) {
              // Try different field names for number of floors
              final numFloors =
                  data['num_floors'] ??
                  data['numberOfFloors'] ??
                  data['num_students_employees'];

              if (numFloors != null) {
                final parsedFloors = int.tryParse(numFloors.toString());
                if (parsedFloors != null && parsedFloors > 0) {
                  _numFloorsFromBackend = parsedFloors;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching building data: $e');
        // Continue with floors fetch even if building data fetch fails
      }

      // Fetch floors
      final response = await _dioClient.get(
        '/api/v1/floors/building/$buildingId',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<FloorDetail> floorsList = [];

        // Handle different response formats
        if (data is List) {
          // Direct array response
          floorsList = data
              .map((f) => FloorDetail.fromJson(f as Map<String, dynamic>))
              .toList();
        } else if (data is Map<String, dynamic>) {
          // Wrapped response - check multiple possible structures
          if (data['data'] != null && data['data'] is List) {
            floorsList = (data['data'] as List)
                .map((f) => FloorDetail.fromJson(f as Map<String, dynamic>))
                .toList();
          } else if (data['floors'] != null && data['floors'] is List) {
            floorsList = (data['floors'] as List)
                .map((f) => FloorDetail.fromJson(f as Map<String, dynamic>))
                .toList();
          } else if (data['success'] == true && data['data'] != null) {
            floorsList = (data['data'] as List)
                .map((f) => FloorDetail.fromJson(f as Map<String, dynamic>))
                .toList();
          }
        }

        if (mounted) {
          setState(() {
            _localFetchedFloors = floorsList;
            // Update completed floors based on floors with floor_plan_link
            _updateCompletedFloorsFromBackend(floorsList);
            _initializeFloorNames();
          });
        }
      }
    } catch (e) {
      // Log error but allow user to still add floors manually
      if (mounted) {
        debugPrint('Error fetching floors from backend: $e');
        // Initialize with default floors even if fetch fails
        _initializeFloorNames();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFloors = false;
        });
      }
    }
  }

  void _updateCompletedFloorsFromBackend(List<FloorDetail> floors) {
    // Mark floors as completed if they have a floor_plan_link
    final completedFloorsSet = <int>{};
    final totalFloors = widget.building.numberOfFloors ?? 1;

    for (int i = 0; i < floors.length && i < totalFloors; i++) {
      final floor = floors[i];
      // Only mark as completed if floor has a floor plan link
      if (floor.floorPlanLink != null && floor.floorPlanLink!.isNotEmpty) {
        // Use index + 1 as floor number (floors are 1-indexed)
        completedFloorsSet.add(i + 1);
      }
    }

    setState(() {
      _completedFloors = completedFloorsSet;
    });
  }

  void _initializeFloorNames() {
    // Use _totalFloors which prioritizes backend floors length
    final totalFloors = _totalFloors;

    // Dispose existing controllers first to prevent memory leaks
    for (final controller in _floorNameControllers.values) {
      controller.dispose();
    }
    _floorNameControllers.clear();

    // Use local fetched floors if available, otherwise use widget's fetched floors
    final floorsToUse = _localFetchedFloors.isNotEmpty
        ? _localFetchedFloors
        : widget.fetchedFloors;

    // Create a map of floor indices to floor details from backend
    // Floors from backend are indexed by their position (0-indexed)
    final Map<int, FloorDetail> floorMap = {};
    for (int i = 0; i < floorsToUse.length; i++) {
      // Map backend floor at index i to floor number i+1
      floorMap[i + 1] = floorsToUse[i];
    }

    // Initialize controllers with existing names from backend or default values
    // Use totalFloors which is based on backend floors length
    for (int i = 1; i <= totalFloors; i++) {
      final floorDetail = floorMap[i];
      final defaultName = floorDetail?.name ?? 'Etage $i';
      _floorNameControllers[i] = TextEditingController(text: defaultName);
    }
  }

  void _navigateAfterCompletion() {
    // Extract fromDashboard from current route
    final fromDashboard = Uri.parse(
      GoRouterState.of(context).uri.toString(),
    ).queryParameters['fromDashboard'];

    // Get switchId from PropertySetupCubit (saved at login stage)
    final propertyCubit = sl<PropertySetupCubit>();
    final switchId = propertyCubit.state.switchId;
    final localStorage = sl<LocalStorage>();
    final siteId =
        localStorage.getSelectedSiteId() ?? propertyCubit.state.siteId;

    // Check if navigation is from dashboard
    final isFromDashboard = fromDashboard == 'true';

    if (isFromDashboard) {
      // If from dashboard, redirect to dashboard after completion
      context.goNamed(Routelists.dashboard);
    } else if (siteId == null && switchId != null && switchId.isNotEmpty) {
      context.goNamed(
        Routelists.addPropertyName,
        queryParameters: {'switchId': switchId},
      );
    } else {
      // Fallback: navigate to additional building list if switchId not available

      context.goNamed(
        Routelists.additionalBuildingList,
        queryParameters: {
          // if (widget.userName != null) 'userName': widget.userName!,
          if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
          if (fromDashboard != null) 'fromDashboard': fromDashboard,
        },
      );
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
      // If widget provides new fetched floors, use them
      if (widget.fetchedFloors.isNotEmpty) {
        setState(() {
          _localFetchedFloors = List.from(widget.fetchedFloors);
          _initializeFloorNames();
        });
      } else {
        setState(() {
          _initializeFloorNames();
        });
      }
    }
  }

  int get _totalFloors {
    // Priority 1: Use num_floors from building data response (num_students_employees or num_floors)
    if (_numFloorsFromBackend != null && _numFloorsFromBackend! > 0) {
      return _numFloorsFromBackend!;
    }

    // Priority 2: Use floors from backend if available
    final floorsToUse = _localFetchedFloors.isNotEmpty
        ? _localFetchedFloors
        : widget.fetchedFloors;

    if (floorsToUse.isNotEmpty) {
      // Use the length of floors from backend
      return floorsToUse.length;
    }

    // Priority 3: Fallback to building.numberOfFloors if no floors from backend
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
                  if (_isLoadingFloors || widget.isLoadingFloors)
                    const Center(child: CircularProgressIndicator())
                  // Floor list - show fetched floors if available, otherwise show default list
                  else if (_localFetchedFloors.isNotEmpty ||
                      widget.fetchedFloors.isNotEmpty)
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
                        onTap: _navigateAfterCompletion,
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

    // Use local fetched floors if available, otherwise use widget's fetched floors
    final floorsToUse = _localFetchedFloors.isNotEmpty
        ? _localFetchedFloors
        : widget.fetchedFloors;

    // Create a map of floor numbers (1-indexed) to floor details from backend
    final Map<int, FloorDetail> floorMap = {};
    for (int i = 0; i < floorsToUse.length; i++) {
      // Map backend floor at index i to floor number i+1
      floorMap[i + 1] = floorsToUse[i];
    }

    // Generate floor list based on total floors
    // If numberOfFloors > fetchedFloors.length, show additional floors with default names
    for (int i = 1; i <= _totalFloors; i++) {
      final floorDetail = floorMap[i];
      // Use name from backend if available, otherwise use default "Etage i"
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
}
//   void _showPlaceSearchDialog(int floorNumber) async {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Container(
//           width: MediaQuery.of(context).size.width * 0.9,
//           height: MediaQuery.of(context).size.height * 0.7,
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               // Header
//               Row(
//                 children: [
//                   Text(
//                     'Search Places - Floor $floorNumber',
//                     style: const TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const Spacer(),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.of(context).pop(),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               // PlaceSearchField widget
//               Expanded(
//                 child: PlaceSearchField(
//                   apiKey: _googlePlacesApiKey,
//                   isLatLongRequired: true,
//                   // Optional: Add CORS proxy URL for web if needed
//                   webCorsProxyUrl: "https://cors-anywhere.herokuapp.com",
//                   onPlaceSelected: (placeId, latLng) async {
//                     developer.log('Place ID: $placeId');
//                     developer.log('Latitude and Longitude: $latLng');

//                     // Get place details to get the name
//                     try {
//                       // Use the new Places API (New) REST endpoint to get place details
//                       final response = await _dio.get(
//                         'https://places.googleapis.com/v1/places/$placeId',
//                         options: Options(
//                           headers: {
//                             'Content-Type': 'application/json',
//                             'X-Goog-Api-Key': _googlePlacesApiKey,
//                             'X-Goog-FieldMask':
//                                 'id,displayName,formattedAddress',
//                           },
//                         ),
//                       );

//                       if (response.statusCode == 200 &&
//                           response.data != null &&
//                           mounted) {
//                         final place = response.data;

//                         // Handle displayName which can be an object with 'text' property or a string
//                         final displayName = place['displayName'];
//                         final displayNameText = displayName is Map
//                             ? (displayName['text'] ?? displayName.toString())
//                             : (displayName?.toString() ?? '');

//                         // Update the floor name with the place name
//                         final placeName = displayNameText.isNotEmpty
//                             ? displayNameText
//                             : (place['formattedAddress'] ?? '');

//                         if (_floorNameControllers.containsKey(floorNumber)) {
//                           _floorNameControllers[floorNumber]!.text = placeName;
//                           // Call onEditFloor to save the change
//                           widget.onEditFloor(floorNumber, placeName);
//                         }

//                         Navigator.of(context).pop();
//                       }
//                     } catch (e) {
//                       developer.log('Error getting place details: $e');
//                       if (mounted) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             content: Text('Error loading place details: $e'),
//                             backgroundColor: Colors.red,
//                           ),
//                         );
//                       }
//                     }
//                   },
//                   decorationBuilder: (context, child) {
//                     return Material(
//                       type: MaterialType.card,
//                       elevation: 4,
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(8),
//                       child: child,
//                     );
//                   },
//                   itemBuilder: (context, prediction) => ListTile(
//                     leading: const Icon(Icons.location_on),
//                     title: Text(
//                       prediction.description,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
