import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_site_bloc.dart';
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
  List<Map<String, dynamic>> _createdSites = [];
  bool _isLoadingSites = false;

  @override
  void initState() {
    super.initState();
    // Fetch existing sites on page load
    _fetchSites();
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleAddPropertyDetails(Map<String, String> data) {
    // Navigate to add property name page with siteId for updating
    // Pass ONLY siteId, not switchId when navigating to single site
    context.pushNamed(
      Routelists.addPropertyName,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        'isSingleProperty': widget.isSingleProperty.toString(),
        'propertyName': data['propertyName'],
        'siteId': data['siteId'],
      },
    );
  }

  void _handleGoToHome() {
    // Navigate to dashboard/home page
    context.goNamed(Routelists.dashboard);
  }

  void _handleConfirmProperties(
    BuildContext blocContext,
    List<String> propertyNames,
  ) {
    if (widget.switchId == null || widget.switchId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switch ID is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create sites for each property
    final createSiteBloc = blocContext.read<CreateSiteBloc>();

    // Create sites sequentially
    _createSitesSequentially(createSiteBloc, propertyNames, 0, []);
  }

  Future<void> _createSitesSequentially(
    CreateSiteBloc createSiteBloc,
    List<String> propertyNames,
    int index,
    List<String> createdSiteIds,
  ) async {
    // Base case: All sites created, now fetch them to refresh the page with IDs
    if (index >= propertyNames.length) {
      // Wait a bit to ensure backend has processed all creations
      await Future.delayed(const Duration(milliseconds: 500));
      // Fetch sites to refresh the page with backend IDs
      await _fetchSites(showSuccessMessage: true);
      return;
    }

    final propertyName = propertyNames[index];
    final request = CreateSiteRequest(
      name: propertyName,
      address: '', // You may want to get address from user or use a default
      resourceType: 'Commercial', // Default or get from user
    );

    // Create a completer to wait for the site creation
    final completer = Completer<void>();
    late StreamSubscription subscription;

    subscription = createSiteBloc.stream.listen((state) {
      if (state is CreateSiteSuccess) {
        if (!completer.isCompleted) {
          createdSiteIds.add(state.response.data?.id ?? '');
          completer.complete();
        }
      } else if (state is CreateSiteFailure) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    createSiteBloc.add(
      CreateSiteSubmitted(switchId: widget.switchId!, request: request),
    );

    // Wait for the current site to be created
    await completer.future;
    subscription.cancel();

    // Continue with next site
    _createSitesSequentially(
      createSiteBloc,
      propertyNames,
      index + 1,
      createdSiteIds,
    );
  }

  Future<void> _fetchSites({bool showSuccessMessage = false}) async {
    if (widget.switchId == null || widget.switchId!.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingSites = true;
    });

    try {
      // Direct API call to get all sites
      final dioClient = sl<DioClient>();
      final response = await dioClient.get(
        '/api/v1/sites/bryteswitch/${widget.switchId}',
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        final sites = responseData['data'] as List<dynamic>? ?? [];

        setState(() {
          _createdSites = sites
              .map((site) => site as Map<String, dynamic>)
              .toList();
          _isLoadingSites = false;
        });

        if (mounted && showSuccessMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully created and fetched ${sites.length} site(s)',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingSites = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching sites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return MultiBlocProvider(
      providers: [BlocProvider(create: (context) => sl<CreateSiteBloc>())],
      child: BlocListener<CreateSiteBloc, CreateSiteState>(
        listener: (context, state) {
          if (state is CreateSiteFailure) {
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
                        AddPropertiesWidget(
                          userName: widget.userName,
                          switchId: widget.switchId,
                          isSingleProperty: widget.isSingleProperty,
                          createdSites: _createdSites,
                          isLoadingSites: _isLoadingSites,
                          onLanguageChanged: _handleLanguageChanged,
                          onBack: _handleBack,
                          onAddPropertyDetails: _handleAddPropertyDetails,
                          onGoToHome: _handleGoToHome,
                          onConfirmProperties: (propertyNames) =>
                              _handleConfirmProperties(
                                blocContext,
                                propertyNames,
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
              );
            },
          ),
        ),
      ),
    );
  }
}
