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
import 'package:frontend_aicono/features/switch_creation/presentation/widget/add_property_location_widget.dart';

class AddPropertyLocationPage extends StatefulWidget {
  final String? userName;
  final String? switchId;
  final String? siteId;

  const AddPropertyLocationPage({
    super.key,
    this.userName,
    this.switchId,
    this.siteId,
  });

  @override
  State<AddPropertyLocationPage> createState() =>
      _AddPropertyLocationPageState();
}

class _AddPropertyLocationPageState extends State<AddPropertyLocationPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() => context.pop();

  void _handleSkip() {
    // TODO: navigate to next step or skip location setup
    context.pushNamed(
      Routelists.selectResources,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.switchId != null) 'switchId': widget.switchId!,
        if (widget.siteId != null) 'siteId': widget.siteId!,
      },
    );
  }

  void _handleContinue(BuildContext blocContext) {
    // If siteId exists, update the site with address
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
    }
    // else {
    //   // Navigate to select resources page (normal flow)
    //   context.pushNamed(
    //     Routelists.selectResources,
    //     queryParameters: {
    //       if (widget.userName != null) 'userName': widget.userName!,
    //       if (widget.switchId != null) 'switchId': widget.switchId!,
    //     },
    //   );
    // }
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
            // Site updated successfully, navigate to select resources page
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Site updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              // Navigate to select resources page with siteId for updating
              context.pushNamed(
                Routelists.selectResources,
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
          backgroundColor: AppTheme.primary,
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
                        AddPropertyLocationWidget(
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
