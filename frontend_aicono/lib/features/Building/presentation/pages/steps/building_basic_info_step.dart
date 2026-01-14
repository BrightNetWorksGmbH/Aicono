import 'package:flutter/material.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';

class BuildingBasicInfoStep extends StatefulWidget {
  final BuildingEntity building;
  final Function(BuildingEntity) onUpdate;
  final VoidCallback onNext;

  const BuildingBasicInfoStep({
    super.key,
    required this.building,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<BuildingBasicInfoStep> createState() => _BuildingBasicInfoStepState();
}

class _BuildingBasicInfoStepState extends State<BuildingBasicInfoStep> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.building.name);
    _descriptionController = TextEditingController(text: widget.building.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveAndNext() {
    if (_formKey.currentState!.validate()) {
      final updatedBuilding = widget.building.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Let\'s start with the basic details of your building',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Building Name *',
                hintText: 'Enter building name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a building name';
                }
                return null;
              },
              onChanged: (_) {
                final updatedBuilding = widget.building.copyWith(
                  name: _nameController.text.trim(),
                );
                widget.onUpdate(updatedBuilding);
              },
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter a brief description (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 4,
              onChanged: (_) {
                final updatedBuilding = widget.building.copyWith(
                  description: _descriptionController.text.trim().isEmpty
                      ? null
                      : _descriptionController.text.trim(),
                );
                widget.onUpdate(updatedBuilding);
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saveAndNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

