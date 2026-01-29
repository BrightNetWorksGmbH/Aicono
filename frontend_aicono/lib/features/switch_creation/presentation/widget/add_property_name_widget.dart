import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

import '../../../../core/widgets/page_header_row.dart';

class AddPropertyNameWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final ValueChanged<String>? onPropertyNameChanged;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const AddPropertyNameWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onPropertyNameChanged,
    this.onSkip,
    this.onContinue,
    this.onBack,
  });

  @override
  State<AddPropertyNameWidget> createState() => _AddPropertyNameWidgetState();
}

class _AddPropertyNameWidgetState extends State<AddPropertyNameWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'add_property_name.progress_text'.tr(namedArgs: {'name': name});
    }
    return 'add_property_name.progress_text_fallback'.tr();
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
                        value: 0.33,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF8B9A5B), // Muted green color
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 32),
                    PageHeaderRow(
                      title: 'add_property_name.title'.tr(),
                      showBackButton: widget.onBack != null,
                      onBack: widget.onBack,
                    ),

                    const SizedBox(height: 40),
                    TextField(
                      controller: _controller,
                      onChanged: (value) {
                        widget.onPropertyNameChanged?.call(value);
                        setState(() {}); // Update button state
                      },
                      decoration: InputDecoration(
                        hintText: 'add_property_name.hint'.tr(),
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey.shade400,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: const BorderSide(
                            color: Colors.black54,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppTheme.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: widget.onSkip,
                      child: Text(
                        'add_property_name.skip_link'.tr(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryOutlineButton(
                      label: 'add_property_name.button_text'.tr(),
                      width: 260,
                      enabled: _controller.text.trim().isNotEmpty,
                      onPressed: _controller.text.trim().isNotEmpty
                          ? widget.onContinue
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
}
