import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

class SetSwitchColorWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onChangeColor;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const SetSwitchColorWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onChangeColor,
    this.onSkip,
    this.onContinue,
    this.onBack,
  });

  @override
  State<SetSwitchColorWidget> createState() => _SetSwitchColorWidgetState();
}

class _SetSwitchColorWidgetState extends State<SetSwitchColorWidget> {
  Color _accentColor = const Color(0xFF0095A5);

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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(
                        child: Text(
                          '#0095A5 Türkis',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        widget.onChangeColor?.call();
                      },
                      child: Text(
                        'set_switch_color.change_color'.tr(),
                        style: AppTextStyles.bodySmall.copyWith(
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                        ),
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
