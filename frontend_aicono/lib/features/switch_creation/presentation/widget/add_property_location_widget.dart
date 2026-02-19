import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';

import '../../../../core/widgets/page_header_row.dart';

class AddPropertyLocationWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const AddPropertyLocationWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onSkip,
    this.onContinue,
    this.onBack,
  });

  @override
  State<AddPropertyLocationWidget> createState() =>
      _AddPropertyLocationWidgetState();
}

class _AddPropertyLocationWidgetState extends State<AddPropertyLocationWidget> {
  late final TextEditingController _locationController;
  bool _enableAutocomplete = true;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoadingSearch = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController();
    // Initialize from cubit if available
    final cubit = sl<PropertySetupCubit>();
    if (cubit.state.location != null) {
      _locationController.text = cubit.state.location!;
    }

    // Listen to location input changes with debouncing for autocomplete
    _locationController.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onLocationChanged() {
    if (!_enableAutocomplete) {
      // Update cubit immediately when autocomplete is disabled
      sl<PropertySetupCubit>().setLocation(_locationController.text.trim());
      setState(() {}); // Update button state
      return;
    }

    // Debounce autocomplete search when enabled
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = _locationController.text.trim();
      if (query.isNotEmpty) {
        _searchPlaces(query);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoadingSearch = true;
    });

    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.get(
        '/api/v1/googlemap/places/autocomplete',
        queryParameters: {'input': query},
      );

      if (mounted) {
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          List<Map<String, dynamic>> results = [];

          // Parse the response structure: {success: true, data: {predictions: [...], status: "OK"}}
          if (data is Map<String, dynamic>) {
            // Check if response has success and data fields
            if (data['success'] == true && data['data'] != null) {
              final dataMap = data['data'];

              // Extract predictions array from data.predictions
              if (dataMap is Map<String, dynamic> &&
                  dataMap['predictions'] != null) {
                final predictions = dataMap['predictions'];
                if (predictions is List) {
                  results = predictions
                      .map((item) => item as Map<String, dynamic>)
                      .toList();
                }
              }
            }
            // Fallback: if data is directly a Map with predictions
            else if (data['predictions'] != null) {
              final predictions = data['predictions'];
              if (predictions is List) {
                results = predictions
                    .map((item) => item as Map<String, dynamic>)
                    .toList();
              }
            }
          }
          // Fallback: if data itself is a list
          else if (data is List) {
            results = data.map((item) => item as Map<String, dynamic>).toList();
          }

          setState(() {
            _searchResults = results;
            _isLoadingSearch = false;
          });
        } else {
          setState(() {
            _searchResults = [];
            _isLoadingSearch = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoadingSearch = false;
        });
        debugPrint('Error searching places: $e');
      }
    }
  }

  void _selectPlace(Map<String, dynamic> place) {
    // Extract place description or name
    final description =
        place['description']?.toString() ??
        place['name']?.toString() ??
        place['formatted_address']?.toString() ??
        '';

    if (description.isNotEmpty) {
      setState(() {
        _locationController.text = description;
        _searchResults = [];
        _enableAutocomplete = false; // Disable autocomplete after selection
      });

      // Update cubit with selected location
      sl<PropertySetupCubit>().setLocation(description);
    }
  }

  void _toggleGpsSearch() {
    setState(() {
      _enableAutocomplete = !_enableAutocomplete;
      if (!_enableAutocomplete) {
        _searchResults = [];
      } else {
        // If there's already text, trigger a search
        final query = _locationController.text.trim();
        if (query.isNotEmpty) {
          _searchPlaces(query);
        }
      }
    });
  }

  String _buildProgressText() {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'add_property_location.progress_text'.tr(
        namedArgs: {'name': name},
      );
    }
    return 'add_property_location.progress_text_fallback'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocBuilder<PropertySetupCubit, PropertySetupState>(
      bloc: sl<PropertySetupCubit>(),
      builder: (context, state) {
        final propertyName = state.propertyName;

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            height: (screenSize.height * 0.95) + 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
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
                    SizedBox(
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
                              value: 0.7,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF8B9A5B), // Muted green color
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 32),
                          PageHeaderRow(
                            title: 'add_property_location.title'.tr(),
                            showBackButton: widget.onBack != null,
                            onBack: widget.onBack,
                          ),

                          const SizedBox(height: 40),
                          // Show property name with check icon if available
                          if (propertyName != null &&
                              propertyName.isNotEmpty) ...[
                            _buildCompletedField(value: propertyName),
                            const SizedBox(height: 24),
                          ],
                          // Location  with Autocomplete
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _enableAutocomplete
                                        ? const Color(0xFF8B9A5B)
                                        : Colors.black54,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _locationController,
                                        decoration: InputDecoration(
                                          hintText: 'add_property_location.hint'
                                              .tr(),
                                          border: InputBorder.none,
                                          hintStyle: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: Colors.grey.shade400,
                                              ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 18,
                                              ),
                                          suffixIcon:
                                              _enableAutocomplete &&
                                                  _isLoadingSearch
                                              ? const Padding(
                                                  padding: EdgeInsets.all(12.0),
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                    // TextButton(
                                    //   onPressed: _toggleGpsSearch,
                                    //   style: TextButton.styleFrom(
                                    //     foregroundColor: _enableAutocomplete
                                    //         ? const Color(0xFF8B9A5B)
                                    //         : Colors.black87,
                                    //   ),
                                    //   child:
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                      ),
                                      child: Text(
                                        'add_property_location.option_gps'.tr(),
                                      ),
                                    ),
                                    // ),
                                  ],
                                ),
                              ),
                              // Autocomplete Results
                              if (_enableAutocomplete &&
                                  _searchResults.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.black54,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final place = _searchResults[index];
                                      final description =
                                          place['description']?.toString() ??
                                          place['name']?.toString() ??
                                          place['formatted_address']
                                              ?.toString() ??
                                          'Unknown place';

                                      return InkWell(
                                        onTap: () => _selectPlace(place),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on,
                                                size: 20,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  description,
                                                  style: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                        color: Colors.black87,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ] else if (_enableAutocomplete &&
                                  _locationController.text.trim().isNotEmpty &&
                                  !_isLoadingSearch &&
                                  _searchResults.isEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.black54,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: Text(
                                    'No results found',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                          InkWell(
                            onTap: widget.onSkip,
                            child: Text(
                              'add_property_location.skip_link'.tr(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                decoration: TextDecoration.underline,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          PrimaryOutlineButton(
                            label: 'add_property_location.button_text'.tr(),
                            width: 260,
                            enabled: _locationController.text.trim().isNotEmpty,
                            onPressed:
                                _locationController.text.trim().isNotEmpty
                                ? widget.onContinue
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedField({required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/check.png',
            width: 16,
            height: 16,
            color: const Color(0xFF238636), // Green checkmark
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
