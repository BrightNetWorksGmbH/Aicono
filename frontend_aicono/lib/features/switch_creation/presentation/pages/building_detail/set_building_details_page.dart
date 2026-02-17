import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/building_detail_widget/set_building_details_widget.dart';

class SetBuildingDetailsPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingId;
  final String? siteId;
  final String?
  fromDashboard; // Flag to indicate if navigation is from dashboard
  const SetBuildingDetailsPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingId,
    this.siteId,
    this.fromDashboard,
  });

  @override
  State<SetBuildingDetailsPage> createState() => _SetBuildingDetailsPageState();
}

class _SetBuildingDetailsPageState extends State<SetBuildingDetailsPage> {
  Map<String, String?> _buildingDetails = {};
  String? _buildingName = 'Building';
  Map<String, dynamic>? _buildingData;
  bool _isLoadingBuilding = false;
  bool _isUpdatingBuilding = false;
  bool _hasFetchedData = false;
  final DioClient _dioClient = sl<DioClient>();

  @override
  void initState() {
    super.initState();
    // Try to get buildingId from widget first (doesn't require context)
    if (widget.buildingId != null && widget.buildingId!.isNotEmpty) {
      _fetchBuildingData(widget.buildingId!);
      _hasFetchedData = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get buildingId from route parameters if not already fetched
    if (!_hasFetchedData) {
      final buildingId = GoRouterState.of(
        context,
      ).uri.queryParameters['buildingId'];
      if (buildingId != null && buildingId.isNotEmpty) {
        _hasFetchedData = true;
        _fetchBuildingData(buildingId);
      }
    }
  }

  Future<void> _fetchBuildingData(String buildingId) async {
    setState(() {
      _isLoadingBuilding = true;
    });

    try {
      final response = await _dioClient.get('/api/v1/buildings/$buildingId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _buildingData = data['data'] as Map<String, dynamic>;
            // Update building name if available
            if (_buildingData?['name'] != null) {
              _buildingName = _buildingData!['name'].toString();
            }
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
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleBuildingDetailsChanged(Map<String, String?> details) {
    setState(() {
      _buildingDetails = details;
    });
  }

  Future<void> _handleContinue() async {
    // Get buildingId from widget or route parameters
    final buildingId =
        widget.buildingId ??
        GoRouterState.of(context).uri.queryParameters['buildingId'];

    if (buildingId == null || buildingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Building ID is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prepare request body
    final requestBody = <String, dynamic>{};

    // Name - use building name from widget or existing data
    if (_buildingName != null &&
        _buildingName!.isNotEmpty &&
        _buildingName != 'Building') {
      requestBody['name'] = _buildingName;
    } else if (_buildingData?['name'] != null) {
      requestBody['name'] = _buildingData!['name'];
    }

    // Building size
    if (_buildingDetails['size'] != null &&
        _buildingDetails['size']!.isNotEmpty) {
      final size = double.tryParse(_buildingDetails['size']!);
      if (size != null) {
        requestBody['building_size'] = size;
      }
    } else if (_buildingData?['building_size'] != null) {
      requestBody['building_size'] = _buildingData!['building_size'];
    }

    // Number of floors - use existing data if available
    if (_buildingDetails['rooms'] != null &&
        _buildingDetails['rooms']!.isNotEmpty) {
      requestBody['num_floors'] = int.tryParse(_buildingDetails['rooms']!);
    }

    // Year of construction
    if (_buildingDetails['year'] != null &&
        _buildingDetails['year']!.isNotEmpty) {
      final year = int.tryParse(_buildingDetails['year']!);
      if (year != null) {
        requestBody['year_of_construction'] = year;
      }
    } else if (_buildingData?['year_of_construction'] != null) {
      requestBody['year_of_construction'] =
          _buildingData!['year_of_construction'];
    }

    // Heated building area - use building_size if available, otherwise existing data
    if (_buildingDetails['size'] != null &&
        _buildingDetails['size']!.isNotEmpty) {
      final heatedArea = double.tryParse(_buildingDetails['size']!);
      if (heatedArea != null) {
        requestBody['heated_building_area'] = heatedArea;
      }
    } else if (_buildingData?['heated_building_area'] != null) {
      // Handle nested structure
      if (_buildingData!['heated_building_area'] is Map) {
        final nested = _buildingData!['heated_building_area'] as Map;
        requestBody['heated_building_area'] =
            double.tryParse(nested['\$numberDecimal']?.toString() ?? '') ??
            nested.values.first;
      } else {
        requestBody['heated_building_area'] =
            _buildingData!['heated_building_area'];
      }
    }

    // Type of use - use existing data if available
    if (_buildingData?['type_of_use'] != null) {
      requestBody['type_of_use'] = _buildingData!['type_of_use'];
    }

    // Number of students/employees
    if (_buildingDetails['rooms'] != null &&
        _buildingDetails['rooms']!.isNotEmpty) {
      final numStudents = int.tryParse(_buildingDetails['rooms']!);
      if (numStudents != null) {
        requestBody['num_students_employees'] = numStudents;
      }
    } else if (_buildingData?['num_students_employees'] != null) {
      requestBody['num_students_employees'] =
          _buildingData!['num_students_employees'];
    }

    // Make PATCH request to update building
    setState(() {
      _isUpdatingBuilding = true;
    });

    try {
      final response = await _dioClient.patch(
        '/api/v1/buildings/$buildingId',
        data: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Navigate to floor management page with building details
        final numberOfFloors = _buildingDetails['rooms'] != null
            ? int.tryParse(_buildingDetails['rooms']!)
            : (_buildingData?['num_floors'] as int?) ?? 1;

        final totalArea = _buildingDetails['size'] != null
            ? double.tryParse(_buildingDetails['size']!)
            : (_buildingData?['building_size'] as double?) ??
                  (_buildingData?['heated_building_area'] != null
                      ? (double.tryParse(
                              _buildingData!['heated_building_area'].toString(),
                            ) ??
                            (_buildingData!['heated_building_area'] is Map
                                ? double.tryParse(
                                    (_buildingData!['heated_building_area']
                                                as Map)['\$numberDecimal']
                                            ?.toString() ??
                                        '',
                                  )
                                : null))
                      : null);

        final numberOfRooms = _buildingDetails['rooms'] != null
            ? int.tryParse(_buildingDetails['rooms']!)
            : (_buildingData?['num_students_employees'] as int?);

        if (mounted) {
          final fromDashboard =
              widget.fromDashboard ??
              Uri.parse(
                GoRouterState.of(context).uri.toString(),
              ).queryParameters['fromDashboard'];
          context.pushNamed(
            Routelists.buildingSetup,
            queryParameters: {
              'buildingId': buildingId,
              'siteId':
                  widget.siteId ??
                  Uri.parse(
                    GoRouterState.of(context).uri.toString(),
                  ).queryParameters['siteId'],
              'buildingName': _buildingName,
              if (widget.buildingAddress != null)
                'buildingAddress': widget.buildingAddress!,
              'numberOfFloors': numberOfFloors.toString(),
              if (numberOfRooms != null)
                'numberOfRooms': numberOfRooms.toString(),
              if (totalArea != null) 'totalArea': totalArea.toString(),
              if (_buildingDetails['year'] != null)
                'constructionYear': _buildingDetails['year']!,
              if (fromDashboard != null) 'fromDashboard': fromDashboard,
            },
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update building: ${response.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating building: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingBuilding = false;
        });
      }
    }
  }

  void _handleSkip() {
    // Navigate back to the previous page (skip this step)
    final fromDashboard =
        widget.fromDashboard ??
        Uri.parse(
          GoRouterState.of(context).uri.toString(),
        ).queryParameters['fromDashboard'];
    context.pushNamed(
      Routelists.additionalBuildingList,
      queryParameters: {
        'siteId':
            widget.siteId ??
            Uri.parse(
              GoRouterState.of(context).uri.toString(),
            ).queryParameters['siteId'],
        if (fromDashboard != null) 'fromDashboard': fromDashboard,
      },
    );
  }

  void _handleEditAddress() {
    // Navigate back to address selection page
    if (context.canPop()) {
      context.pop();
    }
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
                SetBuildingDetailsWidget(
                  userName: widget.userName,
                  buildingAddress: widget.buildingAddress,
                  onLanguageChanged: _handleLanguageChanged,
                  onBuildingDetailsChanged: _handleBuildingDetailsChanged,
                  onBack: _handleBack,
                  onContinue: _handleContinue,
                  onSkip: _handleSkip,
                  onEditAddress: _handleEditAddress,
                  initialData: _buildingData,
                  isLoading: _isLoadingBuilding || _isUpdatingBuilding,
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
