import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';

import '../../../../core/widgets/page_header_row.dart';

class SelectPropertyTypeWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onBack;
  final ValueChanged<bool>? onContinue; // true = single, false = multiple

  const SelectPropertyTypeWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onBack,
    this.onContinue,
  });

  @override
  State<SelectPropertyTypeWidget> createState() =>
      _SelectPropertyTypeWidgetState();
}

class _SelectPropertyTypeWidgetState extends State<SelectPropertyTypeWidget> {
  bool _isSingleProperty = true; // Default to single property (checked)

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'select_property_type.progress_text'.tr(namedArgs: {'name': name});
    }
    return 'select_property_type.progress_text_fallback'.tr();
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
                        value: 0.8,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF8B9A5B), // Muted green color
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 32),
                    PageHeaderRow(
                      title: 'select_property_type.title'.tr(),
                      showBackButton: widget.onBack != null,
                      onBack: widget.onBack,
                    ),

                    const SizedBox(height: 40),
                    // Single property option
                    _buildCheckboxOption(
                      label: 'select_property_type.option_single'.tr(),
                      isSelected: _isSingleProperty,
                      onTap: () {
                        setState(() {
                          _isSingleProperty = true;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Multiple properties option
                    _buildCheckboxOption(
                      label: 'select_property_type.option_multiple'.tr(),
                      isSelected: !_isSingleProperty,
                      onTap: () {
                        setState(() {
                          _isSingleProperty = false;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    // Tip text
                    Text(
                      'select_property_type.tip'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryOutlineButton(
                      label: 'select_property_type.button_text'.tr(),
                      width: 260,
                      onPressed: widget.onContinue != null
                          ? () => widget.onContinue!(_isSingleProperty)
                          : null,
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

  Widget _buildCheckboxOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          XCheckBox(value: isSelected, onChanged: (_) => onTap()),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
