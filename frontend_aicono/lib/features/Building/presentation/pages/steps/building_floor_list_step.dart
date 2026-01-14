import 'package:flutter/material.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';

class BuildingFloorListStep extends StatefulWidget {
  final BuildingEntity building;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final Function(int floorNumber) onEditFloor;
  final Set<int> completedFloors;

  const BuildingFloorListStep({
    super.key,
    required this.building,
    required this.onNext,
    this.onSkip,
    this.onBack,
    required this.onEditFloor,
    this.completedFloors = const {},
  });

  @override
  State<BuildingFloorListStep> createState() => _BuildingFloorListStepState();
}

class _BuildingFloorListStepState extends State<BuildingFloorListStep> {
  late Set<int> _completedFloors;

  @override
  void initState() {
    super.initState();
    _completedFloors = Set<int>.from(widget.completedFloors);
  }

  @override
  void didUpdateWidget(BuildingFloorListStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completedFloors != oldWidget.completedFloors) {
      setState(() {
        _completedFloors = Set<int>.from(widget.completedFloors);
      });
    }
  }

  int get _totalFloors {
    return widget.building.numberOfFloors ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back button
                  if (widget.onBack != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: widget.onBack,
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
                    const SizedBox(height: 16),
                  ],
                  // Title
                  const Text(
                    'Etagen verwalten',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Floor list
                  if (_totalFloors > 0)
                    ...List.generate(_totalFloors, (index) {
                      final floorNumber = index + 1;
                      final isCompleted = _completedFloors.contains(
                        floorNumber,
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCompleted
                                ? Colors.green
                                : Colors.grey[300]!,
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
                              // Floor number/name
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      isCompleted
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: isCompleted
                                          ? Colors.green
                                          : Colors.grey[600],
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Etage $floorNumber',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: isCompleted
                                            ? Colors.green[700]
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (isCompleted) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '(Abgeschlossen)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Edit button
                              ElevatedButton.icon(
                                onPressed: () {
                                  widget.onEditFloor(floorNumber);
                                },
                                icon: Icon(
                                  isCompleted ? Icons.edit : Icons.add,
                                  size: 18,
                                ),
                                label: Text(
                                  isCompleted ? 'Bearbeiten' : 'Hinzufügen',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                  // Skip step link
                  if (widget.onSkip != null)
                    InkWell(
                      onTap: widget.onSkip,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                  const SizedBox(height: 8),
                  // Next button (only show if all floors are completed)
                  if (_completedFloors.length == _totalFloors &&
                      _totalFloors > 0)
                    ElevatedButton(
                      onPressed: widget.onNext,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Weiter',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
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
}
