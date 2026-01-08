import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/select_resources_widget.dart';

class SelectResourcesPage extends StatefulWidget {
  final String? userName;

  const SelectResourcesPage({super.key, this.userName});

  @override
  State<SelectResourcesPage> createState() => _SelectResourcesPageState();
}

class _SelectResourcesPageState extends State<SelectResourcesPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleResourcesChanged(List<String> resources) {
    // Handle resources selection if needed
    // Currently not used but kept for future integration
  }

  void _handleSkip() {
    // TODO: navigate to next step or skip resource selection
    context.pushNamed(Routelists.floorPlanEditor);
  }

  void _handleContinue() {
    // Navigate to add additional buildings page
    context.pushNamed(
      Routelists.addAdditionalBuildings,
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
                SelectResourcesWidget(
                  userName: widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onResourcesChanged: _handleResourcesChanged,
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

