import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';

class SetPersonalizeLookWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const SetPersonalizeLookWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onContinue,
    this.onBack,
  });

  @override
  State<SetPersonalizeLookWidget> createState() =>
      _SetPersonalizeLookWidgetState();
}

class _SetPersonalizeLookWidgetState extends State<SetPersonalizeLookWidget> {
  bool _opt1 = true; // Light mode
  bool _opt2 = false; // Dark mode

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Text(
                        'set_personalized_look.title'.tr(),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildOption(
                      value: _opt1,
                      onChanged: (v) {
                        setState(() {
                          _opt1 = v ?? false;
                          if (_opt1) _opt2 = false; // Ensure only one is selected
                        });
                      },
                      text: 'set_personalized_look.option_1'.tr(),
                    ),
                    _buildOption(
                      value: _opt2,
                      onChanged: (v) {
                        setState(() {
                          _opt2 = v ?? false;
                          if (_opt2) _opt1 = false; // Ensure only one is selected
                        });
                      },
                      text: 'set_personalized_look.option_2'.tr(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'set_personalized_look.tip'.tr(),
                      textAlign: TextAlign.left,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: PrimaryOutlineButton(
                        label: 'set_personalized_look.button_text'.tr(),
                        width: 260,
                        onPressed: widget.onContinue,
                      ),
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

  Widget _buildOption({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          XCheckBox(value: value, onChanged: onChanged),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
