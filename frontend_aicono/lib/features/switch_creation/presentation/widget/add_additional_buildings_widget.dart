import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';

class AddAdditionalBuildingsWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final ValueChanged<bool>? onHasAdditionalBuildingsChanged;
  final ValueChanged<List<BuildingItem>>? onBuildingsChanged;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const AddAdditionalBuildingsWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onHasAdditionalBuildingsChanged,
    this.onBuildingsChanged,
    this.onSkip,
    this.onContinue,
    this.onBack,
  });

  @override
  State<AddAdditionalBuildingsWidget> createState() =>
      _AddAdditionalBuildingsWidgetState();
}

class BuildingItem {
  final String id;
  final String name;
  final String? resources;
  final bool isPreSelected;
  final bool isEditable;

  BuildingItem({
    required this.id,
    required this.name,
    this.resources,
    this.isPreSelected = false,
    this.isEditable = false,
  });
}

class _AddAdditionalBuildingsWidgetState
    extends State<AddAdditionalBuildingsWidget> {
  bool? _hasAdditionalBuildings; // null = not selected, true = yes, false = no
  final List<BuildingItem> _buildings = [];
  final TextEditingController _newBuildingController = TextEditingController();
  bool _showAddBuildingInput = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate with the two default buildings
    _buildings.addAll([
      BuildingItem(
        id: 'headquarters',
        name: 'add_additional_buildings.building_headquarters'.tr(),
        resources: 'add_additional_buildings.resources'.tr(),
        isPreSelected: true,
      ),
      BuildingItem(
        id: 'address',
        name: 'add_additional_buildings.building_address'.tr(),
        isPreSelected: true,
      ),
    ]);
    widget.onBuildingsChanged?.call(_buildings);
  }

  @override
  void dispose() {
    _newBuildingController.dispose();
    super.dispose();
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'add_additional_buildings.progress_text'.tr(
        namedArgs: {'name': name},
      );
    }
    return 'add_additional_buildings.progress_text_fallback'.tr();
  }

  void _handleYesNoSelection(bool isYes) {
    setState(() {
      _hasAdditionalBuildings = isYes;
      if (!isYes) {
        // If "no" is selected, remove any additional buildings (keep only pre-selected)
        _buildings.removeWhere((b) => !b.isPreSelected);
        _showAddBuildingInput = false;
        _newBuildingController.clear();
      }
    });
    widget.onHasAdditionalBuildingsChanged?.call(isYes);
    widget.onBuildingsChanged?.call(_buildings);
  }

  void _showAddBuildingField() {
    setState(() {
      _showAddBuildingInput = true;
    });
  }

  void _addBuilding() {
    final name = _newBuildingController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _buildings.add(BuildingItem(
          id: 'building_${_buildings.length}',
          name: name,
          isEditable: true,
        ));
        _newBuildingController.clear();
        _showAddBuildingInput = false;
      });
      widget.onBuildingsChanged?.call(_buildings);
    }
  }

  void _removeBuilding(String id) {
    setState(() {
      _buildings.removeWhere((b) => b.id == id);
    });
    widget.onBuildingsChanged?.call(_buildings);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Padding(
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
                onLanguageChanged: widget.onLanguageChanged,
                containerWidth: screenSize.width > 500
                    ? 500
                    : screenSize.width * 0.98,
              ),
              if (widget.onBack != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Icon(Icons.arrow_back, color: Colors.black87, size: 24),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 50),
              SizedBox(
                width: screenSize.width < 600
                    ? screenSize.width * 0.95
                    : screenSize.width < 1200
                        ? screenSize.width * 0.5
                        : screenSize.width * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _buildProgressText(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.9,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF8B9A5B), // Muted green color
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'add_additional_buildings.title'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Display existing buildings
                    ..._buildings.map((building) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildBuildingItem(building),
                        )),
                    // Show input field if "yes" is selected and add button was clicked
                    if (_hasAdditionalBuildings == true &&
                        _showAddBuildingInput) ...[
                      TextField(
                        controller: _newBuildingController,
                        decoration: InputDecoration(
                          hintText: 'add_additional_buildings.building_hint'.tr(),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: const Color(0xFF8B9A5B),
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: const Color(0xFF8B9A5B),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                        onSubmitted: (_) => _addBuilding(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Yes/No selection (always show below buildings)
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildYesNoOption(
                          label: 'add_additional_buildings.yes'.tr(),
                          isSelected: _hasAdditionalBuildings == true,
                          onTap: () => _handleYesNoSelection(true),
                        ),
                        const SizedBox(width: 24),
                        _buildYesNoOption(
                          label: 'add_additional_buildings.no'.tr(),
                          isSelected: _hasAdditionalBuildings == false,
                          onTap: () => _handleYesNoSelection(false),
                        ),
                      ],
                    ),
                    // Add building link (only show if "yes" is selected)
                    if (_hasAdditionalBuildings == true &&
                        !_showAddBuildingInput) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _showAddBuildingField,
                        child: Text(
                          'add_additional_buildings.add_building_link'.tr(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            decoration: TextDecoration.underline,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: widget.onSkip,
                      child: Text(
                        'add_additional_buildings.skip_link'.tr(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryOutlineButton(
                      label: 'add_additional_buildings.button_text'.tr(),
                      width: 260,
                      onPressed: widget.onContinue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuildingItem(BuildingItem building) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(
          color: building.isEditable
              ? const Color(0xFF8B9A5B) // Green border for editable
              : Colors.black54,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          if (building.isPreSelected) ...[
            const Icon(
              Icons.check_circle,
              color: Color(0xFF238636), // Green checkmark
              size: 24,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              building.name,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          if (building.resources != null) ...[
            Text(
              building.resources!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.black54,
              ),
            ),
          ],
          if (building.isEditable) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _removeBuilding(building.id),
              child: Text(
                'add_additional_buildings.add_details_link'.tr(),
                style: AppTextStyles.bodyMedium.copyWith(
                  decoration: TextDecoration.underline,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYesNoOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          XCheckBox(
            value: isSelected,
            onChanged: (_) => onTap(),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

