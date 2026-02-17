import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/Building/presentation/widgets/add_floor_name_widget.dart';

class AddFloorNamePage extends StatefulWidget {
  final String? userName;
  final String? switchId;
  final String? floorName;
  final String? siteId;
  final String? buildingId;
  final String? fromDashboard;

  const AddFloorNamePage({
    super.key,
    this.userName,
    this.switchId,
    this.floorName,
    this.siteId,
    this.buildingId,
    this.fromDashboard,
  });

  @override
  State<AddFloorNamePage> createState() => _AddFloorNamePageState();
}

class _AddFloorNamePageState extends State<AddFloorNamePage> {
  String? _floorName;

  @override
  void initState() {
    super.initState();
    // Initialize with floor name from previous page if available
    if (widget.floorName != null && widget.floorName!.isNotEmpty) {
      _floorName = widget.floorName;
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleFloorNameChanged(String value) {
    setState(() {
      _floorName = value.trim().isEmpty ? null : value.trim();
    });
  }

  void _handleSkip() {
    // Navigate to floor management page without floor name
    if (widget.buildingId != null && widget.buildingId!.isNotEmpty &&
        widget.siteId != null && widget.siteId!.isNotEmpty) {
      context.pushNamed(
        Routelists.buildingFloorManagement,
        queryParameters: {
          if (widget.userName != null) 'userName': widget.userName!,
          if (widget.switchId != null) 'switchId': widget.switchId!,
          'siteId': widget.siteId!,
          'buildingId': widget.buildingId!,
          if (widget.fromDashboard != null) 'fromDashboard': widget.fromDashboard!,
        },
      );
    }
  }

  void _handleContinue() {
    if (_floorName != null && _floorName!.isNotEmpty) {
      // Navigate to floor management page with floor name
      if (widget.buildingId != null && widget.buildingId!.isNotEmpty &&
          widget.siteId != null && widget.siteId!.isNotEmpty) {
        context.pushNamed(
          Routelists.buildingFloorManagement,
          queryParameters: {
            if (widget.userName != null) 'userName': widget.userName!,
            if (widget.switchId != null) 'switchId': widget.switchId!,
            'siteId': widget.siteId!,
            'buildingId': widget.buildingId!,
            'floorName': _floorName!,
            if (widget.fromDashboard != null) 'fromDashboard': widget.fromDashboard!,
          },
        );
      }
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
                AddFloorNameWidget(
                  userName: widget.userName,
                  initialFloorName: widget.floorName,
                  onLanguageChanged: _handleLanguageChanged,
                  onFloorNameChanged: _handleFloorNameChanged,
                  onBack: _handleBack,
                  onSkip: _handleSkip,
                  onContinue: _floorName != null
                      ? _handleContinue
                      : null,
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

