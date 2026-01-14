import 'package:flutter/material.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';

class BuildingDetailsStep extends StatefulWidget {
  final BuildingEntity building;
  final Function(BuildingEntity) onUpdate;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const BuildingDetailsStep({
    super.key,
    required this.building,
    required this.onUpdate,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<BuildingDetailsStep> createState() => _BuildingDetailsStepState();
}

class _BuildingDetailsStepState extends State<BuildingDetailsStep> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _buildingTypeController;
  late TextEditingController _numberOfFloorsController;
  late TextEditingController _totalAreaController;
  late TextEditingController _constructionYearController;

  final List<String> _buildingTypes = [
    'Residential',
    'Commercial',
    'Industrial',
    'Mixed Use',
    'Educational',
    'Healthcare',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _buildingTypeController = TextEditingController(
      text: widget.building.buildingType ?? '',
    );
    _numberOfFloorsController = TextEditingController(
      text: widget.building.numberOfFloors?.toString() ?? '',
    );
    _totalAreaController = TextEditingController(
      text: widget.building.totalArea?.toString() ?? '',
    );
    _constructionYearController = TextEditingController(
      text: widget.building.constructionYear ?? '',
    );
  }

  @override
  void dispose() {
    _buildingTypeController.dispose();
    _numberOfFloorsController.dispose();
    _totalAreaController.dispose();
    _constructionYearController.dispose();
    super.dispose();
  }

  void _saveAndNext() {
    if (_formKey.currentState!.validate()) {
      final updatedBuilding = widget.building.copyWith(
        buildingType: _buildingTypeController.text.trim().isEmpty
            ? null
            : _buildingTypeController.text.trim(),
        numberOfFloors: _numberOfFloorsController.text.trim().isEmpty
            ? null
            : int.tryParse(_numberOfFloorsController.text.trim()),
        totalArea: _totalAreaController.text.trim().isEmpty
            ? null
            : double.tryParse(_totalAreaController.text.trim()),
        constructionYear: _constructionYearController.text.trim().isEmpty
            ? null
            : _constructionYearController.text.trim(),
      );
      widget.onUpdate(updatedBuilding);
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add more details about your building',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              DropdownButtonFormField<String>(
                value: widget.building.buildingType,
                decoration: const InputDecoration(
                  labelText: 'Building Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _buildingTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _buildingTypeController.text = value ?? '';
                  });
                  final updatedBuilding = widget.building.copyWith(
                    buildingType: value,
                  );
                  widget.onUpdate(updatedBuilding);
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _numberOfFloorsController,
                decoration: const InputDecoration(
                  labelText: 'Number of Floors',
                  hintText: 'Enter number of floors',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.layers),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      int.tryParse(value.trim()) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onChanged: (_) {
                  final updatedBuilding = widget.building.copyWith(
                    numberOfFloors:
                        _numberOfFloorsController.text.trim().isEmpty
                        ? null
                        : int.tryParse(_numberOfFloorsController.text.trim()),
                  );
                  widget.onUpdate(updatedBuilding);
                },
              ),

              const SizedBox(height: 24),
              TextFormField(
                controller: _totalAreaController,
                decoration: const InputDecoration(
                  labelText: 'Total Area (sq ft)',
                  hintText: 'Enter total area',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.square_foot),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      double.tryParse(value.trim()) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onChanged: (_) {
                  final updatedBuilding = widget.building.copyWith(
                    totalArea: _totalAreaController.text.trim().isEmpty
                        ? null
                        : double.tryParse(_totalAreaController.text.trim()),
                  );
                  widget.onUpdate(updatedBuilding);
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _constructionYearController,
                decoration: const InputDecoration(
                  labelText: 'Construction Year',
                  hintText: 'Enter construction year',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  final updatedBuilding = widget.building.copyWith(
                    constructionYear:
                        _constructionYearController.text.trim().isEmpty
                        ? null
                        : _constructionYearController.text.trim(),
                  );
                  widget.onUpdate(updatedBuilding);
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onPrevious,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveAndNext,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
