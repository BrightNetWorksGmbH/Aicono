import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_buildings_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/additional_building_list_widget.dart';

class AdditionalBuildingListPage extends StatefulWidget {
  final String? userName;
  final String? siteId;

  const AdditionalBuildingListPage({super.key, this.userName, this.siteId});

  @override
  State<AdditionalBuildingListPage> createState() =>
      _AdditionalBuildingListPageState();
}

class _AdditionalBuildingListPageState
    extends State<AdditionalBuildingListPage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleAddBuildingDetails(BuildingData building) {
    // Store buildingId in PropertySetupCubit for global access
    final propertyCubit = sl<PropertySetupCubit>();
    propertyCubit.setBuildingId(building.id);

    // Navigate to building details page with building information
    // context.pushNamed(
    //   Routelists.setBuildingDetails,
    //   queryParameters: {
    //     if (widget.userName != null) 'userName': widget.userName!,
    //     'buildingId': building.id,
    //     'buildingName': building.name,
    //   },
    // );
    // // Navigate to Loxone connection page first
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
    context.pushNamed(Routelists.addPropertyName);
  }

  void _handleContinue(BuildContext blocContext) {
    // Get switchId from localStorage (similar to verseId in top_part.dart)
    final localStorage = sl<LocalStorage>();
    final saved = localStorage.getSelectedSwitchId();

    // Fallback to PropertySetupCubit if not in localStorage
    final propertyCubit = sl<PropertySetupCubit>();
    final switchId = saved ?? propertyCubit.state.switchId;

    if (switchId != null && switchId.isNotEmpty) {
      // Navigate directly to add-property page with switchId
      context.goNamed(
        Routelists.addProperties,
        queryParameters: {'switchId': switchId},
      );
    } else {
      // Fallback: show error if switchId not available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switch ID not found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        BlocProvider(
          create: (context) {
            final bloc = sl<GetBuildingsBloc>();
            // Fetch buildings data when bloc is created
            if (widget.siteId != null && widget.siteId!.isNotEmpty) {
              bloc.add(GetBuildingsRequested(siteId: widget.siteId!));
            }
            return bloc;
          },
        ),
      ],
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
              child: Column(
                children: [
                  BlocProvider.value(
                    value: sl<PropertySetupCubit>(),
                    child: AdditionalBuildingListWidget(
                      userName: widget.userName,
                      siteId: widget.siteId,
                      onLanguageChanged: _handleLanguageChanged,
                      onBack: _handleBack,
                      onSkip: _handleSkip,
                      onContinue: _handleContinue,
                      onAddBuildingDetails: _handleAddBuildingDetails,
                    ),
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
      ),
    );
  }
}
