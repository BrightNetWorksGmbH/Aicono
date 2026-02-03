import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/confirm_structure_widget.dart';

import '../../../../core/injection_container.dart';
import '../../../../core/storage/local_storage.dart';

class ConfirmStructurePage extends StatefulWidget {
  final String? userName;
  final String? switchId;

  const ConfirmStructurePage({super.key, this.userName, this.switchId});

  @override
  State<ConfirmStructurePage> createState() => _ConfirmStructurePageState();
}

class _ConfirmStructurePageState extends State<ConfirmStructurePage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleSkip() {
    // TODO: navigate to switchboard/dashboard directly (skip structure setup)
    context.pushNamed(Routelists.floorPlanEditor);
  }

  void _handleFindStructure() async {
    // Navigate to select property type page
    final localStorage = sl<LocalStorage>();
    await localStorage.setSelectedVerseId(widget.switchId!);
    context.pushNamed(
      Routelists.selectPropertyType,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.switchId != null) 'switchId': widget.switchId!,
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
                ConfirmStructureWidget(
                  userName: widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onBack: _handleBack,
                  onSkip: _handleSkip,
                  onFindStructure: _handleFindStructure,
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
