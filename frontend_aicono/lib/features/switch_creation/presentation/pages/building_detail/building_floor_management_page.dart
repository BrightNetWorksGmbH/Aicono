import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_list_step.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_plan_step.dart';
import 'package:frontend_aicono/core/routing/app_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_floors_entity.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';

class BuildingFloorManagementPage extends StatefulWidget {
  final BuildingEntity building;
  final VoidCallback? onBack;
  final String? siteId;
  final String? buildingId;

  const BuildingFloorManagementPage({
    super.key,
    required this.building,
    this.onBack,
    this.siteId,
    this.buildingId,
  });

  @override
  State<BuildingFloorManagementPage> createState() =>
      _BuildingFloorManagementPageState();
}

class _BuildingFloorManagementPageState
    extends State<BuildingFloorManagementPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  int? _editingFloorNumber;
  String? _editingFloorName;
  Set<int> _completedFloors = {};
  bool _hasFetchedFloors = false;
  List<FloorDetail> _fetchedFloors = [];
  bool _isLoadingFloors = false;
  final DioClient _dioClient = sl<DioClient>();

  @override
  void initState() {
    super.initState();
    // Fetch floors from backend if buildingId is available
    if (widget.buildingId != null && widget.buildingId!.isNotEmpty) {
      _fetchFloorsFromBackend();
    }
  }

  Future<void> _fetchFloorsFromBackend() async {
    if (_hasFetchedFloors || widget.buildingId == null) return;

    setState(() {
      _isLoadingFloors = true;
    });

    try {
      final response = await _dioClient.get(
        '/api/v1/floors/building/${widget.buildingId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final floorsList = (data['data'] as List)
              .map((f) => FloorDetail.fromJson(f as Map<String, dynamic>))
              .toList();

          setState(() {
            _fetchedFloors = floorsList;
            _hasFetchedFloors = true;
            // Update completed floors based on floors with floor_plan_link
            _updateCompletedFloorsFromBackend(floorsList);
          });
        }
      }
    } catch (e) {
      // Silently fail - user can still add floors manually
      if (mounted) {
        debugPrint('Error fetching floors: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFloors = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _updateCompletedFloorsFromBackend(List<FloorDetail> floors) {
    // Extract floor numbers from backend data
    // Mark floors as completed if they have a floor_plan_link
    final completedFloorsSet = <int>{};
    final totalFloors = widget.building.numberOfFloors ?? 1;

    for (final floor in floors) {
      // Only mark as completed if floor has a floor plan link
      if (floor.floorPlanLink != null && floor.floorPlanLink!.isNotEmpty) {
        final floorName = floor.name.toLowerCase();
        // Try to extract floor number from name
        if (floorName.contains('ground') || floorName.contains('floor 0')) {
          completedFloorsSet.add(1);
        } else {
          // Try to extract number from "Floor X" or "Etage X"
          final match = RegExp(r'(\d+)').firstMatch(floorName);
          if (match != null) {
            final floorNum = int.tryParse(match.group(1) ?? '');
            if (floorNum != null && floorNum <= totalFloors) {
              completedFloorsSet.add(floorNum);
            }
          }
        }
      }
    }
    setState(() {
      _completedFloors = completedFloorsSet;
    });
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (context.canPop()) {
      context.pop();
    }
  }

  void _goToFloorList() {
    // Navigate back to floor list step
    setState(() {
      _currentStep = 0;
      // Mark the floor as completed when returning from floor plan
      if (_editingFloorNumber != null) {
        _completedFloors.add(_editingFloorNumber!);
      }
      _editingFloorNumber = null;
    });
    _pageController.jumpToPage(0);
  }

  void _editFloor(int floorNumber, String floorName) {
    // Navigate to floor plan step for the specific floor
    setState(() {
      _editingFloorNumber = floorNumber;
      _editingFloorName = floorName;
      _currentStep = 1;
    });
    _pageController.jumpToPage(1);
  }

  void _handleComplete() {
    // All floors completed, navigate to contact person step first
    context.pushNamed(
      Routelists.buildingContactPerson,
      queryParameters: {
        'buildingName': widget.building.name,
        if (widget.building.address != null &&
            widget.building.address!.isNotEmpty)
          'buildingAddress': widget.building.address!,
        'buildingId': widget.buildingId ?? '6948dcd113537bff98eb7338',
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
        if (widget.building.totalArea != null)
          'totalArea': widget.building.totalArea!.toString(),
        if (widget.building.numberOfRooms != null)
          'numberOfRooms': widget.building.numberOfRooms!.toString(),
        if (widget.building.constructionYear != null)
          'constructionYear': widget.building.constructionYear!,
      },
    );
  }

  void _handleSkip() {
    // Skip floor management, go back
    _handleBack();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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
                          TopHeader(
                            onLanguageChanged: _handleLanguageChanged,
                            containerWidth: screenSize.width > 500
                                ? 500
                                : screenSize.width * 0.98,
                          ),

                          // if (widget.onBack != null) ...[
                          //   const SizedBox(height: 16),
                          //   SizedBox(
                          //     width: screenSize.width < 600
                          //         ? screenSize.width * 0.95
                          //         : screenSize.width < 1200
                          //         ? screenSize.width * 0.5
                          //         : screenSize.width * 0.6,
                          //     child: Align(
                          //       alignment: Alignment.centerLeft,
                          //       child: InkWell(
                          //         onTap: _handleBack,
                          //         borderRadius: BorderRadius.circular(8),
                          //         child: const Padding(
                          //           padding: EdgeInsets.symmetric(
                          //             horizontal: 8,
                          //             vertical: 8,
                          //           ),
                          //           child: Icon(
                          //             Icons.arrow_back,
                          //             color: Colors.black87,
                          //             size: 24,
                          //           ),
                          //         ),
                          //       ),
                          //     ),
                          //   ),
                          // ],
                          const SizedBox(height: 16),
                          // Progress Indicator
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: LinearProgressIndicator(
                                value: 0.85, // Adjust value as needed
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8B9A5B),
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 50),
                          Expanded(
                            child: SizedBox.expand(
                              child: PageView(
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  // Step 0: Floor List
                                  BuildingFloorListStep(
                                    building: widget.building,
                                    onNext: _handleComplete,
                                    onSkip: _handleSkip,
                                    onBack: _handleBack,
                                    onEditFloor: _editFloor,
                                    completedFloors: _completedFloors,
                                    fetchedFloors: _fetchedFloors,
                                    isLoadingFloors: _isLoadingFloors,
                                  ),
                                  // Step 1: Floor Plan (for editing a specific floor)
                                  BuildingFloorPlanStep(
                                    building: widget.building,
                                    onNext: _goToFloorList,
                                    onSkip: _goToFloorList,
                                    onBack: _goToFloorList,
                                    onBuildFloorPlan: () {
                                      // Navigate to floor plan editor
                                      AppRouter.instance.pushNamed(
                                        context,
                                        'floor-plan-activation',
                                      );
                                    },
                                    onAddFloorPlan: () {
                                      // Handle add floor plan
                                      AppRouter.instance.pushNamed(
                                        context,
                                        'floor-plan-editor',
                                      );
                                    },
                                    floorNumber: _editingFloorNumber,
                                    floorName: _editingFloorName,
                                    fetchedFloors: _fetchedFloors,
                                  ),
                                ],
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
  }
}
