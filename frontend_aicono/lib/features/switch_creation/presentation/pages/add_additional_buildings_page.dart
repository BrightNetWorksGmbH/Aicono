import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/add_additional_buildings_widget.dart'
    show AddAdditionalBuildingsWidget, BuildingItem;

class AddAdditionalBuildingsPage extends StatefulWidget {
  final String? userName;

  const AddAdditionalBuildingsPage({super.key, this.userName});

  @override
  State<AddAdditionalBuildingsPage> createState() =>
      _AddAdditionalBuildingsPageState();
}

class _AddAdditionalBuildingsPageState extends State<AddAdditionalBuildingsPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleHasAdditionalBuildingsChanged(bool value) {
    // Handle yes/no selection if needed
  }

  void _handleBuildingsChanged(List<BuildingItem> buildings) {
    // Handle buildings list changes if needed
  }

  void _handleSkip() {
    // TODO: navigate to next step or skip
    context.pushNamed(Routelists.floorPlanEditor);
  }

  void _handleContinue() {
    // TODO: navigate to next step in property setup flow
    context.pushNamed(Routelists.floorPlanEditor);
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
                AddAdditionalBuildingsWidget(
                  userName: widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onHasAdditionalBuildingsChanged: _handleHasAdditionalBuildingsChanged,
                  onBuildingsChanged: _handleBuildingsChanged,
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
