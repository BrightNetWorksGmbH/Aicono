import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/shimmer_widget.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_buildings_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';

import '../../../../core/widgets/page_header_row.dart';

class AdditionalBuildingListWidget extends StatefulWidget {
  final String? userName;
  final String? siteId;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onSkip;
  final ValueChanged<BuildContext>? onContinue;
  final VoidCallback? onBack;
  final ValueChanged<BuildingData>? onAddBuildingDetails;

  const AdditionalBuildingListWidget({
    super.key,
    this.userName,
    this.siteId,
    required this.onLanguageChanged,
    this.onSkip,
    this.onContinue,
    this.onBack,
    this.onAddBuildingDetails,
  });

  @override
  State<AdditionalBuildingListWidget> createState() =>
      _AdditionalBuildingListWidgetState();
}

class _AdditionalBuildingListWidgetState
    extends State<AdditionalBuildingListWidget> {
  Widget _buildShimmerField() {
    return ShimmerContainer(width: double.infinity, height: 60);
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

        final isLoadingSite = getSiteState is GetSiteLoading;
        final hasSiteError = getSiteState is GetSiteFailure;

        return BlocBuilder<GetBuildingsBloc, GetBuildingsState>(
          builder: (context, getBuildingsState) {
            final isLoadingBuildings = getBuildingsState is GetBuildingsLoading;

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
                                      const Color(0xFF8B9A5B),
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
                                if (isLoadingSite) ...[
                                  _buildShimmerField(),
                                  const SizedBox(height: 16),
                                  _buildShimmerField(),
                                  const SizedBox(height: 24),
                                ] else if (hasSiteError) ...[
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
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          getSiteState.message,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
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
                                    _buildCompletedField(
                                      value: fallbackLocation,
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ],
                                // Display buildings list
                                if (isLoadingBuildings) ...[
                                  _buildShimmerField(),
                                  const SizedBox(height: 16),
                                  _buildShimmerField(),
                                  const SizedBox(height: 16),
                                  _buildShimmerField(),
                                ] else if (getBuildingsState
                                    is GetBuildingsFailure) ...[
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
                                          'Error loading buildings',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          getBuildingsState.message,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: Colors.red.shade600,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (widget.siteId != null &&
                                                widget.siteId!.isNotEmpty) {
                                              context
                                                  .read<GetBuildingsBloc>()
                                                  .add(
                                                    GetBuildingsRequested(
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
                                ] else if (getBuildingsState
                                    is GetBuildingsSuccess) ...[
                                  if (getBuildingsState
                                      .buildings
                                      .isNotEmpty) ...[
                                    ...getBuildingsState.buildings.map(
                                      (building) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: _buildBuildingItem(building),
                                      ),
                                    ),
                                  ] else ...[
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'No buildings found',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ),
                                  ],
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
                                PrimaryOutlineButton(
                                  label: 'add_additional_buildings.button_text'
                                      .tr(),
                                  width: 260,
                                  onPressed: widget.onContinue != null
                                      ? () => widget.onContinue!(context)
                                      : null,
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
            color: const Color(0xFF238636),
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

  Widget _buildBuildingItem(BuildingData building) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF8B9A5B), width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/check.png',
            width: 16,
            height: 16,
            color: const Color(0xFF238636),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              building.name,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
            ),
          ),
          // Add details link
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              widget.onAddBuildingDetails?.call(building);
            },
            child: Text(
              'add_additional_buildings.add_details_link'.tr(),
              style: AppTextStyles.bodyMedium.copyWith(
                decoration: TextDecoration.underline,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
