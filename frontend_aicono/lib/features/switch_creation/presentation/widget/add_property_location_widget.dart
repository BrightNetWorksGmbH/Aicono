import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';

import '../../../../core/widgets/page_header_row.dart';

class AddPropertyLocationWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const AddPropertyLocationWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onSkip,
    this.onContinue,
    this.onBack,
  });

  @override
  State<AddPropertyLocationWidget> createState() =>
      _AddPropertyLocationWidgetState();
}

class _AddPropertyLocationWidgetState extends State<AddPropertyLocationWidget> {
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController();
    // Initialize from cubit if available
    final cubit = sl<PropertySetupCubit>();
    if (cubit.state.location != null) {
      _locationController.text = cubit.state.location!;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'add_property_location.progress_text'.tr(
        namedArgs: {'name': name},
      );
    }
    return 'add_property_location.progress_text_fallback'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocBuilder<PropertySetupCubit, PropertySetupState>(
      bloc: sl<PropertySetupCubit>(),
      builder: (context, state) {
        final propertyName = state.propertyName;

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
                            value: 0.7,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF8B9A5B), // Muted green color
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 32),
                        PageHeaderRow(
                          title: 'add_property_location.title'.tr(),
                          showBackButton: widget.onBack != null,
                          onBack: widget.onBack,
                        ),

                        const SizedBox(height: 40),
                        // Show property name with check icon if available
                        if (propertyName != null &&
                            propertyName.isNotEmpty) ...[
                          _buildCompletedField(value: propertyName),
                          const SizedBox(height: 24),
                        ],
                        // Location TextField
                        TextField(
                          controller: _locationController,
                          onChanged: (value) {
                            sl<PropertySetupCubit>().setLocation(value.trim());
                            setState(() {}); // Update button state
                          },
                          decoration: InputDecoration(
                            hintText: 'add_property_location.hint'.tr(),
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
                            'add_property_location.skip_link'.tr(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              decoration: TextDecoration.underline,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        PrimaryOutlineButton(
                          label: 'add_property_location.button_text'.tr(),
                          width: 260,
                          enabled: _locationController.text.trim().isNotEmpty,
                          onPressed: _locationController.text.trim().isNotEmpty
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
      },
    );
  }

  Widget _buildCompletedField({required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/check.png',
            width: 16,
            height: 16,
            color: const Color(0xFF238636), // Green checkmark
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
