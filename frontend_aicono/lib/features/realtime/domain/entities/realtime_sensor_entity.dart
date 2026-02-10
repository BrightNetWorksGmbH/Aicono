import 'package:equatable/equatable.dart';

/// Represents a single sensor's real-time value from the WebSocket stream.
class RealtimeSensorData extends Equatable {
  final String sensorId;
  final double value;
  final String unit;
  final DateTime timestamp;

  const RealtimeSensorData({
    required this.sensorId,
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  String get formattedValue => '$value $unit';

  @override
  List<Object?> get props => [sensorId, value, unit, timestamp];
}
