import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/page_header_row.dart';

class DashboardReportSetupPage extends StatefulWidget {
  final String buildingId;
  final String? fromDashboard;
  final String? reportingJson; // JSON string of ReportDetailReportingEntity
  final String? recipientsJson; // JSON string of List<ReportRecipientEntity>
  const DashboardReportSetupPage({
    super.key,
    required this.buildingId,
    this.fromDashboard,
    this.reportingJson,
    this.recipientsJson,
  });

  @override
  State<DashboardReportSetupPage> createState() =>
      _DashboardReportSetupPageState();
}

class _DashboardReportSetupPageState extends State<DashboardReportSetupPage> {
  final TextEditingController _reportingNameController =
      TextEditingController();
  String _selectedFrequencyKey = 'monthly';
  Map<String, bool> _reportOptions = {
    'total_consumption': true,
    'peak_loads': false,
    'anomalies': false,
    'rooms_by_consumption': true,
    'underutilization': true,
  };
  final DioClient _dioClient = sl<DioClient>();
  bool _isLoading = false;
  List<Map<String, dynamic>> _savedReportConfigs = [];
  int? _editingConfigIndex;

  // Responsible persons state (multiple)
  List<Map<String, dynamic>> _selectedResponsiblePersons = [];
  int? _editingPersonIndex; // Track which person is being edited

  String get _selectedFrequency =>
      'building_responsible_persons.$_selectedFrequencyKey'.tr();

  @override
  void initState() {
    super.initState();
    // If editing existing report, load report data first (which includes recipients)
    // Otherwise, load from building
    if (widget.reportingJson != null || widget.recipientsJson != null) {
      _loadExistingReport();
    } else {
      _loadExistingResponsiblePerson();
    }
  }

  @override
  void dispose() {
    _reportingNameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingResponsiblePerson() async {
    try {
      final response = await _dioClient.get(
        '/api/v1/buildings/${widget.buildingId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final buildingData = data['data'] as Map<String, dynamic>;

          // Check if reportingRecipients exists and load all of them
          if (buildingData['reportingRecipients'] != null &&
              buildingData['reportingRecipients'] is List) {
            final recipients = buildingData['reportingRecipients'] as List;
            if (recipients.isNotEmpty) {
              setState(() {
                _selectedResponsiblePersons = recipients
                    .map<Map<String, dynamic>>((recipient) {
                      final recipientMap = recipient as Map<String, dynamic>;
                      return {
                        'name': recipientMap['name']?.toString() ?? '',
                        'email': recipientMap['email']?.toString() ?? '',
                        'phone': recipientMap['phone']?.toString() ?? '',
                        'id':
                            recipientMap['_id']?.toString() ??
                            recipientMap['id']?.toString() ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        'method': 'domain',
                      };
                    })
                    .toList();
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading responsible persons: $e');
    }
  }

  Future<void> _loadExistingReport() async {
    try {
      // Load reporting data
      if (widget.reportingJson != null && widget.reportingJson!.isNotEmpty) {
        final reportingData =
            jsonDecode(widget.reportingJson!) as Map<String, dynamic>;

        setState(() {
          // Set reporting name
          _reportingNameController.text =
              reportingData['name']?.toString() ?? '';

          // Set frequency based on interval
          final interval =
              reportingData['interval']?.toString().toLowerCase() ?? 'monthly';
          switch (interval) {
            case 'daily':
              _selectedFrequencyKey = 'daily';
              break;
            case 'weekly':
              _selectedFrequencyKey = 'weekly';
              break;
            case 'monthly':
              _selectedFrequencyKey = 'monthly';
              break;
            case 'yearly':
              _selectedFrequencyKey = 'yearly';
              break;
            default:
              _selectedFrequencyKey = 'monthly';
          }

          // Set report options based on reportContents
          final reportContents = reportingData['reportContents'] as List? ?? [];
          _reportOptions = {
            'total_consumption': reportContents.contains('TotalConsumption'),
            'peak_loads': reportContents.contains('PeakLoads'),
            'anomalies': reportContents.contains('Anomalies'),
            'rooms_by_consumption': reportContents.contains(
              'ConsumptionByRoom',
            ),
            'underutilization': reportContents.contains('InefficientUsage'),
          };

          // Add to saved configs if it has a name
          if (_reportingNameController.text.isNotEmpty) {
            _savedReportConfigs.add({
              'name': _reportingNameController.text,
              'interval': reportingData['interval'] ?? 'Monthly',
              'intervalKey': _selectedFrequencyKey,
              'reportContents': List<String>.from(reportContents),
              'reportOptions': Map<String, bool>.from(_reportOptions),
              'completed': true,
            });
          }
        });
      }

      // Load recipients data
      if (widget.recipientsJson != null && widget.recipientsJson!.isNotEmpty) {
        final recipientsList = jsonDecode(widget.recipientsJson!) as List;

        setState(() {
          _selectedResponsiblePersons = recipientsList
              .map<Map<String, dynamic>>((r) {
                final recipientMap = r as Map<String, dynamic>;
                return {
                  'name': recipientMap['recipientName']?.toString() ?? '',
                  'email': recipientMap['recipientEmail']?.toString() ?? '',
                  'id':
                      recipientMap['recipientId']?.toString() ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  'method': 'domain',
                };
              })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading report data: $e');
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  Future<void> _handleAutomaticFromDomain() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await _dioClient.dio.get(
        '/api/v1/buildings/contacts',
        queryParameters: {'buildingId': widget.buildingId},
      );

      if (mounted) {
        Navigator.of(context).pop();
      }

      List<Map<String, dynamic>> contactsList = [];
      if (response.data != null) {
        if (response.data is List) {
          contactsList = List<Map<String, dynamic>>.from(response.data);
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          if (responseMap['data'] != null && responseMap['data'] is List) {
            contactsList = List<Map<String, dynamic>>.from(responseMap['data']);
          } else if (responseMap['contacts'] != null &&
              responseMap['contacts'] is List) {
            contactsList = List<Map<String, dynamic>>.from(
              responseMap['contacts'],
            );
          } else if (responseMap['results'] != null &&
              responseMap['results'] is List) {
            contactsList = List<Map<String, dynamic>>.from(
              responseMap['results'],
            );
          }
        }
      }

      if (mounted) {
        _showContactsDialog(contactsList);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
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

                      // Check if person already exists
                      final existingIndex = _selectedResponsiblePersons
                          .indexWhere((p) => p['id'] == contactId);

                      if (existingIndex == -1) {
                        // Add new person
                        setState(() {
                          _selectedResponsiblePersons.add({
                            'name': name,
                            'email': email,
                            'phone': selectedContact['phone'] ?? '',
                            'id': contactId.isNotEmpty
                                ? contactId
                                : DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                            'method': 'domain',
                          });
                        });
                      }
                      Navigator.of(context).pop();
                    },
              width: 260,
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreatePerson() {
    setState(() {
      _selectedResponsiblePersons.add({
        'name': '',
        'email': '',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'method': 'upload',
      });
      _editingPersonIndex = _selectedResponsiblePersons.length - 1;
    });
  }

  void _handlePersonNameChanged(int index, String name) {
    setState(() {
      if (index >= 0 && index < _selectedResponsiblePersons.length) {
        _selectedResponsiblePersons[index]['name'] = name;
      }
    });
  }

  void _handlePersonEmailChanged(int index, String email) {
    setState(() {
      if (index >= 0 && index < _selectedResponsiblePersons.length) {
        _selectedResponsiblePersons[index]['email'] = email;
      }
    });
  }

  void _handleRemovePerson(int index) {
    setState(() {
      if (index >= 0 && index < _selectedResponsiblePersons.length) {
        _selectedResponsiblePersons.removeAt(index);
        if (_editingPersonIndex == index) {
          _editingPersonIndex = null;
        } else if (_editingPersonIndex != null &&
            _editingPersonIndex! > index) {
          _editingPersonIndex = _editingPersonIndex! - 1;
        }
      }
    });
  }

  void _handleConfirmPerson(int index) {
    setState(() {
      if (index >= 0 && index < _selectedResponsiblePersons.length) {
        final person = _selectedResponsiblePersons[index];
        final name = person['name']?.toString().trim() ?? '';
        final email = person['email']?.toString().trim() ?? '';

        if (name.isNotEmpty && email.isNotEmpty) {
          _editingPersonIndex = null;
        }
      }
    });
  }

  void _handleFrequencyChange() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('building_responsible_persons.select_frequency'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFrequencyOption(
              'building_responsible_persons.daily'.tr(),
              'daily',
            ),
            _buildFrequencyOption(
              'building_responsible_persons.weekly'.tr(),
              'weekly',
            ),
            _buildFrequencyOption(
              'building_responsible_persons.monthly'.tr(),
              'monthly',
            ),
            _buildFrequencyOption(
              'building_responsible_persons.yearly'.tr(),
              'yearly',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyOption(String frequency, String key) {
    return ListTile(
      title: Text(frequency),
      onTap: () {
        setState(() {
          _selectedFrequencyKey = key;
        });
        Navigator.of(context).pop();
      },
    );
  }

  void _handleReportOptionToggle(String option) {
    setState(() {
      _reportOptions[option] = !(_reportOptions[option] ?? false);
    });
  }

  String _getReportOptionLabel(String key) {
    return 'building_responsible_persons.$key'.tr();
  }

  bool _validateCurrentForm() {
    if (_savedReportConfigs.isNotEmpty) {
      return true;
    }
    if (_reportingNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'building_responsible_persons.validation_name_required'.tr(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    final hasSelectedOption = _reportOptions.values.any(
      (value) => value == true,
    );
    if (!hasSelectedOption) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'building_responsible_persons.validation_option_required'.tr(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  void _handleCreateOwnRoutine() {
    if (!_validateCurrentForm()) {
      return;
    }

    List<String> reportContents = [];
    if (_reportOptions['total_consumption'] == true) {
      reportContents.add('TotalConsumption');
    }
    if (_reportOptions['rooms_by_consumption'] == true) {
      reportContents.add('ConsumptionByRoom');
    }
    if (_reportOptions['peak_loads'] == true) {
      reportContents.add('PeakLoads');
    }
    if (_reportOptions['anomalies'] == true) {
      reportContents.add('Anomalies');
    }
    if (_reportOptions['underutilization'] == true) {
      reportContents.add('InefficientUsage');
    }

    String interval = 'Monthly';
    switch (_selectedFrequencyKey) {
      case 'daily':
        interval = 'Daily';
        break;
      case 'weekly':
        interval = 'Weekly';
        break;
      case 'monthly':
        interval = 'Monthly';
        break;
      case 'yearly':
        interval = 'Yearly';
        break;
    }

    final wasEditing = _editingConfigIndex != null;

    setState(() {
      final configData = {
        'name': _reportingNameController.text.trim(),
        'interval': interval,
        'intervalKey': _selectedFrequencyKey,
        'reportContents': reportContents,
        'reportOptions': Map<String, bool>.from(_reportOptions),
        'completed': true,
      };

      if (_editingConfigIndex != null) {
        _savedReportConfigs[_editingConfigIndex!] = configData;
        _editingConfigIndex = null;
      } else {
        _savedReportConfigs.add(configData);
      }

      _reportingNameController.clear();
      _selectedFrequencyKey = 'monthly';
      _reportOptions = {
        'total_consumption': true,
        'peak_loads': false,
        'anomalies': false,
        'rooms_by_consumption': true,
        'underutilization': true,
      };
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasEditing
              ? 'building_responsible_persons.routine_updated'.tr()
              : 'building_responsible_persons.routine_saved'.tr(),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_isLoading) return;

    // Validate responsible persons - at least one required
    if (_selectedResponsiblePersons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select or create at least one responsible person',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (widget.reportingJson != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Edit functionality is not available for reports'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Validate all persons have required fields
    for (var i = 0; i < _selectedResponsiblePersons.length; i++) {
      final person = _selectedResponsiblePersons[i];
      final name = person['name']?.toString().trim() ?? '';
      final email = person['email']?.toString().trim() ?? '';

      if (name.isEmpty || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please complete all required fields for responsible person ${i + 1}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate form
    if (!_validateCurrentForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Build reportingRecipients from all selected persons
      List<Map<String, dynamic>> reportingRecipients = [];

      for (var person in _selectedResponsiblePersons) {
        final contactId = person['id'];
        final method = person['method'];
        final idString = contactId?.toString() ?? '';
        final isMongoObjectId =
            idString.length == 24 &&
            RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(idString);
        final isFromDialog =
            method == 'domain' &&
            contactId != null &&
            idString.isNotEmpty &&
            isMongoObjectId;

        Map<String, dynamic> recipientData;
        if (isFromDialog) {
          recipientData = {'id': contactId.toString()};
        } else {
          recipientData = {
            'name': person['name'] ?? '',
            'email': person['email'] ?? '',
          };
          if (person['phone'] != null &&
              person['phone'].toString().isNotEmpty) {
            recipientData['phone'] = person['phone'];
          }
        }

        reportingRecipients.add(recipientData);
      }

      // Build reportConfigs from saved configs
      List<Map<String, dynamic>> reportConfigs = [];
      for (var savedConfig in _savedReportConfigs) {
        reportConfigs.add({
          'name': savedConfig['name'] ?? '',
          'interval': savedConfig['interval'] ?? 'Monthly',
          'reportContents': List<String>.from(
            savedConfig['reportContents'] ?? [],
          ),
        });
      }

      // Also check if current form has data
      if (_reportingNameController.text.trim().isNotEmpty ||
          _reportOptions.values.any((value) => value == true)) {
        List<String> reportContents = [];
        if (_reportOptions['total_consumption'] == true) {
          reportContents.add('TotalConsumption');
        }
        if (_reportOptions['rooms_by_consumption'] == true) {
          reportContents.add('ConsumptionByRoom');
        }
        if (_reportOptions['peak_loads'] == true) {
          reportContents.add('PeakLoads');
        }
        if (_reportOptions['anomalies'] == true) {
          reportContents.add('Anomalies');
        }
        if (_reportOptions['underutilization'] == true) {
          reportContents.add('InefficientUsage');
        }

        String interval = 'Monthly';
        switch (_selectedFrequencyKey) {
          case 'daily':
            interval = 'Daily';
            break;
          case 'weekly':
            interval = 'Weekly';
            break;
          case 'monthly':
            interval = 'Monthly';
            break;
          case 'yearly':
            interval = 'Yearly';
            break;
        }

        reportConfigs.add({
          'name': _reportingNameController.text.isNotEmpty
              ? _reportingNameController.text.trim()
              : 'Executive Weekly Report',
          'interval': interval,
          'reportContents': reportContents,
        });
      }

      // Add reportConfig to all recipients if there are configs
      // if (reportConfigs.isNotEmpty) {
      //   for (var recipient in reportingRecipients) {
      //     recipient['reportConfig'] = reportConfigs;
      //   }
      // }

      final requestBody = {
        'reportingRecipients': reportingRecipients,
        if (reportConfigs.isNotEmpty) 'reportConfigs': reportConfigs,
      };
      print(requestBody);
      final response = await _dioClient.dio.patch(
        '/api/v1/buildings/${widget.buildingId}',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report setup saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          context.goNamed(Routelists.dashboard);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save report setup: ${response.statusCode}',
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
            content: Text('Error: ${e.toString()}'),
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

  Widget _buildReportOptionCheckbox(String option) {
    final isSelected = _reportOptions[option] ?? false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleReportOptionToggle(option),
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 1),
                  borderRadius: BorderRadius.zero,
                  color: Colors.white,
                ),
                child: isSelected
                    ? const Icon(Icons.close, size: 16, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                _getReportOptionLabel(option),
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
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
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        SizedBox(
                          width: screenSize.width < 600
                              ? screenSize.width * 0.95
                              : screenSize.width < 1200
                              ? screenSize.width * 0.5
                              : screenSize.width * 0.6,
                          child: PageHeaderRow(
                            title: 'dashboard.report_setup.title'.tr(),
                            showBackButton: true,
                            onBack: () => context.pop(),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: screenSize.width < 600
                              ? screenSize.width * 0.95
                              : screenSize.width < 1200
                              ? screenSize.width * 0.5
                              : screenSize.width * 0.6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Responsible Persons Section
                              const Text(
                                'Responsible Persons',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Display all selected responsible persons
                              if (_selectedResponsiblePersons.isNotEmpty)
                                ..._selectedResponsiblePersons.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final person = entry.value;
                                  final isEditing =
                                      _editingPersonIndex == index;

                                  return Column(
                                    children: [
                                      if (isEditing) ...[
                                        // Show text fields when editing
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          height: 50,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF8B9A5B),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.zero,
                                            color: Colors.white,
                                          ),
                                          child: TextFormField(
                                            initialValue: person['name'] ?? '',
                                            decoration: InputDecoration(
                                              hintText: 'Name',
                                              border: InputBorder.none,
                                              hintStyle: AppTextStyles
                                                  .bodyMedium
                                                  .copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: Colors.black87,
                                                ),
                                            onChanged: (value) {
                                              _handlePersonNameChanged(
                                                index,
                                                value,
                                              );
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          height: 50,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF8B9A5B),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.zero,
                                            color: Colors.white,
                                          ),
                                          child: TextFormField(
                                            initialValue: person['email'] ?? '',
                                            decoration: InputDecoration(
                                              hintText: 'Email',
                                              border: InputBorder.none,
                                              hintStyle: AppTextStyles
                                                  .bodyMedium
                                                  .copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: Colors.black87,
                                                ),
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            onChanged: (value) {
                                              _handlePersonEmailChanged(
                                                index,
                                                value,
                                              );
                                            },
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  _handleConfirmPerson(index);
                                                },
                                                borderRadius: BorderRadius.zero,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    'Confirm',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      decoration: TextDecoration
                                                          .underline,
                                                      color: Colors.blue[700],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else
                                        // Show confirmation box when confirmed
                                        Container(
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
                                                    person['name'] != null &&
                                                            person['name']
                                                                .toString()
                                                                .isNotEmpty
                                                        ? '${person['name']}      ${person['email'] != null && person['email'].toString().isNotEmpty ? person['email'] : ''}'
                                                        : person['email'] !=
                                                                  null &&
                                                              person['email']
                                                                  .toString()
                                                                  .isNotEmpty
                                                        ? person['email']
                                                        : '',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _editingPersonIndex =
                                                            index;
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
                                                        'Edit',
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
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      _handleRemovePerson(
                                                        index,
                                                      );
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
                                    ],
                                  );
                                }),
                              // Action links - always show to add more
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _handleAutomaticFromDomain,
                                      borderRadius: BorderRadius.zero,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '+',
                                              style: TextStyle(
                                                fontSize: screenSize.width < 600
                                                    ? 14
                                                    : 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            SizedBox(
                                              width: screenSize.width < 600
                                                  ? 4
                                                  : 8,
                                            ),
                                            Flexible(
                                              child: Text(
                                                'building_contact_person.automatic_from_domain'
                                                    .tr(),
                                                style: TextStyle(
                                                  fontSize:
                                                      screenSize.width < 600
                                                      ? 12
                                                      : 16,
                                                  color: Colors.black,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: screenSize.width < 600 ? 12 : 24,
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _handleCreatePerson,
                                      borderRadius: BorderRadius.zero,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '+',
                                              style: TextStyle(
                                                fontSize: screenSize.width < 600
                                                    ? 14
                                                    : 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            SizedBox(
                                              width: screenSize.width < 600
                                                  ? 4
                                                  : 8,
                                            ),
                                            Flexible(
                                              child: Text(
                                                'Create new person',
                                                style: TextStyle(
                                                  fontSize:
                                                      screenSize.width < 600
                                                      ? 12
                                                      : 16,
                                                  color: Colors.black,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              // Report Setup Section
                              const Text(
                                'Report Setup',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Display saved report configs
                              if (_savedReportConfigs.isNotEmpty &&
                                  widget.reportingJson == null) ...[
                                ..._savedReportConfigs.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final savedConfig = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFF8B9A5B),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.zero,
                                      color: Colors.grey[50],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Image.asset(
                                              'assets/images/check.png',
                                              width: 16,
                                              height: 16,
                                              color: const Color(0xFF238636),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                savedConfig['name'] ?? '',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                              ),
                                            ),
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _editingConfigIndex = index;
                                                    _reportingNameController
                                                            .text =
                                                        savedConfig['name'] ??
                                                        '';
                                                    _selectedFrequencyKey =
                                                        savedConfig['intervalKey'] ??
                                                        'monthly';
                                                    if (savedConfig['reportOptions'] !=
                                                        null) {
                                                      _reportOptions =
                                                          Map<
                                                            String,
                                                            bool
                                                          >.from(
                                                            savedConfig['reportOptions'],
                                                          );
                                                    }
                                                  });
                                                },
                                                borderRadius: BorderRadius.zero,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    'Edit',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    if (_editingConfigIndex ==
                                                        index) {
                                                      _editingConfigIndex =
                                                          null;
                                                      _reportingNameController
                                                          .clear();
                                                      _selectedFrequencyKey =
                                                          'monthly';
                                                      _reportOptions = {
                                                        'total_consumption':
                                                            true,
                                                        'peak_loads': false,
                                                        'anomalies': false,
                                                        'rooms_by_consumption':
                                                            true,
                                                        'underutilization':
                                                            true,
                                                      };
                                                    }
                                                    _savedReportConfigs
                                                        .removeAt(index);
                                                  });
                                                },
                                                borderRadius: BorderRadius.zero,
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(
                                                    Icons.close,
                                                    size: 18,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Interval: ${savedConfig['interval'] ?? ''}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(color: Colors.black87),
                                        ),
                                        if (savedConfig['reportContents'] !=
                                                null &&
                                            (savedConfig['reportContents']
                                                    as List)
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            (savedConfig['reportContents']
                                                    as List)
                                                .join(', '),
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: Colors.grey[700],
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 16),
                              ],
                              // Reporting Name Field
                              Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF8B9A5B),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: TextFormField(
                                  controller: _reportingNameController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'building_responsible_persons.reporting_name_hint'
                                            .tr(),
                                    border: InputBorder.none,
                                    hintStyle: AppTextStyles.bodyMedium
                                        .copyWith(color: Colors.grey[600]),
                                  ),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Frequency Field
                              Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF8B9A5B),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedFrequency,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(color: Colors.black87),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _handleFrequencyChange,
                                        child: Text(
                                          '+ ${'building_responsible_persons.change_frequency'.tr()}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                decoration:
                                                    TextDecoration.underline,
                                                color: Colors.black,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Report Options Checkboxes
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildReportOptionCheckbox(
                                    'total_consumption',
                                  ),
                                  _buildReportOptionCheckbox('peak_loads'),
                                  _buildReportOptionCheckbox('anomalies'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildReportOptionCheckbox(
                                    'rooms_by_consumption',
                                  ),
                                  _buildReportOptionCheckbox(
                                    'underutilization',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              // Create own routine link
                              if (_editingConfigIndex == null &&
                                  widget.reportingJson == null)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _handleCreateOwnRoutine,
                                    child: Text(
                                      '+ ${'building_responsible_persons.create_own_routines'.tr()}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              // else
                              //   Material(
                              //     color: Colors.transparent,
                              //     child: InkWell(
                              //       onTap: _handleCreateOwnRoutine,
                              //       child: Text(
                              //         'building_responsible_persons.update_routine'
                              //             .tr(),
                              //         style: AppTextStyles.bodyMedium.copyWith(
                              //           decoration: TextDecoration.underline,
                              //           color: Colors.blue[700],
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              const SizedBox(height: 32),
                              // Save button
                              Center(
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : PrimaryOutlineButton(
                                        label: 'Save',
                                        width: 260,
                                        onPressed: _handleSave,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
  }
}
