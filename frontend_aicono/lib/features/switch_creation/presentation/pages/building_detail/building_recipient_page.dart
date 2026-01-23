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
  final Map<String, bool> _editingRecipients =
      {}; // Track which recipients are being edited
  final Map<String, Map<String, dynamic>> _recipientConfigs =
      {}; // Store report configurations for each recipient
  bool _isLoading = false; // Track loading state for complete setup

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

  String _getBuildingSummary() {
    final parts = <String>[];
    if (widget.totalArea != null && widget.totalArea!.isNotEmpty) {
      final area = double.tryParse(widget.totalArea!);
      if (area != null) {
        parts.add('${area.toStringAsFixed(0)}qm');
      }
    }
    if (widget.numberOfRooms != null && widget.numberOfRooms!.isNotEmpty) {
      final rooms = int.tryParse(widget.numberOfRooms!);
      if (rooms != null) {
        parts.add('$rooms Räume');
        // Add "Sanitäranlage" if it's a building with rooms
        if (rooms > 0) {
          parts.add('Sanitäranlage');
        }
      }
    }
    if (widget.constructionYear != null &&
        widget.constructionYear!.isNotEmpty) {
      parts.add('Baujahr ${widget.constructionYear}');
    }
    return parts.join(' ');
  }

  String _getFloorPlanStatus() {
    // Return floor plan status - this would come from building data
    // For now, return a default status
    return 'building_recipient.floor_plan_status'.tr();
  }

  void _handleAddContact() {
    setState(() {
      _recipients.add({
        'name': '',
        'email': '',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      });
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

                      _selectedContactIds.add(contactId);
                      _recipients.add({
                        'name': name,
                        'email': email,
                        'phone': contact['phone'] ?? '',
                        'id': contactId.isNotEmpty
                            ? contactId
                            : DateTime.now().millisecondsSinceEpoch.toString(),
                        'method': 'domain',
                      });
                    }
                  }

                  // Mark recipients as confirmed if they were selected from dialog
                  if (_recipients.isNotEmpty) {
                    _isConfirmed = true;
                    _editingRecipients.clear();
                  }
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
    // If not confirmed yet, validate and show confirmation
    if (!_isConfirmed) {
      if (_validateRecipients()) {
        setState(() {
          _isConfirmed = true;
          // Clear editing state
          _editingRecipients.clear();
        });
      }
      return;
    }

    // If confirmed and all recipients have configs, show complete setup option
    // Otherwise, this button is just for confirmation (legacy behavior)
    // The actual navigation happens via edit buttons on each recipient
  }

  Future<void> _handleCompleteSetup() async {
    if (_isLoading) return;

    // Check if all recipients have configurations
    final allRecipientsHaveConfig = _recipients.every((recipient) {
      final id = recipient['id']?.toString();
      return id != null && _recipientConfigs.containsKey(id);
    });

    if (!allRecipientsHaveConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('building_recipient.config_all_recipients'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Build reportingRecipients array
      List<Map<String, dynamic>> reportingRecipients = [];
      for (var recipient in _recipients) {
        final id = recipient['id']?.toString();
        if (id != null && _recipientConfigs.containsKey(id)) {
          final config = _recipientConfigs[id]!;
          reportingRecipients.add({
            'name': (recipient['name'] ?? '').toString().trim(),
            'email': (recipient['email'] ?? '').toString().trim(),
            'phone': (recipient['phone'] ?? '').toString().trim(),
            'reportConfig': [
              {
                'name': config['name'] ?? 'Executive Weekly Report',
                'interval': config['interval'] ?? 'Monthly',
                'reportContents': config['reportContents'] ?? [],
              },
            ],
          });
        }
      }

      // Build request body
      final requestBody = {
        'reportingRecipients': reportingRecipients,
        'buildingIds': widget.buildingId != null ? [widget.buildingId!] : [],
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
      };

      // Make API call
      final response = await _dioClient.dio.post(
        '/api/v1/reporting/setup',
        data: requestBody,
      );

      // Check if response is successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Navigate to add additional buildings page
        if (mounted) {
          context.goNamed(
            Routelists.addAdditionalBuildings,
            queryParameters: {
              if (widget.userName != null) 'userName': widget.userName!,
              if (widget.siteId != null && widget.siteId!.isNotEmpty)
                'siteId': widget.siteId!,
            },
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save reporting setup'),
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

  void _handleEditRecipient(String id) {
    // Navigate to responsible persons page with recipient data
    final recipient = _recipients.firstWhere((r) => r['id'] == id);
    final recipientJson = jsonEncode({
      'name': recipient['name'] ?? '',
      'email': recipient['email'] ?? '',
      'phone': recipient['phone'] ?? '',
      'id': id,
    });

    context
        .pushNamed(
          Routelists.buildingResponsiblePersons,
          queryParameters: {
            if (widget.userName != null) 'userName': widget.userName!,
            if (widget.buildingAddress != null &&
                widget.buildingAddress!.isNotEmpty)
              'buildingAddress': widget.buildingAddress!,
            if (widget.buildingName != null)
              'buildingName': widget.buildingName!,
            if (widget.buildingId != null) 'buildingId': widget.buildingId!,
            if (widget.siteId != null && widget.siteId!.isNotEmpty)
              'siteId': widget.siteId!,
            'recipient': recipientJson,
            'allRecipients': jsonEncode(_recipients),
            'recipientConfigs': jsonEncode(_recipientConfigs),
          },
        )
        .then((result) {
          // When returning from responsible persons page, update the config
          if (result != null && result is Map<String, dynamic>) {
            setState(() {
              _recipientConfigs.addAll(
                Map<String, Map<String, dynamic>>.from(result),
              );
            });
          }
        });
  }

  void _handleCreateReportForAll() {
    // Navigate to responsible persons page for all recipients at once
    // Encode all recipients as JSON
    final recipientsJson = jsonEncode(
      _recipients
          .map(
            (r) => {
              'name': (r['name'] ?? '').toString().trim(),
              'email': (r['email'] ?? '').toString().trim(),
              if (r['phone'] != null && (r['phone'] as String).isNotEmpty)
                'phone': (r['phone'] ?? '').toString().trim(),
            },
          )
          .toList(),
    );

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

  void _handleConfirmEditRecipient(String id) {
    // Validate the edited recipient
    final recipient = _recipients.firstWhere((r) => r['id'] == id);
    final name = recipient['name']?.toString().trim() ?? '';
    final email = recipient['email']?.toString().trim() ?? '';

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('building_recipient.validation_name_required'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('building_recipient.validation_email_required'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('building_recipient.validation_email_invalid'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _editingRecipients[id] = false;
      _isConfirmed = true; // Re-confirm after successful edit
    });
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
                                    // Information boxes (similar to contact person step)
                                    // 1. Building Address
                                    if (widget.buildingAddress != null &&
                                        widget.buildingAddress!.isNotEmpty)
                                      Container(
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
                                                  widget.buildingAddress!,
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
                                    // 2. Building Summary
                                    if (_getBuildingSummary().isNotEmpty)
                                      Container(
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
                                                  _getBuildingSummary(),
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
                                    // 3. Floor Plan Status
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
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
                                    // 4. Contact Person Information Box (if available)
                                    if (_contactPerson != null &&
                                        _getContactPersonDisplay().isNotEmpty)
                                      Container(
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
                                    const SizedBox(height: 24),
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

                                        // Show confirmation box if confirmed and not editing
                                        if (_isConfirmed && !isEditing) {
                                          final hasConfig = _recipientConfigs
                                              .containsKey(recipientId);
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
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: hasConfig
                                                            ? const Color(
                                                                0xFF8B9A5B,
                                                              )
                                                            : Colors.grey[400]!,
                                                        width: 2,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      color: hasConfig
                                                          ? const Color(
                                                              0xFF8B9A5B,
                                                            )
                                                          : Colors.white,
                                                    ),
                                                    child: hasConfig
                                                        ? const Icon(
                                                            Icons.check,
                                                            size: 16,
                                                            color: Colors.white,
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 12),
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
                                                          'building_recipient.edit'
                                                              .tr(),
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors
                                                                .blue[700],
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
                                                    // Confirm button when editing
                                                    if (isEditing) ...[
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      Center(
                                                        child: Material(
                                                          color: Colors
                                                              .transparent,
                                                          child: PrimaryOutlineButton(
                                                            label:
                                                                'building_recipient.confirm'
                                                                    .tr(),
                                                            width: 200,
                                                            onPressed: () =>
                                                                _handleConfirmEditRecipient(
                                                                  recipientId,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              // Cancel button at top right corner (only show when not confirmed or when editing)
                                              if (!_isConfirmed || isEditing)
                                                Positioned(
                                                  top: 1,
                                                  right: 1,
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        if (isEditing) {
                                                          // Cancel editing
                                                          setState(() {
                                                            _editingRecipients[recipientId] =
                                                                false;
                                                          });
                                                        } else {
                                                          // Remove recipient
                                                          _handleRemoveRecipient(
                                                            recipient['id'],
                                                          );
                                                        }
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
                                    // Action links - side by side (only show when not confirmed)
                                    if (!_isConfirmed) ...[
                                      const SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _handleAutomaticFromDomain,
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'building_recipient.automatic_from_domain'
                                                          .tr(),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.black,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _handleUploadContact,
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'building_recipient.upload_contact'
                                                          .tr(),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.black,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
                                    // Two buttons: "Create report for all user" and "Reportings festlegen"/"Complete Setup"
                                    if (_isConfirmed &&
                                        _recipients.isNotEmpty) ...[
                                      // "Create report for all user" button
                                      Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: PrimaryOutlineButton(
                                            label:
                                                'building_recipient.create_report_for_all'
                                                    .tr(),
                                            width: 260,
                                            onPressed:
                                                _handleCreateReportForAll,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    // "Reportings festlegen" button or "Complete Setup" button
                                    if (_isConfirmed &&
                                        _recipients.isNotEmpty &&
                                        _recipients.every((r) {
                                          final id = r['id']?.toString();
                                          return id != null &&
                                              _recipientConfigs.containsKey(id);
                                        })) ...[
                                      // Show "Complete Setup" button if all recipients are configured
                                      Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: _isLoading
                                              ? const CircularProgressIndicator()
                                              : PrimaryOutlineButton(
                                                  label:
                                                      'building_recipient.complete_setup'
                                                          .tr(),
                                                  width: 260,
                                                  onPressed:
                                                      _handleCompleteSetup,
                                                ),
                                        ),
                                      ),
                                    ] else if (!_isConfirmed ||
                                        _recipients.isEmpty) ...[
                                      // Show "Reportings festlegen" button
                                      Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: PrimaryOutlineButton(
                                            label: _isConfirmed
                                                ? 'building_recipient.button_text_continue'
                                                      .tr()
                                                : 'building_recipient.button_text'
                                                      .tr(),
                                            width: 260,
                                            onPressed: _handleContinue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
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
