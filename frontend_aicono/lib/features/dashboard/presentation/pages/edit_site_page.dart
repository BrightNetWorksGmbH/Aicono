import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';

class EditSitePage extends StatefulWidget {
  final String siteId;

  const EditSitePage({super.key, required this.siteId});

  @override
  State<EditSitePage> createState() => _EditSitePageState();
}

class _EditSitePageState extends State<EditSitePage> {
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _siteAddressController = TextEditingController();
  final Set<String> _selectedResources = {};

  @override
  void initState() {
    super.initState();
    _loadSiteData();
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _siteAddressController.dispose();
    super.dispose();
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
                  .map((r) => r.trim())
                  .toList();
              _selectedResources.addAll(resources);
            }
          }
        },
        child: BlocListener<CreateSiteBloc, CreateSiteState>(
          listener: (context, state) {
            if (state is CreateSiteSuccess) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Site updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Refresh site details
                context.read<DashboardSiteDetailsBloc>().add(
                  DashboardSiteDetailsRequested(siteId: widget.siteId),
                );
                // Navigate back
                context.pop();
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
            backgroundColor: AppTheme.background,
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
                      height: screenSize.height * .9,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                                            const Expanded(
                                              child: Center(
                                                child: Text(
                                                  'Edit Site',
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Update site information',
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
                                            hintText: 'Enter site name',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(0),
                                            ),
                                            // prefixIcon: Icon(Icons.),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Site name is required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: screenSize.width < 600
                                            ? screenSize.width * 0.95
                                            : screenSize.width < 1200
                                            ? screenSize.width * 0.5
                                            : screenSize.width * 0.6,
                                        child: TextFormField(
                                          controller: _siteAddressController,
                                          decoration: InputDecoration(
                                            hintText: 'Enter site location',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(0),
                                            ),
                                            prefixIcon: Icon(Icons.place),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 24),
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
                                              label: 'Energy',
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
                                              label: 'Water',
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
                                              label: 'Gas',
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
                                      const SizedBox(height: 32),
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
                                                    _siteAddressController.text
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
                                                    const SnackBar(
                                                      content: Text(
                                                        'Site name is required',
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
                                              label: 'Save Changes',
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
