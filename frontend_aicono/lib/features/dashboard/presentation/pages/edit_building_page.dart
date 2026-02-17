import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
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

  // Contact person state
  Map<String, dynamic>? _selectedContact;
  bool _isEditingContact = false;
  bool _createContactClicked = false;
  bool _isLoadingBuildingContact = false;
  final DioClient _dioClient = sl<DioClient>();

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

  Future<void> _loadContactPersonFromBuilding() async {
    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.get(
        '/api/v1/buildings/${widget.buildingId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final buildingData = data['data'] as Map<String, dynamic>;

          // Check if buildingContact exists
          if (buildingData['buildingContact'] != null) {
            final contactData = buildingData['buildingContact'];

            // Handle both object and ID cases
            if (contactData is Map<String, dynamic>) {
              setState(() {
                _selectedContact = {
                  'name': contactData['name']?.toString() ?? '',
                  'email': contactData['email']?.toString() ?? '',
                  'phone': contactData['phone']?.toString() ?? '',
                  'id':
                      contactData['_id']?.toString() ??
                      contactData['id']?.toString() ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  'method': 'domain',
                };
                _isEditingContact = false;
              });
            } else if (contactData is String) {
              // If it's just an ID, we might need to fetch the contact details
              // For now, just store the ID
              setState(() {
                _selectedContact = {'id': contactData, 'method': 'domain'};
                _isEditingContact = false;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading contact person: $e');
    }
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

  Future<void> _handleSaveBuildingContact() async {
    // TODO: Implement save building contact logic
    setState(() {
      _isLoadingBuildingContact = true;
    });
    try {
      final dioClient = sl<DioClient>();
      final requestBody = <String, dynamic>{
        'buildingContact': _selectedContact,
      };

      final response = await dioClient.patch(
        '/api/v1/buildings/${widget.buildingId}',
        data: requestBody,
      );
      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Building contact saved successfully'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save building contact: ${response.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving building contact: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving building contact: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBuildingContact = false;
        });
      }
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

  Future<void> _handleAutomaticFromDomain() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch contacts from endpoint
      final buildingId = widget.buildingId;
      final response = await _dioClient.dio.get(
        '/api/v1/buildings/contacts',
        queryParameters: buildingId.isNotEmpty
            ? {'buildingId': buildingId}
            : null,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Parse response
      List<Map<String, dynamic>> contactsList = [];
      if (response.data != null) {
        // Handle different response structures
        if (response.data is List) {
          contactsList = List<Map<String, dynamic>>.from(response.data);
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;

          if (responseMap['data'] != null) {
            if (responseMap['data'] is List) {
              contactsList = List<Map<String, dynamic>>.from(
                responseMap['data'],
              );
            }
          } else if (responseMap['contacts'] != null) {
            if (responseMap['contacts'] is List) {
              contactsList = List<Map<String, dynamic>>.from(
                responseMap['contacts'],
              );
            }
          } else if (responseMap['results'] != null) {
            if (responseMap['results'] is List) {
              contactsList = List<Map<String, dynamic>>.from(
                responseMap['results'],
              );
            }
          }
        }
      }

      // Show contacts dialog
      if (mounted) {
        _showContactsDialog(contactsList);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error or empty dialog
      if (mounted) {
        _showContactsDialog([]);
      }
    }
  }

  void _showContactsDialog(List<Map<String, dynamic>> contactsList) {
    final Size screenSize = MediaQuery.of(context).size;
    String? selectedContactId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          actionsAlignment: MainAxisAlignment.center,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          backgroundColor: Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'building_contact_person.contacts_from_domain'.tr(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: screenSize.width < 600
                ? screenSize.width * 0.9
                : screenSize.width < 1200
                ? screenSize.width * 0.5
                : screenSize.width * 0.4,
            child: contactsList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'building_contact_person.no_contacts_found'.tr(),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'building_contact_person.choose_one_contact'.tr(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: contactsList.length,
                          itemBuilder: (context, index) {
                            final contact = contactsList[index];
                            final name =
                                contact['name'] ?? contact['fullName'] ?? '';
                            final email =
                                contact['email'] ??
                                contact['emailAddress'] ??
                                '';
                            final contactId =
                                contact['_id'] ?? contact['id'] ?? '';

                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedContactId = contactId;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Radio<String>(
                                      value: contactId,
                                      activeColor: Colors.black,
                                      groupValue: selectedContactId,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          selectedContactId = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name.isNotEmpty
                                                ? name
                                                : 'Unbekannt',
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          if (email.isNotEmpty)
                                            Text(
                                              email,
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            PrimaryOutlineButton(
              label: 'building_contact_person.choose_contact'.tr(),
              onPressed: selectedContactId == null
                  ? null
                  : () {
                      final selectedContact = contactsList.firstWhere((
                        contact,
                      ) {
                        final contactId = contact['_id'] ?? contact['id'] ?? '';
                        return contactId == selectedContactId;
                      });

                      final name =
                          selectedContact['name'] ??
                          selectedContact['fullName'] ??
                          '';
                      final email =
                          selectedContact['email'] ??
                          selectedContact['emailAddress'] ??
                          '';
                      final contactId =
                          selectedContact['_id'] ?? selectedContact['id'] ?? '';

                      setState(() {
                        _selectedContact = {
                          'name': name,
                          'email': email,
                          'phone': selectedContact['phone'] ?? '',
                          'id': contactId.isNotEmpty
                              ? contactId
                              : DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                          'method': 'domain',
                        };
                        _isEditingContact = false;
                        _createContactClicked = false;
                      });
                      Navigator.of(context).pop();
                    },
              width: 260,
            ),
          ],
        ),
      ),
    );
  }

  void _handleUploadContact() {
    setState(() {
      _selectedContact = {
        'name': '',
        'email': '',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'method': 'upload',
      };
      _isEditingContact = true;
      _createContactClicked = true;
    });
  }

  void _handleContactNameChanged(String name) {
    setState(() {
      if (_selectedContact != null) {
        _selectedContact!['name'] = name;
      }
    });
  }

  void _handleContactEmailChanged(String email) {
    setState(() {
      if (_selectedContact != null) {
        _selectedContact!['email'] = email;
      }
    });
  }

  void _handleConfirmContact() {
    setState(() {
      _isEditingContact = false;
    });
  }

  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  bool _isContactFormValid() {
    if (_selectedContact == null) return false;

    final name = _selectedContact!['name']?.toString().trim() ?? '';
    final email = _selectedContact!['email']?.toString().trim() ?? '';

    if (_isEditingContact) {
      return name.isNotEmpty && email.isNotEmpty && _isValidEmail(email);
    }

    return name.isNotEmpty;
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

          // Load contact person if available from building data
          _loadContactPersonFromBuilding();
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
                                  Material(
                                    color: Colors.transparent,
                                    child: TopHeader(
                                      onLanguageChanged: _handleLanguageChanged,
                                      containerWidth: screenSize.width > 500
                                          ? 500
                                          : screenSize.width * 0.98,
                                      // userInitial: widget.userName?[0].toUpperCase(),
                                      verseInitial: null,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
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
                                      'Building contact information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Building contact information section (same as building_contact_person_step.dart)
                                  if (_selectedContact != null) ...[
                                    if (_isEditingContact) ...[
                                      // Show text fields when editing
                                      SizedBox(
                                        width: screenSize.width < 600
                                            ? screenSize.width * 0.95
                                            : screenSize.width < 1200
                                            ? screenSize.width * 0.5
                                            : screenSize.width * 0.6,
                                        child: Column(
                                          children: [
                                            // Name Field
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              height: 50,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF8B9A5B,
                                                  ),
                                                  width: 1,
                                                ),
                                                borderRadius: BorderRadius.zero,
                                                color: Colors.white,
                                              ),
                                              child: TextFormField(
                                                initialValue:
                                                    _selectedContact!['name'] ??
                                                    '',
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'building_contact_person.name_hint'
                                                          .tr(),
                                                  border: InputBorder.none,
                                                  hintStyle: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      color: Colors.black87,
                                                    ),
                                                onChanged: (value) {
                                                  _handleContactNameChanged(
                                                    value,
                                                  );
                                                  setState(() {});
                                                },
                                              ),
                                            ),
                                            // Email Field
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              height: 50,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF8B9A5B,
                                                  ),
                                                  width: 1,
                                                ),
                                                borderRadius: BorderRadius.zero,
                                                color: Colors.white,
                                              ),
                                              child: TextFormField(
                                                initialValue:
                                                    _selectedContact!['email'] ??
                                                    '',
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'building_contact_person.email_hint'
                                                          .tr(),
                                                  border: InputBorder.none,
                                                  hintStyle: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      color: Colors.black87,
                                                    ),
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                onChanged: (value) {
                                                  _handleContactEmailChanged(
                                                    value,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else
                                      // Show confirmation box when confirmed
                                      SizedBox(
                                        width: screenSize.width < 600
                                            ? screenSize.width * 0.95
                                            : screenSize.width < 1200
                                            ? screenSize.width * 0.5
                                            : screenSize.width * 0.6,
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                            borderRadius: BorderRadius.zero,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                Image.asset(
                                                  'assets/images/check.png',
                                                  width: 16,
                                                  height: 16,
                                                  color: const Color(
                                                    0xFF238636,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _selectedContact!['name'] !=
                                                                null &&
                                                            _selectedContact!['name']
                                                                .toString()
                                                                .isNotEmpty
                                                        ? '${_selectedContact!['name']}      ${_selectedContact!['email'] != null && _selectedContact!['email'].toString().isNotEmpty ? _selectedContact!['email'] : ''}'
                                                        : _selectedContact!['email'] !=
                                                                  null &&
                                                              _selectedContact!['email']
                                                                  .toString()
                                                                  .isNotEmpty
                                                        ? _selectedContact!['email']
                                                        : '',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                // Edit button
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _isEditingContact =
                                                            true;
                                                      });
                                                    },
                                                    borderRadius:
                                                        BorderRadius.zero,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      child: Text(
                                                        'building_contact_person.edit'
                                                            .tr(),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Remove button
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _selectedContact = null;
                                                        _isEditingContact =
                                                            false;
                                                        _createContactClicked =
                                                            false;
                                                      });
                                                    },
                                                    borderRadius:
                                                        BorderRadius.zero,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      child: Icon(
                                                        Icons.close,
                                                        size: 18,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                  // Action links - side by side (only show if no contact selected or when editing)
                                  if (_selectedContact == null ||
                                      (_selectedContact != null &&
                                          _isEditingContact))
                                    SizedBox(
                                      width: screenSize.width < 600
                                          ? screenSize.width * 0.95
                                          : screenSize.width < 1200
                                          ? screenSize.width * 0.5
                                          : screenSize.width * 0.6,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _handleAutomaticFromDomain,
                                              borderRadius: BorderRadius.zero,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 4,
                                                    ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '+',
                                                      style: TextStyle(
                                                        fontSize:
                                                            screenSize.width <
                                                                600
                                                            ? 14
                                                            : 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width:
                                                          screenSize.width < 600
                                                          ? 4
                                                          : 8,
                                                    ),
                                                    Flexible(
                                                      child: Text(
                                                        'building_contact_person.automatic_from_domain'
                                                            .tr(),
                                                        style: TextStyle(
                                                          fontSize:
                                                              screenSize.width <
                                                                  600
                                                              ? 12
                                                              : 16,
                                                          color: Colors.black,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: screenSize.width < 600
                                                ? 12
                                                : 24,
                                          ),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _createContactClicked
                                                  ? null
                                                  : _handleUploadContact,
                                              borderRadius: BorderRadius.zero,
                                              child: Opacity(
                                                opacity: _createContactClicked
                                                    ? 0.5
                                                    : 1.0,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 4,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '+',
                                                        style: TextStyle(
                                                          fontSize:
                                                              screenSize.width <
                                                                  600
                                                              ? 14
                                                              : 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              _createContactClicked
                                                              ? Colors.grey
                                                              : Colors.black,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width:
                                                            screenSize.width <
                                                                600
                                                            ? 4
                                                            : 8,
                                                      ),
                                                      Flexible(
                                                        child: Text(
                                                          'building_contact_person.upload_contact'
                                                              .tr(),
                                                          style: TextStyle(
                                                            fontSize:
                                                                screenSize
                                                                        .width <
                                                                    600
                                                                ? 12
                                                                : 16,
                                                            color:
                                                                _createContactClicked
                                                                ? Colors.grey
                                                                : Colors.black,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 32),
                                  // Building contact information section
                                  SizedBox(
                                    width: 260,
                                    child: _isLoadingBuildingContact
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : PrimaryOutlineButton(
                                            onPressed: _isLoadingBuildingContact
                                                ? null
                                                : _handleSaveBuildingContact,
                                            label: 'Save Building Contact',
                                            width: 260,
                                          ),
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

      // Add building contact if provided
      if (_selectedContact != null &&
          _selectedContact!['name'] != null &&
          _selectedContact!['name'].toString().isNotEmpty) {
        final contactId = _selectedContact!['id'];
        final method = _selectedContact!['method'];

        // Check if it's from dialog: method is 'domain' and ID is a MongoDB ObjectId (24 hex characters)
        final idString = contactId?.toString() ?? '';
        final isMongoObjectId =
            idString.length == 24 &&
            RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(idString);
        final isFromDialog =
            method == 'domain' &&
            contactId != null &&
            idString.isNotEmpty &&
            isMongoObjectId; // MongoDB ObjectId format

        if (isFromDialog) {
          // If from dialog, send only the ID
          requestBody['buildingContact'] = contactId.toString();
        } else {
          // If manually entered, send the full object
          requestBody['buildingContact'] = {
            'name': _selectedContact!['name'] ?? '',
            'email': _selectedContact!['email'] ?? '',
            'phone': _selectedContact!['phone'] ?? '',
          };
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
