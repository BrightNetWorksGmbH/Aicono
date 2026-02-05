import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_buildings_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/additional_building_list_widget.dart';

class AdditionalBuildingListPage extends StatefulWidget {
  final String? userName;
  final String? siteId;
  final String? switchId;

  const AdditionalBuildingListPage({
    super.key,
    this.userName,
    this.siteId,
    this.switchId,
  });

  @override
  State<AdditionalBuildingListPage> createState() =>
      _AdditionalBuildingListPageState();
}

class _AdditionalBuildingListPageState
    extends State<AdditionalBuildingListPage> {
  String? currentSwitchId;

  @override
  void initState() {
    super.initState();
    _loadSwitchData();
  }

  Future<void> _loadSwitchData() async {
    try {
      final authService = sl<AuthService>();
      final localStorage = sl<LocalStorage>();

      // Refresh profile from server to get latest data
      print('AdditionalBuildingList: Refreshing user profile from server...');
      final profileResult = await authService.refreshProfile();

      await profileResult.fold(
        (failure) async {
          // If profile refresh fails, fall back to cached user data
          print(
            'AdditionalBuildingList: Profile refresh failed, using cached data: ${failure.message}',
          );
          final loginRepository = sl<LoginRepository>();
          final userResult = await loginRepository.getCurrentUser();

          userResult.fold((failure) {
            // Handle error
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load user: ${failure.message}'),
                ),
              );
            }
          }, (user) => _processUserSwitchData(user, localStorage));
        },
        (user) async {
          // Profile refreshed successfully
          print(
            'AdditionalBuildingList: Profile refreshed. Switches: ${user.roles.map((r) => r.bryteswitchId).toList()}',
          );
          _processUserSwitchData(user, localStorage);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading switch data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _processUserSwitchData(User? user, LocalStorage localStorage) async {
    if (user == null) {
      // No user - should not happen but handle gracefully
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    if (user.joinedVerse.isNotEmpty) {
      // User has verses - proceed normally
      String? initialVerseId;

      // Priority order: passed verseId > saved verseId > first verse
      if (widget.switchId != null &&
          user.joinedVerse.contains(widget.switchId)) {
        // Use the passed verseId if user has access to it
        initialVerseId = widget.switchId;
        print('Dashboard: Using passed verseId: $initialVerseId');
        localStorage.setSelectedVerseId(initialVerseId!);
      } else {
        // await localStorage.setSelectedVerseId(user.joinedVerse.first);
        // Fall back to saved or first verse
        final saved = localStorage.getSelectedVerseId();
        initialVerseId = (saved != null)
            // && user.joinedVerse.contains(saved))
            ? saved
            : user.joinedVerse.first;
        print('Dashboard: Using fallback verseId: $initialVerseId');
      }

      setState(() {
        currentSwitchId = initialVerseId;
      });
    } else {
      // No joined verses - redirect to login
      print('Dashboard: User has no verses, redirecting...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('dashboard.error.no_verses_available'.tr()),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        // Redirect to login after showing message
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go('/login');
          }
        });
      }
      setState(() {
        currentSwitchId = null;
      });
    }
  }

  void _processUserData(User? user, LocalStorage localStorage) {
    if (user == null) {
      // No user - should not happen but handle gracefully
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    // Get switchIds from user roles
    final switchIds = user.roles
        .map((r) => r.bryteswitchId)
        .where((id) => id.isNotEmpty)
        .toList();

    if (switchIds.isNotEmpty) {
      // User has switches - proceed normally
      String? initialSwitchId;

      // Priority order: passed switchId > saved switchId > first switch
      if (widget.switchId != null && switchIds.contains(widget.switchId)) {
        // Use the passed switchId if user has access to it
        initialSwitchId = widget.switchId;
        print(
          'AdditionalBuildingList: Using passed switchId: $initialSwitchId',
        );
        localStorage.setSelectedSwitchId(initialSwitchId!);
      } else {
        // Fall back to saved or first switch
        final saved = localStorage.getSelectedSwitchId();
        initialSwitchId = (saved != null && switchIds.contains(saved))
            ? saved
            : switchIds.first;
        print(
          'AdditionalBuildingList: Using fallback switchId: $initialSwitchId',
        );
      }

      setState(() {
        currentSwitchId = initialSwitchId;
      });
    } else {
      // No switches - redirect to login
      print('AdditionalBuildingList: User has no switches, redirecting...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No switches available. Please login again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        // Redirect to login after showing message
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go('/login');
          }
        });
      }
      setState(() {
        currentSwitchId = null;
      });
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

  void _handleAddBuildingDetails(BuildingData building) async {
    // Store buildingId in PropertySetupCubit for global access
    final propertyCubit = sl<PropertySetupCubit>();
    propertyCubit.setBuildingId(building.id);
    final localStorage = sl<LocalStorage>();
    await localStorage.setSelectedBuildingId(building.id);

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
        'siteId': widget.siteId!,
        'buildingAddress': building.name,
        'redirectTo':
            'setBuildingDetails', // Flag to redirect to setBuildingDetails after connection
      },
    );
  }

  void _handleSkip() {
    // TODO: navigate to next step or skip
    context.pushNamed(Routelists.dashboard);
  }

  void _handleContinue(BuildContext blocContext) {
    // Use the processed switchId from initState
    final switchId = currentSwitchId;

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
