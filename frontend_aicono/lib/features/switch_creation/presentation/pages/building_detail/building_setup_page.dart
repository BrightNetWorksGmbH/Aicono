import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/core/widgets/page_header_row.dart';
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

  void _navigateAfterCompletion() {
    // Get switchId from PropertySetupCubit (saved at login stage)
    final propertyCubit = sl<PropertySetupCubit>();
    final switchId = propertyCubit.state.switchId;
    final localStorage = sl<LocalStorage>();
    final siteId =
        widget.siteId ??
        Uri.parse(
          GoRouterState.of(context).uri.toString(),
        ).queryParameters['siteId'];
    // localStorage.getSelectedSiteId() ?? propertyCubit.state.siteId;

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
        const SnackBar(
          content: Text('Building ID is required'),
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.background,
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
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'Building Setup',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Configure your building settings',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 48),
                          // Set Floors Option
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: InkWell(
                              onTap: _navigateToSetFloors,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black54,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.layers,
                                      size: 32,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Set Floors',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Configure building floors',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Set Contact and Reporting User Option
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: InkWell(
                              onTap: _navigateToSetContactPerson,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black54,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 32,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Set Contact and Reporting User',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Configure contact person and reporting user',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Set Sensor Min and Max Values Option
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: InkWell(
                              onTap: _navigateToSetSensorMinMax,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black54,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.sensors,
                                      size: 32,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Set Sensors Min and Max Values',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Configure sensor threshold values',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryOutlineButton(
                            onPressed: () => _navigateAfterCompletion(),
                            label: 'Continue to the next building',
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
