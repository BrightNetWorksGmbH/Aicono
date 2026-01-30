import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

import '../../../../core/widgets/page_header_row.dart';

class PropertyItem {
  final TextEditingController controller;
  bool isConfirmed;

  PropertyItem({required this.controller, this.isConfirmed = false});
}

class AddPropertiesWidget extends StatefulWidget {
  final String? userName;
  final bool isSingleProperty;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onBack;
  final ValueChanged<String>? onAddPropertyDetails; // propertyName
  final VoidCallback? onGoToHome;

  const AddPropertiesWidget({
    super.key,
    this.userName,
    required this.isSingleProperty,
    required this.onLanguageChanged,
    this.onBack,
    this.onAddPropertyDetails,
    this.onGoToHome,
  });

  @override
  State<AddPropertiesWidget> createState() => _AddPropertiesWidgetState();
}

class _AddPropertiesWidgetState extends State<AddPropertiesWidget> {
  final List<PropertyItem> _properties = [];
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    // Initialize with one property field
    _properties.add(PropertyItem(controller: TextEditingController()));
  }

  @override
  void dispose() {
    for (var property in _properties) {
      property.controller.dispose();
    }
    super.dispose();
  }

  void _addNewProperty() {
    setState(() {
      _properties.add(PropertyItem(controller: TextEditingController()));
    });
  }

  void _confirmProperty(int index) {
    setState(() {
      _properties[index].isConfirmed = true;
    });
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'add_properties.progress_text'.tr(namedArgs: {'name': name});
    }
    return 'add_properties.progress_text_fallback'.tr();
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
                            value: 0.85,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF8B9A5B),
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 32),
                        PageHeaderRow(
                          title: 'add_properties.title'.tr(),
                          showBackButton: widget.onBack != null,
                          onBack: widget.onBack,
                        ),

                        const SizedBox(height: 40),
                        // Property text fields
                        ...List.generate(
                          _properties.length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildPropertyField(index),
                          ),
                        ),
                        // Add new property button (only for multiple properties)
                        if (!widget.isSingleProperty) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _addNewProperty,
                            child: Text(
                              'add_properties.add_new_property'.tr(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                decoration: TextDecoration.underline,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Combined button: Confirm properties first, then Go to home
                        PrimaryOutlineButton(
                          label: _isConfirmed
                              ? 'add_properties.go_to_home'.tr()
                              : 'add_properties.confirm_properties'.tr(),
                          width: 260,
                          enabled:
                              _isConfirmed ||
                              _properties.any(
                                (p) => p.controller.text.trim().isNotEmpty,
                              ),
                          onPressed: _isConfirmed
                              ? widget.onGoToHome
                              : () {
                                  // Check if at least one property has text
                                  final hasAnyText = _properties.any(
                                    (p) => p.controller.text.trim().isNotEmpty,
                                  );
                                  if (!hasAnyText) {
                                    return; // Don't allow confirmation without text
                                  }
                                  // Mark all non-empty properties as confirmed
                                  for (int i = 0; i < _properties.length; i++) {
                                    if (_properties[i].controller.text
                                            .trim()
                                            .isNotEmpty &&
                                        !_properties[i].isConfirmed) {
                                      _confirmProperty(i);
                                    }
                                  }
                                  // Change button to "Go to home"
                                  setState(() {
                                    _isConfirmed = true;
                                  });
                                },
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

  Widget _buildPropertyField(int index) {
    final property = _properties[index];
    final isConfirmed = property.isConfirmed;
    final hasValue = property.controller.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isConfirmed ? const Color(0xFF8B9A5B) : Colors.black54,
          width: 2,
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          if (isConfirmed) ...[
            Image.asset(
              'assets/images/check.png',
              width: 16,
              height: 16,
              color: const Color(0xFF238636),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: property.controller,
              enabled: !isConfirmed,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'add_properties.property_name_hint'.tr(),
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey.shade400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
            ),
          ),
          if (hasValue && _isConfirmed) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                final propertyName = property.controller.text.trim();
                if (propertyName.isNotEmpty) {
                  widget.onAddPropertyDetails?.call(propertyName);
                }
              },
              child: Text(
                'add_properties.add_property_details'.tr(),
                style: AppTextStyles.bodyMedium.copyWith(
                  decoration: TextDecoration.underline,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
