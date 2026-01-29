import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

import '../../../../core/widgets/page_header_row.dart';

class ConfirmStructureWidget extends StatelessWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onSkip;
  final VoidCallback? onFindStructure;
  final VoidCallback? onBack;

  const ConfirmStructureWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onSkip,
    this.onFindStructure,
    this.onBack,
  });

  String _buildProgressText() {
    final name = userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'confirm_structure.progress_text'.tr(namedArgs: {'name': name});
    }
    return 'confirm_structure.progress_text_fallback'.tr();
  }

  String _buildHeading() {
    final name = userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'confirm_structure.heading'.tr(namedArgs: {'name': name});
    }
    return 'confirm_structure.heading_fallback'.tr();
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
                onLanguageChanged: onLanguageChanged,
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
                        value: 0.75,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF8B9A5B), // Muted green color
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 32),
                    PageHeaderRow(
                      title: _buildHeading(),
                      showBackButton: onBack != null,
                      onBack: onBack,
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'confirm_structure.description'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: onSkip,
                      child: Text(
                        'confirm_structure.skip_link'.tr(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryOutlineButton(
                      label: 'confirm_structure.button_text'.tr(),
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
