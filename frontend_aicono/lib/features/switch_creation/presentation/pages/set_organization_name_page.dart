import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_organization_name_widget.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/switch_creation_cubit.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';

class SetOrganizationNamePage extends StatefulWidget {
  final String? userName;
  final InvitationEntity? invitation;

  const SetOrganizationNamePage({
    super.key,
    this.userName,
    this.invitation,
  });

  @override
  State<SetOrganizationNamePage> createState() =>
      _SetOrganizationNamePageState();
}

class _SetOrganizationNamePageState extends State<SetOrganizationNamePage> {
  String? _organizationName;

  @override
  void initState() {
    super.initState();
    final cubit = sl<SwitchCreationCubit>();
    // Initialize bloc from invitation if available
    if (widget.invitation != null) {
      cubit.initializeFromInvitation(
        organizationName: widget.invitation!.organizationName,
        subDomain: widget.invitation!.subDomain,
      );
      if (widget.invitation!.organizationName != null &&
          widget.invitation!.organizationName!.isNotEmpty) {
        _organizationName = widget.invitation!.organizationName;
      }
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

  void _handleNameChanged(String value) {
    setState(() {
      _organizationName = value.trim().isEmpty ? null : value.trim();
    });
    // Update bloc
    if (_organizationName != null) {
      sl<SwitchCreationCubit>().setOrganizationName(_organizationName!);
    }
  }

  void _handleContinue() {
    // Update bloc with organization name
    if (_organizationName != null) {
      sl<SwitchCreationCubit>().setOrganizationName(_organizationName!);
    }
    // Navigate to set switch name page, passing userName and organizationName
    context.pushNamed(
      Routelists.setSwitchName,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (_organizationName != null) 'organizationName': _organizationName!,
      },
      extra: widget.invitation,
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
                  initialOrganizationName: widget.invitation?.organizationName,
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
