import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

class StructureSwitchWidget extends StatelessWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onStartDirectly;
  final VoidCallback? onFindStructure;
  final VoidCallback? onBack;

  const StructureSwitchWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onStartDirectly,
    this.onFindStructure,
    this.onBack,
  });

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
                onLanguageChanged: onLanguageChanged,
                containerWidth: screenSize.width > 500
                    ? 500
                    : screenSize.width * 0.98,
              ),
              if (onBack != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: onBack,
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
                      'structure_switch.title'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'structure_switch.tip'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: onStartDirectly,
                      child: Text(
                        'structure_switch.start_directly_link'.tr(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryOutlineButton(
                      label: 'structure_switch.button_text'.tr(),
                      width: 260,
                      onPressed: onFindStructure,
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
