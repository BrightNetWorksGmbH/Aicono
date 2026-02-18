import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';

import '../../../../core/widgets/top_part_widget.dart';

class EditSitePage extends StatefulWidget {
  final String siteId;

  const EditSitePage({super.key, required this.siteId});

  @override
  State<EditSitePage> createState() => _EditSitePageState();
}

class _EditSitePageState extends State<EditSitePage> {
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _siteAddressController = TextEditingController();
  final FocusNode _siteAddressFocusNode = FocusNode();
  final Set<String> _selectedResources = {};
  bool _enableAutocomplete = true;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoadingSearch = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSiteData();
    // Listen to address input changes with debouncing for autocomplete
    _siteAddressController.addListener(_onAddressChanged);
    // Listen to focus changes
    _siteAddressFocusNode.addListener(() {
      setState(() {}); // Rebuild when focus changes
    });
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _siteAddressController.dispose();
    _siteAddressFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onAddressChanged() {
    if (!_enableAutocomplete) {
      return;
    }

    // Debounce autocomplete search when enabled
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = _siteAddressController.text.trim();
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
        _siteAddressController.text = description;
        _searchResults = [];
        _enableAutocomplete = false; // Disable autocomplete after selection
      });
    }
  }

  void _toggleGpsSearch() {
    setState(() {
      _enableAutocomplete = !_enableAutocomplete;
      if (!_enableAutocomplete) {
        _searchResults = [];
      } else {
        // If there's already text, trigger a search
        final query = _siteAddressController.text.trim();
        if (query.isNotEmpty) {
          _searchPlaces(query);
        }
      }
    });
  }

  void _loadSiteData() {
    // Request site details to get current values
    context.read<DashboardSiteDetailsBloc>().add(
      DashboardSiteDetailsRequested(siteId: widget.siteId),
    );
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return BlocProvider(
      create: (context) => sl<CreateSiteBloc>(),
      child: BlocListener<DashboardSiteDetailsBloc, DashboardSiteDetailsState>(
        listener: (context, state) {
          if (state is DashboardSiteDetailsSuccess) {
            // Initialize fields with current values
            _siteNameController.text = state.details.name;
            _siteAddressController.text = state.details.address;
            _selectedResources.clear();
            if (state.details.resourceType.isNotEmpty) {
              final resources = state.details.resourceType
                  .split(',')
                  .map((r) => r.trim().toLowerCase())
                  .toList();
              _selectedResources.addAll(resources);
              setState(() {});
            }
          }
        },
        child: BlocListener<CreateSiteBloc, CreateSiteState>(
          listener: (context, state) {
            if (state is CreateSiteSuccess) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('edit_site.site_updated_successfully'.tr()),
                    backgroundColor: Colors.green,
                  ),
                );
                // Refresh site details
                context.read<DashboardSiteDetailsBloc>().add(
                  DashboardSiteDetailsRequested(siteId: widget.siteId),
                );
                // Navigate back
                // context.pop();
                context.pushReplacementNamed(Routelists.dashboard);
              }
            } else if (state is CreateSiteFailure) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.primary,
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
                      height: screenSize.height * .97,
                      margin: const EdgeInsets.all(8),
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
                            child: BlocBuilder<CreateSiteBloc, CreateSiteState>(
                              builder: (context, createSiteState) {
                                final isLoading =
                                    createSiteState is CreateSiteLoading;

                                return Form(
                                  child: SizedBox(
                                    width: screenSize.width < 600
                                        ? screenSize.width * 0.95
                                        : screenSize.width < 1200
                                        ? screenSize.width * 0.5
                                        : screenSize.width * 0.6,
                                    child: Column(
                                      // crossAxisAlignment:
                                      //     CrossAxisAlignment.stretch,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: TopHeader(
                                            onLanguageChanged:
                                                _handleLanguageChanged,
                                            containerWidth:
                                                screenSize.width > 500
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
                                                icon: const Icon(
                                                  Icons.arrow_back,
                                                ),
                                                onPressed: () => context.pop(),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Center(
                                                  child: Text(
                                                    'edit_site.page_title'.tr(),
                                                    style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'edit_site.subtitle'.tr(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        // Site name field
                                        SizedBox(
                                          width: screenSize.width < 600
                                              ? screenSize.width * 0.95
                                              : screenSize.width < 1200
                                              ? screenSize.width * 0.5
                                              : screenSize.width * 0.6,
                                          child: TextFormField(
                                            controller: _siteNameController,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'edit_site.site_name_hint'
                                                      .tr(),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 20,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(0),
                                                borderSide: BorderSide(
                                                  color: const Color(
                                                    0xFF8B9A5B,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(0),
                                                borderSide: BorderSide(
                                                  color: const Color(
                                                    0xFF8B9A5B,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(0),
                                                borderSide: BorderSide(
                                                  color: const Color(
                                                    0xFF8B9A5B,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                              // prefixIcon: Icon(Icons.),
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'edit_site.site_name_required'
                                                    .tr();
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Site address field with Autocomplete
                                        SizedBox(
                                          width: screenSize.width < 600
                                              ? screenSize.width * 0.95
                                              : screenSize.width < 1200
                                              ? screenSize.width * 0.5
                                              : screenSize.width * 0.6,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF8B9A5B,
                                                    ),
                                                    width: 2,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.zero,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextFormField(
                                                        controller:
                                                            _siteAddressController,
                                                        focusNode:
                                                            _siteAddressFocusNode,
                                                        decoration: InputDecoration(
                                                          hintText:
                                                              'edit_site.site_location_hint'
                                                                  .tr(),
                                                          border:
                                                              InputBorder.none,
                                                          hintStyle: AppTextStyles
                                                              .bodyMedium
                                                              .copyWith(
                                                                color: Colors
                                                                    .grey
                                                                    .shade400,
                                                              ),
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 16,
                                                                vertical: 18,
                                                              ),
                                                          prefixIcon:
                                                              const Icon(
                                                                Icons.place,
                                                              ),
                                                          suffixIcon:
                                                              _enableAutocomplete &&
                                                                  _isLoadingSearch
                                                              ? const Padding(
                                                                  padding:
                                                                      EdgeInsets.all(
                                                                        12.0,
                                                                      ),
                                                                  child: SizedBox(
                                                                    width: 20,
                                                                    height: 20,
                                                                    child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                                  ),
                                                                )
                                                              : null,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8.0,
                                                          ),
                                                      child: Text(
                                                        'edit_site.gps'.tr(),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Autocomplete Results
                                              if (_enableAutocomplete &&
                                                  _siteAddressFocusNode
                                                      .hasFocus &&
                                                  _siteAddressController.text
                                                      .trim()
                                                      .isNotEmpty &&
                                                  _searchResults
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.black54,
                                                      width: 2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.zero,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxHeight: 200,
                                                      ),
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        _searchResults.length,
                                                    itemBuilder: (context, index) {
                                                      final place =
                                                          _searchResults[index];
                                                      final description =
                                                          place['description']
                                                              ?.toString() ??
                                                          place['name']
                                                              ?.toString() ??
                                                          place['formatted_address']
                                                              ?.toString() ??
                                                          'Unknown place';

                                                      return InkWell(
                                                        onTap: () =>
                                                            _selectPlace(place),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 16,
                                                                vertical: 12,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .location_on,
                                                                size: 20,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  description,
                                                                  style: AppTextStyles
                                                                      .bodyMedium
                                                                      .copyWith(
                                                                        color: Colors
                                                                            .black87,
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
                                                  _siteAddressFocusNode
                                                      .hasFocus &&
                                                  _siteAddressController.text
                                                      .trim()
                                                      .isNotEmpty &&
                                                  !_isLoadingSearch &&
                                                  _searchResults.isEmpty) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(
                                                    16.0,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.black54,
                                                      width: 2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.zero,
                                                  ),
                                                  child: Text(
                                                    'edit_site.no_results_found'
                                                        .tr(),
                                                    style: AppTextStyles
                                                        .bodyMedium
                                                        .copyWith(
                                                          color: Colors.grey,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 16),
                                        // Resource selection
                                        SizedBox(
                                          width: screenSize.width < 600
                                              ? screenSize.width * 0.95
                                              : screenSize.width < 1200
                                              ? screenSize.width * 0.5
                                              : screenSize.width * 0.6,
                                          child: Row(
                                            children: [
                                              _buildResourceCheckbox(
                                                value: 'energy',
                                                label:
                                                    'edit_site.resource_energy'
                                                        .tr(),
                                                isSelected: _selectedResources
                                                    .contains('energy'),
                                                onChanged: (selected) {
                                                  setState(() {
                                                    if (selected) {
                                                      _selectedResources.add(
                                                        'energy',
                                                      );
                                                    } else {
                                                      _selectedResources.remove(
                                                        'energy',
                                                      );
                                                    }
                                                  });
                                                },
                                              ),
                                              const SizedBox(width: 24),
                                              _buildResourceCheckbox(
                                                value: 'water',
                                                label:
                                                    'edit_site.resource_water'
                                                        .tr(),
                                                isSelected: _selectedResources
                                                    .contains('water'),
                                                onChanged: (selected) {
                                                  setState(() {
                                                    if (selected) {
                                                      _selectedResources.add(
                                                        'water',
                                                      );
                                                    } else {
                                                      _selectedResources.remove(
                                                        'water',
                                                      );
                                                    }
                                                  });
                                                },
                                              ),
                                              const SizedBox(width: 24),
                                              _buildResourceCheckbox(
                                                value: 'gas',
                                                label: 'edit_site.resource_gas'
                                                    .tr(),
                                                isSelected: _selectedResources
                                                    .contains('gas'),
                                                onChanged: (selected) {
                                                  setState(() {
                                                    if (selected) {
                                                      _selectedResources.add(
                                                        'gas',
                                                      );
                                                    } else {
                                                      _selectedResources.remove(
                                                        'gas',
                                                      );
                                                    }
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 48),
                                        // Save button
                                        isLoading
                                            ? const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              )
                                            : PrimaryOutlineButton(
                                                onPressed: () {
                                                  final siteName =
                                                      _siteNameController.text
                                                          .trim();
                                                  final siteAddress =
                                                      _siteAddressController
                                                          .text
                                                          .trim();
                                                  final resourceType =
                                                      _selectedResources.isEmpty
                                                      ? ''
                                                      : _selectedResources.join(
                                                          ', ',
                                                        );

                                                  if (siteName.isEmpty) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'edit_site.site_name_required'
                                                              .tr(),
                                                        ),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                    return;
                                                  }

                                                  final request =
                                                      CreateSiteRequest(
                                                        name: siteName,
                                                        address: siteAddress,
                                                        resourceType:
                                                            resourceType,
                                                      );

                                                  context
                                                      .read<CreateSiteBloc>()
                                                      .add(
                                                        UpdateSiteSubmitted(
                                                          siteId: widget.siteId,
                                                          request: request,
                                                        ),
                                                      );
                                                },
                                                label: 'edit_site.save_changes'
                                                    .tr(),
                                                width: 260,
                                              ),
                                      ],
                                    ),
                                  ),
                                );
                              },
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
        ),
      ),
    );
  }

  Widget _buildResourceCheckbox({
    required String value,
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!isSelected),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          XCheckBox(
            value: isSelected,
            onChanged: (bool? newValue) {
              onChanged(newValue ?? false);
            },
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
