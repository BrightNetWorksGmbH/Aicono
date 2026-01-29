import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

import '../../../../core/widgets/page_header_row.dart';

class SetSwitchColorWidget extends StatefulWidget {
  final String? userName;
  final Color primaryColor;
  final String colorHex;
  final String colorName;
  final VoidCallback onLanguageChanged;
  final Function(Color, String)? onColorChanged;
  final ValueChanged<String>? onColorNameChanged;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const SetSwitchColorWidget({
    super.key,
    this.userName,
    required this.primaryColor,
    required this.colorHex,
    required this.colorName,
    required this.onLanguageChanged,
    this.onColorChanged,
    this.onColorNameChanged,
    this.onSkip,
    this.onContinue,
    this.onBack,
  });

  @override
  State<SetSwitchColorWidget> createState() => _SetSwitchColorWidgetState();
}

class _SetSwitchColorWidgetState extends State<SetSwitchColorWidget> {
  late TextEditingController _colorNameController;
  final FocusNode _colorNameFocusNode = FocusNode();
  bool _isColorNameFocused = false;
  bool _isColorNameEmpty = true;

  @override
  void initState() {
    super.initState();
    _colorNameController = TextEditingController(text: widget.colorName);
    _isColorNameEmpty = widget.colorName.trim().isEmpty;
    _colorNameFocusNode.addListener(() {
      setState(() {
        _isColorNameFocused = _colorNameFocusNode.hasFocus;
      });
    });
  }

  @override
  void didUpdateWidget(SetSwitchColorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if the value changed from outside (not from user typing)
    if (widget.colorName != oldWidget.colorName &&
        _colorNameController.text != widget.colorName) {
      _colorNameController.value = TextEditingValue(
        text: widget.colorName,
        selection: TextSelection.collapsed(offset: widget.colorName.length),
      );
      setState(() {
        _isColorNameEmpty = widget.colorName.trim().isEmpty;
      });
    }
  }

  @override
  void dispose() {
    _colorNameController.dispose();
    _colorNameFocusNode.dispose();
    super.dispose();
  }

  void _pickColor() {
    showDialog<Color?>(
      context: context,
      builder: (dialogCtx) {
        Color tempColor = widget.primaryColor;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('set_switch_color.pick_color_dialog_title'.tr()),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return ColorPicker(
                  pickerColor: tempColor,
                  onColorChanged: (color) {
                    setStateDialog(() => tempColor = color);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(tempColor),
              child: Text('set_switch_color.done'.tr()),
            ),
          ],
        );
      },
    ).then((picked) {
      if (picked != null) {
        // Convert to 6-digit hex format (remove alpha channel)
        String hexValue = picked.value.toRadixString(16).padLeft(8, '0');
        String colorHex =
            '#${hexValue.substring(2)}'; // Remove alpha (first 2 characters)
        widget.onColorChanged?.call(picked, colorHex);
      }
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
                    PageHeaderRow(
                      title: 'set_switch_color.title'.tr(),
                      showBackButton: widget.onBack != null,
                      onBack: widget.onBack,
                    ),

                    const SizedBox(height: 32),
                    // Color Display Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: widget.primaryColor,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.colorHex.toUpperCase()} ${widget.colorName.isNotEmpty ? widget.colorName : ""}',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickColor,
                      child: Text(
                        'set_switch_color.change_color'.tr(),
                        style: AppTextStyles.bodySmall.copyWith(
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Color Name Input Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: _isColorNameFocused
                              ? widget.primaryColor
                              : Colors.grey[300]!,
                          width: _isColorNameFocused ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              'set_switch_color.color_name_label'.tr(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _colorNameController,
                              focusNode: _colorNameFocusNode,
                              onChanged: (value) {
                                setState(() {
                                  _isColorNameEmpty = value.trim().isEmpty;
                                });
                                widget.onColorNameChanged?.call(value);
                              },
                              decoration: InputDecoration(
                                hintText: 'set_switch_color.color_name_hint'
                                    .tr(),
                                hintStyle: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.grey[400],
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text.rich(
                      TextSpan(
                        text: 'set_switch_color.tip'.tr(),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(text: ' '),
                          WidgetSpan(
                            child: InkWell(
                              onTap: widget.onSkip,
                              child: Text(
                                'set_switch_color.skip_link'.tr(),
                                style: AppTextStyles.bodySmall.copyWith(
                                  decoration: TextDecoration.underline,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    PrimaryOutlineButton(
                      label: 'set_switch_color.button_text'.tr(),
                      width: 260,
                      enabled: !_isColorNameEmpty,
                      onPressed: _isColorNameEmpty ? null : widget.onContinue,
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
}
