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
  final List<Map<String, dynamic>> _contacts = [];
  final DioClient _dioClient = sl<DioClient>();

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

  String _getBuildingSummary() {
    final parts = <String>[];
    final building = _building;
    if (building.totalArea != null) {
      parts.add('${building.totalArea!.toStringAsFixed(0)}qm');
    }
    if (building.numberOfRooms != null) {
      parts.add('${building.numberOfRooms} Räume');
    }
    // Add "Sanitäranlage" if it's a building with rooms
    if (building.numberOfRooms != null && building.numberOfRooms! > 0) {
      parts.add('Sanitäranlage');
    }
    if (building.constructionYear != null) {
      parts.add('Baujahr ${building.constructionYear}');
    }
    return parts.join(' ');
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
        '/api/v1/contacts',
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
        if (response.data is List) {
          contactsList = List<Map<String, dynamic>>.from(response.data);
        } else if (response.data['contacts'] != null) {
          contactsList = List<Map<String, dynamic>>.from(
            response.data['contacts'],
          );
        } else if (response.data['data'] != null) {
          contactsList = List<Map<String, dynamic>>.from(response.data['data']);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('building_contact_person.contacts_from_domain'.tr()),
        content: SizedBox(
          width: double.maxFinite,
          child: contactsList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('building_contact_person.no_contacts_found'.tr()),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: contactsList.length,
                  itemBuilder: (context, index) {
                    final contact = contactsList[index];
                    final name = contact['name'] ?? contact['fullName'] ?? '';
                    final email =
                        contact['email'] ?? contact['emailAddress'] ?? '';
                    final contactId = contact['id'] ?? contact['_id'] ?? '';

                    return ListTile(
                      title: Text(name.isNotEmpty ? name : 'Unbekannt'),
                      subtitle: email.isNotEmpty ? Text(email) : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          // Add selected contact to the list
                          setState(() {
                            _contacts.add({
                              'name': name,
                              'email': email,
                              'id': contactId.isNotEmpty
                                  ? contactId
                                  : DateTime.now().millisecondsSinceEpoch
                                        .toString(),
                              'method': 'domain',
                            });
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('building_contact_person.close'.tr()),
          ),
        ],
      ),
    );
  }

  void _handleUploadContact() {
    setState(() {
      _contacts.add({
        'name': '',
        'email': '',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'method': 'upload',
      });
    });
  }

  void _handleRemoveContact(String id) {
    setState(() {
      _contacts.removeWhere((contact) => contact['id'] == id);
    });
  }

  void _handleContactNameChanged(String id, String name) {
    setState(() {
      final index = _contacts.indexWhere((contact) => contact['id'] == id);
      if (index != -1) {
        _contacts[index]['name'] = name;
      }
    });
  }

  void _handleContactEmailChanged(String id, String email) {
    setState(() {
      final index = _contacts.indexWhere((contact) => contact['id'] == id);
      if (index != -1) {
        _contacts[index]['email'] = email;
      }
    });
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

  void _handleNext() {
    if (widget.onNext != null) {
      widget.onNext!();
    } else {
      // Navigate to responsible persons page
      _navigateToResponsiblePersons();
    }
  }

  void _navigateToResponsiblePersons() {
    context.pushNamed(
      Routelists.buildingResponsiblePersons,
      queryParameters: {
        if (widget.buildingName != null) 'buildingName': widget.buildingName!,
        if (widget.buildingAddress != null &&
            widget.buildingAddress!.isNotEmpty)
          'buildingAddress': widget.buildingAddress!,
        if (widget.buildingId != null) 'buildingId': widget.buildingId!,
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
        if (widget.userName != null) 'userName': widget.userName!,
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
                                    // Information boxes
                                    if (_building.address != null)
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
                                                  _building.address!,
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
                                    const SizedBox(height: 24),
                                    // Contact Cards
                                    if (_contacts.isNotEmpty)
                                      ..._contacts.map((contact) {
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
                                                  16,
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
                                                            contact['name'],
                                                        decoration: InputDecoration(
                                                          hintText:
                                                              'building_contact_person.name_hint'
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
                                                          _handleContactNameChanged(
                                                            contact['id'],
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
                                                            contact['email'],
                                                        decoration: InputDecoration(
                                                          hintText:
                                                              'building_contact_person.email_hint'
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
                                                          _handleContactEmailChanged(
                                                            contact['id'],
                                                            value,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Cancel button at top right corner
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () =>
                                                        _handleRemoveContact(
                                                          contact['id'],
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.close,
                                                        color: Colors.grey[700],
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
                                    // Action links - side by side (only show if no contacts or allow adding more)
                                    if (_contacts.isEmpty)
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
                                                      'building_contact_person.automatic_from_domain'
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
                                                      'building_contact_person.upload_contact'
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
                                      )
                                    else
                                      // Show option to add more contacts
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _contacts.add({
                                                'name': '',
                                                'email': '',
                                                'id': DateTime.now()
                                                    .millisecondsSinceEpoch
                                                    .toString(),
                                                'method': 'manual',
                                              });
                                            });
                                          },
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
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'building_contact_person.add_more_contact'
                                                      .tr(),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 32),
                                    // Skip step link
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _handleSkip,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Center(
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
                                        child: PrimaryOutlineButton(
                                          label:
                                              'building_contact_person.button_text'
                                                  .tr(),
                                          width: 260,
                                          onPressed: _handleNext,
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
