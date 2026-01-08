import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/add_property_name_widget.dart';

class AddPropertyNamePage extends StatefulWidget {
  final String? userName;

  const AddPropertyNamePage({super.key, this.userName});

  @override
  State<AddPropertyNamePage> createState() => _AddPropertyNamePageState();
}

class _AddPropertyNamePageState extends State<AddPropertyNamePage> {
  String? _propertyName;

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handlePropertyNameChanged(String value) {
    setState(() {
      _propertyName = value.trim().isEmpty ? null : value.trim();
    });
  }

  void _handleSkip() {
    // TODO: navigate to next step or skip property setup
    context.pushNamed(Routelists.floorPlanEditor);
  }

  void _handleContinue() {
    // Navigate to add property location page
    context.pushNamed(
      Routelists.addPropertyLocation,
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
                AddPropertyNameWidget(
                  userName: widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onPropertyNameChanged: _handlePropertyNameChanged,
                  onBack: _handleBack,
                  onSkip: _handleSkip,
                  onContinue: _propertyName != null ? _handleContinue : null,
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

