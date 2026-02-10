import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/features/realtime/domain/entities/realtime_sensor_entity.dart';

/// Connection status for the real-time WebSocket.
enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  subscribed,
  error,
  reconnecting,
}

/// Represents the current state of the real-time sensor connection and data.
class RealtimeConnectionState extends Equatable {
  final RealtimeConnectionStatus status;
  final String? clientId;
  final String? errorMessage;
  final Map<String, RealtimeSensorData> sensorValues;
  final String? subscribedRoomId;
  final String? subscribedSensorId;
  final int reconnectAttempt;

  const RealtimeConnectionState({
    this.status = RealtimeConnectionStatus.disconnected,
    this.clientId,
    this.errorMessage,
    this.sensorValues = const {},
    this.subscribedRoomId,
    this.subscribedSensorId,
    this.reconnectAttempt = 0,
  });

  RealtimeConnectionState copyWith({
    RealtimeConnectionStatus? status,
    String? clientId,
    String? errorMessage,
    Map<String, RealtimeSensorData>? sensorValues,
    String? subscribedRoomId,
    String? subscribedSensorId,
    int? reconnectAttempt,
  }) {
    return RealtimeConnectionState(
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      errorMessage: errorMessage,
      sensorValues: sensorValues ?? this.sensorValues,
      subscribedRoomId: subscribedRoomId ?? this.subscribedRoomId,
      subscribedSensorId: subscribedSensorId ?? this.subscribedSensorId,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
    );
  }

  /// Get sensor value by ID, or null if not yet received.
  RealtimeSensorData? getSensorValue(String sensorId) => sensorValues[sensorId];

  /// Whether connection is active (connected or subscribed).
  bool get isActive =>
      status == RealtimeConnectionStatus.connected ||
      status == RealtimeConnectionStatus.subscribed;

  @override
  List<Object?> get props => [
        status,
        clientId,
        errorMessage,
        sensorValues,
        subscribedRoomId,
        subscribedSensorId,
        reconnectAttempt,
      ];
}
