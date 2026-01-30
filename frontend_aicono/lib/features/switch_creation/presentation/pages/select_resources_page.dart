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
import 'package:frontend_aicono/features/switch_creation/presentation/widget/select_resources_widget.dart';

class SelectResourcesPage extends StatefulWidget {
  final String? userName;
  final String? switchId;

  const SelectResourcesPage({super.key, this.userName, this.switchId});

  @override
  State<SelectResourcesPage> createState() => _SelectResourcesPageState();
}

class _SelectResourcesPageState extends State<SelectResourcesPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleSkip() {
    // TODO: navigate to next step or skip resource selection
    context.pushNamed(Routelists.additionalBuildingList);
  }

  void _handleContinue(BuildContext blocContext) {
    // Get data from PropertySetupCubit
    final propertyCubit = sl<PropertySetupCubit>();
    final propertyName = propertyCubit.state.propertyName;
    final location = propertyCubit.state.location;
    final resourceTypes = propertyCubit.state.resourceTypes;

    // Validate required fields
    if (propertyName == null || propertyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Property name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (location == null || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.switchId == null || widget.switchId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switch ID is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Map resource types to resource_type string
    // Join resource types with comma, or use "Commercial" as default if empty
    final resourceType = resourceTypes.isNotEmpty
        ? resourceTypes.join(', ')
        : 'Commercial';

    // Create request
    final request = CreateSiteRequest(
      name: propertyName,
      address: location,
      resourceType: resourceType,
    );

    // Dispatch event to create site using the bloc context
    blocContext.read<CreateSiteBloc>().add(
      CreateSiteSubmitted(switchId: widget.switchId!, request: request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<PropertySetupCubit>()),
        BlocProvider(create: (context) => sl<CreateSiteBloc>()),
      ],
      child: BlocListener<CreateSiteBloc, CreateSiteState>(
        listener: (context, state) {
          if (state is CreateSiteSuccess) {
            // Extract site ID from response
            final siteId = state.response.data?.id;

            if (siteId == null || siteId.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to get site ID from response'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }

            // Store siteId in PropertySetupCubit for use across pages
            final propertyCubit = sl<PropertySetupCubit>();
            propertyCubit.setSiteId(siteId);

            // Navigate to add additional buildings page on success with site ID
            if (mounted) {
              context.pushNamed(
                Routelists.addAdditionalBuildings,
                queryParameters: {
                  if (widget.userName != null) 'userName': widget.userName!,
                  'siteId': siteId,
                },
              );
            }
          } else if (state is CreateSiteFailure) {
            // Show error message
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
                        SelectResourcesWidget(
                          userName: widget.userName,
                          onLanguageChanged: _handleLanguageChanged,
                          onBack: _handleBack,
                          onSkip: _handleSkip,
                          onContinue: () => _handleContinue(blocContext),
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
