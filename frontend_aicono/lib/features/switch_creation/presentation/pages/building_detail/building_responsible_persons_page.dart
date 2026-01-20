import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';

class BuildingResponsiblePersonsPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? buildingId;
  final String? siteId;

  const BuildingResponsiblePersonsPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.buildingId,
    this.siteId,
  });

  @override
  State<BuildingResponsiblePersonsPage> createState() =>
      _BuildingResponsiblePersonsPageState();
}

class _BuildingResponsiblePersonsPageState
    extends State<BuildingResponsiblePersonsPage> {
  final List<Map<String, dynamic>> _contacts = [];
  final List<Map<String, dynamic>> _properties = [];

  @override
  void initState() {
    super.initState();
    // Initialize with default properties
    _properties.addAll([
      {'name': 'Liegenschaft, gesamt', 'selected': true},
      {'name': 'Büroräume, Vorderhaus', 'selected': true},
      {'name': 'Lagergebäude', 'selected': true},
    ]);
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleAddContact() {
    setState(() {
      _contacts.add({
        'name': '',
        'email': '',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
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

  void _handlePropertyToggle(int index) {
    setState(() {
      _properties[index]['selected'] = !_properties[index]['selected'];
    });
  }

  void _handleContinue() {
    // TODO: Save responsible persons data
    // Navigate back to add additional buildings page
    context.goNamed(
      Routelists.addAdditionalBuildings,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
      },
    );
  }

  void _handleSkip() {
    // Skip this step
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
                              'Fast geschafft, ${widget.userName}!',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.95,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8B9A5B),
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
                                    Text(
                                      'Wer soll automatische Reportings erhalten?',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.headlineSmall
                                          .copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                          ),
                                    ),
                                    const SizedBox(height: 32),
                                    // Contact Fields
                                    if (_contacts.isEmpty)
                                      _buildAddContactButton()
                                    else
                                      ..._contacts.map((contact) {
                                        return Column(
                                          children: [
                                            _buildContactField(
                                              contact['id'],
                                              contact['name'],
                                              contact['email'],
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        );
                                      }),
                                    if (_contacts.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _handleAddContact,
                                          child: Text(
                                            '+ Weiteren Kontakt hinzufügen',
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  color: Colors.black87,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    // Property Selection Checkboxes
                                    // ..._properties.asMap().entries.map((entry) {
                                    //   final index = entry.key;
                                    //   final property = entry.value;
                                    //   return Padding(
                                    //     padding: const EdgeInsets.only(
                                    //       bottom: 12,
                                    //     ),
                                    //     child: Material(
                                    //       color: Colors.transparent,
                                    //       child: InkWell(
                                    //         onTap: () =>
                                    //             _handlePropertyToggle(index),
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
                                    //               Checkbox(
                                    //                 value: property['selected'],
                                    //                 onChanged: null,
                                    //                 activeColor: const Color(
                                    //                   0xFF8B9A5B,
                                    //                 ),
                                    //               ),
                                    //               const SizedBox(width: 8),
                                    //               Expanded(
                                    //                 child: Text(
                                    //                   property['name'],
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
                                    // const SizedBox(height: 32),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _handleSkip,
                                        child: Text(
                                          'Schritt überspringen',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                decoration:
                                                    TextDecoration.underline,
                                                color: Colors.black87,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Material(
                                      color: Colors.transparent,
                                      child: PrimaryOutlineButton(
                                        label: 'Reportings festlegen',
                                        width: 260,
                                        onPressed: _handleContinue,
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

  Widget _buildAddContactButton() {
    return Column(
      children: [
        _buildContactField(null, '', ''),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleAddContact,
            child: Text(
              '+ Kontakt hinzufügen',
              style: AppTextStyles.bodyMedium.copyWith(
                decoration: TextDecoration.underline,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactField(String? id, String name, String email) {
    final contactId = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final isNew = id == null;

    return Column(
      children: [
        // Name Field
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: name,
                  decoration: InputDecoration(
                    hintText: 'Name',
                    border: InputBorder.none,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.black87,
                  ),
                  onChanged: (value) {
                    if (!isNew) {
                      _handleContactNameChanged(contactId, value);
                    }
                  },
                ),
              ),
              if (!isNew)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleRemoveContact(contactId),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Email Field
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: email,
                  decoration: InputDecoration(
                    hintText: 'Mailadresse',
                    border: InputBorder.none,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.black87,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    if (!isNew) {
                      _handleContactEmailChanged(contactId, value);
                    }
                  },
                ),
              ),
              if (!isNew)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleRemoveContact(contactId),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
