import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/add_property_name_widget.dart';

class AddPropertyNamePage extends StatefulWidget {
  final String? userName;
  final String? switchId;
  final String? propertyName;
  final String? siteId;

  const AddPropertyNamePage({
    super.key,
    this.userName,
    this.switchId,
    this.propertyName,
    this.siteId,
  });

  @override
  State<AddPropertyNamePage> createState() => _AddPropertyNamePageState();
}

class _AddPropertyNamePageState extends State<AddPropertyNamePage> {
  String? _propertyName;

  @override
  void initState() {
    super.initState();
    // Initialize with property name from previous page if available
    if (widget.propertyName != null && widget.propertyName!.isNotEmpty) {
      _propertyName = widget.propertyName;
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

  void _handlePropertyNameChanged(String value) {
    setState(() {
      _propertyName = value.trim().isEmpty ? null : value.trim();
      if (_propertyName != null) {
        sl<PropertySetupCubit>().setPropertyName(_propertyName!);
      }
    });
  }

  void _handleSkip() {
    // TODO: navigate to next step or skip property setup
    context.pushNamed(
      Routelists.addPropertyLocation,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.switchId != null) 'switchId': widget.switchId!,
        if (widget.siteId != null) 'siteId': widget.siteId!,
      },
    );
  }

  void _handleContinue(BuildContext blocContext) {
    if (_propertyName != null && _propertyName!.isNotEmpty) {
      sl<PropertySetupCubit>().setPropertyName(_propertyName!);

      // If siteId exists, update the site
      if (widget.siteId != null && widget.siteId!.isNotEmpty) {
        final propertyCubit = sl<PropertySetupCubit>();
        final address = propertyCubit.state.location ?? '';
        final resourceType = propertyCubit.state.resourceTypes.isNotEmpty
            ? propertyCubit.state.resourceTypes.join(', ')
            : '';

        final request = CreateSiteRequest(
          name: _propertyName!,
          address: address,
          resourceType: resourceType,
        );

        final createSiteBloc = blocContext.read<CreateSiteBloc>();
        createSiteBloc.add(
          UpdateSiteSubmitted(siteId: widget.siteId!, request: request),
        );
      }
      // else {
      //   // Navigate to add property location page (normal flow)
      //   context.pushNamed(
      //     Routelists.addPropertyLocation,
      //     queryParameters: {
      //       if (widget.userName != null) 'userName': widget.userName!,
      //       if (widget.switchId != null) 'switchId': widget.switchId!,

      //     },
      //   );
      // }
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
            // Site updated successfully, navigate to next step
            if (mounted) {
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(
              //     content: Text('Site updated successfully'),
              //     backgroundColor: Colors.green,
              //   ),
              // );
              // Navigate to add property location page with siteId
              context.pushNamed(
                Routelists.addPropertyLocation,
                queryParameters: {
                  if (widget.userName != null) 'userName': widget.userName!,
                  if (widget.switchId != null) 'switchId': widget.switchId!,
                  if (widget.siteId != null) 'siteId': widget.siteId!,
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
                        AddPropertyNameWidget(
                          userName: widget.userName,
                          initialPropertyName: widget.propertyName,
                          onLanguageChanged: _handleLanguageChanged,
                          onPropertyNameChanged: _handlePropertyNameChanged,
                          onBack: _handleBack,
                          onSkip: _handleSkip,
                          onContinue: _propertyName != null
                              ? () => _handleContinue(blocContext)
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
              );
            },
          ),
        ),
      ),
    );
  }
}
