import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/core/widgets/shimmer_widget.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_buildings_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';

import '../../../../core/widgets/page_header_row.dart';

class AddAdditionalBuildingsWidget extends StatefulWidget {
  final String? userName;
  final String? siteId;
  final VoidCallback onLanguageChanged;
  final ValueChanged<bool>? onHasAdditionalBuildingsChanged;
  final ValueChanged<List<BuildingItem>>? onBuildingsChanged;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final ValueChanged<BuildingItem>? onAddBuildingDetails;

  const AddAdditionalBuildingsWidget({
    super.key,
    this.userName,
    this.siteId,
    required this.onLanguageChanged,
    this.onHasAdditionalBuildingsChanged,
    this.onBuildingsChanged,
    this.onSkip,
    this.onContinue,
    this.onBack,
    this.onAddBuildingDetails,
  });

  @override
  State<AddAdditionalBuildingsWidget> createState() =>
      _AddAdditionalBuildingsWidgetState();
}

class BuildingItem {
  final String id;
  final String name;
  final String? resources;
  final bool isPreSelected;
  final bool isEditable;

  BuildingItem({
    required this.id,
    required this.name,
    this.resources,
    this.isPreSelected = false,
    this.isEditable = false,
  });
}

class _AddAdditionalBuildingsWidgetState
    extends State<AddAdditionalBuildingsWidget> {
  bool? _hasAdditionalBuildings; // null = not selected, true = yes, false = no
  final List<BuildingItem> _buildings = [];
  final Map<String, TextEditingController> _buildingControllers = {};

  @override
  void initState() {
    super.initState();
    // Buildings list will be populated by user adding new buildings
    // Property name and location are shown separately from cubit state
  }

  @override
  void dispose() {
    for (var controller in _buildingControllers.values) {
      controller.dispose();
    }
    _buildingControllers.clear();
    super.dispose();
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'add_additional_buildings.progress_text'.tr(
        namedArgs: {'name': name},
      );
    }
    return 'add_additional_buildings.progress_text_fallback'.tr();
  }

  void _handleYesNoSelection(bool isYes) {
    setState(() {
      _hasAdditionalBuildings = isYes;
      if (isYes) {
        // When "ja" is selected for the first time, create one default building text field
        if (_buildings.isEmpty) {
          final buildingId =
              'building_${DateTime.now().millisecondsSinceEpoch}';
          final controller = TextEditingController();
          _buildingControllers[buildingId] = controller;
          _buildings.add(
            BuildingItem(id: buildingId, name: '', isEditable: true),
          );
        }
      } else {
        // If "no" is selected, remove all user-added buildings
        for (var controller in _buildingControllers.values) {
          controller.dispose();
        }
        _buildingControllers.clear();
        _buildings.clear();
      }
    });
    widget.onHasAdditionalBuildingsChanged?.call(isYes);
    widget.onBuildingsChanged?.call(_buildings);
  }

  void _addNewBuildingField() {
    setState(() {
      final buildingId = 'building_${DateTime.now().millisecondsSinceEpoch}';
      final controller = TextEditingController();
      _buildingControllers[buildingId] = controller;
      _buildings.add(BuildingItem(id: buildingId, name: '', isEditable: true));
    });
    widget.onBuildingsChanged?.call(_buildings);
  }

  void _updateBuildingName(String buildingId, String name) {
    setState(() {
      final building = _buildings.firstWhere((b) => b.id == buildingId);
      final index = _buildings.indexOf(building);
      _buildings[index] = BuildingItem(
        id: building.id,
        name: name,
        isEditable: building.isEditable,
      );
    });
    widget.onBuildingsChanged?.call(_buildings);
  }

  bool _hasBuildingsWithData() {
    if (_buildings.isEmpty) return false;
    return _buildings.every((building) {
      final controller = _buildingControllers[building.id];
      return controller != null && controller.text.trim().isNotEmpty;
    });
  }

  void _removeBuilding(String buildingId) {
    setState(() {
      final controller = _buildingControllers[buildingId];
      if (controller != null) {
        controller.dispose();
        _buildingControllers.remove(buildingId);
      }
      _buildings.removeWhere((building) => building.id == buildingId);

      // If all buildings are removed and "ja" was selected, reset to show checkboxes
      if (_buildings.isEmpty && _hasAdditionalBuildings == true) {
        _hasAdditionalBuildings = null;
        widget.onHasAdditionalBuildingsChanged?.call(false);
      }
    });
    widget.onBuildingsChanged?.call(_buildings);
  }

  Widget _buildShimmerField() {
    return ShimmerContainer(width: double.infinity, height: 60);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocBuilder<GetSiteBloc, GetSiteState>(
      builder: (context, getSiteState) {
        // Get site data from bloc if available
        SiteData? siteData;
        if (getSiteState is GetSiteSuccess) {
          siteData = getSiteState.siteData;
        }

        // Use siteData from bloc if available, otherwise fall back to PropertySetupCubit
        final propertyName = siteData?.name;
        final location = siteData?.address;
        final resourceTypes = siteData != null
            ? [siteData.resourceType]
            : <String>[];

        // If siteData is not provided, try to get from cubit as fallback
        final cubit = sl<PropertySetupCubit>();
        final fallbackPropertyName = propertyName ?? cubit.state.propertyName;
        final fallbackLocation = location ?? cubit.state.location;
        final fallbackResourceTypes = resourceTypes.isNotEmpty
            ? resourceTypes
            : cubit.state.resourceTypes;

        final isLoading = getSiteState is GetSiteLoading;
        final hasError = getSiteState is GetSiteFailure;

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
                  Expanded(
                    child: SingleChildScrollView(
                      child: SizedBox(
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
                                value: 0.9,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color(0xFF8B9A5B), // Muted green color
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 32),
                            PageHeaderRow(
                              title: 'add_additional_buildings.title'.tr(),
                              showBackButton: widget.onBack != null,
                              onBack: widget.onBack,
                            ),

                            const SizedBox(height: 40),
                            // Show property name with resource types and check icon if available
                            if (isLoading) ...[
                              _buildShimmerField(),
                              const SizedBox(height: 16),
                              _buildShimmerField(),
                              const SizedBox(height: 24),
                            ] else if (hasError) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                  ),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Error loading site data',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      getSiteState.message,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.red.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        if (widget.siteId != null &&
                                            widget.siteId!.isNotEmpty) {
                                          context.read<GetSiteBloc>().add(
                                            GetSiteRequested(
                                              siteId: widget.siteId!,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ] else ...[
                              if (fallbackPropertyName != null &&
                                  fallbackPropertyName.isNotEmpty) ...[
                                _buildCompletedField(
                                  value: fallbackPropertyName,
                                  resourceTypes: fallbackResourceTypes,
                                ),
                                const SizedBox(height: 16),
                              ],
                              // Show location with check icon if available
                              if (fallbackLocation != null &&
                                  fallbackLocation.isNotEmpty) ...[
                                _buildCompletedField(value: fallbackLocation),
                                const SizedBox(height: 24),
                              ],
                            ],
                            // Display buildings with text fields
                            if (_buildings.isNotEmpty) ...[
                              ..._buildings.map(
                                (building) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildBuildingTextField(building),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Add building link (show only if buildings have data)
                            if (_hasBuildingsWithData()) ...[
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: _addNewBuildingField,
                                child: Text(
                                  'add_additional_buildings.add_building_link'
                                      .tr(),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    decoration: TextDecoration.underline,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                            // Yes/No selection (only show when "ja" hasn't been selected yet)
                            if (_hasAdditionalBuildings == null) ...[
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildYesNoOption(
                                    label: 'add_additional_buildings.yes'.tr(),
                                    isSelected: false,
                                    onTap: () => _handleYesNoSelection(true),
                                  ),
                                  const SizedBox(width: 24),
                                  _buildYesNoOption(
                                    label: 'add_additional_buildings.no'.tr(),
                                    isSelected: false,
                                    onTap: () => _handleYesNoSelection(false),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),
                            InkWell(
                              onTap: widget.onSkip,
                              child: Text(
                                'add_additional_buildings.skip_link'.tr(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  decoration: TextDecoration.underline,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            BlocBuilder<
                              CreateBuildingsBloc,
                              CreateBuildingsState
                            >(
                              builder: (context, createBuildingsState) {
                                final isLoading =
                                    createBuildingsState
                                        is CreateBuildingsLoading;
                                return isLoading
                                    ? const SizedBox(
                                        width: 260,
                                        height: 48,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : PrimaryOutlineButton(
                                        label:
                                            'add_additional_buildings.button_text'
                                                .tr(),
                                        width: 260,
                                        enabled:
                                            _hasBuildingsWithData() &&
                                            !isLoading,
                                        onPressed:
                                            _hasBuildingsWithData() &&
                                                !isLoading
                                            ? widget.onContinue
                                            : null,
                                      );
                              },
                            ),
                          ],
                        ),
                      ),
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
    List<String>? resourceTypes,
  }) {
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
          if (resourceTypes != null && resourceTypes.isNotEmpty) ...[
            const SizedBox(width: 16),
            Text(
              _formatResourceTypes(resourceTypes),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatResourceTypes(List<String> resourceTypes) {
    final List<String> translatedTypes = resourceTypes.map((type) {
      switch (type) {
        case 'energy':
          return 'select_resources.option_energy'.tr();
        case 'water':
          return 'select_resources.option_water'.tr();
        case 'gas':
          return 'select_resources.option_gas'.tr();
        default:
          return type;
      }
    }).toList();
    return translatedTypes.join(', ');
  }

  Widget _buildBuildingTextField(BuildingItem building) {
    final controller =
        _buildingControllers[building.id] ?? TextEditingController();
    if (!_buildingControllers.containsKey(building.id)) {
      _buildingControllers[building.id] = controller;
    }

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'add_additional_buildings.building_hint'.tr(),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: Colors.grey.shade400,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: const Color(0xFF8B9A5B), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: const Color(0xFF8B9A5B), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        suffixIcon: IconButton(
          onPressed: () => _removeBuilding(building.id),
          icon: const Icon(Icons.close, color: Colors.grey),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ),
      onChanged: (value) {
        _updateBuildingName(building.id, value);
      },
    );
  }

  Widget _buildYesNoOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          XCheckBox(value: isSelected, onChanged: (_) => onTap()),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
