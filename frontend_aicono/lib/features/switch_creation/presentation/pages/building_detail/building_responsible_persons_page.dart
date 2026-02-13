import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';

import '../../../../../core/storage/local_storage.dart';
import '../../../../../core/widgets/page_header_row.dart';

class BuildingResponsiblePersonsPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? buildingId;
  final String? buildingIds; // Comma-separated list of buildingIds
  final String? siteId;
  final String? recipientsJson; // Legacy: for backward compatibility
  final String? recipient; // Current recipient being configured
  final String? allRecipients; // All recipients list
  final String? recipientConfigs; // Existing configurations
  final String? createForAll; // Flag to indicate "create for all" mode
  final String? reportConfigs; // Report configs from "create for all" dialog
  final String?
  fromDashboard; // Flag to indicate if navigation is from dashboard
  final String? floorName; // Floor name from add floor name page

  const BuildingResponsiblePersonsPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.buildingId,
    this.buildingIds,
    this.siteId,
    this.recipientsJson,
    this.recipient,
    this.allRecipients,
    this.recipientConfigs,
    this.createForAll,
    this.reportConfigs,
    this.fromDashboard,
    this.floorName,
  });

  @override
  State<BuildingResponsiblePersonsPage> createState() =>
      _BuildingResponsiblePersonsPageState();
}

class _BuildingResponsiblePersonsPageState
    extends State<BuildingResponsiblePersonsPage> {
  final TextEditingController _reportingNameController =
      TextEditingController();
  String _selectedFrequencyKey = 'monthly';
  Map<String, bool> _reportOptions = {
    'total_consumption': true,
    'consumption_by_room': true,
    'peak_loads': false,
    'measurement_type_breakdown': false,
    'eui': false,
    'per_capita_consumption': false,
    'benchmark_comparison': false,
    'inefficient_usage': true,
    'anomalies': false,
    'period_comparison': false,
    'time_based_analysis': false,
    'building_comparison': false,
    'temperature_analysis': false,
    'data_quality_report': false,
  };
  final List<Map<String, dynamic>> _responsiblePersons = [];
  final DioClient _dioClient = sl<DioClient>();
  bool _isLoading = false;
  Map<String, dynamic>? _currentRecipient;
  List<Map<String, dynamic>> _allRecipients = [];
  Map<String, Map<String, dynamic>> _allRecipientConfigs = {};
  Map<String, Map<String, dynamic>> _completedConfigs = {};
  List<Map<String, dynamic>> _savedReportConfigs =
      []; // Store multiple saved report configs
  int? _editingConfigIndex; // Track which config is being edited

  String get _selectedFrequency =>
      'building_responsible_persons.$_selectedFrequencyKey'.tr();

  @override
  void initState() {
    super.initState();
    // Parse current recipient if provided
    if (widget.recipient != null && widget.recipient!.isNotEmpty) {
      try {
        _currentRecipient = jsonDecode(widget.recipient!);
        // Load existing config if available
        if (widget.recipientConfigs != null &&
            widget.recipientConfigs!.isNotEmpty) {
          _allRecipientConfigs = Map<String, Map<String, dynamic>>.from(
            jsonDecode(widget.recipientConfigs!),
          );
          final recipientId = _currentRecipient!['id'];
          if (_allRecipientConfigs.containsKey(recipientId)) {
            final config = _allRecipientConfigs[recipientId]!;
            _reportingNameController.text = config['name'] ?? '';
            _selectedFrequencyKey = config['intervalKey'] ?? 'monthly';
            if (config['reportOptions'] != null) {
              _reportOptions.addAll(
                Map<String, bool>.from(config['reportOptions']),
              );
            }
          }
        }
      } catch (e) {
        // If parsing fails, ignore
      }
    }
    // Parse all recipients if provided
    if (widget.allRecipients != null && widget.allRecipients!.isNotEmpty) {
      try {
        _allRecipients = List<Map<String, dynamic>>.from(
          jsonDecode(widget.allRecipients!),
        );
      } catch (e) {
        // If parsing fails, ignore
      }
    }
    // Parse existing configs
    if (widget.recipientConfigs != null &&
        widget.recipientConfigs!.isNotEmpty) {
      try {
        _allRecipientConfigs = Map<String, Map<String, dynamic>>.from(
          jsonDecode(widget.recipientConfigs!),
        );
        _completedConfigs = Map.from(_allRecipientConfigs);
      } catch (e) {
        // If parsing fails, ignore
      }
    }
    // Parse reportConfigs from "create for all" dialog if provided
    if (widget.reportConfigs != null && widget.reportConfigs!.isNotEmpty) {
      try {
        final decoded = jsonDecode(widget.reportConfigs!) as List;
        _savedReportConfigs = decoded.map<Map<String, dynamic>>((config) {
          return Map<String, dynamic>.from(config);
        }).toList();
      } catch (e) {
        // If parsing fails, ignore
      }
    }
  }

  @override
  void dispose() {
    _reportingNameController.dispose();
    super.dispose();
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _navigateAfterCompletion() {
    // If user came from dashboard (e.g. via reports sidebar), go back to dashboard.
    final isFromDashboard = widget.fromDashboard == 'true';
    if (isFromDashboard) {
      context.goNamed(Routelists.dashboard);
      return;
    }

    // Default behaviour for the building setup wizard: continue to building setup.
    context.goNamed(
      Routelists.buildingSetup,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.siteId != null) 'siteId': widget.siteId!,
        if (widget.buildingId != null) 'buildingId': widget.buildingId!,
        if (widget.fromDashboard != null)
          'fromDashboard': widget.fromDashboard!,
      },
    );
    // final propertyCubit = sl<PropertySetupCubit>();
    // final switchId = propertyCubit.state.switchId;
    // final localStorage = sl<LocalStorage>();
    // final siteId =
    //     widget.siteId ??
    //     Uri.parse(
    //       GoRouterState.of(context).uri.toString(),
    //     ).queryParameters['siteId'];
    // // localStorage.getSelectedSiteId() ?? propertyCubit.state.siteId;

    // // Check if navigation is from dashboard
    // final isFromDashboard = widget.fromDashboard == 'true';

    // if (isFromDashboard) {
    //   // If from dashboard, redirect to dashboard after completion
    //   context.goNamed(Routelists.dashboard);
    // } else if (siteId == null && switchId != null && switchId.isNotEmpty) {
    //   context.goNamed(
    //     Routelists.addPropertyName,
    //     queryParameters: {'switchId': switchId},
    //   );
    // } else {
    //   // Fallback: navigate to additional building list if switchId not available

    //   context.goNamed(
    //     Routelists.additionalBuildingList,
    //     queryParameters: {
    //       if (widget.userName != null) 'userName': widget.userName!,
    //       if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
    //       if (widget.fromDashboard != null)
    //         'fromDashboard': widget.fromDashboard!,
    //     },
    //   );
    // }
  }

  void _handleFrequencyChange() {
    // Show frequency selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('building_responsible_persons.select_frequency'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFrequencyOption(
              'building_responsible_persons.daily'.tr(),
              'daily',
            ),
            _buildFrequencyOption(
              'building_responsible_persons.weekly'.tr(),
              'weekly',
            ),
            _buildFrequencyOption(
              'building_responsible_persons.monthly'.tr(),
              'monthly',
            ),
            _buildFrequencyOption(
              'building_responsible_persons.yearly'.tr(),
              'yearly',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyOption(String frequency, String key) {
    return ListTile(
      title: Text(frequency),
      onTap: () {
        setState(() {
          _selectedFrequencyKey = key;
        });
        Navigator.of(context).pop();
      },
    );
  }

  void _handleReportOptionToggle(String option) {
    setState(() {
      _reportOptions[option] = !(_reportOptions[option] ?? false);
    });
  }

  bool _validateCurrentForm() {
    // If there's at least one saved config, validation passes
    if (_savedReportConfigs.isNotEmpty) {
      return true;
    }

    // Otherwise, validate the current form
    // Check if reporting name is filled
    if (_reportingNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'building_responsible_persons.validation_name_required'.tr(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Check if at least one report option is selected
    final hasSelectedOption = _reportOptions.values.any(
      (value) => value == true,
    );
    if (!hasSelectedOption) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'building_responsible_persons.validation_option_required'.tr(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  void _handleCreateOwnRoutine() {
    // Validate current form
    if (!_validateCurrentForm()) {
      return;
    }

    // Build report contents from selected options
    List<String> reportContents = [];
    if (_reportOptions['total_consumption'] == true) {
      reportContents.add('TotalConsumption');
    }
    if (_reportOptions['consumption_by_room'] == true) {
      reportContents.add('ConsumptionByRoom');
    }
    if (_reportOptions['peak_loads'] == true) {
      reportContents.add('PeakLoads');
    }
    if (_reportOptions['measurement_type_breakdown'] == true) {
      reportContents.add('MeasurementTypeBreakdown');
    }
    if (_reportOptions['eui'] == true) {
      reportContents.add('EUI');
    }
    if (_reportOptions['per_capita_consumption'] == true) {
      reportContents.add('PerCapitaConsumption');
    }
    if (_reportOptions['benchmark_comparison'] == true) {
      reportContents.add('BenchmarkComparison');
    }
    if (_reportOptions['inefficient_usage'] == true) {
      reportContents.add('InefficientUsage');
    }
    if (_reportOptions['anomalies'] == true) {
      reportContents.add('Anomalies');
    }
    if (_reportOptions['period_comparison'] == true) {
      reportContents.add('PeriodComparison');
    }
    if (_reportOptions['time_based_analysis'] == true) {
      reportContents.add('TimeBasedAnalysis');
    }
    if (_reportOptions['building_comparison'] == true) {
      reportContents.add('BuildingComparison');
    }
    if (_reportOptions['temperature_analysis'] == true) {
      reportContents.add('TemperatureAnalysis');
    }
    if (_reportOptions['data_quality_report'] == true) {
      reportContents.add('DataQualityReport');
    }

    // Map frequency key to API format
    String interval = 'Monthly';
    switch (_selectedFrequencyKey) {
      case 'daily':
        interval = 'Daily';
        break;
      case 'weekly':
        interval = 'Weekly';
        break;
      case 'monthly':
        interval = 'Monthly';
        break;
      case 'yearly':
        interval = 'Yearly';
        break;
    }

    // Save current config to the list
    final wasEditing = _editingConfigIndex != null;

    setState(() {
      final configData = {
        'name': _reportingNameController.text.trim(),
        'interval': interval,
        'intervalKey': _selectedFrequencyKey,
        'reportContents': reportContents,
        'reportOptions': Map<String, bool>.from(_reportOptions),
        'completed': true,
      };

      if (_editingConfigIndex != null) {
        // Update existing config
        _savedReportConfigs[_editingConfigIndex!] = configData;
        _editingConfigIndex = null;
      } else {
        // Add new config
        _savedReportConfigs.add(configData);
      }

      // Reset form for new entry
      _reportingNameController.clear();
      _selectedFrequencyKey = 'monthly';
      _reportOptions = {
        'total_consumption': true,
        'consumption_by_room': true,
        'peak_loads': false,
        'measurement_type_breakdown': false,
        'eui': false,
        'per_capita_consumption': false,
        'benchmark_comparison': false,
        'inefficient_usage': true,
        'anomalies': false,
        'period_comparison': false,
        'time_based_analysis': false,
        'building_comparison': false,
        'temperature_analysis': false,
        'data_quality_report': false,
      };
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasEditing
              ? 'building_responsible_persons.routine_updated'.tr()
              : 'building_responsible_persons.routine_saved'.tr(),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getReportOptionLabel(String key) {
    // Map option keys to translation keys from en.json
    final translationKeyMap = {
      'total_consumption': 'Total Consumption',
      'consumption_by_room': 'Consumption by Room',
      'peak_loads': 'Peak Loads',
      'measurement_type_breakdown': 'Measurement Type Breakdown',
      'eui': 'EUI',
      'per_capita_consumption': 'Per Capita Consumption',
      'benchmark_comparison': 'Benchmark Comparison',
      'inefficient_usage': 'Inefficient Usage',
      'anomalies': 'Anomalies',
      'period_comparison': 'Period Comparison',
      'time_based_analysis': 'Time Based Analysis',
      'building_comparison': 'Building Comparison',
      'temperature_analysis': 'Temperature Analysis',
      'data_quality_report': 'Data Quality Report',
    };

    final translationKey = translationKeyMap[key] ?? key;
    return translationKey.tr();
  }

  void _showEditRoutineDialog(int index) {
    final savedConfig = _savedReportConfigs[index];
    final screenSize = MediaQuery.of(context).size;

    // Create controllers for the dialog
    final TextEditingController dialogNameController = TextEditingController(
      text: savedConfig['name'] ?? '',
    );
    String dialogSelectedFrequencyKey = savedConfig['intervalKey'] ?? 'monthly';
    Map<String, bool> dialogReportOptions = Map<String, bool>.from(
      savedConfig['reportOptions'] ??
          {
            'total_consumption': true,
            'consumption_by_room': true,
            'peak_loads': false,
            'measurement_type_breakdown': false,
            'eui': false,
            'per_capita_consumption': false,
            'benchmark_comparison': false,
            'inefficient_usage': true,
            'anomalies': false,
            'period_comparison': false,
            'time_based_analysis': false,
            'building_comparison': false,
            'temperature_analysis': false,
            'data_quality_report': false,
          },
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Function to validate form
          bool validateForm() {
            if (dialogNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'building_responsible_persons.validation_name_required'
                        .tr(),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return false;
            }

            final hasSelectedOption = dialogReportOptions.values.any(
              (value) => value == true,
            );
            if (!hasSelectedOption) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'building_responsible_persons.validation_at_least_one_option'
                        .tr(),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return false;
            }

            return true;
          }

          // Function to save changes
          void saveChanges() {
            if (!validateForm()) {
              return;
            }

            // Build report contents from selected options
            List<String> reportContents = [];
            if (dialogReportOptions['total_consumption'] == true) {
              reportContents.add('TotalConsumption');
            }
            if (dialogReportOptions['consumption_by_room'] == true) {
              reportContents.add('ConsumptionByRoom');
            }
            if (dialogReportOptions['peak_loads'] == true) {
              reportContents.add('PeakLoads');
            }
            if (dialogReportOptions['measurement_type_breakdown'] == true) {
              reportContents.add('MeasurementTypeBreakdown');
            }
            if (dialogReportOptions['eui'] == true) {
              reportContents.add('EUI');
            }
            if (dialogReportOptions['per_capita_consumption'] == true) {
              reportContents.add('PerCapitaConsumption');
            }
            if (dialogReportOptions['benchmark_comparison'] == true) {
              reportContents.add('BenchmarkComparison');
            }
            if (dialogReportOptions['inefficient_usage'] == true) {
              reportContents.add('InefficientUsage');
            }
            if (dialogReportOptions['anomalies'] == true) {
              reportContents.add('Anomalies');
            }
            if (dialogReportOptions['period_comparison'] == true) {
              reportContents.add('PeriodComparison');
            }
            if (dialogReportOptions['time_based_analysis'] == true) {
              reportContents.add('TimeBasedAnalysis');
            }
            if (dialogReportOptions['building_comparison'] == true) {
              reportContents.add('BuildingComparison');
            }
            if (dialogReportOptions['temperature_analysis'] == true) {
              reportContents.add('TemperatureAnalysis');
            }
            if (dialogReportOptions['data_quality_report'] == true) {
              reportContents.add('DataQualityReport');
            }

            // Map frequency key to API format
            String interval = 'Monthly';
            switch (dialogSelectedFrequencyKey) {
              case 'daily':
                interval = 'Daily';
                break;
              case 'weekly':
                interval = 'Weekly';
                break;
              case 'monthly':
                interval = 'Monthly';
                break;
              case 'yearly':
                interval = 'Yearly';
                break;
            }

            // Update the saved config
            setState(() {
              _savedReportConfigs[index] = {
                'name': dialogNameController.text.trim(),
                'interval': interval,
                'intervalKey': dialogSelectedFrequencyKey,
                'reportContents': reportContents,
                'reportOptions': Map<String, bool>.from(dialogReportOptions),
                'completed': true,
              };
            });

            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'building_responsible_persons.routine_updated'.tr(),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Build checkbox widget for dialog
          Widget buildDialogCheckbox(String option) {
            final isSelected = dialogReportOptions[option] ?? false;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setDialogState(() {
                    dialogReportOptions[option] = !isSelected;
                  });
                },
                borderRadius: BorderRadius.zero,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black54, width: 1),
                          borderRadius: BorderRadius.zero,
                          color: Colors.white,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.black,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getReportOptionLabel(option),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            backgroundColor: Colors.white,
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding: const EdgeInsets.all(24),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'building_responsible_persons.edit_routine'.tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
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
                  ? screenSize.width * 0.6
                  : screenSize.width * 0.5,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle
                    Text(
                      'building_responsible_persons.edit_routine_subtitle'.tr(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Report Name Field
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF8B9A5B),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: TextFormField(
                        controller: dialogNameController,
                        decoration: InputDecoration(
                          hintText:
                              'building_responsible_persons.reporting_name_hint'
                                  .tr(),
                          border: InputBorder.none,
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Frequency Field
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF8B9A5B),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'building_responsible_persons.$dialogSelectedFrequencyKey'
                                  .tr(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Builder(
                            builder: (buttonContext) => Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  final RenderBox? renderBox =
                                      buttonContext.findRenderObject()
                                          as RenderBox?;
                                  if (renderBox != null) {
                                    final Offset offset = renderBox
                                        .localToGlobal(Offset.zero);
                                    final Size size = renderBox.size;

                                    final double left = offset.dx;
                                    final double top = offset.dy + size.height;
                                    final double right =
                                        MediaQuery.of(context).size.width -
                                        left -
                                        size.width;
                                    final double bottom =
                                        MediaQuery.of(context).size.height -
                                        top -
                                        200;

                                    showMenu(
                                      context: context,
                                      color: Colors.white,
                                      position: RelativeRect.fromLTRB(
                                        left,
                                        top,
                                        right,
                                        bottom,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(0),
                                      ),
                                      elevation: 8,
                                      items: [
                                        PopupMenuItem<String>(
                                          value: 'daily',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              'building_responsible_persons.daily'
                                                  .tr(),
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color: Colors.black87,
                                                    fontWeight:
                                                        dialogSelectedFrequencyKey ==
                                                            'daily'
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                            ),
                                          ),
                                          onTap: () {
                                            Future.delayed(Duration.zero, () {
                                              setDialogState(() {
                                                dialogSelectedFrequencyKey =
                                                    'daily';
                                              });
                                            });
                                          },
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'weekly',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              'building_responsible_persons.weekly'
                                                  .tr(),
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color: Colors.black87,
                                                    fontWeight:
                                                        dialogSelectedFrequencyKey ==
                                                            'weekly'
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                            ),
                                          ),
                                          onTap: () {
                                            Future.delayed(Duration.zero, () {
                                              setDialogState(() {
                                                dialogSelectedFrequencyKey =
                                                    'weekly';
                                              });
                                            });
                                          },
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'monthly',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              'building_responsible_persons.monthly'
                                                  .tr(),
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color: Colors.black87,
                                                    fontWeight:
                                                        dialogSelectedFrequencyKey ==
                                                            'monthly'
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                            ),
                                          ),
                                          onTap: () {
                                            Future.delayed(Duration.zero, () {
                                              setDialogState(() {
                                                dialogSelectedFrequencyKey =
                                                    'monthly';
                                              });
                                            });
                                          },
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'yearly',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              'building_responsible_persons.yearly'
                                                  .tr(),
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color: Colors.black87,
                                                    fontWeight:
                                                        dialogSelectedFrequencyKey ==
                                                            'yearly'
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                            ),
                                          ),
                                          onTap: () {
                                            Future.delayed(Duration.zero, () {
                                              setDialogState(() {
                                                dialogSelectedFrequencyKey =
                                                    'yearly';
                                              });
                                            });
                                          },
                                        ),
                                      ],
                                    );
                                  }
                                },
                                child: Text(
                                  '+ ${'building_responsible_persons.change_frequency'.tr()}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    decoration: TextDecoration.underline,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Report Options Checkboxes
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        buildDialogCheckbox('total_consumption'),
                        buildDialogCheckbox('consumption_by_room'),
                        buildDialogCheckbox('peak_loads'),
                        buildDialogCheckbox('measurement_type_breakdown'),
                        buildDialogCheckbox('eui'),
                        buildDialogCheckbox('per_capita_consumption'),
                        buildDialogCheckbox('benchmark_comparison'),
                        buildDialogCheckbox('inefficient_usage'),
                        buildDialogCheckbox('anomalies'),
                        buildDialogCheckbox('period_comparison'),
                        buildDialogCheckbox('time_based_analysis'),
                        buildDialogCheckbox('building_comparison'),
                        buildDialogCheckbox('temperature_analysis'),
                        buildDialogCheckbox('data_quality_report'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              PrimaryOutlineButton(
                label: 'building_recipient.done'.tr(),
                onPressed: saveChanges,
                width: 260,
              ),
            ],
            actionsAlignment: MainAxisAlignment.center,
          );
        },
      ),
    );
  }

  void _handleAddResponsiblePerson() {
    setState(() {
      _responsiblePersons.add({
        'name': '',
        'email': '',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    });
  }

  void _handleRemoveResponsiblePerson(String id) {
    setState(() {
      _responsiblePersons.removeWhere((person) => person['id'] == id);
    });
  }

  void _handleResponsiblePersonNameChanged(String id, String name) {
    setState(() {
      final index = _responsiblePersons.indexWhere(
        (person) => person['id'] == id,
      );
      if (index != -1) {
        _responsiblePersons[index]['name'] = name;
      }
    });
  }

  void _handleResponsiblePersonEmailChanged(String id, String email) {
    setState(() {
      final index = _responsiblePersons.indexWhere(
        (person) => person['id'] == id,
      );
      if (index != -1) {
        _responsiblePersons[index]['email'] = email;
      }
    });
  }

  void _saveCurrentConfig() {
    // Build report contents from selected options
    List<String> reportContents = [];
    if (_reportOptions['total_consumption'] == true) {
      reportContents.add('TotalConsumption');
    }
    if (_reportOptions['consumption_by_room'] == true) {
      reportContents.add('ConsumptionByRoom');
    }
    if (_reportOptions['peak_loads'] == true) {
      reportContents.add('PeakLoads');
    }
    if (_reportOptions['measurement_type_breakdown'] == true) {
      reportContents.add('MeasurementTypeBreakdown');
    }
    if (_reportOptions['eui'] == true) {
      reportContents.add('EUI');
    }
    if (_reportOptions['per_capita_consumption'] == true) {
      reportContents.add('PerCapitaConsumption');
    }
    if (_reportOptions['benchmark_comparison'] == true) {
      reportContents.add('BenchmarkComparison');
    }
    if (_reportOptions['inefficient_usage'] == true) {
      reportContents.add('InefficientUsage');
    }
    if (_reportOptions['anomalies'] == true) {
      reportContents.add('Anomalies');
    }
    if (_reportOptions['period_comparison'] == true) {
      reportContents.add('PeriodComparison');
    }
    if (_reportOptions['time_based_analysis'] == true) {
      reportContents.add('TimeBasedAnalysis');
    }
    if (_reportOptions['building_comparison'] == true) {
      reportContents.add('BuildingComparison');
    }
    if (_reportOptions['temperature_analysis'] == true) {
      reportContents.add('TemperatureAnalysis');
    }
    if (_reportOptions['data_quality_report'] == true) {
      reportContents.add('DataQualityReport');
    }

    // Map frequency key to API format
    String interval = 'Monthly';
    switch (_selectedFrequencyKey) {
      case 'daily':
        interval = 'Daily';
        break;
      case 'weekly':
        interval = 'Weekly';
        break;
      case 'monthly':
        interval = 'Monthly';
        break;
      case 'yearly':
        interval = 'Yearly';
        break;
    }

    // Save current recipient's configuration
    if (_currentRecipient != null) {
      final recipientId = _currentRecipient!['id']?.toString();
      if (recipientId != null) {
        final config = {
          'name': _reportingNameController.text.isNotEmpty
              ? _reportingNameController.text
              : 'Executive Weekly Report',
          'interval': interval,
          'intervalKey': _selectedFrequencyKey,
          'reportContents': reportContents,
          'reportOptions': Map<String, bool>.from(_reportOptions),
        };
        _completedConfigs[recipientId] = config;
        _allRecipientConfigs[recipientId] = config;
      }
    }
  }

  void _handleSaveAndBack() {
    // Save current configuration
    _saveCurrentConfig();

    // Update all recipient configs with completed configs
    _allRecipientConfigs.addAll(_completedConfigs);

    // Return to previous page with updated config
    if (mounted) {
      Navigator.of(context).pop(_allRecipientConfigs);
    }
  }

  Future<void> _handleCreateForAll() async {
    if (_isLoading) return;

    // Validate form before proceeding
    if (!_validateCurrentForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // PART 1: Build reportingRecipients from building_recipient_page.dart
      // Each recipient should include their individual reportConfig array
      List<Map<String, dynamic>> reportingRecipients = [];

      if (widget.recipientsJson != null && widget.recipientsJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(widget.recipientsJson!) as List;
          for (var r in decoded) {
            final recipientData = <String, dynamic>{};

            // Check if ID is from backend (MongoDB ObjectId - 24 hex characters)
            final recipientId = r['id']?.toString() ?? '';
            final isBackendId =
                recipientId.length == 24 &&
                RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(recipientId);

            if (isBackendId) {
              // For recipients from backend (automatic domain), only send id and reportConfig
              recipientData['id'] = recipientId;

              // Include reportConfig if present (from individual recipient configuration)
              // This comes from the "Edit" button dialog in building_recipient_page.dart
              if (r['reportConfig'] != null && r['reportConfig'] is List) {
                // Use reportConfig directly from the recipient page
                recipientData['reportConfig'] = r['reportConfig'];
              }
            } else {
              // For manually added recipients (frontend-generated ID), send name and email
              recipientData['name'] = (r['name'] ?? '').toString().trim();
              recipientData['email'] = (r['email'] ?? '').toString().trim();

              // Include phone if present
              if (r['phone'] != null && (r['phone'] as String).isNotEmpty) {
                recipientData['phone'] = (r['phone'] ?? '').toString().trim();
              }

              // Include reportConfig if present (from individual recipient configuration)
              // This comes from the "Edit" button dialog in building_recipient_page.dart
              if (r['reportConfig'] != null && r['reportConfig'] is List) {
                // Use reportConfig directly from the recipient page
                recipientData['reportConfig'] = r['reportConfig'];
              }
            }

            reportingRecipients.add(recipientData);
          }
        } catch (e) {
          // If parsing fails, use empty list
          reportingRecipients = [];
        }
      }

      // PART 2: Build reportConfigs from this page (building_responsible_persons_page.dart)
      // These are created using "Create own routines" button
      List<Map<String, dynamic>> reportConfigs = [];

      // First, check if reportConfigs were passed from the "create for all" dialog
      if (widget.reportConfigs != null && widget.reportConfigs!.isNotEmpty) {
        try {
          final decoded = jsonDecode(widget.reportConfigs!) as List;
          for (var config in decoded) {
            reportConfigs.add({
              'name': config['name'] ?? '',
              'interval': config['interval'] ?? 'Monthly',
              'reportContents': List<String>.from(
                config['reportContents'] ?? [],
              ),
            });
          }
        } catch (e) {
          // If parsing fails, continue with saved configs
        }
      }

      // Also include any configs created on this page using "Create own routines"
      for (var savedConfig in _savedReportConfigs) {
        reportConfigs.add({
          'name': savedConfig['name'] ?? '',
          'interval': savedConfig['interval'] ?? 'Monthly',
          'reportContents': List<String>.from(
            savedConfig['reportContents'] ?? [],
          ),
        });
      }

      // Also check if current form has data (if user filled form but didn't click "Create own routines")
      if (_reportingNameController.text.trim().isNotEmpty ||
          _reportOptions.values.any((value) => value == true)) {
        // Build report contents from current form
        List<String> reportContents = [];
        if (_reportOptions['total_consumption'] == true) {
          reportContents.add('TotalConsumption');
        }
        if (_reportOptions['consumption_by_room'] == true) {
          reportContents.add('ConsumptionByRoom');
        }
        if (_reportOptions['measurement_type_breakdown'] == true) {
          reportContents.add('MeasurementTypeBreakdown');
        }
        if (_reportOptions['eui'] == true) {
          reportContents.add('EUI');
        }
        if (_reportOptions['per_capita_consumption'] == true) {
          reportContents.add('PerCapitaConsumption');
        }
        if (_reportOptions['benchmark_comparison'] == true) {
          reportContents.add('BenchmarkComparison');
        }
        if (_reportOptions['peak_loads'] == true) {
          reportContents.add('PeakLoads');
        }
        if (_reportOptions['anomalies'] == true) {
          reportContents.add('Anomalies');
        }
        if (_reportOptions['inefficient_usage'] == true) {
          reportContents.add('InefficientUsage');
        }
        if (_reportOptions['period_comparison'] == true) {
          reportContents.add('PeriodComparison');
        }
        if (_reportOptions['time_based_analysis'] == true) {
          reportContents.add('TimeBasedAnalysis');
        }
        if (_reportOptions['building_comparison'] == true) {
          reportContents.add('BuildingComparison');
        }
        if (_reportOptions['temperature_analysis'] == true) {
          reportContents.add('TemperatureAnalysis');
        }
        if (_reportOptions['data_quality_report'] == true) {
          reportContents.add('DataQualityReport');
        }

        // Map frequency key to API format
        String interval = 'Monthly';
        switch (_selectedFrequencyKey) {
          case 'daily':
            interval = 'Daily';
            break;
          case 'weekly':
            interval = 'Weekly';
            break;
          case 'monthly':
            interval = 'Monthly';
            break;
          case 'yearly':
            interval = 'Yearly';
            break;
        }

        // Add current form config to reportConfigs
        reportConfigs.add({
          'name': _reportingNameController.text.isNotEmpty
              ? _reportingNameController.text.trim()
              : 'Executive Weekly Report',
          'interval': interval,
          'reportContents': reportContents,
        });
      }

      // Build request body
      final requestBody = {
        'reportingRecipients': reportingRecipients,
        if (reportConfigs.isNotEmpty) 'reportConfigs': reportConfigs,
      };

      // Get building IDs - use buildingIds if provided, otherwise use single buildingId
      List<String> buildingIdsList = [];
      if (widget.buildingIds != null && widget.buildingIds!.isNotEmpty) {
        buildingIdsList = widget.buildingIds!
            .split(',')
            .where((id) => id.trim().isNotEmpty)
            .toList();
      } else if (widget.buildingId != null && widget.buildingId!.isNotEmpty) {
        buildingIdsList = [widget.buildingId!];
      }

      if (buildingIdsList.isEmpty) {
        throw Exception('Building ID(s) are required');
      }

      // Make API call for each building
      // Note: If multiple buildings, we'll update each one
      var lastResponse;
      for (final buildingId in buildingIdsList) {
        lastResponse = await _dioClient.dio.patch(
          '/api/v1/buildings/$buildingId',
          data: requestBody,
        );
      }

      // Use the last response for navigation check
      final response = lastResponse!;

      // Check if response is successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Navigate to add property name page with switchId
        if (mounted) {
          _navigateAfterCompletion();
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save reporting setup'),
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
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCompleteSetup() async {
    if (_isLoading) return;

    // Save current config before completing (if editing a specific recipient)
    if (_currentRecipient != null) {
      _saveCurrentConfig();
    } else if (widget.createForAll == 'true') {
      // If in "create for all" mode and form has data, save it as a config for all recipients
      if (_reportingNameController.text.trim().isNotEmpty ||
          _reportOptions.values.any((value) => value == true)) {
        // Build report contents from selected options
        List<String> reportContents = [];
        if (_reportOptions['total_consumption'] == true) {
          reportContents.add('TotalConsumption');
        }
        if (_reportOptions['consumption_by_room'] == true) {
          reportContents.add('ConsumptionByRoom');
        }
        if (_reportOptions['measurement_type_breakdown'] == true) {
          reportContents.add('MeasurementTypeBreakdown');
        }
        if (_reportOptions['eui'] == true) {
          reportContents.add('EUI');
        }
        if (_reportOptions['per_capita_consumption'] == true) {
          reportContents.add('PerCapitaConsumption');
        }
        if (_reportOptions['benchmark_comparison'] == true) {
          reportContents.add('BenchmarkComparison');
        }
        if (_reportOptions['peak_loads'] == true) {
          reportContents.add('PeakLoads');
        }
        if (_reportOptions['anomalies'] == true) {
          reportContents.add('Anomalies');
        }
        if (_reportOptions['inefficient_usage'] == true) {
          reportContents.add('InefficientUsage');
        }
        if (_reportOptions['period_comparison'] == true) {
          reportContents.add('PeriodComparison');
        }
        if (_reportOptions['time_based_analysis'] == true) {
          reportContents.add('TimeBasedAnalysis');
        }
        if (_reportOptions['building_comparison'] == true) {
          reportContents.add('BuildingComparison');
        }
        if (_reportOptions['temperature_analysis'] == true) {
          reportContents.add('TemperatureAnalysis');
        }
        if (_reportOptions['data_quality_report'] == true) {
          reportContents.add('DataQualityReport');
        }

        // Map frequency key to API format
        String interval = 'Monthly';
        switch (_selectedFrequencyKey) {
          case 'daily':
            interval = 'Daily';
            break;
          case 'weekly':
            interval = 'Weekly';
            break;
          case 'monthly':
            interval = 'Monthly';
            break;
          case 'yearly':
            interval = 'Yearly';
            break;
        }

        // Apply current form config to all recipients that don't have configs
        for (var recipient in _allRecipients) {
          final id = recipient['id']?.toString();
          if (id != null &&
              !_allRecipientConfigs.containsKey(id) &&
              _reportingNameController.text.isNotEmpty) {
            _allRecipientConfigs[id] = {
              'name': _reportingNameController.text.isNotEmpty
                  ? _reportingNameController.text
                  : 'Executive Weekly Report',
              'interval': interval,
              'reportContents': reportContents,
            };
          }
        }
      }
    }

    // Merge completed configs into all recipient configs
    _allRecipientConfigs.addAll(_completedConfigs);

    // Check if all recipients have configurations
    final allRecipientsHaveConfig = _allRecipients.every((recipient) {
      final id = recipient['id']?.toString();
      return id != null && _allRecipientConfigs.containsKey(id);
    });

    if (!allRecipientsHaveConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'building_responsible_persons.config_all_recipients'.tr(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Build reportingRecipients array
      List<Map<String, dynamic>> reportingRecipients = [];
      for (var recipient in _allRecipients) {
        final id = recipient['id']?.toString();
        if (id != null && _allRecipientConfigs.containsKey(id)) {
          final config = _allRecipientConfigs[id]!;
          reportingRecipients.add({
            'id': id,
            'name': recipient['name'] ?? '',
            'email': recipient['email'] ?? '',
            'phone': recipient['phone'] ?? '',
            'reportConfig': [
              {
                'name': config['name'] ?? 'Executive Weekly Report',
                'interval': config['interval'] ?? 'Monthly',
                'reportContents': config['reportContents'] ?? [],
              },
            ],
          });
        }
      }

      // Build request body
      final requestBody = {
        'reportingRecipients': reportingRecipients,
        'buildingIds': widget.buildingId != null ? [widget.buildingId!] : [],
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
      };

      // Get building ID
      final buildingId = widget.buildingId ?? '6948dcd113537bff98eb7338';
      if (buildingId.isEmpty) {
        throw Exception('Building ID is required');
      }

      // Make API call
      final response = await _dioClient.dio.patch(
        '/api/v1/buildings/$buildingId',
        data: requestBody,
      );

      // Check if response is successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Navigate to add property name page with switchId
        if (mounted) {
          _navigateAfterCompletion();
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save reporting setup'),
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
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleContinue() async {
    // If editing a specific recipient, save and go back
    if (_currentRecipient != null) {
      _handleSaveAndBack();
      return;
    }

    // If "create for all" mode, combine individual recipient configs with all-user configs
    if (widget.createForAll == 'true' && _allRecipients.isNotEmpty) {
      if (_isLoading) return;

      setState(() {
        _isLoading = true;
      });

      try {
        // Build reportingRecipients from recipient page (with individual report configs from edit button)
        List<Map<String, dynamic>> reportingRecipients = [];
        for (var recipient in _allRecipients) {
          final id = recipient['id']?.toString();
          final recipientData = {
            'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'name': recipient['name'] ?? '',
            'email': recipient['email'] ?? '',
            if (recipient['phone'] != null &&
                (recipient['phone'] as String).isNotEmpty)
              'phone': recipient['phone'] ?? '',
          };

          // If recipient has a config from edit button, add it to reportConfig array
          if (id != null && _allRecipientConfigs.containsKey(id)) {
            final config = _allRecipientConfigs[id]!;
            recipientData['reportConfig'] = [
              {
                'name': config['name'] ?? 'Executive Weekly Report',
                'interval': config['interval'] ?? 'Monthly',
                'reportContents': config['reportContents'] ?? [],
              },
            ];
          }

          reportingRecipients.add(recipientData);
        }

        // Build reportConfigs from saved report configs (created with "Create own routines" for all users)
        List<Map<String, dynamic>> reportConfigs = [];
        for (var savedConfig in _savedReportConfigs) {
          reportConfigs.add({
            'name': savedConfig['name'] ?? 'Executive Weekly Report',
            'interval': savedConfig['interval'] ?? 'Monthly',
            'reportContents': savedConfig['reportContents'] ?? [],
          });
        }

        // Also check if current form has data (if user filled form but didn't click "Create own routines")
        if (_reportingNameController.text.trim().isNotEmpty ||
            _reportOptions.values.any((value) => value == true)) {
          // Build report contents from current form
          List<String> reportContents = [];
          if (_reportOptions['total_consumption'] == true) {
            reportContents.add('TotalConsumption');
          }
          if (_reportOptions['consumption_by_room'] == true) {
            reportContents.add('ConsumptionByRoom');
          }
          if (_reportOptions['peak_loads'] == true) {
            reportContents.add('PeakLoads');
          }
          if (_reportOptions['measurement_type_breakdown'] == true) {
            reportContents.add('MeasurementTypeBreakdown');
          }
          if (_reportOptions['eui'] == true) {
            reportContents.add('EUI');
          }
          if (_reportOptions['per_capita_consumption'] == true) {
            reportContents.add('PerCapitaConsumption');
          }
          if (_reportOptions['benchmark_comparison'] == true) {
            reportContents.add('BenchmarkComparison');
          }
          if (_reportOptions['inefficient_usage'] == true) {
            reportContents.add('InefficientUsage');
          }
          if (_reportOptions['anomalies'] == true) {
            reportContents.add('Anomalies');
          }
          if (_reportOptions['period_comparison'] == true) {
            reportContents.add('PeriodComparison');
          }
          if (_reportOptions['time_based_analysis'] == true) {
            reportContents.add('TimeBasedAnalysis');
          }
          if (_reportOptions['building_comparison'] == true) {
            reportContents.add('BuildingComparison');
          }
          if (_reportOptions['temperature_analysis'] == true) {
            reportContents.add('TemperatureAnalysis');
          }
          if (_reportOptions['data_quality_report'] == true) {
            reportContents.add('DataQualityReport');
          }

          // Map frequency key to API format
          String interval = 'Monthly';
          switch (_selectedFrequencyKey) {
            case 'daily':
              interval = 'Daily';
              break;
            case 'weekly':
              interval = 'Weekly';
              break;
            case 'monthly':
              interval = 'Monthly';
              break;
            case 'yearly':
              interval = 'Yearly';
              break;
          }

          // Add current form config to reportConfigs
          reportConfigs.add({
            'name': _reportingNameController.text.isNotEmpty
                ? _reportingNameController.text
                : 'Executive Weekly Report',
            'interval': interval,
            'reportContents': reportContents,
          });
        }

        // Build request body with both reportingRecipients and reportConfigs
        final requestBody = {
          'reportingRecipients': reportingRecipients,
          if (reportConfigs.isNotEmpty) 'reportConfigs': reportConfigs,
          'buildingIds': widget.buildingId != null ? [widget.buildingId!] : [],
          if (widget.siteId != null && widget.siteId!.isNotEmpty)
            'siteId': widget.siteId!,
        };

        // Get building ID
        final buildingId = widget.buildingId ?? '6948dcd113537bff98eb7338';
        if (buildingId.isEmpty) {
          throw Exception('Building ID is required');
        }

        // Make API call with PATCH
        final response = await _dioClient.dio.patch(
          '/api/v1/buildings/$buildingId',
          data: requestBody,
        );

        // Check if response is successful
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Navigate to add additional buildings page
          if (mounted) {
            // Get siteId from widget or route state
            final siteId =
                widget.siteId ??
                GoRouterState.of(context).uri.queryParameters['siteId'];

            context.goNamed(
              Routelists.additionalBuildingList,
              queryParameters: {
                if (widget.userName != null) 'userName': widget.userName!,
                if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
              },
            );
          }
        } else {
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save reporting setup'),
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
            _isLoading = false;
          });
        }
      }
      return;
    }

    // If "create for all" mode without individual configs, use the old API structure
    if (widget.createForAll == 'true') {
      await _handleCreateForAll();
      return;
    }

    // Legacy behavior for backward compatibility
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get recipients from widget property (passed from previous page)
      List<Map<String, dynamic>> recipients = [];
      if (widget.recipientsJson != null && widget.recipientsJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(widget.recipientsJson!) as List;
          recipients = decoded.map<Map<String, dynamic>>((r) {
            return {'name': r['name'] ?? '', 'email': r['email'] ?? ''};
          }).toList();
        } catch (e) {
          // If parsing fails, use empty list
          recipients = [];
        }
      }

      // Build report contents from selected options
      List<String> reportContents = [];
      if (_reportOptions['total_consumption'] == true) {
        reportContents.add('TotalConsumption');
      }
      if (_reportOptions['consumption_by_room'] == true) {
        reportContents.add('ConsumptionByRoom');
      }
      if (_reportOptions['peak_loads'] == true) {
        reportContents.add('PeakLoads');
      }
      if (_reportOptions['measurement_type_breakdown'] == true) {
        reportContents.add('MeasurementTypeBreakdown');
      }
      if (_reportOptions['eui'] == true) {
        reportContents.add('EUI');
      }
      if (_reportOptions['per_capita_consumption'] == true) {
        reportContents.add('PerCapitaConsumption');
      }
      if (_reportOptions['benchmark_comparison'] == true) {
        reportContents.add('BenchmarkComparison');
      }
      if (_reportOptions['inefficient_usage'] == true) {
        reportContents.add('InefficientUsage');
      }
      if (_reportOptions['anomalies'] == true) {
        reportContents.add('Anomalies');
      }
      if (_reportOptions['period_comparison'] == true) {
        reportContents.add('PeriodComparison');
      }
      if (_reportOptions['time_based_analysis'] == true) {
        reportContents.add('TimeBasedAnalysis');
      }
      if (_reportOptions['building_comparison'] == true) {
        reportContents.add('BuildingComparison');
      }
      if (_reportOptions['temperature_analysis'] == true) {
        reportContents.add('TemperatureAnalysis');
      }
      if (_reportOptions['data_quality_report'] == true) {
        reportContents.add('DataQualityReport');
      }

      // Map frequency key to API format
      String interval = 'Monthly';
      switch (_selectedFrequencyKey) {
        case 'daily':
          interval = 'Daily';
          break;
        case 'weekly':
          interval = 'Weekly';
          break;
        case 'monthly':
          interval = 'Monthly';
          break;
        case 'yearly':
          interval = 'Yearly';
          break;
      }

      // Build request body
      final requestBody = {
        'recipients': recipients,
        'reportConfig': {
          'name': _reportingNameController.text.isNotEmpty
              ? _reportingNameController.text
              : 'Executive Weekly Report',
          'interval': interval,
          if (reportContents.isNotEmpty) 'reportContents': reportContents,
        },
        'buildingIds': widget.buildingId != null ? [widget.buildingId!] : [],
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
      };

      // Make API call
      final response = await _dioClient.dio.post(
        '/api/v1/reporting/setup',
        data: requestBody,
      );

      // Check if response is successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Navigate to add property name page with switchId
        if (mounted) {
          _navigateAfterCompletion();
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save reporting setup'),
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
          _isLoading = false;
        });
      }
    }
  }

  void _handleSkip() async {
    // If in "create for all" mode, send data to backend before skipping
    // Similar to _handleContinue but WITHOUT reportConfigs (all user configs)
    // if (widget.createForAll == 'true' && _allRecipients.isNotEmpty) {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Build reportingRecipients from recipient page (with individual report configs)
      // Similar to previous page but WITHOUT reportConfigs (all user configs)
      List<Map<String, dynamic>> reportingRecipients = [];

      // First, try to get recipients from recipientsJson (from "create for all" button)
      if (widget.recipientsJson != null && widget.recipientsJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(widget.recipientsJson!) as List;
          for (var r in decoded) {
            final recipientData = <String, dynamic>{};

            // Check if ID is from backend (MongoDB ObjectId - 24 hex characters)
            final recipientId = r['id']?.toString() ?? '';
            final isBackendId =
                recipientId.length == 24 &&
                RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(recipientId);

            if (isBackendId) {
              // For recipients from backend (automatic domain), only send id and reportConfig
              recipientData['id'] = recipientId;

              // Include reportConfig if present (from individual recipient configuration)
              if (r['reportConfig'] != null && r['reportConfig'] is List) {
                recipientData['reportConfig'] = r['reportConfig'];
              }
            } else {
              // For manually added recipients (frontend-generated ID), send name and email
              recipientData['name'] = (r['name'] ?? '').toString().trim();
              recipientData['email'] = (r['email'] ?? '').toString().trim();

              // Include phone if present
              if (r['phone'] != null && (r['phone'] as String).isNotEmpty) {
                recipientData['phone'] = (r['phone'] ?? '').toString().trim();
              }

              // Include reportConfig if present (from individual recipient configuration)
              if (r['reportConfig'] != null && r['reportConfig'] is List) {
                recipientData['reportConfig'] = r['reportConfig'];
              }
            }

            reportingRecipients.add(recipientData);
          }
        } catch (e) {
          // If parsing fails, use empty list
          reportingRecipients = [];
        }
      }

      // Fallback: Use _allRecipients if recipientsJson is not available
      if (reportingRecipients.isEmpty && _allRecipients.isNotEmpty) {
        for (var recipient in _allRecipients) {
          final id = recipient['id']?.toString();
          final recipientData = {
            'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'name': recipient['name'] ?? '',
            'email': recipient['email'] ?? '',
            if (recipient['phone'] != null &&
                (recipient['phone'] as String).isNotEmpty)
              'phone': recipient['phone'] ?? '',
          };

          // If recipient has a config from edit button, add it to reportConfig array
          if (id != null && _allRecipientConfigs.containsKey(id)) {
            final config = _allRecipientConfigs[id]!;
            recipientData['reportConfig'] = [
              {
                'name': config['name'] ?? 'Executive Weekly Report',
                'interval': config['interval'] ?? 'Monthly',
                'reportContents': config['reportContents'] ?? [],
              },
            ];
          }

          reportingRecipients.add(recipientData);
        }
      }

      // Build request body WITHOUT reportConfigs (all user configs)
      final requestBody = {
        'reportingRecipients': reportingRecipients,
        // Note: NOT including reportConfigs here - only individual recipient configs
        if (widget.buildingId != null) 'buildingIds': [widget.buildingId!],
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
      };

      // Get building ID
      final buildingId = widget.buildingId ?? '6948dcd113537bff98eb7338';
      if (buildingId.isEmpty) {
        throw Exception('Building ID is required');
      }

      // Make API call with PATCH
      final response = await _dioClient.dio.patch(
        '/api/v1/buildings/$buildingId',
        data: requestBody,
      );

      // Check if response is successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Navigate to add property name page with switchId
        if (mounted) {
          _navigateAfterCompletion();
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save reporting setup'),
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
          _isLoading = false;
        });
      }
    }
    // } else {
    //   // Regular skip - just go back
    //   if (context.canPop()) {
    //     context.pop();
    //   }
    // }
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
                      borderRadius: BorderRadius.zero,
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
                          const SizedBox(height: 16),
                          if (widget.userName != null)
                            Text(
                              'building_responsible_persons.progress_text'.tr(
                                namedArgs: {'name': widget.userName!},
                              ),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: screenSize.width < 600
                                ? screenSize.width * 0.95
                                : screenSize.width < 1200
                                ? screenSize.width * 0.5
                                : screenSize.width * 0.6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: LinearProgressIndicator(
                                value: 0.95,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8B9A5B),
                                ),
                                minHeight: 8,
                              ),
                            ),
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
                                    // Back button if editing a specific recipient
                                    // if (_currentRecipient != null) ...[

                                    // const SizedBox(height: 12),
                                    // ],
                                    PageHeaderRow(
                                      title:
                                          'building_responsible_persons.title'
                                              .tr(),
                                      showBackButton: true,
                                      onBack: () => context.pop(),
                                    ),
                                    const SizedBox(height: 32),
                                    // Display saved report configs
                                    if (_savedReportConfigs.isNotEmpty) ...[
                                      ..._savedReportConfigs.asMap().entries.map((
                                        entry,
                                      ) {
                                        final index = entry.key;
                                        final savedConfig = entry.value;
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF8B9A5B),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.zero,
                                            color: Colors.grey[50],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Image.asset(
                                                    'assets/images/check.png',
                                                    width: 16,
                                                    height: 16,
                                                    color: const Color(
                                                      0xFF238636,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      savedConfig['name'] ?? '',
                                                      style: AppTextStyles
                                                          .bodyMedium
                                                          .copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                    ),
                                                  ),
                                                  // Edit button
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        _showEditRoutineDialog(
                                                          index,
                                                        );
                                                      },
                                                      borderRadius:
                                                          BorderRadius.zero,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        child: Text(
                                                          'building_recipient.edit'
                                                              .tr(),
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color:
                                                                Colors.black87,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Remove button
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          // If editing this routine, reset editing state
                                                          if (_editingConfigIndex ==
                                                              index) {
                                                            _editingConfigIndex =
                                                                null;
                                                            _reportingNameController
                                                                .clear();
                                                            _selectedFrequencyKey =
                                                                'monthly';
                                                            _reportOptions = {
                                                              'total_consumption':
                                                                  true,
                                                              'consumption_by_room':
                                                                  true,
                                                              'peak_loads':
                                                                  false,
                                                              'measurement_type_breakdown':
                                                                  false,
                                                              'eui': false,
                                                              'per_capita_consumption':
                                                                  false,
                                                              'benchmark_comparison':
                                                                  false,
                                                              'inefficient_usage':
                                                                  true,
                                                              'anomalies':
                                                                  false,
                                                              'period_comparison':
                                                                  false,
                                                              'time_based_analysis':
                                                                  false,
                                                              'building_comparison':
                                                                  false,
                                                              'temperature_analysis':
                                                                  false,
                                                              'data_quality_report':
                                                                  false,
                                                            };
                                                          }
                                                          _savedReportConfigs
                                                              .removeAt(index);
                                                        });
                                                      },
                                                      borderRadius:
                                                          BorderRadius.zero,
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(
                                                          4,
                                                        ),
                                                        child: Icon(
                                                          Icons.close,
                                                          size: 18,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'building_responsible_persons.interval_label'
                                                        .tr() +
                                                    ': ${savedConfig['interval'] ?? ''}',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      color: Colors.black87,
                                                    ),
                                              ),
                                              if (savedConfig['reportContents'] !=
                                                      null &&
                                                  (savedConfig['reportContents']
                                                          as List)
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  (savedConfig['reportContents']
                                                          as List)
                                                      .join(', '),
                                                  style: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                        color: Colors.grey[700],
                                                        fontSize: 12,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 16),
                                    ],

                                    // Reporting Name Field
                                    Container(
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
                                      ),
                                      child: TextFormField(
                                        controller: _reportingNameController,
                                        decoration: InputDecoration(
                                          hintText:
                                              'building_responsible_persons.reporting_name_hint'
                                                  .tr(),
                                          border: InputBorder.none,
                                          hintStyle: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(color: Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Frequency Field
                                    Container(
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
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _selectedFrequency,
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color: Colors.black87,
                                                  ),
                                            ),
                                          ),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _handleFrequencyChange,
                                              child: Text(
                                                '+ ${'building_responsible_persons.change_frequency'.tr()}',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      decoration: TextDecoration
                                                          .underline,
                                                      color: Colors.black,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),

                                    // Report Options Checkboxes
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 12,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildReportOptionCheckbox(
                                          'total_consumption',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'consumption_by_room',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'peak_loads',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'measurement_type_breakdown',
                                        ),
                                        _buildReportOptionCheckbox('eui'),
                                        _buildReportOptionCheckbox(
                                          'per_capita_consumption',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'benchmark_comparison',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'inefficient_usage',
                                        ),
                                        _buildReportOptionCheckbox('anomalies'),
                                        _buildReportOptionCheckbox(
                                          'period_comparison',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'time_based_analysis',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'building_comparison',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'temperature_analysis',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'data_quality_report',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    // Responsible Persons Fields
                                    if (_responsiblePersons.isNotEmpty)
                                      ..._responsiblePersons.map((person) {
                                        return Column(
                                          children: [
                                            _buildResponsiblePersonField(
                                              person['id'],
                                              person['name'],
                                              person['email'],
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        );
                                      }),

                                    // Add Responsible Person Link
                                    // Material(
                                    //   color: Colors.transparent,
                                    //   child: InkWell(
                                    //     onTap: _handleAddResponsiblePerson,
                                    //     child: Padding(
                                    //       padding: const EdgeInsets.symmetric(
                                    //         vertical: 8,
                                    //         horizontal: 4,
                                    //       ),
                                    //       child: Row(
                                    //         mainAxisSize: MainAxisSize.min,
                                    //         children: [
                                    //           Text(
                                    //             '+',
                                    //             style: TextStyle(
                                    //               fontSize: 18,
                                    //               fontWeight: FontWeight.bold,
                                    //               color: Colors.black,
                                    //             ),
                                    //           ),
                                    //           const SizedBox(width: 8),
                                    //           Text(
                                    //             'building_responsible_persons.add_responsible_person'
                                    //                 .tr(),
                                    //             style: TextStyle(
                                    //               fontSize: 16,
                                    //               color: Colors.black,
                                    //               decoration:
                                    //                   TextDecoration.underline,
                                    //             ),
                                    //           ),
                                    //         ],
                                    //       ),
                                    //     ),
                                    //   ),
                                    // ),
                                    const SizedBox(height: 32),
                                    // Additional Options
                                    if (_editingConfigIndex == null)
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _handleCreateOwnRoutine,
                                          child: Text(
                                            '+ ${'building_responsible_persons.create_own_routines'.tr()}',
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  color: Colors.black87,
                                                ),
                                          ),
                                        ),
                                      )
                                    else
                                      // Show update button when editing
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _handleCreateOwnRoutine,
                                          child: Text(
                                            'building_responsible_persons.update_routine'
                                                .tr(),
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  color: Colors.blue[700],
                                                ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _handleSkip,
                                        child: Text(
                                          'building_responsible_persons.skip_step'
                                              .tr(),
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
                                    // Show different buttons based on context
                                    if (_currentRecipient != null) ...[
                                      // Show "Save" button when editing a specific recipient
                                      Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: PrimaryOutlineButton(
                                            label:
                                                'building_responsible_persons.save'
                                                    .tr(),
                                            width: 260,
                                            onPressed: _handleSaveAndBack,
                                          ),
                                        ),
                                      ),
                                      // Show "Complete Setup" button if all recipients are configured
                                      // Check if current recipient config is saved and all others have configs
                                      Builder(
                                        builder: (context) {
                                          // Save current config temporarily to check
                                          final tempConfigs =
                                              Map<
                                                String,
                                                Map<String, dynamic>
                                              >.from(_allRecipientConfigs);
                                          if (_currentRecipient != null) {
                                            final currentId =
                                                _currentRecipient!['id']
                                                    ?.toString();
                                            if (currentId != null) {
                                              // Build current config
                                              List<String> reportContents = [];
                                              if (_reportOptions['total_consumption'] ==
                                                  true) {
                                                reportContents.add(
                                                  'TotalConsumption',
                                                );
                                              }
                                              if (_reportOptions['consumption_by_room'] ==
                                                  true) {
                                                reportContents.add(
                                                  'ConsumptionByRoom',
                                                );
                                              }
                                              if (_reportOptions['peak_loads'] ==
                                                  true) {
                                                reportContents.add('PeakLoads');
                                              }
                                              if (_reportOptions['measurement_type_breakdown'] ==
                                                  true) {
                                                reportContents.add(
                                                  'MeasurementTypeBreakdown',
                                                );
                                              }
                                              if (_reportOptions['eui'] ==
                                                  true) {
                                                reportContents.add('EUI');
                                              }
                                              if (_reportOptions['per_capita_consumption'] ==
                                                  true) {
                                                reportContents.add(
                                                  'PerCapitaConsumption',
                                                );
                                              }
                                              if (_reportOptions['benchmark_comparison'] ==
                                                  true) {
                                                reportContents.add(
                                                  'BenchmarkComparison',
                                                );
                                              }
                                              if (_reportOptions['inefficient_usage'] ==
                                                  true) {
                                                reportContents.add(
                                                  'InefficientUsage',
                                                );
                                              }
                                              if (_reportOptions['anomalies'] ==
                                                  true) {
                                                reportContents.add('Anomalies');
                                              }
                                              if (_reportOptions['period_comparison'] ==
                                                  true) {
                                                reportContents.add(
                                                  'PeriodComparison',
                                                );
                                              }
                                              if (_reportOptions['time_based_analysis'] ==
                                                  true) {
                                                reportContents.add(
                                                  'TimeBasedAnalysis',
                                                );
                                              }
                                              if (_reportOptions['building_comparison'] ==
                                                  true) {
                                                reportContents.add(
                                                  'BuildingComparison',
                                                );
                                              }
                                              if (_reportOptions['temperature_analysis'] ==
                                                  true) {
                                                reportContents.add(
                                                  'TemperatureAnalysis',
                                                );
                                              }
                                              if (_reportOptions['data_quality_report'] ==
                                                  true) {
                                                reportContents.add(
                                                  'DataQualityReport',
                                                );
                                              }
                                              String interval = 'Monthly';
                                              switch (_selectedFrequencyKey) {
                                                case 'daily':
                                                  interval = 'Daily';
                                                  break;
                                                case 'weekly':
                                                  interval = 'Weekly';
                                                  break;
                                                case 'monthly':
                                                  interval = 'Monthly';
                                                  break;
                                                case 'yearly':
                                                  interval = 'Yearly';
                                                  break;
                                              }
                                              tempConfigs[currentId] = {
                                                'name':
                                                    _reportingNameController
                                                        .text
                                                        .isNotEmpty
                                                    ? _reportingNameController
                                                          .text
                                                    : 'Executive Weekly Report',
                                                'interval': interval,
                                                'reportContents':
                                                    reportContents,
                                              };
                                            }
                                          }
                                          final allHaveConfig =
                                              _allRecipients.isNotEmpty &&
                                              _allRecipients.every((r) {
                                                final id = r['id']?.toString();
                                                return id != null &&
                                                    tempConfigs.containsKey(id);
                                              });
                                          // if (allHaveConfig) {
                                          //   return Column(
                                          //     children: [
                                          //       const SizedBox(height: 16),
                                          //       Center(
                                          //         child: Material(
                                          //           color: Colors.transparent,
                                          //           child: _isLoading
                                          //               ? const CircularProgressIndicator()
                                          //               : PrimaryOutlineButton(
                                          //                   label:
                                          //                       'building_responsible_persons.complete_setup'
                                          //                           .tr(),
                                          //                   width: 260,
                                          //                   // onPressed:
                                          //                   //     _handleCompleteSetup,
                                          //                 ),
                                          //         ),
                                          //       ),
                                          //     ],
                                          //   );
                                          // }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ] else ...[
                                      // Legacy: Show continue button
                                      Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: _isLoading
                                              ? const CircularProgressIndicator()
                                              : PrimaryOutlineButton(
                                                  label:
                                                      'building_responsible_persons.button_text'
                                                          .tr(),
                                                  width: 260,
                                                  onPressed: _handleContinue,
                                                ),
                                        ),
                                      ),
                                    ],
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

  Widget _buildReportOptionCheckbox(String option) {
    final isSelected = _reportOptions[option] ?? false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleReportOptionToggle(option),
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            // border: Border.all(color: Colors.black54, width: 1),
            //             borderRadius: BorderRadius.zero,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 1),
                  borderRadius: BorderRadius.zero,
                  color: Colors.white,
                ),
                child: isSelected
                    ? const Icon(Icons.close, size: 16, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                _getReportOptionLabel(option),
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiblePersonField(String id, String name, String email) {
    return Column(
      children: [
        // Name Field
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54, width: 2),
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: name,
                  decoration: InputDecoration(
                    hintText: 'building_responsible_persons.name_hint'.tr(),
                    border: InputBorder.none,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.black87,
                  ),
                  onChanged: (value) {
                    _handleResponsiblePersonNameChanged(id, value);
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleRemoveResponsiblePerson(id),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.close, color: Colors.grey[600], size: 20),
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
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: email,
                  decoration: InputDecoration(
                    hintText: 'building_responsible_persons.email_hint'.tr(),
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
                    _handleResponsiblePersonEmailChanged(id, value);
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleRemoveResponsiblePerson(id),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.close, color: Colors.grey[600], size: 20),
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
