import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_switch_name_widget.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/switch_creation_cubit.dart';
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
  String? _subDomain;

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
      if (widget.invitation!.subDomain != null &&
          widget.invitation!.subDomain!.isNotEmpty) {
        _subDomain = widget.invitation!.subDomain;
      }
    }
    // If no subdomain from invitation, check cubit state
    if (_subDomain == null || _subDomain!.isEmpty) {
      _subDomain = cubit.state.subDomain;
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

  void _handleSubDomainChanged(String value) {
    setState(() {
      _subDomain = value.trim().isEmpty ? null : value.trim();
    });
    // Update cubit with subdomain
    if (_subDomain != null && _subDomain!.isNotEmpty) {
      sl<SwitchCreationCubit>().setSubDomain(_subDomain!);
    }
  }

  void _handleContinue() {
    // Update cubit with subdomain before navigating
    if (_subDomain != null && _subDomain!.isNotEmpty) {
      sl<SwitchCreationCubit>().setSubDomain(_subDomain!);
    }
    // Navigate to set switch image page, passing userName, organizationName, and token
    context.pushNamed(
      Routelists.setSwitchImage,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.organizationName != null)
          'organizationName': widget.organizationName!,
        if (widget.invitation != null) 'token': widget.invitation!.token,
      },
      extra: widget.invitation,
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
                  initialSubDomain: _subDomain ?? widget.invitation?.subDomain,
                  onLanguageChanged: _handleLanguageChanged,
                  onSubDomainChanged: _handleSubDomainChanged,
                  onBack: _handleBack,
                  onContinue: _subDomain != null && _subDomain!.isNotEmpty
                      ? _handleContinue
                      : null,
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
