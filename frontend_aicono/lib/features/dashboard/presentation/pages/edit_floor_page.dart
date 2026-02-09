import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_floor_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/dashboard_main_content.dart'
    show FloorPlanEditorWrapper;

import '../../../../core/widgets/primary_outline_button.dart';

class EditFloorPage extends StatefulWidget {
  final String floorId;

  const EditFloorPage({super.key, required this.floorId});

  @override
  State<EditFloorPage> createState() => _EditFloorPageState();
}

class _EditFloorPageState extends State<EditFloorPage> {
  final TextEditingController _floorNameController = TextEditingController();
  bool _isLoading = false;
  String? _floorPlanUrl;
  String? _floorName;

  @override
  void initState() {
    super.initState();
    _loadFloorData();
  }

  @override
  void dispose() {
    _floorNameController.dispose();
    super.dispose();
  }

  void _loadFloorData() {
    // Request floor details to get current values
    context.read<DashboardFloorDetailsBloc>().add(
      DashboardFloorDetailsRequested(floorId: widget.floorId),
    );
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return BlocListener<DashboardFloorDetailsBloc, DashboardFloorDetailsState>(
      listener: (context, state) {
        if (state is DashboardFloorDetailsSuccess) {
          // Initialize fields with current values
          setState(() {
            _floorNameController.text = state.details.name;
            _floorPlanUrl = state.details.floorPlanLink;
            _floorName = state.details.name;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SingleChildScrollView(
          child: Center(
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
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: screenSize.width < 600
                          ? screenSize.width * 0.95
                          : screenSize.width < 1200
                          ? screenSize.width * 0.5
                          : screenSize.width * 0.6,
                      child: Form(
                        child: Column(
                          // crossAxisAlignment: CrossAxisAlignment.stretch,
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () => context.pop(),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Center(
                                      child: Text(
                                        'Edit Floor',
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
                              'Update floor information',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Floor name field
                            SizedBox(
                              width: screenSize.width < 600
                                  ? screenSize.width * 0.95
                                  : screenSize.width < 1200
                                  ? screenSize.width * 0.5
                                  : screenSize.width * 0.6,
                              child: TextFormField(
                                controller: _floorNameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter floor name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  prefixIcon: Icon(Icons.layers),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Floor name is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Floor Plan Editor Section
                            const Text(
                              'Edit Floor Plan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add or edit rooms and floor plan',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_floorName != null && _floorName!.isNotEmpty)
                              SizedBox(
                                width: screenSize.width < 600
                                    ? screenSize.width * 0.95
                                    : screenSize.width < 1200
                                    ? screenSize.width * 0.5
                                    : screenSize.width * 0.6,
                                child: FloorPlanEditorWrapper(
                                  floorId: widget.floorId,
                                  floorName: _floorName!,
                                  initialFloorPlanUrl: _floorPlanUrl,
                                  onSave: (String? floorPlanUrl) async {
                                    // Save floor plan URL
                                    if (floorPlanUrl != null) {
                                      try {
                                        final dioClient = sl<DioClient>();
                                        await dioClient.patch(
                                          '/api/v1/floors/${widget.floorId}',
                                          data: {
                                            'floor_plan_link': floorPlanUrl,
                                          },
                                        );
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Floor plan saved successfully',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          // Refresh floor details
                                          context
                                              .read<DashboardFloorDetailsBloc>()
                                              .add(
                                                DashboardFloorDetailsRequested(
                                                  floorId: widget.floorId,
                                                ),
                                              );
                                          setState(() {
                                            _floorPlanUrl = floorPlanUrl;
                                          });
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error saving floor plan: $e',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  onCancel: () {
                                    // Cancel action - can be empty or navigate back
                                  },
                                ),
                              )
                            else
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            const SizedBox(height: 32),
                            // Save button
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : PrimaryOutlineButton(
                                    width: 260,
                                    onPressed: _handleSave,
                                    label: 'Save Changes',
                                  ),
                          ],
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
    );
  }

  Future<void> _handleSave() async {
    final floorName = _floorNameController.text.trim();

    if (floorName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Floor name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dioClient = sl<DioClient>();
      final requestBody = <String, dynamic>{'name': floorName};

      final response = await dioClient.patch(
        '/api/v1/floors/${widget.floorId}',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Floor updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh floor details
          context.read<DashboardFloorDetailsBloc>().add(
            DashboardFloorDetailsRequested(floorId: widget.floorId),
          );
          // Navigate back
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update floor: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating floor: $e'),
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
}
