import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import '../../../../../core/constant.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/primary_outline_button.dart';
import '../../../../../core/widgets/app_footer.dart';
import '../../../../../core/widgets/top_part_widget.dart';
import '../../../../../core/routing/routeLists.dart';
import '../../../../../core/network/dio_client.dart';
import '../../../../../core/injection_container.dart';

class BuildingContactPersonStep extends StatefulWidget {
  final BuildingEntity? building;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  // Query parameters for route-based navigation
  final String? buildingName;
  final String? buildingAddress;
  final String? buildingId;
  final String? siteId;
  final String? userName;
  final String? totalArea;
  final String? numberOfRooms;
  final String? constructionYear;

  const BuildingContactPersonStep({
    super.key,
    this.building,
    this.onNext,
    this.onSkip,
    this.onBack,
    this.buildingName,
    this.buildingAddress,
    this.buildingId,
    this.siteId,
    this.userName,
    this.totalArea,
    this.numberOfRooms,
    this.constructionYear,
  });

  @override
  State<BuildingContactPersonStep> createState() =>
      _BuildingContactPersonStepState();
}

class _BuildingContactPersonStepState extends State<BuildingContactPersonStep> {
  Map<String, dynamic>? _selectedContact;
  bool _isEditingContact = false;
  final DioClient _dioClient = sl<DioClient>();
  bool _isSaving = false;
  bool _createContactClicked = false;

  BuildingEntity get _building {
    if (widget.building != null) {
      return widget.building!;
    }
    // Construct from query parameters
    return BuildingEntity(
      id: widget.buildingId,
      name: widget.buildingName ?? '',
      address: widget.buildingAddress,
      totalArea: widget.totalArea != null
          ? double.tryParse(widget.totalArea!)
          : null,
      numberOfRooms: widget.numberOfRooms != null
          ? int.tryParse(widget.numberOfRooms!)
          : null,
      constructionYear: widget.constructionYear,
    );
  }

  String _getFloorPlanStatus() {
    // Check if floor plan is activated - this would come from building data
    // For now, return a default status
    return 'building_contact_person.floor_plan_status'.tr();
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
      // Assuming endpoint: /api/v1/contacts or /api/v1/buildings/{buildingId}/contacts
      final buildingId = widget.buildingId ?? _building.id ?? '';
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
    String? selectedContactId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          backgroundColor: Colors.white,
          title: Text('building_contact_person.contacts_from_domain'.tr()),
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
                      // Instruction text
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'building_contact_person.choose_one_contact'.tr(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      // Contacts list
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
                                contact['_id'] ??
                                contact['id'] ??
                                ''; // Prioritize _id from MongoDB

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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('building_contact_person.cancel'.tr()),
            ),
            TextButton(
              onPressed: selectedContactId == null
                  ? null
                  : () {
                      // Find the selected contact
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

                      // Set selected contact as completed
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
                        _isEditingContact =
                            false; // Mark as completed immediately
                        _createContactClicked =
                            false; // Re-enable "Create contact" when selecting from domain
                      });
                      Navigator.of(context).pop();
                    },
              child: Text('building_contact_person.choose_contact'.tr()),
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
      _createContactClicked = true; // Disable the "Create contact" button
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

  bool _isFormValid() {
    if (_selectedContact == null) return false;

    final name = _selectedContact!['name']?.toString().trim() ?? '';
    final email = _selectedContact!['email']?.toString().trim() ?? '';

    // If editing, check if fields are filled and email is valid
    if (_isEditingContact) {
      return name.isNotEmpty && email.isNotEmpty && _isValidEmail(email);
    }

    // If confirmed, check if name is not empty (email validation already done)
    return name.isNotEmpty;
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleSkip() {
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      // Navigate to responsible persons page
      _navigateToResponsiblePersons();
    }
  }

  Future<void> _handleNext() async {
    if (_isSaving) return;

    // If editing contact, confirm it first
    if (_selectedContact != null && _isEditingContact) {
      _handleConfirmContact();
      return; // Return early to allow UI to update, user can click again
    }

    // Get building ID
    final buildingId = widget.buildingId ?? _building.id;
    if (buildingId == null || buildingId.isEmpty) {
      // If no building ID, just navigate
      if (widget.onNext != null) {
        widget.onNext!();
      } else {
        _navigateToResponsiblePersons();
      }
      return;
    }

    // If there's a selected contact, save it first
    if (_selectedContact != null &&
        _selectedContact!['name'] != null &&
        _selectedContact!['name'].toString().isNotEmpty) {
      setState(() {
        _isSaving = true;
      });

      try {
        // Build request body based on whether contact is from dialog (has ID) or manually entered
        final Map<String, dynamic> requestBody;

        // Check if contact was selected from dialog (has an ID from backend)
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
          requestBody = {'buildingContact': contactId.toString()};
        } else {
          // If manually entered, send the full object
          requestBody = {
            'buildingContact': {
              'name': _selectedContact!['name'] ?? '',
              'email': _selectedContact!['email'] ?? '',
              'phone': _selectedContact!['phone'] ?? '',
            },
          };
        }

        // Make API call
        final response = await _dioClient.dio.patch(
          '/api/v1/buildings/$buildingId',
          data: requestBody,
        );

        // Check if response is successful
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Navigate after successful save
          if (mounted) {
            if (widget.onNext != null) {
              widget.onNext!();
            } else {
              _navigateToResponsiblePersons();
            }
          }
        } else {
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save contact person'),
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
            _isSaving = false;
          });
        }
      }
    } else {
      // No contact to save, just navigate
      if (widget.onNext != null) {
        widget.onNext!();
      } else {
        _navigateToResponsiblePersons();
      }
    }
  }

  void _navigateToResponsiblePersons() {
    // Encode contact person data if available
    String? contactPersonJson;
    if (_selectedContact != null &&
        _selectedContact!['name'] != null &&
        _selectedContact!['name'].toString().isNotEmpty) {
      contactPersonJson = jsonEncode({
        'name': _selectedContact!['name'] ?? '',
        'email': _selectedContact!['email'] ?? '',
        'phone': _selectedContact!['phone'] ?? '',
      });
    }

    context.pushNamed(
      Routelists.buildingRecipient,
      queryParameters: {
        if (widget.buildingName != null) 'buildingName': widget.buildingName!,
        if (widget.buildingAddress != null &&
            widget.buildingAddress!.isNotEmpty)
          'buildingAddress': widget.buildingAddress!,
        if (widget.buildingId != null) 'buildingId': widget.buildingId!,
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
        if (widget.userName != null) 'userName': widget.userName!,
        if (contactPersonJson != null) 'contactPerson': contactPersonJson,
        if (widget.totalArea != null) 'totalArea': widget.totalArea!,
        if (widget.numberOfRooms != null)
          'numberOfRooms': widget.numberOfRooms!,
        if (widget.constructionYear != null)
          'constructionYear': widget.constructionYear!,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

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
                              'building_contact_person.progress_text'.tr(
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
                                value: 0.85,
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
                              'building_contact_person.progress_text_fallback'
                                  .tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.85,
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
                                    if (widget.onBack != null ||
                                        widget.buildingId != null) ...[
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap:
                                                widget.onBack ??
                                                () => context.pop(),
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
                                    // Question
                                    Text(
                                      'building_contact_person.title'.tr(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    // Floor plan activated box (always shown on first page)
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
                                    // const SizedBox(height: 12),
                                    // Contact Fields or Confirmation Box
                                    if (_selectedContact != null) ...[
                                      if (_isEditingContact) ...[
                                        // Show text fields when editing
                                        // Name Field
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
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            color: Colors.white,
                                          ),
                                          child: TextFormField(
                                            initialValue:
                                                _selectedContact!['name'] ?? '',
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
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: Colors.black87,
                                                ),
                                            onChanged: (value) {
                                              _handleContactNameChanged(value);
                                              // Trigger rebuild to update button state
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF8B9A5B),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
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
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: Colors.black87,
                                                ),
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            onChanged: (value) {
                                              _handleContactEmailChanged(value);
                                            },
                                          ),
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
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                    // Action links - side by side (only show if no contact selected or when editing)
                                    if (_selectedContact == null ||
                                        (_selectedContact != null &&
                                            _isEditingContact))
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
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                    const SizedBox(height: 32),
                                    // Skip step link (only show if no contact selected or when editing)
                                    if (_selectedContact == null ||
                                        (_selectedContact != null &&
                                            _isEditingContact))
                                      Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _handleSkip,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              child: Text(
                                                'building_contact_person.skip_step'
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
                                    // "Das passt so" button
                                    Center(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: _isSaving
                                            ? const CircularProgressIndicator()
                                            : PrimaryOutlineButton(
                                                label:
                                                    'building_contact_person.button_text'
                                                        .tr(),
                                                width: 260,
                                                onPressed: _isFormValid()
                                                    ? _handleNext
                                                    : null,
                                                enabled: _isFormValid(),
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
