import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

import '../../../../core/widgets/page_header_row.dart';

class PropertyItem {
  final TextEditingController controller;
  bool isConfirmed;

  PropertyItem({required this.controller, this.isConfirmed = false});
}

class AddPropertiesWidget extends StatefulWidget {
  final String? userName;
  final String? switchId;
  final bool isSingleProperty;
  final List<Map<String, dynamic>> createdSites;
  final bool isLoadingSites;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onBack;
  final ValueChanged<Map<String, String>>?
  onAddPropertyDetails; // {propertyName, siteId}
  final VoidCallback? onGoToHome;
  final ValueChanged<List<String>>? onConfirmProperties; // propertyNames
  final String? fromDashboard;
  const AddPropertiesWidget({
    super.key,
    this.fromDashboard,
    this.userName,
    this.switchId,
    required this.isSingleProperty,
    this.createdSites = const [],
    this.isLoadingSites = false,
    required this.onLanguageChanged,
    this.onBack,
    this.onAddPropertyDetails,
    this.onGoToHome,
    this.onConfirmProperties,
  });

  @override
  State<AddPropertiesWidget> createState() => _AddPropertiesWidgetState();
}

class _AddPropertiesWidgetState extends State<AddPropertiesWidget> {
  final List<PropertyItem> _properties = [];
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    // If fromDashboard is true, don't initialize with a property field
    // User will add fields by clicking "Add property" button
    // Otherwise, initialize with one property field
    if (widget.fromDashboard != 'true') {
      _properties.add(PropertyItem(controller: TextEditingController()));
    }
    // If sites already exist (returning from responsible persons page), show "Go to home" button
    // BUT: If fromDashboard is true, always start with input fields (don't set _isConfirmed)
    if (widget.createdSites.isNotEmpty && widget.fromDashboard != 'true') {
      _isConfirmed = true;
    }
  }

  @override
  void didUpdateWidget(AddPropertiesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If sites are loaded after widget initialization, show "Go to home" button
    if (widget.createdSites.isNotEmpty) {
      if (widget.fromDashboard == 'true') {
        // When from dashboard: only set confirmed if sites were just fetched (after confirmation)
        // Check if sites were just added (they weren't there before, or we just confirmed)
        if (oldWidget.createdSites.isEmpty && widget.createdSites.isNotEmpty) {
          // Sites were just fetched after confirmation
          setState(() {
            _isConfirmed = true;
          });
        } else if (_isConfirmed && widget.createdSites.isNotEmpty) {
          // Already confirmed and sites exist, keep confirmed state
          setState(() {
            _isConfirmed = true;
          });
        }
      } else {
        // Not from dashboard, use normal flow
        setState(() {
          _isConfirmed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    for (var property in _properties) {
      property.controller.dispose();
    }
    super.dispose();
  }

  void _addNewProperty() {
    setState(() {
      _properties.add(PropertyItem(controller: TextEditingController()));
    });
  }

  void _confirmProperty(int index) {
    setState(() {
      _properties[index].isConfirmed = true;
    });
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'add_properties.progress_text'.tr(namedArgs: {'name': name});
    }
    return 'add_properties.progress_text_fallback'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Padding(
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
              TopHeader(
                onLanguageChanged: widget.onLanguageChanged,
                containerWidth: screenSize.width > 500
                    ? 500
                    : screenSize.width * 0.98,
              ),

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
                          _buildProgressText(),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF8B9A5B),
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 32),
                        PageHeaderRow(
                          title: widget.isSingleProperty
                              ? 'add_properties.title_single'.tr()
                              : 'add_properties.title_multiple'.tr(),
                          showBackButton: widget.onBack != null,
                          onBack: widget.onBack,
                        ),

                        const SizedBox(height: 40),
                        // Show loading indicator if fetching sites
                        if (widget.isLoadingSites) ...[
                          const CircularProgressIndicator(),
                          const SizedBox(height: 24),
                        ] else ...[
                          // Always show existing sites list first (if any)
                          if (widget.createdSites.isNotEmpty) ...[
                            _buildExistingSitesView(),
                            const SizedBox(height: 24),
                          ],

                          // Show "Add property" button (always show when fromDashboard or not single property)

                          // Show new text fields below (added by clicking "Add property")
                          if (_properties.isNotEmpty) ...[
                            _buildPropertyInputFields(),
                          ],
                          if (!widget.isSingleProperty ||
                              widget.fromDashboard == 'true') ...[
                            Center(
                              child: InkWell(
                                onTap: _addNewProperty,
                                child: Text(
                                  'add_properties.add_new_property'.tr(),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    decoration: TextDecoration.underline,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                        const SizedBox(height: 24),

                        // Button logic:
                        // - If there is at least one property AND all text fields are empty, show "Go to home"
                        // - If there is at least one property AND any text field has a value, show "Confirm"
                        Builder(
                          builder: (context) {
                            // Check if at least one field has a value
                            final hasAnyValue = _properties.any(
                              (p) => p.controller.text.trim().isNotEmpty,
                            );

                            // Check if there is at least one property (site)
                            final hasAtLeastOneProperty =
                                widget.createdSites.length >= 1;

                            // Show "Go to home" when:
                            // - There is at least one property (site)
                            // - All text fields are empty (no values)
                            final shouldShowGoToHome =
                                hasAtLeastOneProperty && !hasAnyValue;

                            // Show "Confirm" when any text field has a value
                            // (so user can confirm newly added property names even with 0 createdSites)
                            final shouldShowConfirm = hasAnyValue;

                            return PrimaryOutlineButton(
                              label: shouldShowGoToHome
                                  ? 'add_properties.go_to_home'.tr()
                                  : 'add_properties.confirm_properties'.tr(),
                              width: 260,
                              enabled: shouldShowGoToHome || shouldShowConfirm,
                              onPressed: shouldShowGoToHome
                                  ? widget.onGoToHome
                                  : (shouldShowConfirm
                                        ? () {
                                            // Collect only non-empty property names (omit empty fields)
                                            final propertyNames = _properties
                                                .map(
                                                  (p) =>
                                                      p.controller.text.trim(),
                                                )
                                                .where(
                                                  (name) => name.isNotEmpty,
                                                )
                                                .toList();

                                            if (propertyNames.isEmpty) {
                                              return; // Don't allow confirmation without any text
                                            }

                                            // Mark all non-empty properties as confirmed
                                            for (
                                              int i = 0;
                                              i < _properties.length;
                                              i++
                                            ) {
                                              if (_properties[i].controller.text
                                                      .trim()
                                                      .isNotEmpty &&
                                                  !_properties[i].isConfirmed) {
                                                _confirmProperty(i);
                                              }
                                            }

                                            // Call the callback to create sites
                                            // This will trigger backend save and fetch
                                            // Empty fields are already omitted in propertyNames
                                            widget.onConfirmProperties?.call(
                                              propertyNames,
                                            );

                                            // Clear all text fields after saving
                                            setState(() {
                                              // Dispose controllers and clear the list
                                              for (var property
                                                  in _properties) {
                                                property.controller.dispose();
                                              }
                                              _properties.clear();
                                            });

                                            // Don't set _isConfirmed here - wait for sites to be fetched
                                            // The _isConfirmed will be set in didUpdateWidget when sites are loaded
                                          }
                                        : null),
                            );
                          },
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
    );
  }

  void _removePropertyAt(int index) {
    if (_properties.length <= 1) return;
    setState(() {
      _properties[index].controller.dispose();
      _properties.removeAt(index);
    });
  }

  Widget _buildPropertyField(int index) {
    final property = _properties[index];
    final isConfirmed = property.isConfirmed;
    final canRemove = _properties.length > 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isConfirmed ? const Color(0xFF8B9A5B) : Colors.black54,
          width: 2,
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          if (isConfirmed) ...[
            Image.asset(
              'assets/images/check.png',
              width: 16,
              height: 16,
              color: const Color(0xFF238636),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: property.controller,
              enabled: !isConfirmed,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'add_properties.property_name_hint'.tr(),
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey.shade400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 8,
                ),
                isDense: true,
              ),
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
            ),
          ),
          if (canRemove && !isConfirmed)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _removePropertyAt(index),
              tooltip: 'Remove property',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),

          // if (hasValue && _isConfirmed) ...[
          //   const SizedBox(width: 12),
          //   InkWell(
          //     onTap: () {
          //       final propertyName = property.controller.text.trim();
          //       if (propertyName.isNotEmpty) {
          //         // Find the siteId from created sites by matching the property name
          //         final matchingSite = widget.createdSites.firstWhere(
          //           (site) => site['name']?.toString() == propertyName,
          //           orElse: () => <String, dynamic>{},
          //         );
          //         final siteId =
          //             matchingSite['_id']?.toString() ??
          //             matchingSite['id']?.toString() ??
          //             '';
          //         if (siteId != '') {
          //           widget.onAddPropertyDetails?.call({
          //             'propertyName': propertyName,
          //             'siteId': siteId,
          //           });
          //         }
          //       }
          //     },
          //     child: Text(
          //       'add_properties.add_property_details'.tr(),
          //       style: AppTextStyles.bodyMedium.copyWith(
          //         decoration: TextDecoration.underline,
          //         color: Colors.grey,
          //       ),
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }

  Widget _buildExistingSitesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Properties',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ...widget.createdSites.map(
          (site) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF8B9A5B), width: 2),
                borderRadius: BorderRadius.zero,
              ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site['name']?.toString() ?? '',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (site['address'] != null &&
                            site['address'].toString().isNotEmpty)
                          Text(
                            site['address'].toString(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      final propertyName = site['name']?.toString() ?? '';
                      final siteId =
                          site['_id']?.toString() ??
                          site['id']?.toString() ??
                          '';

                      if (propertyName.isNotEmpty && siteId.isNotEmpty) {
                        widget.onAddPropertyDetails?.call({
                          'propertyName': propertyName,
                          'siteId': siteId,
                        });
                      }
                    },
                    child: Text(
                      'add_properties.add_property_details'.tr(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        decoration: TextDecoration.underline,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Property text fields
        ...List.generate(
          _properties.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPropertyField(index),
          ),
        ),
      ],
    );
  }
}
