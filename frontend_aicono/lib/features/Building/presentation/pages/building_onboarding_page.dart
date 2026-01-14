import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/routing/app_router.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_bloc.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_event.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_state.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_appearance_step.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_list_step.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_plan_step.dart';
import '../../../../core/widgets/app_footer.dart';

class BuildingOnboardingPage extends StatefulWidget {
  final String? buildingId;

  const BuildingOnboardingPage({super.key, this.buildingId});

  @override
  State<BuildingOnboardingPage> createState() => _BuildingOnboardingPageState();
}

class _BuildingOnboardingPageState extends State<BuildingOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  BuildingEntity? _buildingData;
  int? _editingFloorNumber; // Track which floor is being edited
  final Set<int> _completedFloors = {}; // Track completed floors

  @override
  void initState() {
    super.initState();
    // Initialize with a default name if creating new building
    _buildingData = BuildingEntity(
      name: widget.buildingId != null ? '' : 'Neues Gebäude',
    );

    // If editing existing building, load it
    if (widget.buildingId != null) {
      _loadBuilding();
    }
  }

  void _loadBuilding() {
    final state = context.read<BuildingBloc>().state;
    if (state is BuildingLoaded) {
      final building = state.buildings.firstWhere(
        (b) => b.id == widget.buildingId,
        orElse: () => BuildingEntity(name: ''),
      );
      if (building.id != null) {
        setState(() {
          _buildingData = building;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Steps: 0=Appearance, 1=FloorList, 2=FloorPlan
    if (_currentStep < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else if (_currentStep == 1) {
      // From floor list, if all floors completed, save and finish
      _saveBuilding();
    } else {
      // From floor plan step, go back to floor list
      _goToFloorList();
    }
  }

  void _goToFloorList() {
    // Navigate back to floor list step
    setState(() {
      _currentStep = 1;
      // Mark the floor as completed when returning from floor plan
      if (_editingFloorNumber != null) {
        _completedFloors.add(_editingFloorNumber!);
      }
      _editingFloorNumber = null;
    });
    _pageController.jumpToPage(1);
  }

  void _editFloor(int floorNumber) {
    // Navigate to floor plan step for the specific floor
    setState(() {
      _editingFloorNumber = floorNumber;
      _currentStep = 2;
    });
    _pageController.jumpToPage(2);
  }

  void _updateBuildingData(BuildingEntity updatedData) {
    setState(() {
      _buildingData = updatedData;
    });
  }

  void _saveBuilding() {
    if (_buildingData == null || _buildingData!.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte füllen Sie alle erforderlichen Felder aus'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.buildingId != null) {
      // Update existing building
      context.read<BuildingBloc>().add(UpdateBuildingEvent(_buildingData!));
    } else {
      // Create new building
      context.read<BuildingBloc>().add(CreateBuildingEvent(_buildingData!));
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.buildingId != null
              ? 'Gebäude aktualisiert'
              : 'Gebäude erstellt',
        ),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate back to building list
    AppRouter.instance.pop(context);
  }

  void _skipStep() {
    _nextStep();
  }

  @override
  Widget build(BuildContext context) {
    if (_buildingData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Colors.black,
              padding: EdgeInsets.all(10),
              height: screenSize.height * 0.95,
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox.expand(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Step 0: Building Appearance (includes number of floors)
                      BuildingAppearanceStep(
                        building: _buildingData!,
                        onUpdate: _updateBuildingData,
                        onNext: _nextStep,
                        onSkip: _skipStep,
                      ),
                      // Step 1: Floor List
                      BuildingFloorListStep(
                        building: _buildingData!,
                        onNext: _saveBuilding,
                        onSkip: _saveBuilding,
                        onEditFloor: _editFloor,
                        completedFloors: _completedFloors,
                      ),
                      // Step 2: Floor Plan (for editing a specific floor)
                      BuildingFloorPlanStep(
                        building: _buildingData!,
                        onNext: _goToFloorList,
                        onSkip: _goToFloorList,
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
            ),
            Container(
              color: Colors.black,
              child: AppFooter(onLanguageChanged: () {}, containerWidth: 700),
            ),
          ],
        ),
      ),
    );
  }
}
