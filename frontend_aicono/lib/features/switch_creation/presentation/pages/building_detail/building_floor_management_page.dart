import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_list_step.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_plan_step.dart';
import 'package:frontend_aicono/core/routing/app_router.dart';

class BuildingFloorManagementPage extends StatefulWidget {
  final BuildingEntity building;
  final VoidCallback? onBack;

  const BuildingFloorManagementPage({
    super.key,
    required this.building,
    this.onBack,
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
  final Set<int> _completedFloors = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    // All floors completed, go back to building details page
    _handleBack();
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
  }
}

