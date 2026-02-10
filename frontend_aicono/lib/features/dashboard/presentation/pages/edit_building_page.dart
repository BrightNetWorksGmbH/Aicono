import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_building_details_bloc.dart';

import '../../../../core/routing/routeLists.dart';

class EditBuildingPage extends StatefulWidget {
  final String buildingId;

  const EditBuildingPage({super.key, required this.buildingId});

  @override
  State<EditBuildingPage> createState() => _EditBuildingPageState();
}

class _EditBuildingPageState extends State<EditBuildingPage> {
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _buildingTypeController = TextEditingController();
  final TextEditingController _numberOfFloorsController =
      TextEditingController();
  final TextEditingController _totalAreaController = TextEditingController();
  final TextEditingController _constructionYearController =
      TextEditingController();
  final TextEditingController _heatedBuildingAreaController =
      TextEditingController();
  final TextEditingController _numStudentsEmployeesController =
      TextEditingController();
  final TextEditingController _loxoneUserController = TextEditingController();
  final TextEditingController _loxonePassController = TextEditingController();
  final TextEditingController _loxoneExternalAddressController =
      TextEditingController();
  final TextEditingController _loxonePortController = TextEditingController();
  final TextEditingController _loxoneSerialNumberController =
      TextEditingController();

  bool _isLoading = false;
  bool _isLoadingLoxoneChanges = false;
  @override
  void initState() {
    super.initState();
    _loadBuildingData();
  }

  @override
  void dispose() {
    _buildingNameController.dispose();
    _buildingTypeController.dispose();
    _numberOfFloorsController.dispose();
    _totalAreaController.dispose();
    _constructionYearController.dispose();
    _heatedBuildingAreaController.dispose();
    _numStudentsEmployeesController.dispose();
    _loxoneUserController.dispose();
    _loxonePassController.dispose();
    _loxoneExternalAddressController.dispose();
    _loxonePortController.dispose();
    _loxoneSerialNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildingData() async {
    // Request building details to get current values
    context.read<DashboardBuildingDetailsBloc>().add(
      DashboardBuildingDetailsRequested(buildingId: widget.buildingId),
    );
    // Fetch building data to get Loxone connection info
    await _fetchBuildingDataForEdit();
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  Future<void> _fetchBuildingDataForEdit() async {
    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.get(
        '/api/v1/buildings/${widget.buildingId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final buildingData = data['data'] as Map<String, dynamic>;

          // Set Loxone connection fields if available
          _loxoneUserController.text =
              buildingData['miniserver_user']?.toString() ??
              'AICONO_clouduser01';
          _loxonePassController.text =
              buildingData['miniserver_pass']?.toString() ?? 'A9f!Q2m#R7xP';
          _loxoneExternalAddressController.text =
              buildingData['miniserver_external_address']?.toString() ??
              'dns.loxonecloud.com';
          _loxonePortController.text =
              buildingData['miniserver_port']?.toString() ?? '443';
          _loxoneSerialNumberController.text =
              buildingData['miniserver_serial']?.toString() ?? '504F94D107EE';

          // Set heated_building_area if available
          if (buildingData['heated_building_area'] != null) {
            _heatedBuildingAreaController.text =
                buildingData['heated_building_area'].toString();
          }

          // Set num_students_employees if available
          if (buildingData['num_students_employees'] != null) {
            _numStudentsEmployeesController.text =
                buildingData['num_students_employees'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching building data for edit: $e');
      // Use default values if fetch fails
      _loxoneUserController.text = 'AICONO_clouduser01';
      _loxonePassController.text = 'A9f!Q2m#R7xP';
      _loxoneExternalAddressController.text = 'dns.loxonecloud.com';
      _loxonePortController.text = '443';
      _loxoneSerialNumberController.text = '504F94D107EE';
    }
  }

  Future<void> _handleSaveLoxoneChanges() async {
    setState(() {
      _isLoadingLoxoneChanges = true;
    });
    try {
      final dioClient = sl<DioClient>();
      final requestBody = <String, dynamic>{
        'ip': _loxoneExternalAddressController.text.trim(),
        'port': _loxonePortController.text.trim(),
        'user': _loxoneUserController.text.trim(),
        'pass': _loxonePassController.text.trim(),
        'serialNumber': _loxoneSerialNumberController.text.trim(),
      };
      final response = await dioClient.patch(
        '/api/v1/buildings/${widget.buildingId}/loxone-config',
        data: requestBody,
      );
      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loxone changes updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh building details
          context.read<DashboardBuildingDetailsBloc>().add(
            DashboardBuildingDetailsRequested(buildingId: widget.buildingId),
          );
          // Navigate back
          // context.pop();
          context.pushReplacementNamed(Routelists.dashboard);
        } else if (response.statusCode == 404) {
          // If 404, try POST to connect endpoint
          await _connectLoxone(dioClient);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update Loxone changes: ${response.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a 404 error
        if (e is DioException && e.response?.statusCode == 404) {
          try {
            final dioClient = sl<DioClient>();
            await _connectLoxone(dioClient);
          } catch (connectError) {
            debugPrint('Error connecting Loxone: $connectError');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error connecting Loxone: $connectError'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          debugPrint('Error saving Loxone changes: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating Loxone changes: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLoxoneChanges = false;
        });
      }
    }
  }

  Future<void> _connectLoxone(DioClient dioClient) async {
    try {
      // Parse port as integer, default to 443 if invalid
      final port = int.tryParse(_loxonePortController.text.trim()) ?? 443;

      final connectRequestBody = <String, dynamic>{
        'user': _loxoneUserController.text.trim(),
        'pass': _loxonePassController.text.trim(),
        'externalAddress': _loxoneExternalAddressController.text.trim(),
        'port': port,
        'serialNumber': _loxoneSerialNumberController.text.trim(),
      };

      final connectResponse = await dioClient.post(
        '/api/v1/loxone/connect/${widget.buildingId}',
        data: connectRequestBody,
      );

      if (mounted) {
        if (connectResponse.statusCode == 200 ||
            connectResponse.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loxone connected successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh building details
          context.read<DashboardBuildingDetailsBloc>().add(
            DashboardBuildingDetailsRequested(buildingId: widget.buildingId),
          );
          // Navigate back
          context.pushReplacementNamed(Routelists.dashboard);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to connect Loxone: ${connectResponse.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error connecting Loxone: $e');
        rethrow; // Re-throw to be handled by caller
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return BlocListener<
      DashboardBuildingDetailsBloc,
      DashboardBuildingDetailsState
    >(
      listener: (context, state) {
        if (state is DashboardBuildingDetailsSuccess) {
          // Initialize fields with current values
          _buildingNameController.text = state.details.name;
          _buildingTypeController.text = state.details.typeOfUse ?? '';
          _numberOfFloorsController.text =
              state.details.numFloors?.toString() ?? '';
          _totalAreaController.text =
              state.details.buildingSize?.toString() ?? '';
          _constructionYearController.text =
              state.details.yearOfConstruction?.toString() ?? '';
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width,
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
                Container(
                  width: double.infinity,
                  height: screenSize.height * .9,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      width: screenSize.width < 600
                          ? screenSize.width * 0.95
                          : screenSize.width < 1200
                          ? screenSize.width * 0.5
                          : screenSize.width * 0.6,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          child: SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: Center(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.arrow_back),
                                          onPressed: () => context.pop(),
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Center(
                                            child: Text(
                                              'Edit Building',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Building information',
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  // Building name field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _buildingNameController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter building name',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        //  prefixIcon: Icon(Icons.business),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Building name is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Building type field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _buildingTypeController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter type of use',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        //  prefixIcon: Icon(Icons.category),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Number of floors field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _numberOfFloorsController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'Enter number of floors',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        //  prefixIcon: Icon(Icons.layers),
                                      ),
                                      validator: (value) {
                                        if (value != null &&
                                            value.trim().isNotEmpty &&
                                            int.tryParse(value.trim()) ==
                                                null) {
                                          return 'Please enter a valid number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Total area field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _totalAreaController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        hintText: 'Enter total area',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        //  prefixIcon: Icon(Icons.square_foot),
                                      ),
                                      validator: (value) {
                                        if (value != null &&
                                            value.trim().isNotEmpty &&
                                            double.tryParse(value.trim()) ==
                                                null) {
                                          return 'Please enter a valid number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Construction year field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _constructionYearController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'Enter construction year',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        //  prefixIcon: Icon(Icons.calendar_today),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Heated building area field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _heatedBuildingAreaController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'Enter heated building area',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        //  prefixIcon: Icon(Icons.thermostat),
                                      ),
                                      validator: (value) {
                                        if (value != null &&
                                            value.trim().isNotEmpty &&
                                            int.tryParse(value.trim()) ==
                                                null) {
                                          return 'Please enter a valid number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Number of students/employees field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller:
                                          _numStudentsEmployeesController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Enter number of students/employees',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        //  prefixIcon: Icon(Icons.people),
                                      ),
                                      validator: (value) {
                                        if (value != null &&
                                            value.trim().isNotEmpty &&
                                            int.tryParse(value.trim()) ==
                                                null) {
                                          return 'Please enter a valid number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Save button
                                  _isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            PrimaryOutlineButton(
                                              onPressed: _handleSave,
                                              label: 'Update Building Changes',
                                              width: 260,
                                            ),
                                          ],
                                        ),
                                  const SizedBox(height: 32),
                                  // Loxone Connection Section
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: const Text(
                                      'Loxone Connection',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Loxone User field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _loxoneUserController,
                                      decoration: InputDecoration(
                                        hintText: 'User',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.person),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Loxone Password field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _loxonePassController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        hintText: 'password',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.lock),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Loxone External Address field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller:
                                          _loxoneExternalAddressController,
                                      decoration: InputDecoration(
                                        hintText: 'External address',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.link),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Loxone Port field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _loxonePortController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'Port',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.settings_ethernet,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Loxone Serial Number field
                                  SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: TextFormField(
                                      controller: _loxoneSerialNumberController,
                                      decoration: InputDecoration(
                                        hintText: 'Serial Number',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.numbers),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  // Save button
                                  _isLoadingLoxoneChanges
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            PrimaryOutlineButton(
                                              onPressed:
                                                  _handleSaveLoxoneChanges,
                                              label: 'Update Loxone Changes',
                                              width: 260,
                                            ),
                                          ],
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AppFooter(
                  onLanguageChanged: _handleLanguageChanged,
                  containerWidth: MediaQuery.of(context).size.width,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final buildingName = _buildingNameController.text.trim();

    if (buildingName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Building name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dioClient = sl<DioClient>();
      final requestBody = <String, dynamic>{'name': buildingName};

      // Add building size if provided
      if (_totalAreaController.text.trim().isNotEmpty) {
        final totalArea = double.tryParse(_totalAreaController.text.trim());
        if (totalArea != null) {
          requestBody['building_size'] = totalArea.toInt();
        }
      }

      // Add number of floors if provided
      if (_numberOfFloorsController.text.trim().isNotEmpty) {
        final numFloors = int.tryParse(_numberOfFloorsController.text.trim());
        if (numFloors != null) {
          requestBody['num_floors'] = numFloors;
        }
      }

      // Add construction year if provided
      if (_constructionYearController.text.trim().isNotEmpty) {
        final year = int.tryParse(_constructionYearController.text.trim());
        if (year != null) {
          requestBody['year_of_construction'] = year;
        }
      }

      // Add building type if provided
      if (_buildingTypeController.text.trim().isNotEmpty) {
        requestBody['type_of_use'] = _buildingTypeController.text.trim();
      }

      // Add heated building area if provided
      if (_heatedBuildingAreaController.text.trim().isNotEmpty) {
        final heatedArea = int.tryParse(
          _heatedBuildingAreaController.text.trim(),
        );
        if (heatedArea != null) {
          requestBody['heated_building_area'] = heatedArea;
        }
      }

      // Add number of students/employees if provided
      if (_numStudentsEmployeesController.text.trim().isNotEmpty) {
        final numStudents = int.tryParse(
          _numStudentsEmployeesController.text.trim(),
        );
        if (numStudents != null) {
          requestBody['num_students_employees'] = numStudents;
        }
      }

      final response = await dioClient.patch(
        '/api/v1/buildings/${widget.buildingId}',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Building updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh building details
          context.read<DashboardBuildingDetailsBloc>().add(
            DashboardBuildingDetailsRequested(buildingId: widget.buildingId),
          );
          // Navigate back
          // context.pop();
          context.pushReplacementNamed(Routelists.dashboard);
        } else {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating building: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
