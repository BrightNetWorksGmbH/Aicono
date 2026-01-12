import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/activate_switchboard_widget.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';

class ActivateSwitchboardPage extends StatefulWidget {
  final String? userName;
  final InvitationEntity? invitation;
  const ActivateSwitchboardPage({
    super.key,
    this.userName,
    this.invitation,
  });

  @override
  State<ActivateSwitchboardPage> createState() =>
      _ActivateSwitchboardPageState();
}

class _ActivateSwitchboardPageState extends State<ActivateSwitchboardPage> {
  void _handleLanguageChanged() {
    // Force rebuild when language changes
    setState(() {});
  }

  void _handleContinue() {
    // Navigate to set organization name page, passing userName if available and invitation
    context.pushNamed(
      Routelists.setOrganizationName,
      queryParameters: widget.userName != null
          ? {'userName': widget.userName!}
          : {},
      extra: widget.invitation,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final Size screenSize = MediaQuery.of(context).size;

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
                ActivateSwitchboardWidget(
                  userName: widget.invitation?.firstName ?? widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
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
