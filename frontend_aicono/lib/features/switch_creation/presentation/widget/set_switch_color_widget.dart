import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _colorNameController = TextEditingController(text: widget.colorName);
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
    }
  }

  @override
  void dispose() {
    _colorNameController.dispose();
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
          title: const Text("Pick Brand Color"),
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
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(tempColor),
              child: const Text('Done'),
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
              if (widget.onBack != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                        size: 24,
                      ),
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
                      'set_switch_color.title'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Color Name Input Field
                    Row(
                      children: [
                        Text(
                          'Color name: ',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _colorNameController,
                            onChanged: (value) {
                              widget.onColorNameChanged?.call(value);
                            },
                            decoration: InputDecoration(
                              hintText: "Bright-NetWorks-Turquoise",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: widget.primaryColor,
                                  width: 2,
                                ),
                              ),
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
}
