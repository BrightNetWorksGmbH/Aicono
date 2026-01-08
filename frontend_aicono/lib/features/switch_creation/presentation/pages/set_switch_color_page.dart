import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_switch_color_widget.dart';

class SetSwitchColorPage extends StatefulWidget {
  final String? userName;

  const SetSwitchColorPage({super.key, this.userName});

  @override
  State<SetSwitchColorPage> createState() => _SetSwitchColorPageState();
}

class _SetSwitchColorPageState extends State<SetSwitchColorPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleChangeColor() {
    // TODO: implement real color picker integration
  }

  void _handleSkip() {
    context.pushNamed(
      Routelists.setPersonalizedLook,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
      },
    );
  }

  void _handleContinue() {
    context.pushNamed(
      Routelists.setPersonalizedLook,
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
                SetSwitchColorWidget(
                  userName: widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onChangeColor: _handleChangeColor,
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
