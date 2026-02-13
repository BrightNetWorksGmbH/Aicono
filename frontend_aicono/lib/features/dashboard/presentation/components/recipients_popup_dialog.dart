import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';

/// Popup dialog showing all recipients with search. Shown when user taps
/// the recipients icon in the report detail header.
class RecipientsPopupDialog extends StatefulWidget {
  final List<ReportRecipientEntity> recipients;
  final String buildingId;
  final String reportId;

  const RecipientsPopupDialog({
    super.key,
    required this.recipients,
    required this.buildingId,
    required this.reportId,
  });

  /// Shows the recipients popup dialog.
  static void show(
    BuildContext context,
    List<ReportRecipientEntity> recipients,
    String buildingId,
    String reportId,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => RecipientsPopupDialog(
        recipients: recipients,
        buildingId: buildingId,
        reportId: reportId,
      ),
    );
  }

  @override
  State<RecipientsPopupDialog> createState() => _RecipientsPopupDialogState();
}

class _RecipientsPopupDialogState extends State<RecipientsPopupDialog> {
  late List<ReportRecipientEntity> _filtered;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final DioClient _dioClient = sl<DioClient>();

  // Edit state
  String? _editingRecipientId;
  final TextEditingController _editNameController = TextEditingController();
  bool _isUpdating = false;

  // Add state
  bool _isAdding = false;
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  bool _isCreating = false;
  String? _selectedContactId; // For domain contact selection
  String? _selectedContactName;
  String? _selectedContactEmail;

  // Delete state
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.recipients);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) {
        _filtered = List.from(widget.recipients);
      } else {
        _filtered = widget.recipients
            .where(
              (r) =>
                  r.recipientName.toLowerCase().contains(q) ||
                  r.recipientEmail.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _editNameController.dispose();
    _newNameController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  void _startEditing(ReportRecipientEntity recipient) {
    setState(() {
      // Cancel adding if active
      if (_isAdding) {
        _cancelAdding();
      }
      _editingRecipientId = recipient.recipientId;
      _editNameController.text = recipient.recipientName;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingRecipientId = null;
      _editNameController.clear();
    });
  }

  void _startAdding() {
    setState(() {
      // Cancel editing if active
      if (_editingRecipientId != null) {
        _cancelEditing();
      }
      _isAdding = true;
      _newNameController.clear();
      _newEmailController.clear();
      _selectedContactId = null;
      _selectedContactName = null;
      _selectedContactEmail = null;
    });
  }

  void _cancelAdding() {
    setState(() {
      _isAdding = false;
      _newNameController.clear();
      _newEmailController.clear();
      _selectedContactId = null;
      _selectedContactName = null;
      _selectedContactEmail = null;
    });
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

                      setState(() {
                        _selectedContactId = contactId;
                        _selectedContactName = name;
                        _selectedContactEmail = email;
                        // Clear manual entry fields
                        _newNameController.clear();
                        _newEmailController.clear();
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

  Future<void> _createRecipient() async {
    // Check if contact is selected from domain or manual entry
    final isFromDomain =
        _selectedContactId != null && _selectedContactId!.isNotEmpty;

    if (!isFromDomain) {
      // Validate manual entry
      final name = _newNameController.text.trim();
      final email = _newEmailController.text.trim();

      if (name.isEmpty || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name and email are required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Get current building data to collect existing recipient IDs
      final buildingResponse = await _dioClient.get(
        '/api/v1/buildings/${widget.buildingId}',
      );

      if (buildingResponse.statusCode != 200 || buildingResponse.data == null) {
        throw Exception('Failed to fetch building data');
      }

      final buildingData =
          buildingResponse.data['data'] as Map<String, dynamic>;
      final reportingRecipients =
          (buildingData['reportingRecipients'] as List?) ?? [];

      // Build recipients array: existing IDs + new recipient
      List<dynamic> recipients = [];

      // Add existing recipient IDs (those that have an 'id' field)
      for (var recipient in reportingRecipients) {
        final recipientMap = recipient as Map<String, dynamic>;
        final id =
            recipientMap['id']?.toString() ??
            recipientMap['recipientId']?.toString() ??
            '';

        // Only add if it's an existing recipient ID (MongoDB ObjectId format)
        if (id.isNotEmpty &&
            id.length == 24 &&
            RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) {
          recipients.add(id);
        }
      }

      // Add new recipient: either ID (from domain) or object (manual entry)
      if (isFromDomain) {
        // Add contact ID if selected from domain
        recipients.add(_selectedContactId!);
      } else {
        // Add recipient object with name and email for manual entry
        recipients.add({
          'name': _newNameController.text.trim(),
          'email': _newEmailController.text.trim(),
        });
      }

      // Build request body
      final requestBody = {
        'recipients': recipients,
        'buildingId': widget.buildingId,
      };

      // Create recipient using POST endpoint
      final response = await _dioClient.post(
        '/api/v1/reporting/${widget.reportId}/recipients',
        data: requestBody,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create recipient: ${response.statusCode}');
      }

      // Get the created recipient data from response
      String? newRecipientId;
      String recipientName;
      String recipientEmail;

      if (isFromDomain) {
        // Use selected contact data
        newRecipientId = _selectedContactId;
        recipientName = _selectedContactName ?? '';
        recipientEmail = _selectedContactEmail ?? '';
      } else {
        // Use manual entry data
        recipientName = _newNameController.text.trim();
        recipientEmail = _newEmailController.text.trim();
      }

      if (response.data != null) {
        final responseData = response.data;
        // Try to extract the new recipient ID from the response
        if (responseData is Map) {
          final data = responseData['data'] ?? responseData;
          if (data is List && data.isNotEmpty) {
            // If response is an array, get the last one (the newly created)
            final createdRecipient = data.last;
            if (createdRecipient is Map) {
              final extractedId =
                  createdRecipient['_id']?.toString() ??
                  createdRecipient['id']?.toString();
              if (extractedId != null) {
                newRecipientId = extractedId;
              }
            }
          } else if (data is Map) {
            final extractedId =
                data['_id']?.toString() ?? data['id']?.toString();
            if (extractedId != null) {
              newRecipientId = extractedId;
            }
          }
        } else if (responseData is List && responseData.isNotEmpty) {
          // Direct array response
          final createdRecipient = responseData.last;
          if (createdRecipient is Map) {
            final extractedId =
                createdRecipient['_id']?.toString() ??
                createdRecipient['id']?.toString();
            if (extractedId != null) {
              newRecipientId = extractedId;
            }
          }
        }
      }

      // Create new recipient entity for local state
      final newRecipientEntity = ReportRecipientEntity(
        recipientId:
            newRecipientId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        recipientName: recipientName,
        recipientEmail: recipientEmail,
      );

      // Update local state
      setState(() {
        widget.recipients.add(newRecipientEntity);
        _filtered = List.from(widget.recipients);
        _isAdding = false;
        _newNameController.clear();
        _newEmailController.clear();
        _selectedContactId = null;
        _selectedContactName = null;
        _selectedContactEmail = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipient created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating recipient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _updateRecipientName(String recipientId) async {
    final newName = _editNameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // First, get the current building data to get all recipients
      final buildingResponse = await _dioClient.get(
        '/api/v1/buildings/${widget.buildingId}',
      );

      if (buildingResponse.statusCode != 200 || buildingResponse.data == null) {
        throw Exception('Failed to fetch building data');
      }

      final buildingData =
          buildingResponse.data['data'] as Map<String, dynamic>;
      final reportingRecipients =
          (buildingData['reportingRecipients'] as List?) ?? [];

      // Find and update the recipient
      bool recipientFound = false;
      final updatedRecipients = reportingRecipients.map((recipient) {
        final recipientMap = recipient as Map<String, dynamic>;
        final id =
            recipientMap['id']?.toString() ??
            recipientMap['recipientId']?.toString() ??
            '';

        // Check if this is the recipient we're updating
        if (id == recipientId ||
            recipientMap['name']?.toString() ==
                widget.recipients
                    .firstWhere((r) => r.recipientId == recipientId)
                    .recipientName) {
          recipientFound = true;
          // Update the name
          final updatedRecipient = Map<String, dynamic>.from(recipientMap);
          updatedRecipient['name'] = newName;
          return updatedRecipient;
        }
        return recipient;
      }).toList();

      if (!recipientFound) {
        // If recipient not found by ID, try to find by name/email
        final recipientToUpdate = widget.recipients.firstWhere(
          (r) => r.recipientId == recipientId,
        );

        final updatedRecipientsWithNew = updatedRecipients.map((recipient) {
          final recipientMap = Map<String, dynamic>.from(recipient);
          final name = recipientMap['name']?.toString() ?? '';
          final email = recipientMap['email']?.toString() ?? '';

          if (name == recipientToUpdate.recipientName ||
              email == recipientToUpdate.recipientEmail) {
            final updatedRecipient = Map<String, dynamic>.from(recipientMap);
            updatedRecipient['name'] = newName;
            return updatedRecipient;
          }
          return recipient;
        }).toList();

        // Update building with new recipients
        await _dioClient.patch(
          '/api/v1/buildings/${widget.buildingId}',
          data: {'reportingRecipients': updatedRecipientsWithNew},
        );
      } else {
        // Update building with updated recipients
        await _dioClient.patch(
          '/api/v1/buildings/${widget.buildingId}',
          data: {'reportingRecipients': updatedRecipients},
        );
      }

      // Update local state
      setState(() {
        final index = _filtered.indexWhere((r) => r.recipientId == recipientId);
        if (index != -1) {
          _filtered[index] = ReportRecipientEntity(
            recipientId: _filtered[index].recipientId,
            recipientName: newName,
            recipientEmail: _filtered[index].recipientEmail,
          );
        }
        // Also update the original list
        final originalIndex = widget.recipients.indexWhere(
          (r) => r.recipientId == recipientId,
        );
        if (originalIndex != -1) {
          widget.recipients[originalIndex] = ReportRecipientEntity(
            recipientId: widget.recipients[originalIndex].recipientId,
            recipientName: newName,
            recipientEmail: widget.recipients[originalIndex].recipientEmail,
          );
        }
        _editingRecipientId = null;
        _editNameController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipient name updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating recipient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _deleteRecipient(String recipientId) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        title: const Text('Delete Recipient'),
        content: const Text(
          'Are you sure you want to delete this recipient? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      // Get current building data
      final buildingResponse = await _dioClient.get(
        '/api/v1/buildings/${widget.buildingId}',
      );

      if (buildingResponse.statusCode != 200 || buildingResponse.data == null) {
        throw Exception('Failed to fetch building data');
      }

      final buildingData =
          buildingResponse.data['data'] as Map<String, dynamic>;
      final reportingRecipients =
          (buildingData['reportingRecipients'] as List?) ?? [];

      // Find the recipient to delete
      final recipientToDelete = widget.recipients.firstWhere(
        (r) => r.recipientId == recipientId,
      );

      // Remove the recipient from the list
      final updatedRecipients = reportingRecipients.where((recipient) {
        final recipientMap = recipient as Map<String, dynamic>;
        final id =
            recipientMap['id']?.toString() ??
            recipientMap['recipientId']?.toString() ??
            '';
        final name = recipientMap['name']?.toString() ?? '';
        final email = recipientMap['email']?.toString() ?? '';

        // Check if this is the recipient we're deleting
        if (id == recipientId) {
          return false;
        }
        // Also check by name/email for custom recipients
        if (name == recipientToDelete.recipientName &&
            email == recipientToDelete.recipientEmail) {
          return false;
        }
        return true;
      }).toList();

      // Update building
      await _dioClient.patch(
        '/api/v1/buildings/${widget.buildingId}',
        data: {'reportingRecipients': updatedRecipients},
      );

      // Update local state
      setState(() {
        widget.recipients.removeWhere((r) => r.recipientId == recipientId);
        _filtered = List.from(widget.recipients);
        // Cancel editing if we were editing this recipient
        if (_editingRecipientId == recipientId) {
          _cancelEditing();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipient deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting recipient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.recipients.length;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: title, total count, close
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All recipients',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total: $total recipient${total == 1 ? '' : 's'}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _isAdding ? null : _startAdding,
                              tooltip: 'Add recipient',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[500],
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                style: AppTextStyles.bodyMedium,
              ),
            ),
            // Scrollable list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: _filtered.length + (_isAdding ? 1 : 0),
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[300]),
                itemBuilder: (context, index) {
                  // Show add form at the top if adding
                  if (_isAdding && index == 0) {
                    final isFromDomain =
                        _selectedContactId != null &&
                        _selectedContactId!.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isFromDomain) ...[
                            // Show selected contact from domain
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
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
                                      color: const Color(0xFF238636),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedContactName != null &&
                                                _selectedContactName!
                                                    .toString()
                                                    .isNotEmpty
                                            ? '${_selectedContactName}      ${_selectedContactEmail != null && _selectedContactEmail!.toString().isNotEmpty ? _selectedContactEmail : ''}'
                                            : _selectedContactEmail != null &&
                                                  _selectedContactEmail!
                                                      .toString()
                                                      .isNotEmpty
                                            ? _selectedContactEmail!
                                            : '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _isCreating
                                            ? null
                                            : () {
                                                setState(() {
                                                  _selectedContactId = null;
                                                  _selectedContactName = null;
                                                  _selectedContactEmail = null;
                                                });
                                              },
                                        borderRadius: BorderRadius.zero,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
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
                          ] else ...[
                            // Manual entry fields
                            // Name field
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                                controller: _newNameController,
                                enabled: !_isCreating,
                                decoration: InputDecoration(
                                  hintText: 'Name',
                                  border: InputBorder.none,
                                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Email field
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                                controller: _newEmailController,
                                enabled: !_isCreating,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'Email',
                                  border: InputBorder.none,
                                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                          // Action links - select from domain or create manually
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isFromDomain) ...[
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isCreating
                                        ? null
                                        : _handleAutomaticFromDomain,
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'building_contact_person.automatic_from_domain'
                                                  .tr(),
                                              style: TextStyle(
                                                fontSize: 12,
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
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Confirm button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isCreating ? null : _createRecipient,
                                  borderRadius: BorderRadius.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: _isCreating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'Confirm',
                                            style: TextStyle(
                                              fontSize: 14,
                                              decoration:
                                                  TextDecoration.underline,
                                              color: Colors.black,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isCreating ? null : _cancelAdding,
                                  borderRadius: BorderRadius.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
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
                        ],
                      ),
                    );
                  }

                  // Adjust index if adding form is shown
                  final recipientIndex = _isAdding ? index - 1 : index;
                  if (recipientIndex < 0 ||
                      recipientIndex >= _filtered.length) {
                    return const SizedBox.shrink();
                  }
                  final r = _filtered[recipientIndex];
                  final isEditing = _editingRecipientId == r.recipientId;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isEditing) ...[
                                    TextField(
                                      controller: _editNameController,
                                      enabled: !_isUpdating,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                      ),
                                      style: AppTextStyles.titleSmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      r.recipientName.isNotEmpty
                                          ? r.recipientName
                                          : '—',
                                      style: AppTextStyles.titleSmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                  if (r.recipientEmail.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      r.recipientEmail,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                if (isEditing) ...[
                                  IconButton(
                                    icon: _isUpdating
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.check),
                                    onPressed: _isUpdating
                                        ? null
                                        : () => _updateRecipientName(
                                            r.recipientId,
                                          ),
                                    tooltip: 'Confirm',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: _isUpdating
                                        ? null
                                        : _cancelEditing,
                                    tooltip: 'Cancel',
                                  ),
                                ] else ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _startEditing(r),
                                    tooltip: 'Edit',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: _isDeleting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.delete),
                                    onPressed: _isDeleting
                                        ? null
                                        : () => _deleteRecipient(r.recipientId),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
