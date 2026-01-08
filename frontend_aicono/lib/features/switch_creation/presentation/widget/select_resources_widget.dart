import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';

class SelectResourcesWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final ValueChanged<List<String>>? onResourcesChanged;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const SelectResourcesWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onResourcesChanged,
    this.onSkip,
    this.onContinue,
    this.onBack,
  });

  @override
  State<SelectResourcesWidget> createState() => _SelectResourcesWidgetState();
}

class _SelectResourcesWidgetState extends State<SelectResourcesWidget> {
  final Set<String> _selectedResources = {};

  @override
  void initState() {
    super.initState();
    // Pre-select the location items (they appear as checked by default)
    _selectedResources.add('headquarters');
    _selectedResources.add('address');
    widget.onResourcesChanged?.call(_selectedResources.toList());
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'select_resources.progress_text'.tr(
        namedArgs: {'name': name},
      );
    }
    return 'select_resources.progress_text_fallback'.tr();
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
                        value: 0.85,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF8B9A5B), // Muted green color
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'select_resources.title'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildLocationOption(
                      value: 'headquarters',
                      label: 'select_resources.option_headquarters'.tr(),
                      isSelected: _selectedResources.contains('headquarters'),
                    ),
                    const SizedBox(height: 16),
                    _buildLocationOption(
                      value: 'address',
                      label: 'select_resources.option_address'.tr(),
                      isSelected: _selectedResources.contains('address'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCheckboxOption(
                          value: 'energy',
                          label: 'select_resources.option_energy'.tr(),
                          isSelected: _selectedResources.contains('energy'),
                        ),
                        const SizedBox(width: 24),
                        _buildCheckboxOption(
                          value: 'water',
                          label: 'select_resources.option_water'.tr(),
                          isSelected: _selectedResources.contains('water'),
                        ),
                        const SizedBox(width: 24),
                        _buildCheckboxOption(
                          value: 'gas',
                          label: 'select_resources.option_gas'.tr(),
                          isSelected: _selectedResources.contains('gas'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: widget.onSkip,
                      child: Text(
                        'select_resources.skip_link'.tr(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryOutlineButton(
                      label: 'select_resources.button_text'.tr(),
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
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedResources.remove(value);
          } else {
            _selectedResources.add(value);
          }
        });
        widget.onResourcesChanged?.call(_selectedResources.toList());
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
            ] else ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black54,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxOption({
    required String value,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedResources.remove(value);
          } else {
            _selectedResources.add(value);
          }
        });
        widget.onResourcesChanged?.call(_selectedResources.toList());
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          XCheckBox(
            value: isSelected,
            onChanged: (bool? newValue) {
              setState(() {
                if (newValue == true) {
                  _selectedResources.add(value);
                } else {
                  _selectedResources.remove(value);
                }
              });
              widget.onResourcesChanged?.call(_selectedResources.toList());
            },
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

