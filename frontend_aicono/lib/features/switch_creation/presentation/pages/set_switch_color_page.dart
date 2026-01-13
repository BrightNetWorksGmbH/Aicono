import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_switch_color_widget.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/switch_creation_cubit.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';

class SetSwitchColorPage extends StatefulWidget {
  final String? userName;
  final InvitationEntity? invitation;

  const SetSwitchColorPage({
    super.key,
    this.userName,
    this.invitation,
  });

  @override
  State<SetSwitchColorPage> createState() => _SetSwitchColorPageState();
}

class _SetSwitchColorPageState extends State<SetSwitchColorPage> {
  Color _primaryColor = const Color(0xFF0095A5);
  String _colorHex = '#0095A5';
  String _colorName = '';

  @override
  void initState() {
    super.initState();
    // Initialize from invitation if available
    if (widget.invitation != null) {
      final cubit = sl<SwitchCreationCubit>();
      cubit.initializeFromInvitation(
        organizationName: widget.invitation!.organizationName,
        subDomain: widget.invitation!.subDomain,
      );
      // Load existing color if available (would need to be parsed from invitation)
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

  void _handleColorChanged(Color color, String colorHex) {
    setState(() {
      _primaryColor = color;
      _colorHex = colorHex;
    });
    // Store in cubit
    sl<SwitchCreationCubit>().setPrimaryColor(colorHex);
  }

  void _handleColorNameChanged(String colorName) {
    setState(() {
      _colorName = colorName;
    });
    // Store in cubit
    sl<SwitchCreationCubit>().setColorName(colorName);
  }

  void _handleSkip() {
    context.pushNamed(
      Routelists.setPersonalizedLook,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.invitation != null) 'token': widget.invitation!.token,
      },
      extra: widget.invitation,
    );
  }

  void _handleContinue() {
    context.pushNamed(
      Routelists.setPersonalizedLook,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.invitation != null) 'token': widget.invitation!.token,
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
                SetSwitchColorWidget(
                  userName: widget.userName,
                  primaryColor: _primaryColor,
                  colorHex: _colorHex,
                  colorName: _colorName,
                  onLanguageChanged: _handleLanguageChanged,
                  onColorChanged: _handleColorChanged,
                  onColorNameChanged: _handleColorNameChanged,
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
