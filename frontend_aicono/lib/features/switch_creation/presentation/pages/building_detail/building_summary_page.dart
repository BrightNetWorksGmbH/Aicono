import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';

class BuildingSummaryPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? buildingSize;
  final int? numberOfRooms;
  final String? constructionYear;
  final String? floorPlanUrl;
  final List<Map<String, dynamic>>? rooms;

  const BuildingSummaryPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.buildingSize,
    this.numberOfRooms,
    this.constructionYear,
    this.floorPlanUrl,
    this.rooms,
  });

  @override
  State<BuildingSummaryPage> createState() => _BuildingSummaryPageState();
}

class _BuildingSummaryPageState extends State<BuildingSummaryPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleContinue() {
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
        'buildingId':
            '6948dcd113537bff98eb7338', // TODO: Get from previous step
        'floorName': 'Ground Floor', // TODO: Get from previous step
        'numberOfFloors': '1', // TODO: Get actual number of floors
        if (widget.buildingSize != null) 'totalArea': widget.buildingSize!,
        if (widget.constructionYear != null)
          'constructionYear': widget.constructionYear!,
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
                                      'Prima, so sieht Dein Gebäude aus.',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.headlineSmall
                                          .copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                          ),
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
                                            const Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF238636),
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                widget.buildingAddress!,
                                                style: AppTextStyles.bodyMedium
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
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF238636),
                                            size: 24,
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
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black54,
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                color: Color(0xFF238636),
                                                size: 24,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Grundriss aktiviert',
                                                style: AppTextStyles.titleMedium
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
                                            _buildRoomLegend(),
                                            const SizedBox(height: 16),
                                            if (widget.floorPlanUrl != null)
                                              Container(
                                                height: 200,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: SvgPicture.network(
                                                    widget.floorPlanUrl!,
                                                    fit: BoxFit.contain,
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
                                                              size: 48,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          );
                                                        },
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ],
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

    final roomColors = [
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: widget.rooms!.asMap().entries.map((entry) {
        final index = entry.key;
        final room = entry.value;
        final color = roomColors[index % roomColors.length];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Colors.black54, width: 1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              room['name'] ?? 'Room ${index + 1}',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.black87),
            ),
          ],
        );
      }).toList(),
    );
  }
}
