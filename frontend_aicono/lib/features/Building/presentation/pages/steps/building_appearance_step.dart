import 'package:flutter/material.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';

import '../../../../../core/widgets/top_part_widget.dart';

class BuildingAppearanceStep extends StatefulWidget {
  final BuildingEntity building;
  final Function(BuildingEntity) onUpdate;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const BuildingAppearanceStep({
    super.key,
    required this.building,
    required this.onUpdate,
    required this.onNext,
    this.onSkip,
  });

  @override
  State<BuildingAppearanceStep> createState() => _BuildingAppearanceStepState();
}

class _BuildingAppearanceStepState extends State<BuildingAppearanceStep> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _addressController;
  late TextEditingController _totalAreaController;
  late TextEditingController _numberOfRoomsController;
  late TextEditingController _constructionYearController;
  late TextEditingController _numberOfFloorsController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.building.address ?? '',
    );
    _totalAreaController = TextEditingController(
      text: widget.building.totalArea?.toString() ?? '',
    );
    _numberOfRoomsController = TextEditingController(
      text: widget.building.numberOfRooms?.toString() ?? '',
    );
    _constructionYearController = TextEditingController(
      text: widget.building.constructionYear ?? '',
    );
    _numberOfFloorsController = TextEditingController(
      text: widget.building.numberOfFloors?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _totalAreaController.dispose();
    _numberOfRoomsController.dispose();
    _constructionYearController.dispose();
    _numberOfFloorsController.dispose();
    super.dispose();
  }

  void _saveAndNext() {
    if (_formKey.currentState!.validate()) {
      final updatedBuilding = widget.building.copyWith(
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        totalArea: _totalAreaController.text.trim().isEmpty
            ? null
            : double.tryParse(_totalAreaController.text.trim()),
        numberOfRooms: _numberOfRoomsController.text.trim().isEmpty
            ? null
            : int.tryParse(_numberOfRoomsController.text.trim()),
        constructionYear: _constructionYearController.text.trim().isEmpty
            ? null
            : _constructionYearController.text.trim(),
        numberOfFloors: _numberOfFloorsController.text.trim().isEmpty
            ? null
            : int.tryParse(_numberOfFloorsController.text.trim()),
      );
      widget.onUpdate(updatedBuilding);
      widget.onNext();
    }
  }

  void _handleLanguageChanged() {
    // TODO: Implement language change
    setState(() {
      // TODO: Implement language change
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Container(
      color: Colors.white,
      // width: screenSize.width < 600
      //     ? screenSize.width * 0.95
      //     : screenSize.width < 1200
      //     ? screenSize.width * 0.5
      //     : screenSize.width * 0.6,
      child: SafeArea(
        child: Container(
          // height: screenSize.height * 0.95,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                width: screenSize.width < 600
                    ? screenSize.width * 0.95
                    : screenSize.width < 1200
                    ? screenSize.width * 0.5
                    : screenSize.width * 0.6,
                child: Material(
                  color: Colors.transparent,
                  child: TopHeader(
                    onLanguageChanged: _handleLanguageChanged,
                    containerWidth: screenSize.width > 500
                        ? 500
                        : screenSize.width * 0.98,
                    verseInitial: null,
                  ),
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
                // height: screenSize.height * 0.5,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Text(
                      'Fast geschafft, Stephan!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: screenSize.width < 600
                          ? screenSize.width * 0.95
                          : screenSize.width < 1200
                          ? screenSize.width * 0.5
                          : screenSize.width * 0.6,
                      child: ClipRRect(
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Question
                          const Text(
                            'Prima, wie sieht das Gebäude aus?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          // Address field with checkmark
                          Container(
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
                                      widget.building.address ??
                                          'Hafenweg 11a, 48155 Münster',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      // Show edit address dialog
                                      _showEditAddressDialog();
                                    },
                                    child: Text(
                                      'anpassen',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Building size field
                          TextFormField(
                            controller: _totalAreaController,
                            decoration: InputDecoration(
                              labelText: 'Wie groß ist das Gebäude?',
                              hintText: 'z.B. 55qm',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              if (value != null &&
                                  value.trim().isNotEmpty &&
                                  double.tryParse(value.trim()) == null) {
                                return 'Bitte geben Sie eine gültige Zahl ein';
                              }
                              return null;
                            },
                            onChanged: (_) {
                              final updatedBuilding = widget.building.copyWith(
                                totalArea:
                                    _totalAreaController.text.trim().isEmpty
                                    ? null
                                    : double.tryParse(
                                        _totalAreaController.text.trim(),
                                      ),
                              );
                              widget.onUpdate(updatedBuilding);
                            },
                          ),
                          const SizedBox(height: 16),
                          // Number of floors field
                          TextFormField(
                            controller: _numberOfFloorsController,
                            decoration: InputDecoration(
                              labelText: 'Wie viele Etagen hat das Gebäude?',
                              hintText: 'z.B. 2',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null &&
                                  value.trim().isNotEmpty &&
                                  int.tryParse(value.trim()) == null) {
                                return 'Bitte geben Sie eine gültige Zahl ein';
                              }
                              return null;
                            },
                            onChanged: (_) {
                              final updatedBuilding = widget.building.copyWith(
                                numberOfFloors:
                                    _numberOfFloorsController.text
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : int.tryParse(
                                        _numberOfFloorsController.text.trim(),
                                      ),
                              );
                              widget.onUpdate(updatedBuilding);
                            },
                          ),

                          const SizedBox(height: 16),
                          // Construction year field
                          TextFormField(
                            controller: _constructionYearController,
                            decoration: InputDecoration(
                              labelText: 'Was ist das Baujahr des Gebäudes?',
                              hintText: 'z.B. 1972',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              final updatedBuilding = widget.building.copyWith(
                                constructionYear:
                                    _constructionYearController.text
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : _constructionYearController.text.trim(),
                              );
                              widget.onUpdate(updatedBuilding);
                            },
                          ),

                          const SizedBox(height: 24),
                          // Skip step link
                          InkWell(
                            onTap: widget.onSkip ?? widget.onNext,
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
                          // Confirm button
                          OutlinedButton(
                            onPressed: _saveAndNext,
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
                              'Das passt so',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ), // Add bottom padding for scroll
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adresse bearbeiten'),
        content: TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Adresse',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              final updatedBuilding = widget.building.copyWith(
                address: _addressController.text.trim(),
              );
              widget.onUpdate(updatedBuilding);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
