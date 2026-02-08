import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/loxone_connection_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/connect_loxone_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/building_detail_widget/loxone_connection_widget.dart';

class LoxoneConnectionPage extends StatefulWidget {
  final String? userName;
  final String? buildingId;
  final String siteId;
  const LoxoneConnectionPage({
    super.key,
    this.userName,
    required this.buildingId,
    required this.siteId,
  });

  @override
  State<LoxoneConnectionPage> createState() => _LoxoneConnectionPageState();
}

class _LoxoneConnectionPageState extends State<LoxoneConnectionPage> {
  Map<String, dynamic>? _connectionData;
  Map<String, dynamic>? _buildingData;
  bool _isLoadingBuilding = false;
  final DioClient _dioClient = sl<DioClient>();

  @override
  void initState() {
    super.initState();
    _fetchBuildingData();
  }

  Future<void> _fetchBuildingData() async {
    if (widget.buildingId == null || widget.buildingId!.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingBuilding = true;
    });

    try {
      final response = await _dioClient.get(
        '/api/v1/buildings/${widget.buildingId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _buildingData = data['data'] as Map<String, dynamic>;
          });
        }
      }
    } catch (e) {
      // Silently fail - user can still fill the form manually
      if (mounted) {
        debugPrint('Error fetching building data: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBuilding = false;
        });
      }
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    context.pushNamed(
      Routelists.additionalBuildingList,
      queryParameters: {
        'siteId':
            widget.siteId ??
            Uri.parse(
              GoRouterState.of(context).uri.toString(),
            ).queryParameters['siteId'],
      },
    );
  }

  void _handleConnectionDataReady(Map<String, dynamic> data) {
    _connectionData = data;
  }

  void _handleConnect(BuildContext blocContext) {
    if (_connectionData == null) return;

    final request = LoxoneConnectionRequest(
      user: _connectionData!['user'] as String,
      pass: _connectionData!['pass'] as String,
      externalAddress: _connectionData!['externalAddress'] as String,
      port: _connectionData!['port'] as int,
      serialNumber: _connectionData!['serialNumber'] as String,
    );

    if (widget.buildingId != null && widget.buildingId!.isNotEmpty) {
      blocContext.read<ConnectLoxoneBloc>().add(
        ConnectLoxoneSubmitted(
          buildingId: widget.buildingId!,
          request: request,
        ),
      );
    } else {
      ScaffoldMessenger.of(blocContext).showSnackBar(
        const SnackBar(
          content: Text('Building ID is required'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateAfterSuccess() {
    final uri = Uri.parse(GoRouterState.of(context).uri.toString());
    final redirectTo = uri.queryParameters['redirectTo'];
    final fromDashboard = uri.queryParameters['fromDashboard'];

    if (redirectTo == 'setBuildingDetails') {
      // Navigate to setBuildingDetails page
      final buildingAddress = uri.queryParameters['buildingAddress'];
      final userName = uri.queryParameters['userName'];

      context.pushNamed(
        Routelists.setBuildingDetails,
        queryParameters: {
          if (userName != null) 'userName': userName,
          if (buildingAddress != null) 'buildingAddress': buildingAddress,
          'siteId': widget.siteId,
          if (widget.buildingId != null && widget.buildingId!.isNotEmpty)
            'buildingId': widget.buildingId!,
          if (fromDashboard != null) 'fromDashboard': fromDashboard,
        },
      );
    } else {
      // Default: navigate to floor management page
      final buildingName = uri.queryParameters['buildingName'] ?? 'Building';
      final buildingAddress = uri.queryParameters['buildingAddress'];
      final numberOfFloors = uri.queryParameters['numberOfFloors'] ?? '1';
      final totalArea = uri.queryParameters['totalArea'];
      final constructionYear = uri.queryParameters['constructionYear'];

      context.pushNamed(
        Routelists.buildingFloorManagement,
        queryParameters: {
          'buildingName': buildingName,
          if (buildingAddress != null) 'buildingAddress': buildingAddress,
          'numberOfFloors': numberOfFloors,
          if (totalArea != null) 'totalArea': totalArea,
          if (constructionYear != null) 'constructionYear': constructionYear,
          'siteId': widget.siteId,
          if (widget.buildingId != null && widget.buildingId!.isNotEmpty)
            'buildingId': widget.buildingId!,
          if (fromDashboard != null) 'fromDashboard': fromDashboard,
        },
      );
    }
  }

  void _handleSkip() {
    // Skip Loxone connection, navigate based on redirectTo parameter
    context.pop();
    // final uri = Uri.parse(GoRouterState.of(context).uri.toString());
    // final redirectTo = uri.queryParameters['redirectTo'];

    // if (redirectTo == 'setBuildingDetails') {
    //   // Navigate to setBuildingDetails page
    //   final buildingAddress = uri.queryParameters['buildingAddress'];
    //   final userName = uri.queryParameters['userName'];

    //   context.pushNamed(
    //     Routelists.setBuildingDetails,
    //     queryParameters: {
    //       if (userName != null) 'userName': userName,
    //       if (buildingAddress != null) 'buildingAddress': buildingAddress,
    //       if (widget.buildingId != null && widget.buildingId!.isNotEmpty)
    //         'buildingId': widget.buildingId!,
    //     },
    //   );
    // } else {
    //   // Default: navigate to floor management
    //   final buildingName = uri.queryParameters['buildingName'] ?? 'Building';
    //   final buildingAddress = uri.queryParameters['buildingAddress'];
    //   final numberOfFloors = uri.queryParameters['numberOfFloors'] ?? '1';
    //   final totalArea = uri.queryParameters['totalArea'];
    //   final constructionYear = uri.queryParameters['constructionYear'];

    //   context.pushNamed(
    //     Routelists.buildingFloorManagement,
    //     queryParameters: {
    //       'buildingName': buildingName,
    //       if (buildingAddress != null) 'buildingAddress': buildingAddress,
    //       'numberOfFloors': numberOfFloors,
    //       if (totalArea != null) 'totalArea': totalArea,
    //       if (constructionYear != null) 'constructionYear': constructionYear,
    //     },
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocProvider(
      create: (context) => sl<ConnectLoxoneBloc>(),
      child: BlocListener<ConnectLoxoneBloc, ConnectLoxoneState>(
        listener: (context, state) {
          if (state is ConnectLoxoneSuccess) {
            _navigateAfterSuccess();
          } else if (state is ConnectLoxoneFailure) {
            // Navigate to building details page with building information
            final uri = Uri.parse(GoRouterState.of(context).uri.toString());
            final buildingAddress = uri.queryParameters['buildingAddress'];
            final fromDashboard = uri.queryParameters['fromDashboard'];
            context.pushNamed(
              Routelists.setBuildingDetails,
              queryParameters: {
                if (widget.userName != null) 'userName': widget.userName!,
                if (widget.buildingId != null && widget.buildingId!.isNotEmpty)
                  'buildingId': widget.buildingId!,
                'siteId': widget.siteId,
                if (buildingAddress != null) 'buildingAddress': buildingAddress,
                if (fromDashboard != null) 'fromDashboard': fromDashboard,
              },
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
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
                child: Column(
                  children: [
                    BlocBuilder<ConnectLoxoneBloc, ConnectLoxoneState>(
                      builder: (blocContext, state) {
                        return LoxoneConnectionWidget(
                          userName: widget.userName,
                          onLanguageChanged: _handleLanguageChanged,
                          onConnect: () => _handleConnect(blocContext),
                          onSkip: _handleSkip,
                          onBack: _handleBack,
                          isLoading:
                              state is ConnectLoxoneLoading ||
                              _isLoadingBuilding,
                          onConnectionDataReady: _handleConnectionDataReady,
                          initialData: _buildingData,
                        );
                      },
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
      ),
    );
  }
}
