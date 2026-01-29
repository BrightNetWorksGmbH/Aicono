import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

import '../../../../../core/widgets/page_header_row.dart';

class SetBuildingDetailsWidget extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final VoidCallback onLanguageChanged;
  final ValueChanged<Map<String, String?>>? onBuildingDetailsChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final VoidCallback? onEditAddress;
  final Map<String, dynamic>? initialData;
  final bool isLoading;

  const SetBuildingDetailsWidget({
    super.key,
    this.userName,
    this.buildingAddress,
    required this.onLanguageChanged,
    this.onBuildingDetailsChanged,
    this.onContinue,
    this.onSkip,
    this.onBack,
    this.onEditAddress,
    this.initialData,
    this.isLoading = false,
  });

  @override
  State<SetBuildingDetailsWidget> createState() =>
      _SetBuildingDetailsWidgetState();
}

class _SetBuildingDetailsWidgetState extends State<SetBuildingDetailsWidget> {
  late final TextEditingController _buildingSizeController;
  late final TextEditingController _numberOfRoomsController;
  late final TextEditingController _yearOfConstructionController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with initial data if available
    _initializeControllers(widget.initialData);
  }

  void _initializeControllers(Map<String, dynamic>? data) {
    // Handle building_size - can be direct value or null
    final buildingSize = data?['building_size']?.toString() ?? '';

    // Handle heated_building_area which might have nested structure
    String? heatedArea;
    if (data?['heated_building_area'] != null) {
      if (data!['heated_building_area'] is Map) {
        heatedArea =
            data['heated_building_area']?['\$numberDecimal']?.toString() ??
            data['heated_building_area']?.toString();
      } else {
        heatedArea = data['heated_building_area']?.toString();
      }
    }

    final sizeValue = buildingSize.isNotEmpty
        ? buildingSize
        : (heatedArea ?? '');
    final roomsValue = data?['num_students_employees']?.toString() ?? '';
    final yearValue = data?['year_of_construction']?.toString() ?? '';

    _buildingSizeController = TextEditingController(text: sizeValue);
    _numberOfRoomsController = TextEditingController(text: roomsValue);
    _yearOfConstructionController = TextEditingController(text: yearValue);
  }

  @override
  void didUpdateWidget(SetBuildingDetailsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers when initialData changes (e.g., after async fetch)
    if (oldWidget.initialData != widget.initialData &&
        widget.initialData != null) {
      _updateControllers(widget.initialData!);
    }
  }

  void _updateControllers(Map<String, dynamic> data) {
    // Handle building_size - can be direct value or null
    final buildingSize = data['building_size']?.toString() ?? '';

    // Handle heated_building_area which might have nested structure
    String? heatedArea;
    if (data['heated_building_area'] != null) {
      if (data['heated_building_area'] is Map) {
        heatedArea =
            data['heated_building_area']?['\$numberDecimal']?.toString() ??
            data['heated_building_area']?.toString();
      } else {
        heatedArea = data['heated_building_area']?.toString();
      }
    }

    final sizeValue = buildingSize.isNotEmpty
        ? buildingSize
        : (heatedArea ?? '');
    final roomsValue = data['num_students_employees']?.toString() ?? '';
    final yearValue = data['year_of_construction']?.toString() ?? '';

    // Only update if field is empty to avoid overwriting user input
    if (_buildingSizeController.text.isEmpty && sizeValue.isNotEmpty) {
      _buildingSizeController.text = sizeValue;
    }
    if (_numberOfRoomsController.text.isEmpty && roomsValue.isNotEmpty) {
      _numberOfRoomsController.text = roomsValue;
    }
    if (_yearOfConstructionController.text.isEmpty && yearValue.isNotEmpty) {
      _yearOfConstructionController.text = yearValue;
    }
  }

  @override
  void dispose() {
    _buildingSizeController.dispose();
    _numberOfRoomsController.dispose();
    _yearOfConstructionController.dispose();
    super.dispose();
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'set_building_details.progress_text'.tr(namedArgs: {'name': name});
    }
    return 'set_building_details.progress_text_fallback'.tr();
  }

  void _notifyDetailsChanged() {
    widget.onBuildingDetailsChanged?.call({
      'address': widget.buildingAddress,
      'size': _buildingSizeController.text.trim().isEmpty
          ? null
          : _buildingSizeController.text.trim(),
      'rooms': _numberOfRoomsController.text.trim().isEmpty
          ? null
          : _numberOfRoomsController.text.trim(),
      'year': _yearOfConstructionController.text.trim().isEmpty
          ? null
          : _yearOfConstructionController.text.trim(),
    });
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

              const SizedBox(height: 50),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: SizedBox(
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
                          const SizedBox(height: 40),
                          PageHeaderRow(
                            title: 'Einrichtung der Gebäudeinformationen',
                            showBackButton: widget.onBack != null,
                            onBack: widget.onBack,
                          ),

                          const SizedBox(height: 40),
                          // Address field (completed state)
                          if (widget.buildingAddress != null &&
                              widget.buildingAddress!.isNotEmpty) ...[
                            _buildCompletedField(
                              value: widget.buildingAddress!,
                              onEdit: widget.onEditAddress,
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Building size field
                          TextField(
                            controller: _buildingSizeController,
                            onChanged: (_) => _notifyDetailsChanged(),
                            decoration: InputDecoration(
                              hintText: 'set_building_details.size_hint'.tr(),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Colors.black54,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Number of rooms field
                          TextField(
                            controller: _numberOfRoomsController,
                            onChanged: (_) => _notifyDetailsChanged(),
                            decoration: InputDecoration(
                              hintText: 'set_building_details.rooms_hint'.tr(),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Colors.black54,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Year of construction field
                          TextField(
                            controller: _yearOfConstructionController,
                            onChanged: (_) => _notifyDetailsChanged(),
                            decoration: InputDecoration(
                              hintText: 'set_building_details.year_hint'.tr(),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Colors.black54,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          InkWell(
                            onTap: widget.onSkip,
                            child: Text(
                              'set_building_details.skip_link'.tr(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                decoration: TextDecoration.underline,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          PrimaryOutlineButton(
                            label: 'set_building_details.button_text'.tr(),
                            width: 260,
                            onPressed: widget.onContinue,
                          ),
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

  Widget _buildCompletedField({required String value, VoidCallback? onEdit}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF238636), // Green checkmark
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: onEdit,
              child: Text(
                'set_building_details.edit_link'.tr(),
                style: AppTextStyles.bodyMedium.copyWith(
                  decoration: TextDecoration.underline,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
