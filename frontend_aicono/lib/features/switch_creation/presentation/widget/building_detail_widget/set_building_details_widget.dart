import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

class SetBuildingDetailsWidget extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final VoidCallback onLanguageChanged;
  final ValueChanged<Map<String, String?>>? onBuildingDetailsChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final VoidCallback? onEditAddress;

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
  });

  @override
  State<SetBuildingDetailsWidget> createState() =>
      _SetBuildingDetailsWidgetState();
}

class _SetBuildingDetailsWidgetState extends State<SetBuildingDetailsWidget> {
  final TextEditingController _buildingSizeController = TextEditingController();
  final TextEditingController _numberOfRoomsController =
      TextEditingController();
  final TextEditingController _yearOfConstructionController =
      TextEditingController();

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
      return 'set_building_details.progress_text'.tr(
        namedArgs: {'name': name},
      );
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
              Expanded(
                child: SingleChildScrollView(
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
                        const SizedBox(height: 32),
                        Text(
                          'set_building_details.title'.tr(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedField({
    required String value,
    VoidCallback? onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black54,
          width: 2,
        ),
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
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.black87,
              ),
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
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
