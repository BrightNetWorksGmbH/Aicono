import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';

import '../../../../../core/widgets/top_part_widget.dart';

class BuildingSetupPage extends StatefulWidget {
  final String? buildingId;
  final String? siteId;
  final String? userName;
  final String? buildingName;
  final String? buildingAddress;
  final String? numberOfFloors;
  final String? numberOfRooms;
  final String? totalArea;
  final String? constructionYear;
  final String? fromDashboard;

  const BuildingSetupPage({
    super.key,
    this.buildingId,
    this.siteId,
    this.userName,
    this.buildingName,
    this.buildingAddress,
    this.numberOfFloors,
    this.numberOfRooms,
    this.totalArea,
    this.constructionYear,
    this.fromDashboard,
  });

  @override
  State<BuildingSetupPage> createState() => _BuildingSetupPageState();
}

class _BuildingSetupPageState extends State<BuildingSetupPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _navigateToSetFloors() {
    context.pushNamed(
      Routelists.buildingFloorManagement,
      queryParameters: {
        if (widget.buildingId != null) 'buildingId': widget.buildingId!,
        if (widget.siteId != null) 'siteId': widget.siteId!,
        if (widget.buildingName != null) 'buildingName': widget.buildingName!,
        if (widget.buildingAddress != null)
          'buildingAddress': widget.buildingAddress!,
        if (widget.numberOfFloors != null)
          'numberOfFloors': widget.numberOfFloors!,
        if (widget.numberOfRooms != null)
          'numberOfRooms': widget.numberOfRooms!,
        if (widget.totalArea != null) 'totalArea': widget.totalArea!,
        if (widget.constructionYear != null)
          'constructionYear': widget.constructionYear!,
        if (widget.fromDashboard != null)
          'fromDashboard': widget.fromDashboard!,
      },
    );
  }

  void _navigateToSetContactPerson() {
    context.pushNamed(
      Routelists.buildingContactPerson,
      queryParameters: {
        if (widget.buildingName != null) 'buildingName': widget.buildingName!,
        if (widget.buildingAddress != null)
          'buildingAddress': widget.buildingAddress!,
        if (widget.buildingId != null) 'buildingId': widget.buildingId!,
        if (widget.siteId != null) 'siteId': widget.siteId!,
        if (widget.totalArea != null) 'totalArea': widget.totalArea!,
        if (widget.numberOfRooms != null)
          'numberOfRooms': widget.numberOfRooms!,
        if (widget.constructionYear != null)
          'constructionYear': widget.constructionYear!,
        if (widget.fromDashboard != null)
          'fromDashboard': widget.fromDashboard!,
      },
    );
  }

  void _navigateToSetSensorMinMax() {
    if (widget.buildingId == null || widget.buildingId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('building_setup.building_id_required'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    context.pushNamed(
      Routelists.sensorMinMax,
      queryParameters: {
        'buildingId': widget.buildingId!,
        if (widget.siteId != null) 'siteId': widget.siteId!,
        if (widget.fromDashboard != null)
          'fromDashboard': widget.fromDashboard!,
      },
    );
  }

  void _navigateAfterCompletion() {
    // Get switchId from PropertySetupCubit (saved at login stage)
    final propertyCubit = sl<PropertySetupCubit>();
    final switchId = propertyCubit.state.switchId;
    final siteId =
        widget.siteId ??
        Uri.parse(
          GoRouterState.of(context).uri.toString(),
        ).queryParameters['siteId'];

    // Check if navigation is from dashboard
    final isFromDashboard = widget.fromDashboard == 'true';

    if (isFromDashboard) {
      // If from dashboard, redirect to dashboard after completion
      context.goNamed(Routelists.dashboard);
    } else if (siteId == null && switchId != null && switchId.isNotEmpty) {
      context.goNamed(
        Routelists.addPropertyName,
        queryParameters: {'switchId': switchId},
      );
    } else {
      // Fallback: navigate to additional building list if switchId not available
      context.goNamed(
        Routelists.additionalBuildingList,
        queryParameters: {
          if (widget.userName != null) 'userName': widget.userName!,
          if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
          if (widget.fromDashboard != null)
            'fromDashboard': widget.fromDashboard!,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: screenSize.height * .9,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Container(
                    width: screenSize.width < 600
                        ? screenSize.width * 0.95
                        : screenSize.width < 1200
                        ? screenSize.width * 0.5
                        : screenSize.width * 0.6,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Material(
                            color: Colors.transparent,
                            child: TopHeader(
                              onLanguageChanged: _handleLanguageChanged,
                              containerWidth: screenSize.width > 500
                                  ? 500
                                  : screenSize.width * 0.98,
                              userInitial: widget.userName?[0].toUpperCase(),
                              verseInitial: null,
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: ClipRRect(
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
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => context.pop(),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'building_setup.title'.tr(),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Configure building floors Option
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color(0xFF636F57),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'building_setup.configure_floors'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _navigateToSetFloors,
                                    child: Text(
                                      'building_setup.update'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Set contact and report person Option
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color(0xFF636F57),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'building_setup.set_contact_report'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _navigateToSetContactPerson,
                                    child: Text(
                                      'building_setup.update'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Set sensor values Option
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color(0xFF636F57),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'building_setup.set_sensor_values'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _navigateToSetSensorMinMax,
                                    child: Text(
                                      'building_setup.update'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          PrimaryOutlineButton(
                            onPressed: _navigateAfterCompletion,
                            label: 'building_setup.continue_button'.tr(),
                            width: 260,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AppFooter(
                onLanguageChanged: _handleLanguageChanged,
                containerWidth: MediaQuery.of(context).size.width,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
