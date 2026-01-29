import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_buildings_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/add_additional_buildings_widget.dart'
    show AddAdditionalBuildingsWidget, BuildingItem;

class AddAdditionalBuildingsPage extends StatefulWidget {
  final String? userName;
  final String? siteId;

  const AddAdditionalBuildingsPage({super.key, this.userName, this.siteId});

  @override
  State<AddAdditionalBuildingsPage> createState() =>
      _AddAdditionalBuildingsPageState();
}

class _AddAdditionalBuildingsPageState
    extends State<AddAdditionalBuildingsPage> {
  List<BuildingItem> _buildings = [];

  @override
  void initState() {
    super.initState();
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleHasAdditionalBuildingsChanged(bool value) {
    // Handle yes/no selection if needed
  }

  void _handleBuildingsChanged(List<BuildingItem> buildings) {
    setState(() {
      _buildings = buildings;
    });
  }

  void _handleAddBuildingDetails(BuildingItem building) {
    // Navigate to Loxone connection page first
    context.pushNamed(
      Routelists.loxoneConnection,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        'buildingId': building.id,
        'buildingAddress': building.name,
        'redirectTo':
            'setBuildingDetails', // Flag to redirect to setBuildingDetails after connection
      },
    );
  }

  void _handleSkip() {
    // TODO: navigate to next step or skip
    context.pushNamed(Routelists.floorPlanEditor);
  }

  void _handleContinue(BuildContext blocContext) {
    // Validate siteId
    if (widget.siteId == null || widget.siteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Site ID is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Collect building names from buildings list
    final buildingNames = _buildings
        .map((building) => building.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (buildingNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one building name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create request
    final request = CreateBuildingsRequest(buildingNames: buildingNames);

    // Dispatch event to create buildings
    blocContext.read<CreateBuildingsBloc>().add(
      CreateBuildingsSubmitted(siteId: widget.siteId!, request: request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<PropertySetupCubit>()),
        BlocProvider(
          create: (context) {
            final bloc = sl<GetSiteBloc>();
            // Fetch site data when bloc is created
            if (widget.siteId != null && widget.siteId!.isNotEmpty) {
              bloc.add(GetSiteRequested(siteId: widget.siteId!));
            }
            return bloc;
          },
        ),
        BlocProvider(create: (context) => sl<CreateBuildingsBloc>()),
      ],
      child: BlocListener<CreateBuildingsBloc, CreateBuildingsState>(
        listener: (context, state) {
          if (state is CreateBuildingsSuccess) {
            // Navigate to additional building list page on success
            if (mounted) {
              context.pushNamed(
                Routelists.additionalBuildingList,
                queryParameters: {
                  if (widget.userName != null) 'userName': widget.userName!,
                  if (widget.siteId != null) 'siteId': widget.siteId!,
                },
              );
            }
          } else if (state is CreateBuildingsFailure) {
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
                child: Builder(
                  builder: (blocContext) {
                    return Column(
                      children: [
                        BlocProvider.value(
                          value: sl<PropertySetupCubit>(),
                          child: AddAdditionalBuildingsWidget(
                            userName: widget.userName,
                            siteId: widget.siteId,
                            onLanguageChanged: _handleLanguageChanged,
                            onHasAdditionalBuildingsChanged:
                                _handleHasAdditionalBuildingsChanged,
                            onBuildingsChanged: _handleBuildingsChanged,
                            onBack: _handleBack,
                            onSkip: _handleSkip,
                            onContinue: () => _handleContinue(blocContext),
                            onAddBuildingDetails: _handleAddBuildingDetails,
                          ),
                        ),
                        AppFooter(
                          onLanguageChanged: _handleLanguageChanged,
                          containerWidth: screenSize.width,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
