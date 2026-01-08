import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_organization_name_widget.dart';

class SetOrganizationNamePage extends StatefulWidget {
  final String? userName;

  const SetOrganizationNamePage({super.key, this.userName});

  @override
  State<SetOrganizationNamePage> createState() =>
      _SetOrganizationNamePageState();
}

class _SetOrganizationNamePageState extends State<SetOrganizationNamePage> {
  String? _organizationName;

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleNameChanged(String value) {
    setState(() {
      _organizationName = value.trim().isEmpty ? null : value.trim();
    });
  }

  void _handleContinue() {
    // Navigate to set switch name page, passing userName and organizationName
    context.pushNamed(
      Routelists.setSwitchName,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (_organizationName != null) 'organizationName': _organizationName!,
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
                SetOrganizationNameWidget(
                  userName: widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onNameChanged: _handleNameChanged,
                  onBack: _handleBack,
                  onContinue: _organizationName != null
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
