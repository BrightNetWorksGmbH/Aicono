import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'dart:io' show File;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_bloc.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_event.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_state.dart';

import '../../../../../core/routing/routeLists.dart';
import '../../widgets/floor_plan/floor_plan_activation_widget.dart';

enum _FloorPlanState {
  initial, // Show upload buttons
  uploaded, // Show uploaded image
  activation, // Show activation button
}

class BuildingFloorPlanStep extends StatefulWidget {
  final BuildingEntity building;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final VoidCallback? onBuildFloorPlan;
  final VoidCallback? onAddFloorPlan;

  const BuildingFloorPlanStep({
    super.key,
    required this.building,
    required this.onNext,
    this.onSkip,
    this.onBuildFloorPlan,
    this.onAddFloorPlan,
  });

  @override
  State<BuildingFloorPlanStep> createState() => _BuildingFloorPlanStepState();
}

class _BuildingFloorPlanStepState extends State<BuildingFloorPlanStep> {
  _FloorPlanState _currentState = _FloorPlanState.initial;
  Uint8List? _uploadedImageBytes;
  int _currentFloorNumber = 1;

  @override
  void initState() {
    super.initState();
    // Start from floor 1
    _currentFloorNumber = 1;
  }

  int get _totalFloors {
    return widget.building.numberOfFloors ?? 1;
  }

  bool get _hasMoreFloors {
    return _currentFloorNumber < _totalFloors;
  }

  Future<void> _moveToNextFloor() async {
    // Save the building first to persist current floor's data
    await _saveBuildingForNextFloor();

    // Always redirect back to floor list screen after saving
    // The user can then choose which floor to edit next
    widget.onNext();
  }

  Future<void> _saveBuildingForNextFloor() async {
    // Save/update the building to persist the current floor's data
    final bloc = context.read<BuildingBloc>();

    if (widget.building.id != null) {
      // Update existing building
      bloc.add(UpdateBuildingEvent(widget.building));
      // Small delay to ensure the update is processed
      await Future.delayed(const Duration(milliseconds: 200));
    } else {
      // Create new building if it doesn't have an ID yet
      bloc.add(CreateBuildingEvent(widget.building));

      // Wait for the building to be created and get an ID
      // Listen to the bloc state to get the created building ID
      try {
        await bloc.stream
            .firstWhere((state) {
              if (state is BuildingLoaded) {
                // Find the created building (it should be the most recent one or match by name)
                try {
                  final createdBuilding = state.buildings.firstWhere(
                    (b) => b.name == widget.building.name && b.id != null,
                  );
                  return createdBuilding.id != null;
                } catch (e) {
                  return false;
                }
              }
              return false;
            })
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                // Return a dummy state if timeout
                return bloc.state;
              },
            );
      } catch (e) {
        // If timeout or error, continue anyway - the building might already be created
        debugPrint('Error waiting for building creation: $e');
      }
    }
  }

  String _getBuildingSummary() {
    final parts = <String>[];
    if (widget.building.totalArea != null) {
      parts.add('${widget.building.totalArea}qm');
    }
    if (widget.building.numberOfRooms != null) {
      parts.add('${widget.building.numberOfRooms} Räume');
    }
    if (widget.building.constructionYear != null) {
      parts.add('Baujahr ${widget.building.constructionYear}');
    }
    return parts.join(', ');
  }

  Future<void> _uploadFloorPlan() async {
    try {
      FilePickerResult? result;

      if (kIsWeb) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['svg', 'png', 'jpg', 'jpeg'],
          withData: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['svg', 'png', 'jpg', 'jpeg'],
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        if (file.extension == 'png' ||
            file.extension == 'jpg' ||
            file.extension == 'jpeg') {
          Uint8List imageBytes;

          if (kIsWeb) {
            final bytes = file.bytes;
            if (bytes == null) {
              _showError('Error: Could not read file data');
              return;
            }
            imageBytes = bytes;
          } else {
            final filePath = file.path;
            if (filePath == null) {
              _showError('Error: Could not read file path');
              return;
            }
            imageBytes = await File(filePath).readAsBytes();
          }

          setState(() {
            _uploadedImageBytes = imageBytes;
            _currentState = _FloorPlanState.uploaded;
          });
        } else if (file.extension == 'svg') {
          _showError(
            'SVG files are not supported for preview. Please use PNG or JPG.',
          );
        }
      }
    } catch (e) {
      _showError('Error uploading file: ${e.toString()}');
    }
  }

  void _handleNext() {
    if (_currentState == _FloorPlanState.uploaded) {
      // Move to activation state
      setState(() {
        _currentState = _FloorPlanState.activation;
      });
    } else {
      // Floor completed (skipped or no floor plan), move to next floor
      _moveToNextFloor();
    }
  }

  void _handleSkip() {
    // Skip current floor, move to next floor or finish
    _moveToNextFloor();
  }

  void _handleActivationComplete() {
    // Move to next floor when activation is complete
    _moveToNextFloor();
  }

  void _handleActivationSkip() {
    // Skip activation, move to next floor
    _moveToNextFloor();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Text(
                        'BRYTE',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      Text(
                        'SWITCH',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'MENU',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Icon(Icons.menu, color: Colors.grey[700]),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Progress indicator
            Container(
              width: screenSize.width < 600
                  ? screenSize.width * 0.95
                  : screenSize.width < 1200
                  ? screenSize.width * 0.5
                  : screenSize.width * 0.6,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Text(
                    'Fast geschafft, Stephan!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.75,
                      minHeight: 6,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green[600]!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Main content card
            Expanded(
              child: Container(
                width: screenSize.width < 600
                    ? screenSize.width * 0.95
                    : screenSize.width < 1200
                    ? screenSize.width * 0.5
                    : screenSize.width * 0.6,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ListView(
                    // crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Question with floor number
                      Text(
                        _totalFloors > 1
                            ? 'Gibt es einen Grundriss für Etage $_currentFloorNumber von $_totalFloors?'
                            : 'Gibt es einen Grundriss zum Gebäude?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Previous info boxes
                      if (widget.building.address != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[600],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.building.address!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_getBuildingSummary().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[600],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _getBuildingSummary(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Floor plan options - Show different UI based on state
                      _DottedBorderContainer(
                        child: Container(
                          height: 250,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (_currentState == _FloorPlanState.initial ||
                                  _currentState == _FloorPlanState.uploaded &&
                                      _uploadedImageBytes != null)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 26,
                                  // runSpacing: 16,
                                  children: [
                                    InkWell(
                                      onTap:
                                          // widget.onBuildFloorPlan ??
                                          () {
                                            context.pushNamed(
                                              Routelists.floorPlanEditor,
                                            );

                                            // // Navigate to floor plan editor
                                            // AppRouter.instance.pushNamed(
                                            //   context,
                                            //   'floor-plan-editor',
                                            // );
                                          },
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
                                            'Grundriss bauen',
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Container(
                                    //   height: 1,
                                    //   color: Colors.grey[300],
                                    //   margin: const EdgeInsets.symmetric(
                                    //     vertical: 8,
                                    //   ),
                                    // ),
                                    InkWell(
                                      onTap: _uploadFloorPlan,
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
                                            'Grundriss hinzufügen',
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              // Show uploaded image in uploaded state
                              const SizedBox(height: 8),
                              if (_currentState == _FloorPlanState.uploaded &&
                                  _uploadedImageBytes != null)
                                Container(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      _uploadedImageBytes!,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      height: 180,
                                    ),
                                  ),
                                ),
                              // Show activation widget in activation state
                              if (_currentState == _FloorPlanState.activation &&
                                  _uploadedImageBytes != null)
                                Expanded(
                                  child: FloorPlanActivationWidget(
                                    initialImageBytes: _uploadedImageBytes,
                                    onComplete: _handleActivationComplete,
                                    onSkip: _handleActivationSkip,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      // Skip step link (only show in initial state)
                      if (_currentState == _FloorPlanState.initial)
                        InkWell(
                          onTap: _handleSkip,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                _hasMoreFloors
                                    ? 'Diese Etage überspringen'
                                    : 'Schritt überspringen',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_currentState == _FloorPlanState.initial)
                        const SizedBox(height: 8),
                      // Confirm/Next button
                      if (_currentState == _FloorPlanState.initial)
                        OutlinedButton(
                          onPressed: _handleNext,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: Colors.grey[400]!,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _hasMoreFloors
                                ? 'Weiter zur nächsten Etage'
                                : 'Das passt so',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      // Next button for uploaded state (moves to activation state)
                      if (_currentState == _FloorPlanState.uploaded)
                        ElevatedButton(
                          onPressed: _handleNext,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _hasMoreFloors
                                ? 'Weiter zur nächsten Etage'
                                : 'Weiter',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom widget for dotted border container
class _DottedBorderContainer extends StatelessWidget {
  final Widget child;

  const _DottedBorderContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: child,
      ),
    );
  }
}

// Custom painter for dotted border
class _DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const borderRadius = 8.0;

    final path = Path();

    // Create a rounded rectangle path
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(borderRadius),
      ),
    );

    // Use PathMetrics to draw dashes along the path
    final pathMetrics = path.computeMetrics();
    for (final pathMetric in pathMetrics) {
      double start = 0.0;
      while (start < pathMetric.length) {
        final end = (start + dashWidth).clamp(0.0, pathMetric.length);
        final dashPath = pathMetric.extractPath(start, end);
        canvas.drawPath(dashPath, paint);
        start += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
