import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/page_header_row.dart';

import '../../../../core/widgets/top_part_widget.dart';

class DashboardReportSetupPage extends StatefulWidget {
  final String buildingId;
  final String? fromDashboard;
  final String? reportingJson; // JSON string of ReportDetailReportingEntity
  final String? recipientsJson; // JSON string of List<ReportRecipientEntity>
  const DashboardReportSetupPage({
    super.key,
    required this.buildingId,
    this.fromDashboard,
    this.reportingJson,
    this.recipientsJson,
  });

  @override
  State<DashboardReportSetupPage> createState() =>
      _DashboardReportSetupPageState();
}

class _DashboardReportSetupPageState extends State<DashboardReportSetupPage> {
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
  final DioClient _dioClient = sl<DioClient>();
  bool _isLoading = false;
  List<Map<String, dynamic>> _savedReportConfigs = [];
  int? _editingConfigIndex;

  // Responsible persons state (multiple)
  List<Map<String, dynamic>> _selectedResponsiblePersons = [];
  int? _editingPersonIndex; // Track which person is being edited

  String get _selectedFrequency =>
      'building_responsible_persons.$_selectedFrequencyKey'.tr();

  @override
  void initState() {
    super.initState();
    // If editing existing report, load report data first (which includes recipients)
    // Otherwise, load from building
    if (widget.reportingJson != null || widget.recipientsJson != null) {
      _loadExistingReport();
    } else {
      _loadExistingResponsiblePerson();
    }
  }

  @override
  void dispose() {
    _reportingNameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingResponsiblePerson() async {
    try {
      final response = await _dioClient.get(
        '/api/v1/buildings/${widget.buildingId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final buildingData = data['data'] as Map<String, dynamic>;

          // Check if reportingRecipients exists and load all of them
          if (buildingData['reportingRecipients'] != null &&
              buildingData['reportingRecipients'] is List) {
            final recipients = buildingData['reportingRecipients'] as List;
            if (recipients.isNotEmpty) {
              setState(() {
                _selectedResponsiblePersons = recipients
                    .map<Map<String, dynamic>>((recipient) {
                      final recipientMap = recipient as Map<String, dynamic>;
                      return {
                        'name': recipientMap['name']?.toString() ?? '',
                        'email': recipientMap['email']?.toString() ?? '',
                        'phone': recipientMap['phone']?.toString() ?? '',
                        'id':
                            recipientMap['_id']?.toString() ??
                            recipientMap['id']?.toString() ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        'method': 'domain',
                      };
                    })
                    .toList();
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading responsible persons: $e');
    }
  }

  Future<void> _loadExistingReport() async {
    try {
      // Load reporting data
      if (widget.reportingJson != null && widget.reportingJson!.isNotEmpty) {
        final reportingData =
            jsonDecode(widget.reportingJson!) as Map<String, dynamic>;

        setState(() {
          // Set reporting name
          _reportingNameController.text =
              reportingData['name']?.toString() ?? '';

          // Set frequency based on interval
          final interval =
              reportingData['interval']?.toString().toLowerCase() ?? 'monthly';
          switch (interval) {
            case 'daily':
              _selectedFrequencyKey = 'daily';
              break;
            case 'weekly':
              _selectedFrequencyKey = 'weekly';
              break;
            case 'monthly':
              _selectedFrequencyKey = 'monthly';
              break;
            case 'yearly':
              _selectedFrequencyKey = 'yearly';
              break;
            default:
              _selectedFrequencyKey = 'monthly';
          }

          // Set report options based on reportContents
          final reportContents = reportingData['reportContents'] as List? ?? [];
          _reportOptions = {
            'total_consumption': reportContents.contains('TotalConsumption'),
            'consumption_by_room': reportContents.contains('ConsumptionByRoom'),
            'peak_loads': reportContents.contains('PeakLoads'),
            'measurement_type_breakdown': reportContents.contains(
              'MeasurementTypeBreakdown',
            ),
            'eui': reportContents.contains('EUI'),
            'per_capita_consumption': reportContents.contains(
              'PerCapitaConsumption',
            ),
            'benchmark_comparison': reportContents.contains(
              'BenchmarkComparison',
            ),
            'inefficient_usage': reportContents.contains('InefficientUsage'),
            'anomalies': reportContents.contains('Anomalies'),
            'period_comparison': reportContents.contains('PeriodComparison'),
            'time_based_analysis': reportContents.contains('TimeBasedAnalysis'),
            'building_comparison': reportContents.contains(
              'BuildingComparison',
            ),
            'temperature_analysis': reportContents.contains(
              'TemperatureAnalysis',
            ),
            'data_quality_report': reportContents.contains('DataQualityReport'),
          };

          // Add to saved configs if it has a name
          if (_reportingNameController.text.isNotEmpty) {
            _savedReportConfigs.add({
              'name': _reportingNameController.text,
              'interval': reportingData['interval'] ?? 'Monthly',
              'intervalKey': _selectedFrequencyKey,
              'reportContents': List<String>.from(reportContents),
              'reportOptions': Map<String, bool>.from(_reportOptions),
              'completed': true,
            });
          }
        });
      }

      // Load recipients data
      if (widget.recipientsJson != null && widget.recipientsJson!.isNotEmpty) {
        final recipientsList = jsonDecode(widget.recipientsJson!) as List;

        setState(() {
          _selectedResponsiblePersons = recipientsList
              .map<Map<String, dynamic>>((r) {
                final recipientMap = r as Map<String, dynamic>;
                return {
                  'name': recipientMap['recipientName']?.toString() ?? '',
                  'email': recipientMap['recipientEmail']?.toString() ?? '',
                  'id':
                      recipientMap['recipientId']?.toString() ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  'method': 'domain',
                };
              })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading report data: $e');
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  Future<void> _handleAutomaticFromDomain() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await _dioClient.dio.get('/api/v1/reporting/recipients');

      if (mounted) {
        Navigator.of(context).pop();
      }

      List<Map<String, dynamic>> recipientsList = [];
      if (response.data != null) {
        if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          // Handle the new response format: {success: true, data: [...], count: 3}
          if (responseMap['data'] != null && responseMap['data'] is List) {
            recipientsList = List<Map<String, dynamic>>.from(
              responseMap['data'],
            );
          }
        } else if (response.data is List) {
          recipientsList = List<Map<String, dynamic>>.from(response.data);
        }
      }

      if (mounted) {
        _showRecipientsDialog(recipientsList);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showRecipientsDialog([]);
      }
    }
  }

  void _showRecipientsDialog(List<Map<String, dynamic>> recipientsList) {
    final Size screenSize = MediaQuery.of(context).size;
    // Get currently selected recipient IDs to pre-select them
    Set<String> selectedRecipientIds = Set.from(
      _selectedResponsiblePersons
          .where((p) => p['method'] == 'domain' && p['id'] != null)
          .map((p) => p['id'].toString())
          .where((id) => id.isNotEmpty),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          actionsAlignment: MainAxisAlignment.center,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          backgroundColor: Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('Select Recipients')),
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
                ? screenSize.width * 0.5
                : screenSize.width * 0.4,
            child: recipientsList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('No recipients found'),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'Select one or more recipients',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: recipientsList.length,
                          itemBuilder: (context, index) {
                            final recipient = recipientsList[index];
                            final name = recipient['name'] ?? '';
                            final email = recipient['email'] ?? '';
                            final recipientId =
                                recipient['_id']?.toString() ??
                                recipient['id']?.toString() ??
                                '';

                            if (recipientId.isEmpty)
                              return const SizedBox.shrink();

                            final isSelected = selectedRecipientIds.contains(
                              recipientId,
                            );

                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedRecipientIds.remove(recipientId);
                                  } else {
                                    selectedRecipientIds.add(recipientId);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: Colors.black,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          if (value == true) {
                                            selectedRecipientIds.add(
                                              recipientId,
                                            );
                                          } else {
                                            selectedRecipientIds.remove(
                                              recipientId,
                                            );
                                          }
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
                                            name.isNotEmpty ? name : 'Unknown',
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
            PrimaryOutlineButton(
              label: selectedRecipientIds.isEmpty
                  ? 'Select Recipients'
                  : 'Add ${selectedRecipientIds.length} Recipient${selectedRecipientIds.length > 1 ? 's' : ''}',
              onPressed: selectedRecipientIds.isEmpty
                  ? null
                  : () {
                      // Get selected recipients from the list
                      final selectedRecipients = recipientsList.where((r) {
                        final id =
                            r['_id']?.toString() ?? r['id']?.toString() ?? '';
                        return selectedRecipientIds.contains(id);
                      }).toList();

                      // Add all selected recipients to _selectedResponsiblePersons
                      for (var recipient in selectedRecipients) {
                        final recipientId =
                            recipient['_id']?.toString() ??
                            recipient['id']?.toString() ??
                            '';
                        final name = recipient['name']?.toString() ?? '';
                        final email = recipient['email']?.toString() ?? '';

                        // Check if person already exists
                        final existingIndex = _selectedResponsiblePersons
                            .indexWhere((p) => p['id'] == recipientId);

                        if (existingIndex == -1) {
                          // Add new person
                          setState(() {
                            _selectedResponsiblePersons.add({
                              'name': name,
                              'email': email,
                              'phone': recipient['phone']?.toString() ?? '',
                              'id': recipientId.isNotEmpty
                                  ? recipientId
                                  : DateTime.now().millisecondsSinceEpoch
                                        .toString(),
                              'method': 'domain',
                            });
                          });
                        }
                      }

                      Navigator.of(context).pop();
                    },
              width: 260,
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreatePerson() {
    setState(() {
      _selectedResponsiblePersons.add({
        'name': '',
        'email': '',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'method': 'upload',
      });
      _editingPersonIndex = _selectedResponsiblePersons.length - 1;
    });
  }

  void _handlePersonNameChanged(int index, String name) {
    setState(() {
      if (index >= 0 && index < _selectedResponsiblePersons.length) {
        _selectedResponsiblePersons[index]['name'] = name;
      }
    });
  }

  void _handlePersonEmailChanged(int index, String email) {
    setState(() {
      if (index >= 0 && index < _selectedResponsiblePersons.length) {
        _selectedResponsiblePersons[index]['email'] = email;
      }
    });
  }

  void _handleRemovePerson(int index) {
    setState(() {
      if (index >= 0 && index < _selectedResponsiblePersons.length) {
        _selectedResponsiblePersons.removeAt(index);
        if (_editingPersonIndex == index) {
          _editingPersonIndex = null;
        } else if (_editingPersonIndex != null &&
            _editingPersonIndex! > index) {
          _editingPersonIndex = _editingPersonIndex! - 1;
        }
      }
    });
  }

  void _handleConfirmPerson(int index) {
    setState(() {
      if (index >= 0 && index < _selectedResponsiblePersons.length) {
        final person = _selectedResponsiblePersons[index];
        final name = person['name']?.toString().trim() ?? '';
        final email = person['email']?.toString().trim() ?? '';

        if (name.isNotEmpty && email.isNotEmpty) {
          _editingPersonIndex = null;
        }
      }
    });
  }

  void _handleFrequencyChange() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        backgroundColor: Colors.white,
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

  bool _validateCurrentForm() {
    if (_savedReportConfigs.isNotEmpty) {
      return true;
    }
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
    if (!_validateCurrentForm()) {
      return;
    }

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
        _savedReportConfigs[_editingConfigIndex!] = configData;
        _editingConfigIndex = null;
      } else {
        _savedReportConfigs.add(configData);
      }

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

  Future<void> _handleSave() async {
    if (_isLoading) return;

    // Validate responsible persons - at least one required
    if (_selectedResponsiblePersons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select or create at least one responsible person',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Check if editing mode
    final isEditing = widget.reportingJson != null;
    String? reportId;

    if (isEditing) {
      try {
        final reportingData =
            jsonDecode(widget.reportingJson!) as Map<String, dynamic>;
        reportId = reportingData['id']?.toString();

        if (reportId == null || reportId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report ID is missing'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error parsing report data: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    // Validate all persons have required fields
    for (var i = 0; i < _selectedResponsiblePersons.length; i++) {
      final person = _selectedResponsiblePersons[i];
      final name = person['name']?.toString().trim() ?? '';
      final email = person['email']?.toString().trim() ?? '';

      if (name.isEmpty || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please complete all required fields for responsible person ${i + 1}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate form
    if (!_validateCurrentForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // If editing, update the report using the reporting endpoint
      if (isEditing && reportId != null) {
        // Build reportContents from selected options
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

        // Determine interval
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

        // Build request body for report update
        final reportRequestBody = {
          'name': _reportingNameController.text.trim().isNotEmpty
              ? _reportingNameController.text.trim()
              : 'Updated Custom Monthly Report',
          'interval': interval,
          'reportContents': reportContents,
        };

        // Update the report
        final response = await _dioClient.patch(
          '/api/v1/reporting/$reportId',
          data: reportRequestBody,
        );

        if (mounted) {
          if (response.statusCode == 200 || response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.goNamed(Routelists.dashboard);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to update report: ${response.statusCode}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }

      // Original logic for creating new report setup
      // Build reportingRecipients from all selected persons
      List<Map<String, dynamic>> reportingRecipients = [];

      for (var person in _selectedResponsiblePersons) {
        final contactId = person['id'];
        final method = person['method'];
        final idString = contactId?.toString() ?? '';
        final isMongoObjectId =
            idString.length == 24 &&
            RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(idString);
        final isFromDialog =
            method == 'domain' &&
            contactId != null &&
            idString.isNotEmpty &&
            isMongoObjectId;

        Map<String, dynamic> recipientData;
        if (isFromDialog) {
          recipientData = {'id': contactId.toString()};
        } else {
          recipientData = {
            'name': person['name'] ?? '',
            'email': person['email'] ?? '',
          };
          if (person['phone'] != null &&
              person['phone'].toString().isNotEmpty) {
            recipientData['phone'] = person['phone'];
          }
        }

        reportingRecipients.add(recipientData);
      }

      // Build reportConfigs from saved configs
      List<Map<String, dynamic>> reportConfigs = [];
      for (var savedConfig in _savedReportConfigs) {
        reportConfigs.add({
          'name': savedConfig['name'] ?? '',
          'interval': savedConfig['interval'] ?? 'Monthly',
          'reportContents': List<String>.from(
            savedConfig['reportContents'] ?? [],
          ),
        });
      }

      // Also check if current form has data
      if (_reportingNameController.text.trim().isNotEmpty ||
          _reportOptions.values.any((value) => value == true)) {
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

        reportConfigs.add({
          'name': _reportingNameController.text.isNotEmpty
              ? _reportingNameController.text.trim()
              : 'Executive Weekly Report',
          'interval': interval,
          'reportContents': reportContents,
        });
      }

      // Add reportConfig to all recipients if there are configs
      // if (reportConfigs.isNotEmpty) {
      //   for (var recipient in reportingRecipients) {
      //     recipient['reportConfig'] = reportConfigs;
      //   }
      // }

      final requestBody = {
        'reportingRecipients': reportingRecipients,
        if (reportConfigs.isNotEmpty) 'reportConfigs': reportConfigs,
      };
      print(requestBody);
      final response = await _dioClient.dio.patch(
        '/api/v1/buildings/${widget.buildingId}',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report setup saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          context.goNamed(Routelists.dashboard);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save report setup: ${response.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
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

  Widget _buildReportOptionCheckbox(String option) {
    final isSelected = _reportOptions[option] ?? false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleReportOptionToggle(option),
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
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
                  width: double.infinity,
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
                          child: PageHeaderRow(
                            title: 'dashboard.report_setup.title'.tr(),
                            showBackButton: true,
                            onBack: () => context.pop(),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: screenSize.width < 600
                              ? screenSize.width * 0.95
                              : screenSize.width < 1200
                              ? screenSize.width * 0.5
                              : screenSize.width * 0.6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Responsible Persons Section
                              if (widget.reportingJson == null) ...[
                                const Text(
                                  'Responsible Persons',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Display all selected responsible persons
                                if (_selectedResponsiblePersons.isNotEmpty)
                                  ..._selectedResponsiblePersons.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final person = entry.value;
                                    final isEditing =
                                        _editingPersonIndex == index;

                                    return Column(
                                      children: [
                                        if (isEditing) ...[
                                          // Show text fields when editing
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
                                              borderRadius: BorderRadius.zero,
                                              color: Colors.white,
                                            ),
                                            child: TextFormField(
                                              initialValue:
                                                  person['name'] ?? '',
                                              decoration: InputDecoration(
                                                hintText: 'Name',
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
                                                _handlePersonNameChanged(
                                                  index,
                                                  value,
                                                );
                                                setState(() {});
                                              },
                                            ),
                                          ),
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
                                              borderRadius: BorderRadius.zero,
                                              color: Colors.white,
                                            ),
                                            child: TextFormField(
                                              initialValue:
                                                  person['email'] ?? '',
                                              decoration: InputDecoration(
                                                hintText: 'Email',
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
                                                _handlePersonEmailChanged(
                                                  index,
                                                  value,
                                                );
                                              },
                                            ),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    _handleConfirmPerson(index);
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
                                                      'Confirm',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                        color: Colors.blue[700],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
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
                                              borderRadius: BorderRadius.zero,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Image.asset(
                                                    'assets/images/check.png',
                                                    width: 16,
                                                    height: 16,
                                                    color: const Color(
                                                      0xFF238636,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      person['name'] != null &&
                                                              person['name']
                                                                  .toString()
                                                                  .isNotEmpty
                                                          ? '${person['name']}      ${person['email'] != null && person['email'].toString().isNotEmpty ? person['email'] : ''}'
                                                          : person['email'] !=
                                                                    null &&
                                                                person['email']
                                                                    .toString()
                                                                    .isNotEmpty
                                                          ? person['email']
                                                          : '',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          _editingPersonIndex =
                                                              index;
                                                        });
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
                                                          'Edit',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        _handleRemovePerson(
                                                          index,
                                                        );
                                                      },
                                                      borderRadius:
                                                          BorderRadius.zero,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4,
                                                            ),
                                                        child: Icon(
                                                          Icons.close,
                                                          size: 18,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                // Action links - always show to add more
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _handleAutomaticFromDomain,
                                        borderRadius: BorderRadius.zero,
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
                                                  fontSize:
                                                      screenSize.width < 600
                                                      ? 14
                                                      : 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              SizedBox(
                                                width: screenSize.width < 600
                                                    ? 4
                                                    : 8,
                                              ),
                                              Flexible(
                                                child: Text(
                                                  'building_contact_person.automatic_from_domain'
                                                      .tr(),
                                                  style: TextStyle(
                                                    fontSize:
                                                        screenSize.width < 600
                                                        ? 12
                                                        : 16,
                                                    color: Colors.black,
                                                    decoration: TextDecoration
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
                                      width: screenSize.width < 600 ? 12 : 24,
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _handleCreatePerson,
                                        borderRadius: BorderRadius.zero,
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
                                                  fontSize:
                                                      screenSize.width < 600
                                                      ? 14
                                                      : 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              SizedBox(
                                                width: screenSize.width < 600
                                                    ? 4
                                                    : 8,
                                              ),
                                              Flexible(
                                                child: Text(
                                                  'Create new person',
                                                  style: TextStyle(
                                                    fontSize:
                                                        screenSize.width < 600
                                                        ? 12
                                                        : 16,
                                                    color: Colors.black,
                                                    decoration: TextDecoration
                                                        .underline,
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

                                const SizedBox(height: 32),
                              ],
                              // Report Setup Section
                              const Text(
                                'Report Setup',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Display saved report configs
                              if (_savedReportConfigs.isNotEmpty &&
                                  widget.reportingJson == null) ...[
                                ..._savedReportConfigs.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final savedConfig = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
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
                                              color: const Color(0xFF238636),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                savedConfig['name'] ?? '',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                              ),
                                            ),
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _editingConfigIndex = index;
                                                    _reportingNameController
                                                            .text =
                                                        savedConfig['name'] ??
                                                        '';
                                                    _selectedFrequencyKey =
                                                        savedConfig['intervalKey'] ??
                                                        'monthly';
                                                    if (savedConfig['reportOptions'] !=
                                                        null) {
                                                      _reportOptions =
                                                          Map<
                                                            String,
                                                            bool
                                                          >.from(
                                                            savedConfig['reportOptions'],
                                                          );
                                                    }
                                                  });
                                                },
                                                borderRadius: BorderRadius.zero,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    'Edit',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
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
                                                        'peak_loads': false,
                                                        'measurement_type_breakdown':
                                                            false,
                                                        'eui': false,
                                                        'per_capita_consumption':
                                                            false,
                                                        'benchmark_comparison':
                                                            false,
                                                        'inefficient_usage':
                                                            true,
                                                        'anomalies': false,
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
                                                borderRadius: BorderRadius.zero,
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
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
                                          'Interval: ${savedConfig['interval'] ?? ''}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(color: Colors.black87),
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
                                            style: AppTextStyles.bodyMedium
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
                                        .copyWith(color: Colors.grey[600]),
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
                                            .copyWith(color: Colors.black87),
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
                                                decoration:
                                                    TextDecoration.underline,
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
                                  _buildReportOptionCheckbox('peak_loads'),
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
                              // Create own routine link
                              if (_editingConfigIndex == null &&
                                  widget.reportingJson == null)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _handleCreateOwnRoutine,
                                    child: Text(
                                      '+ ${'building_responsible_persons.create_own_routines'.tr()}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              // else
                              //   Material(
                              //     color: Colors.transparent,
                              //     child: InkWell(
                              //       onTap: _handleCreateOwnRoutine,
                              //       child: Text(
                              //         'building_responsible_persons.update_routine'
                              //             .tr(),
                              //         style: AppTextStyles.bodyMedium.copyWith(
                              //           decoration: TextDecoration.underline,
                              //           color: Colors.blue[700],
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              const SizedBox(height: 32),
                              // Save button
                              Center(
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : PrimaryOutlineButton(
                                        label: 'Save',
                                        width: 260,
                                        onPressed: _handleSave,
                                      ),
                              ),
                            ],
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
    );
  }
}
