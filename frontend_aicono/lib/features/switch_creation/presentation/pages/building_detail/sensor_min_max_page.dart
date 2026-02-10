import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';

class SensorMinMaxPage extends StatefulWidget {
  final String buildingId;
  final String? siteId;
  final String? fromDashboard;

  const SensorMinMaxPage({
    super.key,
    required this.buildingId,
    this.siteId,
    this.fromDashboard,
  });

  @override
  State<SensorMinMaxPage> createState() => _SensorMinMaxPageState();
}

class _SensorMinMaxPageState extends State<SensorMinMaxPage> {
  List<SensorData> _sensors = [];
  bool _isLoading = false;
  final Map<String, TextEditingController> _minControllers = {};
  final Map<String, TextEditingController> _maxControllers = {};

  @override
  void initState() {
    super.initState();
    _loadSensors();
  }

  @override
  void dispose() {
    for (final controller in _minControllers.values) {
      controller.dispose();
    }
    for (final controller in _maxControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSensors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dioClient = sl<DioClient>();
      // Fetch sensors for the building
      // Adjust the endpoint based on your API structure
      final response = await dioClient.get(
        '/api/v1/sensors/building/${widget.buildingId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final sensorsList = data['data'] as List<dynamic>;
          setState(() {
            _sensors = sensorsList.map((sensor) {
              final sensorId =
                  sensor['_id']?.toString() ??
                  sensor['id']?.toString() ??
                  UniqueKey().toString();
              final sensorName =
                  sensor['name']?.toString() ??
                  sensor['sensorName']?.toString() ??
                  'Unknown Sensor';
              final minValue =
                  sensor['min_value']?.toString() ??
                  sensor['minValue']?.toString() ??
                  '';
              final maxValue =
                  sensor['max_value']?.toString() ??
                  sensor['maxValue']?.toString() ??
                  '';

              // Initialize controllers
              _minControllers[sensorId] = TextEditingController(text: minValue);
              _maxControllers[sensorId] = TextEditingController(text: maxValue);

              return SensorData(
                id: sensorId,
                name: sensorName,
                minValue: minValue,
                maxValue: maxValue,
              );
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading sensors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sensors: $e'),
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

  Future<void> _saveAllSensors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Collect all sensors that have at least one value (min or max)
      final List<Map<String, dynamic>> sensorsToUpdate = [];

      for (final sensor in _sensors) {
        final sensorId = sensor.id;
        final minController = _minControllers[sensorId];
        final maxController = _maxControllers[sensorId];

        if (minController == null || maxController == null) {
          continue;
        }

        final minValue = minController.text.trim();
        final maxValue = maxController.text.trim();

        // Skip if both values are empty
        if (minValue.isEmpty && maxValue.isEmpty) {
          continue;
        }

        // Validate that values are numbers if provided
        if (minValue.isNotEmpty && double.tryParse(minValue) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Min value for ${sensor.name} must be a valid number',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        if (maxValue.isNotEmpty && double.tryParse(maxValue) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Max value for ${sensor.name} must be a valid number',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Build sensor update object
        final sensorUpdate = <String, dynamic>{'sensorId': sensorId};

        // Only include threshold_min if it has a value
        if (minValue.isNotEmpty) {
          sensorUpdate['threshold_min'] = double.parse(minValue);
        }

        // Only include threshold_max if it has a value
        if (maxValue.isNotEmpty) {
          sensorUpdate['threshold_max'] = double.parse(maxValue);
        }

        sensorsToUpdate.add(sensorUpdate);
      }

      // If no sensors to update, show message and return
      if (sensorsToUpdate.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No sensor values to update'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Send bulk update request
      final dioClient = sl<DioClient>();
      final requestBody = <String, dynamic>{'sensors': sensorsToUpdate};

      final response = await dioClient.put(
        '/api/v1/sensors/bulk-update',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sensor values updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload sensors to get updated values
          _loadSensors();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update sensors: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating sensors: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: screenSize.width < 600
                              ? screenSize.width * 0.95
                              : screenSize.width < 1200
                              ? screenSize.width * 0.5
                              : screenSize.width * 0.6,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: 0.9,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF8B9A5B), // Muted green color
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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
                                    'Sensor Min/Max Values',
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
                          'Configure minimum and maximum values for sensors',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 32),
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_sensors.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No sensors found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: SizedBox(
                              width: screenSize.width < 600
                                  ? screenSize.width * 0.95
                                  : screenSize.width < 1200
                                  ? screenSize.width * 0.5
                                  : screenSize.width * 0.6,
                              child: ListView.builder(
                                itemCount: _sensors.length,
                                itemBuilder: (context, index) {
                                  final sensor = _sensors[index];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black54,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.sensors,
                                                color: Colors.black87,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  sensor.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller:
                                                          _minControllers[sensor
                                                              .id],
                                                      keyboardType:
                                                          const TextInputType.numberWithOptions(
                                                            decimal: true,
                                                          ),
                                                      decoration: InputDecoration(
                                                        hintText:
                                                            'Enter minimum value',
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                0,
                                                              ),
                                                        ),
                                                        prefixIcon: Icon(
                                                          Icons.trending_down,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller:
                                                          _maxControllers[sensor
                                                              .id],
                                                      keyboardType:
                                                          const TextInputType.numberWithOptions(
                                                            decimal: true,
                                                          ),
                                                      decoration: InputDecoration(
                                                        hintText:
                                                            'Enter maximum value',
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                0,
                                                              ),
                                                        ),
                                                        prefixIcon: Icon(
                                                          Icons.trending_up,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Center(
                          child: PrimaryOutlineButton(
                            onPressed: _isLoading ? null : _saveAllSensors,
                            label: 'Save All',
                            width: 260,
                          ),
                        ),
                      ],
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
    );
  }
}

class SensorData {
  final String id;
  final String name;
  final String minValue;
  final String maxValue;

  SensorData({
    required this.id,
    required this.name,
    required this.minValue,
    required this.maxValue,
  });
}
