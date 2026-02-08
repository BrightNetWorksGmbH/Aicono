import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
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
  final Map<String, bool> _editingSensors = {};
  final Map<String, TextEditingController> _minControllers = {};
  final Map<String, TextEditingController> _maxControllers = {};
  final Map<String, bool> _savingSensors = {};

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

  void _toggleEdit(String sensorId) {
    setState(() {
      _editingSensors[sensorId] = !(_editingSensors[sensorId] ?? false);
    });
  }

  Future<void> _saveSensorValues(String sensorId) async {
    final minController = _minControllers[sensorId];
    final maxController = _maxControllers[sensorId];

    if (minController == null || maxController == null) {
      return;
    }

    final minValue = minController.text.trim();
    final maxValue = maxController.text.trim();

    // Validate that values are numbers if provided
    if (minValue.isNotEmpty && double.tryParse(minValue) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Min value must be a valid number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (maxValue.isNotEmpty && double.tryParse(maxValue) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Max value must be a valid number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _savingSensors[sensorId] = true;
    });

    try {
      final dioClient = sl<DioClient>();
      final requestBody = <String, dynamic>{};

      if (minValue.isNotEmpty) {
        requestBody['min_value'] = double.parse(minValue);
      }
      if (maxValue.isNotEmpty) {
        requestBody['max_value'] = double.parse(maxValue);
      }

      final response = await dioClient.patch(
        '/api/v1/sensors/$sensorId',
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
          // Update local state
          setState(() {
            final sensorIndex = _sensors.indexWhere((s) => s.id == sensorId);
            if (sensorIndex != -1) {
              _sensors[sensorIndex] = SensorData(
                id: sensorId,
                name: _sensors[sensorIndex].name,
                minValue: minValue,
                maxValue: maxValue,
              );
            }
            _editingSensors[sensorId] = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update sensor: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating sensor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingSensors[sensorId] = false;
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
                            child: ListView.builder(
                              itemCount: _sensors.length,
                              itemBuilder: (context, index) {
                                final sensor = _sensors[index];
                                final isEditing =
                                    _editingSensors[sensor.id] ?? false;
                                final isSaving =
                                    _savingSensors[sensor.id] ?? false;

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
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                isEditing
                                                    ? Icons.close
                                                    : Icons.edit,
                                                color: Colors.black87,
                                              ),
                                              onPressed: isSaving
                                                  ? null
                                                  : () =>
                                                        _toggleEdit(sensor.id),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isEditing) ...[
                                        const Divider(height: 1),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              TextFormField(
                                                controller:
                                                    _minControllers[sensor.id],
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                decoration: InputDecoration(
                                                  labelText: 'Min Value',
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
                                              const SizedBox(height: 16),
                                              TextFormField(
                                                controller:
                                                    _maxControllers[sensor.id],
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                decoration: InputDecoration(
                                                  labelText: 'Max Value',
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
                                              const SizedBox(height: 16),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: isSaving
                                                      ? null
                                                      : () => _saveSensorValues(
                                                          sensor.id,
                                                        ),
                                                  style: ElevatedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 16,
                                                        ),
                                                  ),
                                                  child: isSaving
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        )
                                                      : const Text('Save'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else ...[
                                        if (sensor.minValue.isNotEmpty ||
                                            sensor.maxValue.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 16,
                                              right: 16,
                                              bottom: 16,
                                            ),
                                            child: Row(
                                              children: [
                                                if (sensor
                                                    .minValue
                                                    .isNotEmpty) ...[
                                                  Icon(
                                                    Icons.trending_down,
                                                    size: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Min: ${sensor.minValue}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                                if (sensor
                                                        .minValue
                                                        .isNotEmpty &&
                                                    sensor.maxValue.isNotEmpty)
                                                  const SizedBox(width: 16),
                                                if (sensor
                                                    .maxValue
                                                    .isNotEmpty) ...[
                                                  Icon(
                                                    Icons.trending_up,
                                                    size: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Max: ${sensor.maxValue}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                );
                              },
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
