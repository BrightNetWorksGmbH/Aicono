import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/injection_container.dart';

class BuildingRecipientPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? buildingId;
  final String? siteId;
  final String? contactPerson; // JSON string of contact person
  final String? totalArea;
  final String? numberOfRooms;
  final String? constructionYear;

  const BuildingRecipientPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.buildingId,
    this.siteId,
    this.contactPerson,
    this.totalArea,
    this.numberOfRooms,
    this.constructionYear,
  });

  @override
  State<BuildingRecipientPage> createState() => _BuildingRecipientPageState();
}

class _BuildingRecipientPageState extends State<BuildingRecipientPage> {
  final List<Map<String, dynamic>> _recipients = [];
  Map<String, dynamic>? _contactPerson;
  final DioClient _dioClient = sl<DioClient>();
  final Set<String> _selectedContactIds =
      {}; // Track selected contacts from domain
  bool _isConfirmed = false; // Track if recipients are confirmed
  final Set<String> _confirmedRecipientIds =
      {}; // Track which individual recipients are confirmed
  final Map<String, bool> _editingRecipients =
      {}; // Track which recipients are being edited
  final Map<String, Map<String, dynamic>> _recipientConfigs =
      {}; // Store report configurations for each recipient

  @override
  void initState() {
    super.initState();
    // Parse contact person from JSON if provided
    if (widget.contactPerson != null && widget.contactPerson!.isNotEmpty) {
      try {
        _contactPerson = jsonDecode(widget.contactPerson!);
      } catch (e) {
        // If parsing fails, ignore
        _contactPerson = null;
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  String _getContactPersonDisplay() {
    if (_contactPerson == null) return '';
    final name = _contactPerson!['name'] ?? '';
    final email = _contactPerson!['email'] ?? '';
    if (name.isNotEmpty && email.isNotEmpty) {
      return '$name $email';
    } else if (name.isNotEmpty) {
      return name;
    } else if (email.isNotEmpty) {
      return email;
    }
    return '';
  }

  String _getFloorPlanStatus() {
    // Return floor plan status - this would come from building data
    // For now, return a default status
    return 'building_recipient.floor_plan_status'.tr();
  }

  void _handleAddContact() {
    setState(() {
      final newRecipientId = DateTime.now().millisecondsSinceEpoch.toString();
      _recipients.add({'name': '', 'email': '', 'id': newRecipientId});
      // Set the new recipient as editing so text fields are shown
      _editingRecipients[newRecipientId] = true;
      // Don't reset _isConfirmed - keep confirmed recipients as confirmed
    });
  }

  Future<void> _handleAutomaticFromDomain() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch responsible persons from endpoint
      final buildingId = widget.buildingId ?? '';
      final response = await _dioClient.dio.get(
        '/api/v1/reporting/recipients',
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
          // Direct array response
          contactsList = List<Map<String, dynamic>>.from(response.data);
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;

          // Check for 'data' field first (most common structure)
          if (responseMap['data'] != null) {
            if (responseMap['data'] is List) {
              contactsList = List<Map<String, dynamic>>.from(
                responseMap['data'],
              );
            }
          }
          // Check for 'contacts' field
          else if (responseMap['contacts'] != null) {
            if (responseMap['contacts'] is List) {
              contactsList = List<Map<String, dynamic>>.from(
                responseMap['contacts'],
              );
            }
          }
          // Check for 'results' field (alternative structure)
          else if (responseMap['results'] != null) {
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
    // Initialize temp selection with already selected contacts
    final tempSelectedIds = Set<String>.from(_selectedContactIds);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          backgroundColor: Colors.white,
          title: Text('building_recipient.contacts_from_domain'.tr()),
          content: SizedBox(
            width: screenSize.width < 600
                ? screenSize.width
                : screenSize.width < 1200
                ? screenSize.width * 0.5
                : screenSize.width * 0.5,
            child: contactsList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('building_recipient.no_contacts_found'.tr()),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: contactsList.length,
                    itemBuilder: (context, index) {
                      final contact = contactsList[index];
                      final name = contact['name'] ?? contact['fullName'] ?? '';
                      final email =
                          contact['email'] ?? contact['emailAddress'] ?? '';
                      final contactId =
                          contact['_id'] ??
                          contact['id'] ??
                          ''; // Prioritize _id from MongoDB

                      final isSelected = tempSelectedIds.contains(contactId);

                      return ListTile(
                        title: Text(name.isNotEmpty ? name : 'Unbekannt'),
                        subtitle: email.isNotEmpty ? Text(email) : null,
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                tempSelectedIds.add(contactId);
                              } else {
                                tempSelectedIds.remove(contactId);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Cancel - don't save selections
                Navigator.of(context).pop();
              },
              child: Text('building_recipient.cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                // Confirm - save selected contacts
                setState(() {
                  // Clear existing selections from dialog
                  final existingDialogRecipients = _recipients
                      .where((r) => r['method'] == 'domain')
                      .toList();
                  for (var recipient in existingDialogRecipients) {
                    final id = recipient['id']?.toString();
                    if (id != null) {
                      _selectedContactIds.remove(id);
                      _recipients.removeWhere((r) => r['id'] == id);
                    }
                  }

                  // Add newly selected contacts
                  _selectedContactIds.clear();
                  for (var contact in contactsList) {
                    final contactId = contact['_id'] ?? contact['id'] ?? '';
                    if (tempSelectedIds.contains(contactId)) {
                      final name = contact['name'] ?? contact['fullName'] ?? '';
                      final email =
                          contact['email'] ?? contact['emailAddress'] ?? '';

                      final recipientId = contactId.isNotEmpty
                          ? contactId
                          : DateTime.now().millisecondsSinceEpoch.toString();

                      _selectedContactIds.add(contactId);
                      _recipients.add({
                        'name': name,
                        'email': email,
                        'phone': contact['phone'] ?? '',
                        'id': recipientId,
                        'method': 'domain',
                      });

                      // Mark recipients from domain as confirmed immediately
                      _confirmedRecipientIds.add(recipientId);
                    }
                  }

                  // Mark as confirmed when selecting from domain
                  if (_recipients.isNotEmpty) {
                    _isConfirmed = true;
                  }
                  // Clear editing state for newly added recipients
                  _editingRecipients.clear();
                });
                Navigator.of(context).pop();
              },
              child: Text('building_recipient.confirm'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _handleUploadContact() {
    // Add a new empty recipient field
    _handleAddContact();
  }

  void _handleRemoveRecipient(String id) {
    // Allow removing all recipients
    setState(() {
      _recipients.removeWhere((recipient) => recipient['id'] == id);
      // Also remove from selected contact IDs if it was from domain
      _selectedContactIds.remove(id);
      // Remove from confirmed recipients
      _confirmedRecipientIds.remove(id);
      // Remove from editing state
      _editingRecipients.remove(id);
    });
  }

  void _handleRecipientNameChanged(String id, String name) {
    setState(() {
      final index = _recipients.indexWhere(
        (recipient) => recipient['id'] == id,
      );
      if (index != -1) {
        _recipients[index]['name'] = name;
      }
    });
  }

  void _handleRecipientEmailChanged(String id, String email) {
    setState(() {
      final index = _recipients.indexWhere(
        (recipient) => recipient['id'] == id,
      );
      if (index != -1) {
        _recipients[index]['email'] = email;
      }
    });
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _validateRecipients() {
    if (_recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('building_recipient.validation_no_recipients'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    for (var recipient in _recipients) {
      final name = recipient['name']?.toString().trim() ?? '';
      final email = recipient['email']?.toString().trim() ?? '';

      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('building_recipient.validation_name_required'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('building_recipient.validation_email_required'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      if (!_isValidEmail(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('building_recipient.validation_email_invalid'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    return true;
  }

  void _handleContinue() {
    // Validate all recipients first
    if (!_validateRecipients()) {
      return; // Validation failed, don't proceed
    }

    // Check if there are any unconfirmed recipients
    final hasUnconfirmed = _recipients.any((r) {
      final id = r['id']?.toString();
      return id != null && !_confirmedRecipientIds.contains(id);
    });

    if (hasUnconfirmed) {
      // Confirm all recipients
      setState(() {
        _isConfirmed = true;
        // Mark all recipients as confirmed
        for (var recipient in _recipients) {
          final id = recipient['id']?.toString();
          if (id != null) {
            _confirmedRecipientIds.add(id);
          }
        }
        // Clear editing state
        _editingRecipients.clear();
      });
      return;
    }

    // If confirmed, navigate to responsible persons page to add report configs for all users
    // This will combine individual recipient configs with all-user configs
    context.pushNamed(
      Routelists.buildingResponsiblePersons,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.buildingAddress != null &&
            widget.buildingAddress!.isNotEmpty)
          'buildingAddress': widget.buildingAddress!,
        if (widget.buildingName != null) 'buildingName': widget.buildingName!,
        if (widget.buildingId != null) 'buildingId': widget.buildingId!,
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
        'allRecipients': jsonEncode(_recipients),
        'recipientConfigs': jsonEncode(_recipientConfigs),
        'createForAll': 'true', // Flag to indicate "create for all" mode
      },
    );
  }

  void _handleEditRecipient(String id) {
    // Show dialog with reporting configuration form
    final recipient = _recipients.firstWhere((r) => r['id'] == id);
    _showReportingConfigDialog(recipient);
  }

  void _showReportingConfigDialog(Map<String, dynamic> recipient) {
    final recipientId = recipient['id']?.toString() ?? '';
    final recipientName = recipient['name']?.toString() ?? '';

    // Store multiple saved routines for this recipient
    final List<Map<String, dynamic>> savedRoutines = [];

    // Load existing configs if available
    if (recipientId.isNotEmpty && _recipientConfigs.containsKey(recipientId)) {
      final config = _recipientConfigs[recipientId]!;
      // If config has routines list, use it; otherwise create one routine from existing config
      if (config['routines'] != null && config['routines'] is List) {
        savedRoutines.addAll(
          List<Map<String, dynamic>>.from(config['routines']),
        );
      } else {
        // Convert old single config to routines format
        savedRoutines.add({
          'name': config['name'] ?? '',
          'intervalKey': config['intervalKey'] ?? 'monthly',
          'reportOptions': Map<String, bool>.from(
            config['reportOptions'] ??
                {
                  'total_consumption': true,
                  'peak_loads': false,
                  'anomalies': false,
                  'rooms_by_consumption': true,
                  'underutilization': true,
                },
          ),
        });
      }
    }

    final Size screenSize = MediaQuery.of(context).size;

    // Current form controllers and state
    final TextEditingController currentReportingNameController =
        TextEditingController();
    String currentSelectedFrequencyKey = 'monthly';
    Map<String, bool> currentReportOptions = {
      'total_consumption': true,
      'peak_loads': false,
      'anomalies': false,
      'rooms_by_consumption': true,
      'underutilization': true,
    };
    int? editingRoutineIndex; // Track which routine is being edited

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Function to validate current form
          bool validateCurrentForm() {
            if (currentReportingNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'building_responsible_persons.validation_name_required'
                        .tr(),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return false;
            }

            // Check if at least one checkbox is selected
            final hasSelectedOption = currentReportOptions.values.any(
              (value) => value == true,
            );
            if (!hasSelectedOption) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'building_responsible_persons.validation_at_least_one_option'
                        .tr(),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return false;
            }

            return true;
          }

          // Function to edit a routine
          void editRoutine(int index) {
            final routine = savedRoutines[index];
            setDialogState(() {
              editingRoutineIndex = index;
              currentReportingNameController.text = routine['name'] ?? '';
              currentSelectedFrequencyKey = routine['intervalKey'] ?? 'monthly';
              currentReportOptions = Map<String, bool>.from(
                routine['reportOptions'] ??
                    {
                      'total_consumption': true,
                      'peak_loads': false,
                      'anomalies': false,
                      'rooms_by_consumption': true,
                      'underutilization': true,
                    },
              );
            });
          }

          // Function to save current form as a routine
          void saveCurrentRoutine() {
            if (!validateCurrentForm()) {
              return;
            }

            final wasEditing = editingRoutineIndex != null;

            setDialogState(() {
              final routineData = {
                'name': currentReportingNameController.text.trim(),
                'intervalKey': currentSelectedFrequencyKey,
                'reportOptions': Map<String, bool>.from(currentReportOptions),
              };

              if (editingRoutineIndex != null) {
                // Update existing routine
                savedRoutines[editingRoutineIndex!] = routineData;
                editingRoutineIndex = null;
              } else {
                // Add new routine
                savedRoutines.add(routineData);
              }

              // Reset form for new routine
              currentReportingNameController.clear();
              currentSelectedFrequencyKey = 'monthly';
              currentReportOptions = {
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

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: Colors.white,
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding: const EdgeInsets.all(24),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'building_recipient.reporting_dialog_title'.tr(
                      namedArgs: {'name': recipientName},
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
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
                  ? screenSize.width * 0.6
                  : screenSize.width * 0.5,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle
                    Text(
                      'building_recipient.reporting_dialog_subtitle'.tr(
                        namedArgs: {'name': recipientName},
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Display saved routines above the form
                    if (savedRoutines.isNotEmpty) ...[
                      ...savedRoutines.asMap().entries.map((entry) {
                        final index = entry.key;
                        final routine = entry.value;
                        final routineName = routine['name'] ?? '';
                        final routineIntervalKey =
                            routine['intervalKey'] ?? 'monthly';
                        return Container(
                          margin: EdgeInsets.only(
                            bottom: index < savedRoutines.length - 1 ? 16 : 24,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF8B9A5B),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green[600],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      routineName.isNotEmpty
                                          ? routineName
                                          : 'building_responsible_persons.reporting_name_hint'
                                                .tr(),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'building_responsible_persons.$routineIntervalKey'
                                          .tr(),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Edit button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => editRoutine(index),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      'building_recipient.edit'.tr(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue[700],
                                        decoration: TextDecoration.underline,
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
                                    setDialogState(() {
                                      if (editingRoutineIndex == index) {
                                        // If editing this routine, reset form
                                        editingRoutineIndex = null;
                                        currentReportingNameController.clear();
                                        currentSelectedFrequencyKey = 'monthly';
                                        currentReportOptions = {
                                          'total_consumption': true,
                                          'peak_loads': false,
                                          'anomalies': false,
                                          'rooms_by_consumption': true,
                                          'underutilization': true,
                                        };
                                      }
                                      savedRoutines.removeAt(index);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(4),
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
                        );
                      }),
                    ],
                    // Current form fields
                    // Report Name Field
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF8B9A5B),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextFormField(
                        controller: currentReportingNameController,
                        decoration: InputDecoration(
                          hintText:
                              'building_responsible_persons.reporting_name_hint'
                                  .tr(),
                          border: InputBorder.none,
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey[600],
                          ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF8B9A5B),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'building_responsible_persons.$currentSelectedFrequencyKey'
                                  .tr(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // Show frequency selection dialog
                                showDialog(
                                  context: context,
                                  builder: (freqContext) => AlertDialog(
                                    title: Text(
                                      'building_responsible_persons.select_frequency'
                                          .tr(),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          title: Text(
                                            'building_responsible_persons.daily'
                                                .tr(),
                                          ),
                                          onTap: () {
                                            setDialogState(() {
                                              currentSelectedFrequencyKey =
                                                  'daily';
                                            });
                                            Navigator.of(freqContext).pop();
                                          },
                                        ),
                                        ListTile(
                                          title: Text(
                                            'building_responsible_persons.weekly'
                                                .tr(),
                                          ),
                                          onTap: () {
                                            setDialogState(() {
                                              currentSelectedFrequencyKey =
                                                  'weekly';
                                            });
                                            Navigator.of(freqContext).pop();
                                          },
                                        ),
                                        ListTile(
                                          title: Text(
                                            'building_responsible_persons.monthly'
                                                .tr(),
                                          ),
                                          onTap: () {
                                            setDialogState(() {
                                              currentSelectedFrequencyKey =
                                                  'monthly';
                                            });
                                            Navigator.of(freqContext).pop();
                                          },
                                        ),
                                        ListTile(
                                          title: Text(
                                            'building_responsible_persons.yearly'
                                                .tr(),
                                          ),
                                          onTap: () {
                                            setDialogState(() {
                                              currentSelectedFrequencyKey =
                                                  'yearly';
                                            });
                                            Navigator.of(freqContext).pop();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                '+ ${'building_responsible_persons.change_frequency'.tr()}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  decoration: TextDecoration.underline,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Report Options Checkboxes - Row 1
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.start,
                      children: [
                        _buildReportOptionCheckbox(
                          'total_consumption',
                          currentReportOptions,
                          setDialogState,
                        ),
                        _buildReportOptionCheckbox(
                          'peak_loads',
                          currentReportOptions,
                          setDialogState,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Report Options Checkboxes - Row 2
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.start,
                      children: [
                        _buildReportOptionCheckbox(
                          'anomalies',
                          currentReportOptions,
                          setDialogState,
                        ),
                        _buildReportOptionCheckbox(
                          'rooms_by_consumption',
                          currentReportOptions,
                          setDialogState,
                        ),
                        _buildReportOptionCheckbox(
                          'underutilization',
                          currentReportOptions,
                          setDialogState,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Create own routine link (only show when not editing)
                    if (editingRoutineIndex == null)
                      Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: saveCurrentRoutine,
                            child: Text(
                              '+ ${'building_responsible_persons.create_own_routines'.tr()}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                decoration: TextDecoration.underline,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      // Show update button when editing
                      Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: saveCurrentRoutine,
                            child: Text(
                              'building_responsible_persons.update_routine'
                                  .tr(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                decoration: TextDecoration.underline,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              // Done button
              SizedBox(
                width: double.infinity,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF8B9A5B),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Save current form if it has data
                        if (currentReportingNameController.text
                                .trim()
                                .isNotEmpty ||
                            currentReportOptions.values.any(
                              (value) => value == true,
                            )) {
                          if (!validateCurrentForm()) {
                            return;
                          }
                          saveCurrentRoutine();
                        }

                        // Build report configs from all saved routines
                        final List<Map<String, dynamic>> reportConfigs = [];
                        for (var routine in savedRoutines) {
                          // Build report contents from selected options
                          final routineOptions =
                              routine['reportOptions'] as Map<String, bool>;
                          List<String> reportContents = [];
                          if (routineOptions['total_consumption'] == true) {
                            reportContents.add('TotalConsumption');
                          }
                          if (routineOptions['rooms_by_consumption'] == true) {
                            reportContents.add('ConsumptionByRoom');
                          }
                          if (routineOptions['peak_loads'] == true) {
                            reportContents.add('PeakLoads');
                          }
                          if (routineOptions['anomalies'] == true) {
                            reportContents.add('Anomalies');
                          }
                          if (routineOptions['underutilization'] == true) {
                            reportContents.add('InefficientUsage');
                          }

                          // Map frequency key to API format
                          String interval = 'Monthly';
                          switch (routine['intervalKey']) {
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
                            'name': routine['name'] ?? '',
                            'interval': interval,
                            'reportContents': reportContents,
                          });
                        }

                        // Save all configs
                        setState(() {
                          _recipientConfigs[recipientId] = {
                            'routines': savedRoutines,
                            'reportConfigs': reportConfigs,
                          };
                        });

                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Center(
                        child: Text(
                          'building_recipient.done'.tr(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportOptionCheckbox(
    String option,
    Map<String, bool> reportOptions,
    StateSetter setDialogState,
  ) {
    final isSelected = reportOptions[option] ?? false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setDialogState(() {
            reportOptions[option] = !isSelected;
          });
        },
        borderRadius: BorderRadius.circular(4),
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
                  borderRadius: BorderRadius.circular(4),
                  color: isSelected ? const Color(0xFF8B9A5B) : Colors.white,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'building_responsible_persons.$option'.tr(),
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCreateReportForAll() {
    // Navigate to responsible persons page for all recipients at once
    // Encode all recipients as JSON with their configs
    final recipientsList = _recipients.map((r) {
      final recipientId = r['id']?.toString();
      final recipientData = <String, dynamic>{
        'id': recipientId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'name': (r['name'] ?? '').toString().trim(),
        'email': (r['email'] ?? '').toString().trim(),
        if (r['phone'] != null && (r['phone'] as String).isNotEmpty)
          'phone': (r['phone'] ?? '').toString().trim(),
      };

      // Include reportConfig if recipient has a config
      // The config structure can have 'reportConfigs' array (from dialog) or old format
      if (recipientId != null && _recipientConfigs.containsKey(recipientId)) {
        final config = _recipientConfigs[recipientId]!;

        // Check if config has reportConfigs array (new format from dialog)
        if (config['reportConfigs'] != null &&
            config['reportConfigs'] is List) {
          recipientData['reportConfig'] = List<Map<String, dynamic>>.from(
            config['reportConfigs'],
          );
        } else {
          // Old format - create single reportConfig
          recipientData['reportConfig'] = [
            {
              'name': config['name'] ?? 'Executive Weekly Report',
              'interval': config['interval'] ?? 'Monthly',
              'reportContents': List<String>.from(
                config['reportContents'] ?? [],
              ),
            },
          ];
        }
      }

      return recipientData;
    }).toList();

    final recipientsJson = jsonEncode(recipientsList);

    context.pushNamed(
      Routelists.buildingResponsiblePersons,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.buildingAddress != null &&
            widget.buildingAddress!.isNotEmpty)
          'buildingAddress': widget.buildingAddress!,
        if (widget.buildingName != null) 'buildingName': widget.buildingName!,
        if (widget.buildingId != null) 'buildingId': widget.buildingId!,
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
        'recipients':
            recipientsJson, // Use 'recipients' key for "create for all" mode
        'createForAll':
            'true', // Flag to indicate this is "create for all" mode
      },
    );
  }

  void _handleSkip() {
    // Skip this step and go to responsible persons page
    _handleContinue();
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
              border: Border.all(color: Colors.black, width: 2),
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
                    height: (screenSize.height * 0.95) + 50,
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
                          Material(
                            color: Colors.transparent,
                            child: TopHeader(
                              onLanguageChanged: _handleLanguageChanged,
                              containerWidth: screenSize.width > 500
                                  ? 500
                                  : screenSize.width * 0.98,
                              userInitial: widget.userName?[0].toUpperCase(),
                              verseInitial: null,
                            ),
                          ),
                          if (widget.userName != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'building_recipient.progress_text'.tr(
                                namedArgs: {'name': widget.userName!},
                              ),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.90,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8B9A5B),
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            Text(
                              'building_recipient.progress_text_fallback'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.90,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color(0xFF8B9A5B),
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ],
                          const SizedBox(height: 50),
                          Expanded(
                            child: SingleChildScrollView(
                              child: SizedBox(
                                width: screenSize.width < 600
                                    ? screenSize.width * 0.95
                                    : screenSize.width < 1200
                                    ? screenSize.width * 0.5
                                    : screenSize.width * 0.6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Back button
                                    if (widget.buildingId != null) ...[
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => context.pop(),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 8,
                                              ),
                                              child: Icon(
                                                Icons.arrow_back,
                                                color: Colors.black87,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    // Title
                                    Text(
                                      'building_recipient.title'.tr(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    // Information boxes (matching the image - only Floor plan and Contact person)
                                    // 1. Floor Plan Status (with dark olive-green border)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF8B9A5B),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green[600],
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _getFloorPlanStatus(),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // 2. Contact Person Information Box (if available)
                                    if (_contactPerson != null &&
                                        _getContactPersonDisplay().isNotEmpty)
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFF8B9A5B),
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.green[600],
                                                size: 24,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _getContactPersonDisplay(),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    // Recipient Fields or Confirmation Boxes
                                    if (_recipients.isNotEmpty)
                                      ..._recipients.asMap().entries.map((
                                        entry,
                                      ) {
                                        final recipient = entry.value;
                                        final recipientId = recipient['id'];
                                        final isEditing =
                                            _editingRecipients[recipientId] ??
                                            false;
                                        final isConfirmed =
                                            _confirmedRecipientIds.contains(
                                              recipientId,
                                            );

                                        // Show confirmation box if recipient is confirmed and not editing
                                        if (isConfirmed && !isEditing) {
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  // Checkbox - marked if config exists
                                                  // Container(
                                                  //   width: 24,
                                                  //   height: 24,
                                                  //   decoration: BoxDecoration(
                                                  //     border: Border.all(
                                                  //       color: hasConfig
                                                  //           ? const Color(
                                                  //               0xFF8B9A5B,
                                                  //             )
                                                  //           : Colors.grey[400]!,
                                                  //       width: 2,
                                                  //     ),
                                                  //     borderRadius:
                                                  //         BorderRadius.circular(
                                                  //           4,
                                                  //         ),
                                                  //     color: hasConfig
                                                  //         ? const Color(
                                                  //             0xFF8B9A5B,
                                                  //           )
                                                  //         : Colors.white,
                                                  //   ),
                                                  //   child: hasConfig
                                                  //       ? const Icon(
                                                  //           Icons.check,
                                                  //           size: 16,
                                                  //           color: Colors.white,
                                                  //         )
                                                  //       : null,
                                                  // ),
                                                  // const SizedBox(width: 12),
                                                  // Name
                                                  Expanded(
                                                    child: Text(
                                                      recipient['name']
                                                              ?.toString()
                                                              .trim() ??
                                                          '',
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
                                                      onTap: () =>
                                                          _handleEditRecipient(
                                                            recipientId,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        child: Text(
                                                          'building_recipient.custom_report'
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
                                                ],
                                              ),
                                            ),
                                          );
                                        }

                                        // Show editing fields
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            color: Colors.grey[50],
                                          ),
                                          child: Stack(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  30,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Name Field
                                                    Container(
                                                      height: 50,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: Colors.black54,
                                                          width: 2,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        color: Colors.white,
                                                      ),
                                                      child: TextFormField(
                                                        initialValue:
                                                            recipient['name'],
                                                        decoration: InputDecoration(
                                                          hintText:
                                                              'building_recipient.name_hint'
                                                                  .tr(),
                                                          border:
                                                              InputBorder.none,
                                                          hintStyle: AppTextStyles
                                                              .bodyMedium
                                                              .copyWith(
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                        ),
                                                        style: AppTextStyles
                                                            .bodyMedium
                                                            .copyWith(
                                                              color: Colors
                                                                  .black87,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                        onChanged: (value) {
                                                          _handleRecipientNameChanged(
                                                            recipient['id'],
                                                            value,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    // Email Field
                                                    Container(
                                                      height: 50,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: Colors.black54,
                                                          width: 2,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        color: Colors.white,
                                                      ),
                                                      child: TextFormField(
                                                        initialValue:
                                                            recipient['email'],
                                                        decoration: InputDecoration(
                                                          hintText:
                                                              'building_recipient.email_hint'
                                                                  .tr(),
                                                          border:
                                                              InputBorder.none,
                                                          hintStyle: AppTextStyles
                                                              .bodyMedium
                                                              .copyWith(
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                        ),
                                                        style: AppTextStyles
                                                            .bodyMedium
                                                            .copyWith(
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                        keyboardType:
                                                            TextInputType
                                                                .emailAddress,
                                                        onChanged: (value) {
                                                          _handleRecipientEmailChanged(
                                                            recipient['id'],
                                                            value,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Cancel button at top right corner (only show when recipient is not confirmed)
                                              if (!isConfirmed)
                                                Positioned(
                                                  top: 1,
                                                  right: 1,
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        // Remove recipient
                                                        _handleRemoveRecipient(
                                                          recipient['id'],
                                                        );
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4,
                                                            ),
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Colors
                                                                  .grey[200],
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                        child: Icon(
                                                          Icons.close,
                                                          color:
                                                              Colors.grey[700],
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }),
                                    // Action links - side by side (always show to allow adding more recipients)
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _handleAutomaticFromDomain,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 4,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '+',
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenSize.width < 600
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
                                                      'building_recipient.automatic_from_domain'
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
                                            onTap: _handleUploadContact,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 4,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '+',
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenSize.width < 600
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
                                                      'building_recipient.upload_contact'
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
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    // // Property Checkboxes
                                    // ..._properties.entries.map((entry) {
                                    //   return Padding(
                                    //     padding: const EdgeInsets.only(
                                    //       bottom: 12,
                                    //     ),
                                    //     child: Material(
                                    //       color: Colors.transparent,
                                    //       child: InkWell(
                                    //         onTap: () => _handlePropertyToggle(
                                    //           entry.key,
                                    //         ),
                                    //         borderRadius: BorderRadius.circular(
                                    //           4,
                                    //         ),
                                    //         child: Container(
                                    //           padding:
                                    //               const EdgeInsets.symmetric(
                                    //                 horizontal: 16,
                                    //                 vertical: 12,
                                    //               ),
                                    //           decoration: BoxDecoration(
                                    //             border: Border.all(
                                    //               color: Colors.black54,
                                    //               width: 1,
                                    //             ),
                                    //             borderRadius:
                                    //                 BorderRadius.circular(4),
                                    //           ),
                                    //           child: Row(
                                    //             children: [
                                    //               Container(
                                    //                 width: 20,
                                    //                 height: 20,
                                    //                 decoration: BoxDecoration(
                                    //                   border: Border.all(
                                    //                     color: Colors.black54,
                                    //                     width: 1,
                                    //                   ),
                                    //                   borderRadius:
                                    //                       BorderRadius.circular(
                                    //                         4,
                                    //                       ),
                                    //                   color: entry.value
                                    //                       ? const Color(
                                    //                           0xFF8B9A5B,
                                    //                         )
                                    //                       : Colors.white,
                                    //                 ),
                                    //                 child: entry.value
                                    //                     ? const Icon(
                                    //                         Icons.check,
                                    //                         size: 16,
                                    //                         color: Colors.white,
                                    //                       )
                                    //                     : null,
                                    //               ),
                                    //               const SizedBox(width: 8),
                                    //               Expanded(
                                    //                 child: Text(
                                    //                   'building_recipient.${entry.key}'
                                    //                       .tr(),
                                    //                   style: AppTextStyles
                                    //                       .bodyMedium
                                    //                       .copyWith(
                                    //                         color:
                                    //                             Colors.black87,
                                    //                       ),
                                    //                 ),
                                    //               ),
                                    //             ],
                                    //           ),
                                    //         ),
                                    //       ),
                                    //     ),
                                    //   );
                                    // }),
                                    const SizedBox(height: 32),
                                    // Skip step link
                                    Center(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _handleSkip,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Text(
                                              'building_recipient.skip_step'
                                                  .tr(),
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    decoration: TextDecoration
                                                        .underline,
                                                    color: Colors.black87,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // "Reportings festlegen" button - show when there are unconfirmed recipients (text fields visible)
                                    if (_recipients.any((r) {
                                          final id = r['id']?.toString();
                                          return id != null &&
                                              !_confirmedRecipientIds.contains(
                                                id,
                                              );
                                        }) &&
                                        _recipients.isNotEmpty) ...[
                                      Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: PrimaryOutlineButton(
                                            label:
                                                'building_recipient.button_text'
                                                    .tr(),
                                            width: 260,
                                            onPressed: _handleContinue,
                                          ),
                                        ),
                                      ),
                                    ] else if (_isConfirmed &&
                                        _recipients.isNotEmpty &&
                                        _recipients.every((r) {
                                          final id = r['id']?.toString();
                                          return id != null &&
                                              _recipientConfigs.containsKey(id);
                                        })) ...[
                                      // Show "Complete Setup" button if all recipients are configured
                                      // Center(
                                      //   child: Material(
                                      //     color: Colors.transparent,
                                      //     child: _isLoading
                                      //         ? const CircularProgressIndicator()
                                      //         : PrimaryOutlineButton(
                                      //             label:
                                      //                 'building_recipient.complete_setup'
                                      //                     .tr(),
                                      //             width: 260,
                                      //             onPressed:
                                      //                 _handleCompleteSetup,
                                      //           ),
                                      //   ),
                                      // ),
                                    ] else if (_isConfirmed &&
                                        _recipients.isNotEmpty) ...[
                                      // Show "Continue" button when all are confirmed but not all have configs
                                      // Center(
                                      //   child: Material(
                                      //     color: Colors.transparent,
                                      //     child: PrimaryOutlineButton(
                                      //       label:
                                      //           'building_recipient.button_text_continue'
                                      //               .tr(),
                                      //       width: 260,
                                      //       onPressed: _handleContinue,
                                      //     ),
                                      //   ),
                                      // ),
                                    ],
                                    const SizedBox(height: 16),

                                    // Two buttons: "Create report for all user" and "Reportings festlegen"/"Complete Setup"
                                    // if (_isConfirmed &&
                                    //     _recipients.isNotEmpty) ...[
                                    // "Create report for all user" button
                                    Center(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: PrimaryOutlineButton(
                                          label:
                                              'building_recipient.create_report_for_all'
                                                  .tr(),
                                          width: 260,
                                          onPressed: _handleCreateReportForAll,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  // ],
                                ),
                              ),
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
      ),
    );
  }
}
