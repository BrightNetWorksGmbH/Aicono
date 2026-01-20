import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_floors_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_floors_entity.dart';

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
  Set<int> _completedFloors = {};
  bool _hasFetchedFloors = false;

  @override
  void initState() {
    super.initState();
    // Fetch floors from backend if buildingId is available
    if (widget.buildingId != null &&
        widget.buildingId!.isNotEmpty &&
        !_hasFetchedFloors) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<GetFloorsBloc>().add(
            GetFloorsSubmitted(buildingId: widget.buildingId!),
          );
          _hasFetchedFloors = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _updateCompletedFloorsFromBackend(List<FloorDetail> floors) {
    // Extract floor numbers from backend data
    // Assuming floor names follow pattern like "Ground Floor", "Floor 1", "Floor 2", etc.
    final completedFloorsSet = <int>{};
    for (final floor in floors) {
      final floorName = floor.name.toLowerCase();
      // Try to extract floor number from name
      if (floorName.contains('ground') || floorName.contains('floor 0')) {
        completedFloorsSet.add(1);
      } else {
        // Try to extract number from "Floor X" or "Etage X"
        final match = RegExp(r'(\d+)').firstMatch(floorName);
        if (match != null) {
          final floorNum = int.tryParse(match.group(1) ?? '');
          if (floorNum != null) {
            completedFloorsSet.add(floorNum);
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

  void _editFloor(int floorNumber) {
    // Navigate to floor plan step for the specific floor
    setState(() {
      _editingFloorNumber = floorNumber;
      _currentStep = 1;
    });
    _pageController.jumpToPage(1);
  }

  void _handleComplete() {
    // All floors completed, navigate to responsible persons page
    context.pushNamed(
      Routelists.buildingResponsiblePersons,
      queryParameters: {
        'buildingName': widget.building.name,
        if (widget.building.address != null &&
            widget.building.address!.isNotEmpty)
          'buildingAddress': widget.building.address!,
        'buildingId': widget.buildingId ?? '6948dcd113537bff98eb7338',
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
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

    return BlocProvider(
      create: (_) => sl<GetFloorsBloc>(),
      child: BlocListener<GetFloorsBloc, GetFloorsState>(
        listener: (context, state) {
          if (state is GetFloorsSuccess) {
            _updateCompletedFloorsFromBackend(state.floors);
          }
        },
        child: Builder(
          builder: (blocContext) {
            // Fetch floors when buildingId is available and we haven't fetched yet
            if (!_hasFetchedFloors &&
                widget.buildingId != null &&
                widget.buildingId!.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  blocContext.read<GetFloorsBloc>().add(
                    GetFloorsSubmitted(buildingId: widget.buildingId!),
                  );
                  _hasFetchedFloors = true;
                }
              });
            }

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
                                  InkWell(
                                    onTap: () {
                                      context.read<GetFloorsBloc>().add(
                                        GetFloorsSubmitted(
                                          buildingId: widget.buildingId!,
                                        ),
                                      );
                                    },
                                    child: TopHeader(
                                      onLanguageChanged: _handleLanguageChanged,
                                      containerWidth: screenSize.width > 500
                                          ? 500
                                          : screenSize.width * 0.98,
                                    ),
                                  ),
                                  if (widget.onBack != null) ...[
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        onTap: _handleBack,
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          child: Icon(
                                            Icons.arrow_back,
                                            color: Colors.black87,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 50),
                                  Expanded(
                                    child: SizedBox.expand(
                                      child: PageView(
                                        controller: _pageController,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        children: [
                                          // Step 0: Floor List
                                          BuildingFloorListStep(
                                            building: widget.building,
                                            onNext: _handleComplete,
                                            onSkip: _handleSkip,
                                            onBack: _handleBack,
                                            onEditFloor: _editFloor,
                                            completedFloors: _completedFloors,
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
          },
        ),
      ),
    );
  }
}
