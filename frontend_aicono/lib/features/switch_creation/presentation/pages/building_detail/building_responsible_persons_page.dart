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

class BuildingResponsiblePersonsPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? buildingId;
  final String? siteId;
  final String? recipientsJson; // Legacy: for backward compatibility
  final String? recipient; // Current recipient being configured
  final String? allRecipients; // All recipients list
  final String? recipientConfigs; // Existing configurations
  final String? createForAll; // Flag to indicate "create for all" mode

  const BuildingResponsiblePersonsPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.buildingId,
    this.siteId,
    this.recipientsJson,
    this.recipient,
    this.allRecipients,
    this.recipientConfigs,
    this.createForAll,
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
    'peak_loads': false,
    'anomalies': false,
    'rooms_by_consumption': true,
    'underutilization': true,
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
  }

  @override
  void dispose() {
    _reportingNameController.dispose();
    super.dispose();
  }

  void _handleLanguageChanged() {
    setState(() {});
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
    if (_reportOptions['rooms_by_consumption'] == true) {
      reportContents.add('ConsumptionByRoom');
    }
    if (_reportOptions['peak_loads'] == true) {
      reportContents.add('PeakLoads');
    }
    if (_reportOptions['anomalies'] == true) {
      reportContents.add('Anomalies');
    }
    if (_reportOptions['underutilization'] == true) {
      reportContents.add('InefficientUsage');
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
    setState(() {
      _savedReportConfigs.add({
        'name': _reportingNameController.text.trim(),
        'interval': interval,
        'intervalKey': _selectedFrequencyKey,
        'reportContents': reportContents,
        'reportOptions': Map<String, bool>.from(_reportOptions),
        'completed': true,
      });

      // Reset form for new entry
      _reportingNameController.clear();
      _selectedFrequencyKey = 'monthly';
      _reportOptions = {
        'total_consumption': true,
        'peak_loads': false,
        'anomalies': false,
        'rooms_by_consumption': true,
        'underutilization': true,
      };
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('building_responsible_persons.routine_saved'.tr()),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getReportOptionLabel(String key) {
    return 'building_responsible_persons.$key'.tr();
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
    if (_reportOptions['rooms_by_consumption'] == true) {
      reportContents.add('ConsumptionByRoom');
    }
    if (_reportOptions['peak_loads'] == true) {
      reportContents.add('PeakLoads');
    }
    if (_reportOptions['anomalies'] == true) {
      reportContents.add('Anomalies');
    }
    if (_reportOptions['underutilization'] == true) {
      reportContents.add('InefficientUsage');
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
        _completedConfigs[recipientId] = {
          'name': _reportingNameController.text.isNotEmpty
              ? _reportingNameController.text
              : 'Executive Weekly Report',
          'interval': interval,
          'intervalKey': _selectedFrequencyKey,
          'reportContents': reportContents,
          'reportOptions': Map<String, bool>.from(_reportOptions),
        };
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

    setState(() {
      _isLoading = true;
    });

    try {
      // Get recipients from widget property
      List<Map<String, dynamic>> recipients = [];
      if (widget.recipientsJson != null && widget.recipientsJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(widget.recipientsJson!) as List;
          recipients = decoded.map<Map<String, dynamic>>((r) {
            return {
              'name': (r['name'] ?? '').toString().trim(),
              'email': (r['email'] ?? '').toString().trim(),
              if (r['phone'] != null && (r['phone'] as String).isNotEmpty)
                'phone': (r['phone'] ?? '').toString().trim(),
            };
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
      if (_reportOptions['rooms_by_consumption'] == true) {
        reportContents.add('ConsumptionByRoom');
      }
      if (_reportOptions['peak_loads'] == true) {
        reportContents.add('PeakLoads');
      }
      if (_reportOptions['anomalies'] == true) {
        reportContents.add('Anomalies');
      }
      if (_reportOptions['underutilization'] == true) {
        reportContents.add('InefficientUsage');
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

      // Build report config - use current form if filled, otherwise use saved configs
      Map<String, dynamic> reportConfig;
      if (_reportingNameController.text.trim().isNotEmpty ||
          _reportOptions.values.any((value) => value == true)) {
        // Current form has data, use it
        reportConfig = {
          'name': _reportingNameController.text.isNotEmpty
              ? _reportingNameController.text
              : 'Executive Weekly Report',
          'interval': interval,
          if (reportContents.isNotEmpty) 'reportContents': reportContents,
        };
      } else if (_savedReportConfigs.isNotEmpty) {
        // Use the first saved config (or combine all if needed)
        final firstConfig = _savedReportConfigs.first;
        reportConfig = {
          'name': firstConfig['name'] ?? 'Executive Weekly Report',
          'interval': firstConfig['interval'] ?? 'Monthly',
          if (firstConfig['reportContents'] != null &&
              (firstConfig['reportContents'] as List).isNotEmpty)
            'reportContents': firstConfig['reportContents'],
        };
      } else {
        // Default config
        reportConfig = {
          'name': 'Executive Weekly Report',
          'interval': interval,
        };
      }

      // Build request body for "create for all" mode
      final requestBody = {
        'recipients': recipients,
        'reportConfig': reportConfig,
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
        // Navigate to add additional buildings page
        if (mounted) {
          context.goNamed(
            Routelists.addAdditionalBuildings,
            queryParameters: {
              if (widget.userName != null) 'userName': widget.userName!,
              if (widget.siteId != null && widget.siteId!.isNotEmpty)
                'siteId': widget.siteId!,
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
  }

  Future<void> _handleCompleteSetup() async {
    if (_isLoading) return;

    // Save current config before completing
    _saveCurrentConfig();

    // Check if all recipients have configurations
    final allRecipientsHaveConfig = _allRecipients.every((recipient) {
      final id = recipient['id']?.toString();
      return id != null && _completedConfigs.containsKey(id);
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

      // Make API call
      final response = await _dioClient.dio.post(
        '/api/v1/reporting/setup',
        data: requestBody,
      );

      // Check if response is successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Navigate to add additional buildings page
        if (mounted) {
          context.goNamed(
            Routelists.addAdditionalBuildings,
            queryParameters: {
              if (widget.userName != null) 'userName': widget.userName!,
              if (widget.siteId != null && widget.siteId!.isNotEmpty)
                'siteId': widget.siteId!,
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
  }

  Future<void> _handleContinue() async {
    // If editing a specific recipient, save and go back
    if (_currentRecipient != null) {
      _handleSaveAndBack();
      return;
    }

    // If "create for all" mode, use the new API structure
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
      if (_reportOptions['rooms_by_consumption'] == true) {
        reportContents.add('ConsumptionByRoom');
      }
      if (_reportOptions['peak_loads'] == true) {
        reportContents.add('PeakLoads');
      }
      if (_reportOptions['anomalies'] == true) {
        reportContents.add('Anomalies');
      }
      if (_reportOptions['underutilization'] == true) {
        reportContents.add('InefficientUsage');
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
        // Navigate to add additional buildings page
        if (mounted) {
          context.goNamed(
            Routelists.addAdditionalBuildings,
            queryParameters: {
              if (widget.userName != null) 'userName': widget.userName!,
              if (widget.siteId != null && widget.siteId!.isNotEmpty)
                'siteId': widget.siteId!,
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
                              'building_responsible_persons.progress_text'.tr(
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
                                    // Back button if editing a specific recipient
                                    if (_currentRecipient != null) ...[
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => context.pop(),
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
                                    Text(
                                      widget.createForAll == 'true'
                                          ? 'building_responsible_persons.title_for_all'
                                                .tr()
                                          : _currentRecipient != null
                                          ? 'building_responsible_persons.title_recipient'.tr(
                                              namedArgs: {
                                                'name':
                                                    _currentRecipient!['name'] ??
                                                    '',
                                              },
                                            )
                                          : widget.userName != null
                                          ? 'building_responsible_persons.title'
                                                .tr(
                                                  namedArgs: {
                                                    'name': widget.userName!,
                                                  },
                                                )
                                          : 'building_responsible_persons.title_fallback'
                                                .tr(),
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.headlineSmall
                                          .copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                          ),
                                    ),
                                    const SizedBox(height: 32),
                                    // Display saved report configs
                                    if (_savedReportConfigs.isNotEmpty) ...[
                                      ..._savedReportConfigs.map((savedConfig) {
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            color: Colors.grey[50],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: Colors.green[600],
                                                    size: 20,
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
                                        borderRadius: BorderRadius.circular(4),
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
                                        borderRadius: BorderRadius.circular(4),
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

                                    // Report Options Checkboxes - Row 1
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildReportOptionCheckbox(
                                          'total_consumption',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'peak_loads',
                                        ),
                                        _buildReportOptionCheckbox('anomalies'),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Report Options Checkboxes - Row 2
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildReportOptionCheckbox(
                                          'rooms_by_consumption',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'underutilization',
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
                                              if (_reportOptions['rooms_by_consumption'] ==
                                                  true) {
                                                reportContents.add(
                                                  'ConsumptionByRoom',
                                                );
                                              }
                                              if (_reportOptions['peak_loads'] ==
                                                  true) {
                                                reportContents.add('PeakLoads');
                                              }
                                              if (_reportOptions['anomalies'] ==
                                                  true) {
                                                reportContents.add('Anomalies');
                                              }
                                              if (_reportOptions['underutilization'] ==
                                                  true) {
                                                reportContents.add(
                                                  'InefficientUsage',
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
                                          if (allHaveConfig) {
                                            return Column(
                                              children: [
                                                const SizedBox(height: 16),
                                                Center(
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: _isLoading
                                                        ? const CircularProgressIndicator()
                                                        : PrimaryOutlineButton(
                                                            label:
                                                                'building_responsible_persons.complete_setup'
                                                                    .tr(),
                                                            width: 260,
                                                            onPressed:
                                                                _handleCompleteSetup,
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
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
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // border: Border.all(color: Colors.black54, width: 1),
            // borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 1),
                  borderRadius: BorderRadius.circular(4),
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
            borderRadius: BorderRadius.circular(4),
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
            borderRadius: BorderRadius.circular(4),
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
