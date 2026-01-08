import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_switch_image_widget.dart';

class SetSwitchImagePage extends StatefulWidget {
  final String? userName;
  final String? organizationName;

  const SetSwitchImagePage({super.key, this.userName, this.organizationName});

  @override
  State<SetSwitchImagePage> createState() => _SetSwitchImagePageState();
}

class _SetSwitchImagePageState extends State<SetSwitchImagePage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleImageSelected(File? image) {
    // Handle image selection if needed
    // Currently not used but kept for future integration
  }

  void _handleContinue() {
    // Navigate to set switch color page, passing userName for personalization
    context.pushNamed(
      Routelists.setSwitchColor,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
      },
    );
  }

  void _handleVerseChange() {
    // TODO: implement verse change functionality
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
                SetSwitchImageWidget(
                  userName: widget.userName,
                  organizationName: widget.organizationName,
                  onLanguageChanged: _handleLanguageChanged,
                  onImageSelected: _handleImageSelected,
                  onBack: _handleBack,
                  onContinue: _handleContinue,
                  onVerseChange: _handleVerseChange,
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
