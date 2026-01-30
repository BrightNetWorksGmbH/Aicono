import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/add_properties_widget.dart';

class AddPropertiesPage extends StatefulWidget {
  final String? userName;
  final String? switchId;
  final bool isSingleProperty;

  const AddPropertiesPage({
    super.key,
    this.userName,
    this.switchId,
    required this.isSingleProperty,
  });

  @override
  State<AddPropertiesPage> createState() => _AddPropertiesPageState();
}

class _AddPropertiesPageState extends State<AddPropertiesPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleAddPropertyDetails(String propertyName) {
    // Navigate to add property name page (same as select_property_type_page)
    context.pushNamed(
      Routelists.addPropertyName,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.switchId != null) 'switchId': widget.switchId!,
        'isSingleProperty': widget.isSingleProperty.toString(),
        'propertyName': propertyName,
      },
    );
  }

  void _handleGoToHome() {
    // Navigate to dashboard/home page
    context.goNamed(Routelists.dashboard);
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
                AddPropertiesWidget(
                  userName: widget.userName,
                  isSingleProperty: widget.isSingleProperty,
                  onLanguageChanged: _handleLanguageChanged,
                  onBack: _handleBack,
                  onAddPropertyDetails: _handleAddPropertyDetails,
                  onGoToHome: _handleGoToHome,
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

