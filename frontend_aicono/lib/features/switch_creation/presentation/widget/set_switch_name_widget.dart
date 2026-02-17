import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

import '../../../../core/widgets/page_header_row.dart';

class SetSwitchNameWidget extends StatefulWidget {
  final String? userName;
  final String? organizationName;
  final String? initialSubDomain;
  final VoidCallback onLanguageChanged;
  final ValueChanged<String>? onSubDomainChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onEdit;
  final VoidCallback? onBack;

  const SetSwitchNameWidget({
    super.key,
    this.userName,
    this.organizationName,
    this.initialSubDomain,
    required this.onLanguageChanged,
    this.onSubDomainChanged,
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
    // Initialize with subdomain from invitation or generate from organization name
    final subDomain =
        widget.initialSubDomain ?? _generateSubDomain(widget.organizationName);
    _controller = TextEditingController(text: subDomain);
  }

  String _generateSubDomain(String? orgName) {
    if (orgName == null || orgName.trim().isEmpty) {
      return '';
    }
    // Convert organization name to lowercase, remove special chars, replace spaces with nothing
    final cleaned = orgName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '');
    return cleaned;
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
                      title: 'set_subdomain.title'.tr(),
                      showBackButton: widget.onBack != null,
                      onBack: widget.onBack,
                    ),

                    const SizedBox(height: 40),
                    TextField(
                      controller: _controller,
                      onChanged: (value) {
                        widget.onSubDomainChanged?.call(value);
                      },
                      decoration: InputDecoration(
                        hintText: 'set_subdomain.hint'.tr(),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Colors.black54,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
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
                      'set_subdomain.tip'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,

                      children: [
                        InkWell(
                          onTap: widget.onEdit ?? () => context.pop(),

                          child: Text(
                            'set_subdomain.edit_link'.tr(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              decoration: TextDecoration.underline,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        PrimaryOutlineButton(
                          label: 'set_subdomain.button_text'.tr(),
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
