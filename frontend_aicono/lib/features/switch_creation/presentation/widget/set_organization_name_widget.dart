import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

class SetOrganizationNameWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final ValueChanged<String>? onNameChanged;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;

  const SetOrganizationNameWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onNameChanged,
    this.onBack,
    this.onContinue,
  });

  @override
  State<SetOrganizationNameWidget> createState() =>
      _SetOrganizationNameWidgetState();
}

class _SetOrganizationNameWidgetState extends State<SetOrganizationNameWidget> {
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

  String _buildTitle() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'set_organization_name.title_with_name'.tr(
        namedArgs: {'name': name},
      );
    }
    return 'set_organization_name.title'.tr();
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
                      _buildTitle(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _controller,
                      onChanged: widget.onNameChanged,
                      decoration: InputDecoration(
                        hintText: 'set_organization_name.hint'.tr(),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Colors.black54,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
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
                    const SizedBox(height: 12),
                    Text(
                      'set_organization_name.tip'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    StatefulBuilder(
                      builder: (context, setStateButton) {
                        final hasText = _controller.text.trim().isNotEmpty;
                        return PrimaryOutlineButton(
                          label: 'set_organization_name.button_text'.tr(),
                          width: 260,
                          enabled: hasText,
                          onPressed: hasText ? widget.onContinue : null,
                        );
                      },
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
