import 'package:flutter/material.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';

class BuildingLocationStep extends StatefulWidget {
  final BuildingEntity building;
  final Function(BuildingEntity) onUpdate;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const BuildingLocationStep({
    super.key,
    required this.building,
    required this.onUpdate,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<BuildingLocationStep> createState() => _BuildingLocationStepState();
}

class _BuildingLocationStepState extends State<BuildingLocationStep> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.building.address ?? '');
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _saveAndNext() {
    if (_formKey.currentState!.validate()) {
      final updatedBuilding = widget.building.copyWith(
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
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
              'Location',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Where is this building located?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter building address (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 3,
              onChanged: (_) {
                final updatedBuilding = widget.building.copyWith(
                  address: _addressController.text.trim().isEmpty
                      ? null
                      : _addressController.text.trim(),
                );
                widget.onUpdate(updatedBuilding);
              },
            ),
            const Spacer(),
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
    );
  }
}

