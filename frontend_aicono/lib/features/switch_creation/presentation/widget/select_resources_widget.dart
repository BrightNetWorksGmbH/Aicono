import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';

class SelectResourcesWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const SelectResourcesWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onSkip,
    this.onContinue,
    this.onBack,
  });

  @override
  State<SelectResourcesWidget> createState() => _SelectResourcesWidgetState();
}

class _SelectResourcesWidgetState extends State<SelectResourcesWidget> {
  final Set<String> _selectedResources = {};

  @override
  void initState() {
    super.initState();
    // Initialize from cubit if available
    final cubit = sl<PropertySetupCubit>();
    if (cubit.state.resourceTypes.isNotEmpty) {
      _selectedResources.addAll(cubit.state.resourceTypes);
    }
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'select_resources.progress_text'.tr(
        namedArgs: {'name': name},
      );
    }
    return 'select_resources.progress_text_fallback'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocBuilder<PropertySetupCubit, PropertySetupState>(
      bloc: sl<PropertySetupCubit>(),
      builder: (context, state) {
        final propertyName = state.propertyName;
        final location = state.location;

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
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Icon(Icons.arrow_back,
                              color: Colors.black87, size: 24),
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
                          _buildProgressText(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: 0.85,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF8B9A5B), // Muted green color
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'select_resources.title'.tr(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Show property name with check icon if available
                        if (propertyName != null && propertyName.isNotEmpty) ...[
                          _buildCompletedField(value: propertyName),
                          const SizedBox(height: 16),
                        ],
                        // Show location with check icon if available
                        if (location != null && location.isNotEmpty) ...[
                          _buildCompletedField(value: location),
                          const SizedBox(height: 24),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCheckboxOption(
                              value: 'energy',
                              label: 'select_resources.option_energy'.tr(),
                              isSelected: _selectedResources.contains('energy'),
                            ),
                            const SizedBox(width: 24),
                            _buildCheckboxOption(
                              value: 'water',
                              label: 'select_resources.option_water'.tr(),
                              isSelected: _selectedResources.contains('water'),
                            ),
                            const SizedBox(width: 24),
                            _buildCheckboxOption(
                              value: 'gas',
                              label: 'select_resources.option_gas'.tr(),
                              isSelected: _selectedResources.contains('gas'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        InkWell(
                          onTap: widget.onSkip,
                          child: Text(
                            'select_resources.skip_link'.tr(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              decoration: TextDecoration.underline,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        BlocBuilder<CreateSiteBloc, CreateSiteState>(
                          builder: (context, createSiteState) {
                            final isLoading = createSiteState is CreateSiteLoading;
                            return isLoading
                                ? const SizedBox(
                                    width: 260,
                                    height: 48,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : PrimaryOutlineButton(
                                    label: 'select_resources.button_text'.tr(),
                                    width: 260,
                                    onPressed: widget.onContinue,
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
      },
    );
  }

  Widget _buildCompletedField({
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black54,
          width: 2,
        ),
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
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxOption({
    required String value,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedResources.remove(value);
          } else {
            _selectedResources.add(value);
          }
        });
        sl<PropertySetupCubit>()
            .setResourceTypes(_selectedResources.toList());
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          XCheckBox(
            value: isSelected,
            onChanged: (bool? newValue) {
              setState(() {
                if (newValue == true) {
                  _selectedResources.add(value);
                } else {
                  _selectedResources.remove(value);
                }
              });
              sl<PropertySetupCubit>()
                  .setResourceTypes(_selectedResources.toList());
            },
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

