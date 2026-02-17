import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/select_property_type_widget.dart';

class SelectPropertyTypePage extends StatefulWidget {
  final String? userName;
  final String? switchId;
  final String? siteId;

  const SelectPropertyTypePage({
    super.key,
    this.userName,
    this.switchId,
    this.siteId,
  });

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

  void _handleContinue(BuildContext blocContext, bool isSingleProperty) {
    // If siteId exists, update the site with resource_type
    if (widget.siteId != null && widget.siteId!.isNotEmpty) {
      final propertyCubit = sl<PropertySetupCubit>();
      final propertyName = propertyCubit.state.propertyName ?? '';
      final address = propertyCubit.state.location ?? '';
      final resourceType = propertyCubit.state.resourceTypes.isNotEmpty
          ? propertyCubit.state.resourceTypes.join(', ')
          : 'Commercial';

      final request = CreateSiteRequest(
        name: propertyName,
        address: address,
        resourceType: resourceType,
      );

      final createSiteBloc = blocContext.read<CreateSiteBloc>();
      createSiteBloc.add(
        UpdateSiteSubmitted(siteId: widget.siteId!, request: request),
      );
    } else {
      // Navigate to add properties page (normal flow)
      context.pushNamed(
        Routelists.addProperties,
        queryParameters: {
          if (widget.userName != null) 'userName': widget.userName!,
          if (widget.switchId != null) 'switchId': widget.switchId!,
          'isSingleProperty': isSingleProperty.toString(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocProvider(
      create: (context) => sl<CreateSiteBloc>(),
      child: BlocListener<CreateSiteBloc, CreateSiteState>(
        listener: (context, state) {
          if (state is CreateSiteSuccess) {
            // Site updated successfully, navigate to add properties page
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Site updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              // Navigate to add properties page
              context.pushNamed(
                Routelists.addProperties,
                queryParameters: {
                  if (widget.userName != null) 'userName': widget.userName!,
                  if (widget.switchId != null) 'switchId': widget.switchId!,
                  'isSingleProperty': 'true', // Default, can be adjusted
                },
              );
            }
          } else if (state is CreateSiteFailure) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppTheme.background,
          body: Builder(
            builder: (blocContext) {
              return Center(
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
                          onContinue: (context, isSingleProperty) =>
                              _handleContinue(blocContext, isSingleProperty),
                        ),
                        AppFooter(
                          onLanguageChanged: _handleLanguageChanged,
                          containerWidth: screenSize.width,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
