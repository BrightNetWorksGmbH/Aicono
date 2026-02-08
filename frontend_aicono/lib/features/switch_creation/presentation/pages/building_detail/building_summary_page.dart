import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_svg/svg.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';

import '../../../../../core/widgets/page_header_row.dart';
import '../../../../Building/presentation/pages/steps/building_floor_plan_step.dart'
    show DottedBorderContainer;

class BuildingSummaryPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? buildingSize;
  final int? numberOfRooms;
  final String? constructionYear;
  final String? floorPlanUrl;
  final String? floorName;
  final List<Map<String, dynamic>>? rooms;
  final String siteId;
  final String buildingId;
  const BuildingSummaryPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.buildingSize,
    this.numberOfRooms,
    this.constructionYear,
    this.floorPlanUrl,
    this.floorName,
    this.rooms,
    required this.siteId,
    required this.buildingId,
  });

  @override
  State<BuildingSummaryPage> createState() => _BuildingSummaryPageState();
}

class _BuildingSummaryPageState extends State<BuildingSummaryPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleContinue() async {
    // Get buildingId from PropertySetupCubit (stored when building is selected)
    final propertyCubit = sl<PropertySetupCubit>();
    final storedBuildingId = widget.buildingId.isNotEmpty
        ? widget.buildingId
        : propertyCubit.state.buildingId;

    // Get floorName and numberOfFloors from widget or route parameters
    final currentState = GoRouterState.of(context);
    String floorNameValue =
        widget.floorName ??
        currentState.uri.queryParameters['floorName'] ??
        'Ground Floor';
    int numberOfFloors =
        int.tryParse(
          currentState.uri.queryParameters['numberOfFloors'] ?? '1',
        ) ??
        1;

    // If we have buildingId but numberOfFloors is still 1 (default), try to fetch from building data
    if (storedBuildingId != null &&
        storedBuildingId.isNotEmpty &&
        numberOfFloors == 1) {
      try {
        final dioClient = sl<DioClient>();
        final response = await dioClient.get(
          '/api/v1/buildings/$storedBuildingId',
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data['success'] == true && data['data'] != null) {
            final buildingData = data['data'] as Map<String, dynamic>;
            // Get numberOfFloors from building data
            if (buildingData['num_floors'] != null) {
              numberOfFloors =
                  int.tryParse(buildingData['num_floors'].toString()) ??
                  numberOfFloors;
            } else if (buildingData['numberOfFloors'] != null) {
              numberOfFloors =
                  int.tryParse(buildingData['numberOfFloors'].toString()) ??
                  numberOfFloors;
            }
          }
        }
      } catch (e) {
        // Silently fail - use default values
        debugPrint('Error fetching building data: $e');
      }
    }

    // Extract fromDashboard from current route
    final fromDashboard = Uri.parse(
      GoRouterState.of(context).uri.toString(),
    ).queryParameters['fromDashboard'];
    
    // Navigate to room assignment page
    context.pushNamed(
      Routelists.roomAssignment,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.buildingAddress != null)
          'buildingAddress': widget.buildingAddress!,
        if (widget.buildingName != null) 'buildingName': widget.buildingName!,
        if (widget.floorPlanUrl != null) 'floorPlanUrl': widget.floorPlanUrl!,
        if (widget.rooms != null && widget.rooms!.isNotEmpty)
          'rooms': Uri.encodeComponent(jsonEncode(widget.rooms!)),
        if (storedBuildingId != null && storedBuildingId.isNotEmpty)
          'buildingId': storedBuildingId,
        'siteId': widget.siteId.isNotEmpty
            ? widget.siteId
            : Uri.parse(
                GoRouterState.of(context).uri.toString(),
              ).queryParameters['siteId'],
        'floorName': floorNameValue,
        'numberOfFloors': numberOfFloors.toString(),
        if (widget.buildingSize != null) 'totalArea': widget.buildingSize!,
        if (widget.constructionYear != null)
          'constructionYear': widget.constructionYear!,
        if (fromDashboard != null) 'fromDashboard': fromDashboard,
      },
    );
  }

  void _handleSkip() {
    // Skip to next step
    _handleContinue();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: screenSize.width,
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
                Padding(
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
                          if (widget.userName != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Fast geschafft, ${widget.userName}!',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.8,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8B9A5B),
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                ),
                                child: SizedBox(
                                  width: screenSize.width < 600
                                      ? screenSize.width * 0.95
                                      : screenSize.width < 1200
                                      ? screenSize.width * 0.5
                                      : screenSize.width * 0.6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Progress Indicator
                                      SizedBox(
                                        width: screenSize.width < 600
                                            ? screenSize.width * 0.95
                                            : screenSize.width < 1200
                                            ? screenSize.width * 0.5
                                            : screenSize.width * 0.6,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.zero,
                                          child: LinearProgressIndicator(
                                            value:
                                                0.85, // Adjust value as needed
                                            backgroundColor:
                                                Colors.grey.shade300,
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(Color(0xFF8B9A5B)),
                                            minHeight: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 40),
                                      PageHeaderRow(
                                        title: 'Grundriss aktivieren',
                                        showBackButton: true,
                                        onBack: () {
                                          Navigator.pop(context);
                                        },
                                      ),

                                      const SizedBox(height: 32),
                                      // Building Address
                                      if (widget.buildingAddress != null)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 18,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.black54,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Image.asset(
                                                'assets/images/check.png',
                                                width: 20,
                                                height: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  widget.buildingAddress!,
                                                  style: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                        color: Colors.black87,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (widget.buildingAddress != null)
                                        const SizedBox(height: 16),
                                      // Building Specifications
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.black54,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Image.asset(
                                              'assets/images/check.png',
                                              width: 20,
                                              height: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _buildSpecificationsText(),
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      color: Colors.black87,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Floor Plan Section
                                      DottedBorderContainer(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Image.asset(
                                                    'assets/images/check.png',
                                                    width: 20,
                                                    height: 20,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Grundriss aktiviert',
                                                    style: AppTextStyles
                                                        .titleMedium
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              if (widget.rooms != null &&
                                                  widget.rooms!.isNotEmpty) ...[
                                                const SizedBox(height: 16),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                      ),
                                                  child: Wrap(
                                                    direction: Axis.horizontal,
                                                    spacing: 100,
                                                    runSpacing: 28,
                                                    children: [
                                                      _buildRoomLegend(),

                                                      if (widget.floorPlanUrl !=
                                                          null)
                                                        Container(
                                                          height: 200,
                                                          width: 350,

                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                            child: SvgPicture.network(
                                                              widget
                                                                  .floorPlanUrl!,
                                                              fit: BoxFit
                                                                  .contain,
                                                              errorBuilder:
                                                                  (
                                                                    context,
                                                                    error,
                                                                    stackTrace,
                                                                  ) {
                                                                    return const Center(
                                                                      child: Icon(
                                                                        Icons
                                                                            .image_not_supported,
                                                                        size:
                                                                            48,
                                                                        color: Colors
                                                                            .grey,
                                                                      ),
                                                                    );
                                                                  },
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _handleSkip,
                                          child: Text(
                                            'Schritt überspringen',
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  color: Colors.black87,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Material(
                                        color: Colors.transparent,
                                        child: PrimaryOutlineButton(
                                          label: 'Das passt so',
                                          width: 260,
                                          onPressed: _handleContinue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AppFooter(
                  onLanguageChanged: _handleLanguageChanged,
                  containerWidth: screenSize.width,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildSpecificationsText() {
    final parts = <String>[];
    if (widget.buildingSize != null) {
      parts.add('${widget.buildingSize}qm');
    }
    if (widget.numberOfRooms != null) {
      parts.add('${widget.numberOfRooms} Räume');
    }
    parts.add('Sanitäranlage');
    if (widget.constructionYear != null) {
      parts.add('Baujahr ${widget.constructionYear}');
    }
    return parts.join(', ');
  }

  Widget _buildRoomLegend() {
    if (widget.rooms == null || widget.rooms!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: widget.rooms!.asMap().entries.map((entry) {
        final index = entry.key;
        final room = entry.value;

        // Parse color from room data
        Color roomColor;
        if (room['color'] != null) {
          try {
            final colorValue = int.tryParse(room['color'].toString());
            roomColor = colorValue != null
                ? Color(colorValue)
                : _getDefaultRoomColor(index);
          } catch (e) {
            roomColor = _getDefaultRoomColor(index);
          }
        } else {
          roomColor = _getDefaultRoomColor(index);
        }

        return Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: roomColor,
                    border: Border.all(color: Colors.black54, width: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  room['name'] ?? 'Room ${index + 1}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Color _getDefaultRoomColor(int index) {
    final roomColors = [
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
    ];
    return roomColors[index % roomColors.length];
  }
}
