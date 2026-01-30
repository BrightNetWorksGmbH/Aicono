import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/select_property_type_widget.dart';

class SelectPropertyTypePage extends StatefulWidget {
  final String? userName;
  final String? switchId;

  const SelectPropertyTypePage({super.key, this.userName, this.switchId});

  @override
  State<SelectPropertyTypePage> createState() => _SelectPropertyTypePageState();
}

class _SelectPropertyTypePageState extends State<SelectPropertyTypePage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleContinue(bool isSingleProperty) {
    // Navigate to add properties page
    context.pushNamed(
      Routelists.addProperties,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.switchId != null) 'switchId': widget.switchId!,
        'isSingleProperty': isSingleProperty.toString(),
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
                SelectPropertyTypeWidget(
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
