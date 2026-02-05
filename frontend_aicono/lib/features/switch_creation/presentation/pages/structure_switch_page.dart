import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/structure_switch_widget.dart';

class StructureSwitchPage extends StatefulWidget {
  final String? userName;
  final String? switchId;

  const StructureSwitchPage({super.key, this.userName, this.switchId});

  @override
  State<StructureSwitchPage> createState() => _StructureSwitchPageState();
}

class _StructureSwitchPageState extends State<StructureSwitchPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleStartDirectly() {
    context.pushNamed(Routelists.dashboard);
    // TODO: navigate to switchboard/dashboard directly
    // context.pushNamed(Routelists.floorPlanEditor);
  }

  void _handleFindStructure() {
    // Navigate to confirm structure page
    context.pushNamed(
      Routelists.confirmStructure,
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
                StructureSwitchWidget(
                  userName: widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onStartDirectly: _handleStartDirectly,
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
