import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/routing/app_router.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_bloc.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_event.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_state.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:frontend_aicono/features/Building/presentation/components/building_header.dart';
import 'package:frontend_aicono/features/Building/presentation/components/progress_indicator_widget.dart';

class BuildingListPage extends StatefulWidget {
  const BuildingListPage({super.key});

  @override
  State<BuildingListPage> createState() => _BuildingListPageState();
}

class _BuildingListPageState extends State<BuildingListPage> {
  final List<TextEditingController> _tempBuildingControllers = [];
  final List<FocusNode> _tempBuildingFocusNodes = [];
  final Map<String, TextEditingController> _editControllers = {};
  final Map<String, FocusNode> _editFocusNodes = {};
  String? _editingBuildingId;

  @override
  void initState() {
    super.initState();
    context.read<BuildingBloc>().add(const LoadBuildingsEvent());
  }

  @override
  void dispose() {
    for (var controller in _tempBuildingControllers) {
      controller.dispose();
    }
    for (var focusNode in _tempBuildingFocusNodes) {
      focusNode.dispose();
    }
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _editFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _addNewBuildingField() {
    // First, save any existing temporary fields that have values
    _saveAllTempFieldsWithValues();

    // Then add a new empty field
    setState(() {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      _tempBuildingControllers.add(controller);
      _tempBuildingFocusNodes.add(focusNode);

      // Focus on the new field after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          focusNode.requestFocus();
        }
      });
    });
  }

  void _saveAllTempFieldsWithValues() {
    bool hasSavedAny = false;

    // Save all temporary fields that have values (from last to first to avoid index issues)
    for (int i = _tempBuildingControllers.length - 1; i >= 0; i--) {
      final controller = _tempBuildingControllers[i];
      final buildingName = controller.text.trim();

      if (buildingName.isNotEmpty) {
        hasSavedAny = true;
        final newBuilding = BuildingEntity(name: buildingName, status: 'draft');
        context.read<BuildingBloc>().add(CreateBuildingEvent(newBuilding));

        // Remove the temporary field
        setState(() {
          _tempBuildingControllers[i].dispose();
          _tempBuildingFocusNodes[i].dispose();
          _tempBuildingControllers.removeAt(i);
          _tempBuildingFocusNodes.removeAt(i);
        });
      }
    }

    // Reload buildings list after saving if any were saved
    if (hasSavedAny) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          context.read<BuildingBloc>().add(const LoadBuildingsEvent());
        }
      });
    }
  }

  void _saveBuildingFromField(int index) {
    final controller = _tempBuildingControllers[index];
    final buildingName = controller.text.trim();

    if (buildingName.isNotEmpty) {
      final newBuilding = BuildingEntity(name: buildingName, status: 'draft');

      context.read<BuildingBloc>().add(CreateBuildingEvent(newBuilding));

      // Remove the temporary field
      setState(() {
        _tempBuildingControllers[index].dispose();
        _tempBuildingFocusNodes[index].dispose();
        _tempBuildingControllers.removeAt(index);
        _tempBuildingFocusNodes.removeAt(index);
      });

      // Reload buildings list
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          context.read<BuildingBloc>().add(const LoadBuildingsEvent());
        }
      });
    }
  }

  void _removeTempField(int index) {
    setState(() {
      _tempBuildingControllers[index].dispose();
      _tempBuildingFocusNodes[index].dispose();
      _tempBuildingControllers.removeAt(index);
      _tempBuildingFocusNodes.removeAt(index);
    });
  }

  void _enterEditMode(BuildingEntity building) {
    if (building.id == null) return;

    setState(() {
      _editingBuildingId = building.id;
      if (!_editControllers.containsKey(building.id)) {
        _editControllers[building.id!] = TextEditingController(
          text: building.name,
        );
        final focusNode = FocusNode();
        _editFocusNodes[building.id!] = focusNode;

        // Save when focus is lost
        focusNode.addListener(() {
          if (!focusNode.hasFocus && _editingBuildingId == building.id) {
            _exitEditMode(building, save: true);
          }
        });
      }
    });

    // Focus on the edit field
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _editFocusNodes.containsKey(building.id)) {
        _editFocusNodes[building.id!]?.requestFocus();
      }
    });
  }

  void _exitEditMode(BuildingEntity building, {bool save = true}) {
    if (building.id == null) return;

    final controller = _editControllers[building.id!];
    final focusNode = _editFocusNodes[building.id!];

    if (save && controller != null) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty && newName != building.name) {
        final updatedBuilding = building.copyWith(name: newName);
        context.read<BuildingBloc>().add(UpdateBuildingEvent(updatedBuilding));
      }
    }

    setState(() {
      _editingBuildingId = null;
      if (controller != null) {
        controller.dispose();
        _editControllers.remove(building.id);
      }
      if (focusNode != null) {
        focusNode.dispose();
        _editFocusNodes.remove(building.id);
      }
    });
  }

  void _deleteBuilding(BuildingEntity building) {
    if (building.id == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gebäude löschen'),
        content: Text('Möchten Sie "${building.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              context.read<BuildingBloc>().add(
                DeleteBuildingEvent(building.id!),
              );
              Navigator.pop(context);
              _exitEditMode(building, save: false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            child: ListView(
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: BuildingHeader(
                    userName: 'Stephan',
                    onMenuTap: () {
                      // Handle menu tap
                    },
                    onProfileTap: () {
                      // Handle profile tap
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Centered container with responsive width
                Center(
                  child: SizedBox(
                    width: screenSize.width < 600
                        ? screenSize.width * 0.95
                        : screenSize.width < 1200
                        ? screenSize.width * 0.5
                        : screenSize.width * 0.6,
                    child: Column(
                      children: [
                        // Progress indicator
                        Container(
                          // color: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ProgressIndicatorWidget(
                            progress: 0.75,
                            message: 'Fast geschafft, Stephan!',
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Main content card
                        Container(
                          height: screenSize.height * 0.8,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: BlocBuilder<BuildingBloc, BuildingState>(
                            builder: (context, state) {
                              if (state is BuildingLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (state is BuildingError) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Error: ${state.message}'),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          context.read<BuildingBloc>().add(
                                            const LoadBuildingsEvent(),
                                          );
                                        },
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (state is BuildingLoaded) {
                                final buildings = state.buildings;

                                return Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Question
                                      const Text(
                                        'Hat die Liegenschaft weitere Gebäude?',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 32),
                                      // Building list
                                      Expanded(
                                        child:
                                            (buildings.isEmpty &&
                                                _tempBuildingControllers
                                                    .isEmpty)
                                            ? Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.business,
                                                      size: 64,
                                                      color: Colors.grey[400],
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Noch keine Gebäude',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : ListView.builder(
                                                itemCount:
                                                    buildings.length +
                                                    _tempBuildingControllers
                                                        .length,
                                                itemBuilder: (context, index) {
                                                  // Check if this is a temporary input field
                                                  if (index >=
                                                      buildings.length) {
                                                    final tempIndex =
                                                        index -
                                                        buildings.length;
                                                    return _buildTempBuildingField(
                                                      tempIndex,
                                                    );
                                                  }

                                                  // Regular building card
                                                  final building =
                                                      buildings[index];
                                                  final isCompleted =
                                                      building.status ==
                                                          'completed' ||
                                                      (building
                                                              .name
                                                              .isNotEmpty &&
                                                          building.address !=
                                                              null);
                                                  return _buildBuildingCard(
                                                    building: building,
                                                    isCompleted: isCompleted,
                                                    isEditing:
                                                        _editingBuildingId ==
                                                        building.id,
                                                    onNameTap: () {
                                                      _enterEditMode(building);
                                                    },
                                                    onDelete: () {
                                                      _deleteBuilding(building);
                                                    },
                                                    onSaveEdit: () {
                                                      _exitEditMode(
                                                        building,
                                                        save: true,
                                                      );
                                                    },
                                                    onCancelEdit: () {
                                                      _exitEditMode(
                                                        building,
                                                        save: false,
                                                      );
                                                    },
                                                    onAddDetails: () {
                                                      _navigateToBuildingOnboarding(
                                                        context,
                                                        building,
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Add building link
                                      InkWell(
                                        onTap: _addNewBuildingField,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add,
                                                color: Colors.blue[700],
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Gebäude hinzufügen',
                                                style: TextStyle(
                                                  color: Colors.blue[700],
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Skip step link
                                      InkWell(
                                        onTap: () {
                                          // Handle skip step
                                          AppRouter.instance.pop(context);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Schritt überspringen',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Confirm button
                                      OutlinedButton(
                                        onPressed: () {
                                          // Handle confirmation
                                          AppRouter.instance.pop(context);
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          side: BorderSide(
                                            color: Colors.green[600]!,
                                            width: 2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Das passt so',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  color: Colors.black,
                  child: AppFooter(
                    onLanguageChanged: () {},
                    containerWidth: 700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuildingCard({
    required BuildingEntity building,
    required bool isCompleted,
    required bool isEditing,
    required VoidCallback onNameTap,
    required VoidCallback onDelete,
    required VoidCallback onSaveEdit,
    required VoidCallback onCancelEdit,
    required VoidCallback onAddDetails,
  }) {
    final editController = _editControllers[building.id];
    final editFocusNode = _editFocusNodes[building.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isEditing ? Colors.green[600]! : Colors.grey[300]!,
          width: isEditing ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Checkmark icon
            if (isCompleted)
              Icon(Icons.check_circle, color: Colors.green[600], size: 24)
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[400]!),
                ),
              ),
            const SizedBox(width: 12),
            // Building info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Building name - editable or clickable
                  if (isEditing && editController != null)
                    TextField(
                      controller: editController,
                      focusNode: editFocusNode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => onSaveEdit(),
                    )
                  else
                    InkWell(
                      onTap: onNameTap,
                      child: Text(
                        building.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (building.address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      building.address!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                  if (building.buildingType != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      building.buildingType!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            // Right side actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add details link (always visible, at right end)
                InkWell(
                  onTap: onAddDetails,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'Details hinzufügen',
                      style: TextStyle(color: Colors.blue[700], fontSize: 14),
                    ),
                  ),
                ),
                // Delete icon (only in edit mode)
                if (isEditing) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[600], size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTempBuildingField(int index) {
    final controller = _tempBuildingControllers[index];
    final focusNode = _tempBuildingFocusNodes[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green[600]!, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Empty circle icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[400]!),
              ),
            ),
            const SizedBox(width: 12),
            // Text field
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Büroräume, Vorderhaus',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _saveBuildingFromField(index);
                  } else {
                    _removeTempField(index);
                  }
                },
                onEditingComplete: () {
                  if (controller.text.trim().isNotEmpty) {
                    _saveBuildingFromField(index);
                  }
                },
              ),
            ),
            // Remove button
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
              onPressed: () => _removeTempField(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBuildingOnboarding(
    BuildContext context,
    BuildingEntity building,
  ) {
    // Only navigate if building has an ID (exists)
    if (building.id != null) {
      AppRouter.instance.pushNamed(
        context,
        'building-onboarding',
        queryParameters: {'buildingId': building.id!},
      );
    }
  }
}
