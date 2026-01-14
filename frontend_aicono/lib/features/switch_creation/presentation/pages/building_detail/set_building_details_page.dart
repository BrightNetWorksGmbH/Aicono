import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/building_detail_widget/set_building_details_widget.dart';

class SetBuildingDetailsPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;

  const SetBuildingDetailsPage({
    super.key,
    this.userName,
    this.buildingAddress,
  });

  @override
  State<SetBuildingDetailsPage> createState() => _SetBuildingDetailsPageState();
}

class _SetBuildingDetailsPageState extends State<SetBuildingDetailsPage> {
  Map<String, String?> _buildingDetails = {};
  String? _buildingName = 'Building';

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleBuildingDetailsChanged(Map<String, String?> details) {
    setState(() {
      _buildingDetails = details;
    });
  }

  void _handleContinue() {
    // Navigate to floor management page with building details
    final numberOfFloors = _buildingDetails['rooms'] != null
        ? int.tryParse(_buildingDetails['rooms']!)
        : 1;

    final totalArea = _buildingDetails['size'] != null
        ? double.tryParse(_buildingDetails['size']!)
        : null;

    context.pushNamed(
      Routelists.buildingFloorManagement,
      queryParameters: {
        'buildingName': _buildingName,
        if (widget.buildingAddress != null)
          'buildingAddress': widget.buildingAddress!,
        'numberOfFloors': (numberOfFloors ?? 1).toString(),
        if (totalArea != null) 'totalArea': totalArea.toString(),
        if (_buildingDetails['year'] != null)
          'constructionYear': _buildingDetails['year']!,
      },
    );
  }

  void _handleSkip() {
    // Navigate back to the previous page (skip this step)
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleEditAddress() {
    // Navigate back to address selection page
    if (context.canPop()) {
      context.pop();
    }
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
                SetBuildingDetailsWidget(
                  userName: widget.userName,
                  buildingAddress: widget.buildingAddress,
                  onLanguageChanged: _handleLanguageChanged,
                  onBuildingDetailsChanged: _handleBuildingDetailsChanged,
                  onBack: _handleBack,
                  onContinue: _handleContinue,
                  onSkip: _handleSkip,
                  onEditAddress: _handleEditAddress,
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
}
