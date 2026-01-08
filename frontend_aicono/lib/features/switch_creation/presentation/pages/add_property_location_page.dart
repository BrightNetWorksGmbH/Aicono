import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/add_property_location_widget.dart';

class AddPropertyLocationPage extends StatefulWidget {
  final String? userName;

  const AddPropertyLocationPage({super.key, this.userName});

  @override
  State<AddPropertyLocationPage> createState() =>
      _AddPropertyLocationPageState();
}

class _AddPropertyLocationPageState extends State<AddPropertyLocationPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleLocationSelected(String value) {
    // Handle location selection if needed
    // Currently not used but kept for future integration
  }

  void _handleSkip() {
    // TODO: navigate to next step or skip location setup
    context.pushNamed(Routelists.floorPlanEditor);
  }

  void _handleContinue() {
    // Navigate to select resources page
    context.pushNamed(
      Routelists.selectResources,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
      },
    );
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
                AddPropertyLocationWidget(
                  userName: widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onLocationSelected: _handleLocationSelected,
                  onBack: _handleBack,
                  onSkip: _handleSkip,
                  onContinue: _handleContinue,
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

