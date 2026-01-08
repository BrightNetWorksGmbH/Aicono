import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_personalize_look_widget.dart';

class SetPersonalizedLookPage extends StatefulWidget {
  final String? userName;

  const SetPersonalizedLookPage({super.key, this.userName});

  @override
  State<SetPersonalizedLookPage> createState() =>
      _SetPersonalizedLookPageState();
}

class _SetPersonalizedLookPageState extends State<SetPersonalizedLookPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleContinue() {
    // Navigate to structure switch page
    context.pushNamed(
      Routelists.structureSwitch,
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
                SetPersonalizeLookWidget(
                  userName: widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onBack: _handleBack,
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
