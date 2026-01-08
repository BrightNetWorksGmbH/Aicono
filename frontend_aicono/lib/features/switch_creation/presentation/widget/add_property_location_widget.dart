import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

class AddPropertyLocationWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final ValueChanged<String>? onLocationSelected;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const AddPropertyLocationWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onLocationSelected,
    this.onSkip,
    this.onContinue,
    this.onBack,
  });

  @override
  State<AddPropertyLocationWidget> createState() =>
      _AddPropertyLocationWidgetState();
}

class _AddPropertyLocationWidgetState
    extends State<AddPropertyLocationWidget> {
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    // Default to headquarters option
    _selectedLocation = 'headquarters';
    widget.onLocationSelected?.call(_selectedLocation!);
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'add_property_location.progress_text'.tr(
        namedArgs: {'name': name},
      );
    }
    return 'add_property_location.progress_text_fallback'.tr();
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
                        value: 0.7,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF8B9A5B), // Muted green color
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'add_property_location.title'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildLocationOption(
                      value: 'headquarters',
                      label: 'add_property_location.option_headquarters'.tr(),
                      isSelected: _selectedLocation == 'headquarters',
                    ),
                    const SizedBox(height: 16),
                    _buildLocationOption(
                      value: 'specify',
                      label: 'add_property_location.option_specify'.tr(),
                      rightLabel: 'add_property_location.option_gps'.tr(),
                      isSelected: _selectedLocation == 'specify',
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: widget.onSkip,
                      child: Text(
                        'add_property_location.skip_link'.tr(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryOutlineButton(
                      label: 'add_property_location.button_text'.tr(),
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

  Widget _buildLocationOption({
    required String value,
    required String label,
    String? rightLabel,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedLocation = value;
        });
        widget.onLocationSelected?.call(value);
      },
      child: Container(
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
            if (isSelected) ...[
              const Icon(
                Icons.check_circle,
                color: Color(0xFF238636), // Green checkmark
                size: 24,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium,
              ),
            ),
            if (rightLabel != null) ...[
              Text(
                rightLabel,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

