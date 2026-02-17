import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_create_bloc/verse_create_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_create_bloc/verse_create_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_create_bloc/verse_create_state.dart';

class AddVerseForm extends StatefulWidget {
  const AddVerseForm({super.key});

  @override
  State<AddVerseForm> createState() => _AddVerseFormState();
}

class _AddVerseFormState extends State<AddVerseForm> {
  final _formKey = GlobalKey<FormState>();
  final _verseNameController = TextEditingController();
  final _subdomainController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _positionController = TextEditingController();

  @override
  void dispose() {
    _verseNameController.dispose();
    _subdomainController.dispose();
    _adminEmailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  void _handleCreateVerse() {
    if (_formKey.currentState?.validate() ?? false) {
      final request = CreateVerseRequest(
        name: _verseNameController.text.trim(),
        adminEmail: _adminEmailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        position: _positionController.text.trim(),
        subdomain: _subdomainController.text.trim().toLowerCase(),
      );

      context.read<VerseCreateBloc>().add(CreateVerseRequested(request));
    }
  }

  void _clearForm() {
    _verseNameController.clear();
    _subdomainController.clear();
    _adminEmailController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    _positionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to locale changes to rebuild the widget
    final locale = context.locale;

    return BlocListener<VerseCreateBloc, VerseCreateState>(
      key: ValueKey(locale.toString()), // Force rebuild on locale change
      listener: (context, state) {
        if (state is VerseCreateSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.response.message),
              backgroundColor: Colors.green,
            ),
          );
          _clearForm();
        } else if (state is VerseCreateFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'superadmin.create_new_verse'.tr(),
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: 24),

              // Row 1: Verse Name and Subdomain
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 768;
                  final isWideScreen = constraints.maxWidth > 1400;
                  final double fieldWidth = isMobile
                      ? constraints.maxWidth
                      : isWideScreen
                      ? 500.0
                      : 350.0;
                  return Wrap(
                    spacing: isMobile ? 0 : 16,
                    runSpacing: 16,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: fieldWidth),
                        child: TextFormField(
                          controller: _verseNameController,
                          decoration: InputDecoration(
                            hintText: 'superadmin.verse_name_hint'.tr(),
                            prefixIcon: const Icon(Icons.business_outlined),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                            errorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'superadmin.errors.required'.tr();
                            }
                            return null;
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: fieldWidth),
                        child: TextFormField(
                          controller: _subdomainController,
                          decoration: InputDecoration(
                            hintText: 'e.g., gmail.com, example.com, test.et.',
                            prefixIcon: const Icon(Icons.link_outlined),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                            errorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'superadmin.errors.required'.tr();
                            }
                            final trimmedValue = value.trim().toLowerCase();

                            // Validate domain format: subdomain.domain
                            final domainRegex = RegExp(
                              r'^[a-z0-9-]+\.[a-z]{2,}$',
                              caseSensitive: false,
                            );
                            if (!domainRegex.hasMatch(trimmedValue)) {
                              return 'Please enter a valid domain (e.g., gmail.com, example.com, test.et)';
                            } else if (trimmedValue.endsWith('.org')) {
                              return 'Domain cannot end with .org';
                            }

                            // Split domain into subdomain and extension
                            final parts = trimmedValue.split('.');
                            final subdomain = parts[0];
                            final extension = parts[1];

                            // Validate subdomain part
                            if (subdomain.startsWith('-') ||
                                subdomain.endsWith('-')) {
                              return 'Subdomain cannot start or end with hyphen';
                            }
                            if (subdomain.length < 2) {
                              return 'Subdomain must be at least 2 characters';
                            }

                            // Validate extension (must be at least 2 characters)
                            if (extension.length < 2) {
                              return 'Domain extension must be at least 2 characters';
                            }

                            return null;
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Row 2: Admin Email
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 768;
                  final isWideScreen = constraints.maxWidth > 1400;
                  final double fieldWidth = isMobile
                      ? constraints.maxWidth
                      : isWideScreen
                      ? 1020.0
                      : 716.0;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: fieldWidth),
                    child: TextFormField(
                      controller: _adminEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'superadmin.admin_email_hint'.tr(),
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'superadmin.errors.required'.tr();
                        }
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'superadmin.errors.invalid_email'.tr();
                        }
                        return null;
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Row 3: First Name, Last Name, Position
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 768;
                  final isWideScreen = constraints.maxWidth > 1400;
                  final double fieldWidth = isMobile
                      ? constraints.maxWidth
                      : isWideScreen
                      ? 330.0
                      : 225.0;
                  return Wrap(
                    spacing: isMobile ? 0 : 16,
                    runSpacing: 16,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: fieldWidth),
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            hintText: 'superadmin.first_name_hint'.tr(),
                            prefixIcon: const Icon(Icons.person_outline),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                            errorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'superadmin.errors.required'.tr();
                            }
                            return null;
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: fieldWidth),
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            hintText: 'superadmin.last_name_hint'.tr(),
                            prefixIcon: const Icon(Icons.person_outline),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                            errorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'superadmin.errors.required'.tr();
                            }
                            return null;
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: fieldWidth),
                        child: TextFormField(
                          controller: _positionController,
                          decoration: InputDecoration(
                            hintText: 'superadmin.position_hint'.tr(),
                            prefixIcon: const Icon(Icons.work_outline),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                            errorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'superadmin.errors.required'.tr();
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Create Button
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 768;
                  final isWideScreen = constraints.maxWidth > 1400;
                  final double buttonWidth = isMobile
                      ? constraints.maxWidth
                      : isWideScreen
                      ? 1020.0
                      : 716.0;
                  return BlocBuilder<VerseCreateBloc, VerseCreateState>(
                    builder: (context, state) {
                      final isLoading = state is VerseCreateLoading;
                      return ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: buttonWidth),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _handleCreateVerse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: const RoundedRectangleBorder(),
                              side: const BorderSide(
                                color: Colors.black,
                                width: 3,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'superadmin.create_verse_button'.tr(),
                                    style: AppTextStyles.buttonText.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
