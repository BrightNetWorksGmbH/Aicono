import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_switch_name_widget.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';

class SetSwitchNamePage extends StatefulWidget {
  final String? userName;
  final String? organizationName;
  final InvitationEntity? invitation;

  const SetSwitchNamePage({
    super.key,
    this.userName,
    this.organizationName,
    this.invitation,
  });

  @override
  State<SetSwitchNamePage> createState() => _SetSwitchNamePageState();
}

class _SetSwitchNamePageState extends State<SetSwitchNamePage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleSwitchNameChanged(String value) {
    // Handle switch name changes if needed
    // Currently not used but kept for future integration
  }

  void _handleContinue() {
    // Navigate to set switch image page, passing userName and organizationName
    context.pushNamed(
      Routelists.setSwitchImage,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.organizationName != null)
          'organizationName': widget.organizationName!,
      },
    );
  }

  void _handleEdit() {
    // Navigate back to set organization name page
    context.pop();
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
                SetSwitchNameWidget(
                  userName: widget.userName,
                  organizationName: widget.organizationName,
                  onLanguageChanged: _handleLanguageChanged,
                  onSwitchNameChanged: _handleSwitchNameChanged,
                  onBack: _handleBack,
                  onContinue: _handleContinue,
                  onEdit: _handleEdit,
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
