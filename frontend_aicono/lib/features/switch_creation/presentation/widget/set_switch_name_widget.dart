import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

class SetSwitchNameWidget extends StatefulWidget {
  final String? userName;
  final String? organizationName;
  final VoidCallback onLanguageChanged;
  final ValueChanged<String>? onSwitchNameChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onEdit;
  final VoidCallback? onBack;

  const SetSwitchNameWidget({
    super.key,
    this.userName,
    this.organizationName,
    required this.onLanguageChanged,
    this.onSwitchNameChanged,
    this.onContinue,
    this.onEdit,
    this.onBack,
  });

  @override
  State<SetSwitchNameWidget> createState() => _SetSwitchNameWidgetState();
}

class _SetSwitchNameWidgetState extends State<SetSwitchNameWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Generate switch name from organization name
    final switchName = _generateSwitchName(widget.organizationName);
    _controller = TextEditingController(text: switchName);
  }

  String _generateSwitchName(String? orgName) {
    if (orgName == null || orgName.trim().isEmpty) {
      return 'brightnetworks.switchboard.com';
    }
    // Convert organization name to lowercase, remove special chars, replace spaces with nothing
    final cleaned = orgName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '');
    return '$cleaned.switchboard.com';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                      'set_switch_name.title'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _controller,
                      onChanged: widget.onSwitchNameChanged,
                      decoration: InputDecoration(
                        hintText: 'set_switch_name.hint'.tr(),
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
                      'set_switch_name.tip'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap:
                              widget.onEdit ??
                              () {
                                if (context.canPop()) {
                                  context.pop();
                                }
                              },
                          child: Text(
                            'set_switch_name.edit_link'.tr(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              decoration: TextDecoration.underline,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        PrimaryOutlineButton(
                          label: 'set_switch_name.button_text'.tr(),
                          width: 260,
                          onPressed: widget.onContinue,
                        ),
                      ],
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
