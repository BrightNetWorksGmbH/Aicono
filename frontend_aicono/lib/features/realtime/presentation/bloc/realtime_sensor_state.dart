part of 'realtime_sensor_bloc.dart';

class RealtimeSensorState extends Equatable {
  final RealtimeConnectionStatus status;
  final String? clientId;
  final String? errorMessage;
  final Map<String, RealtimeSensorData> sensorValues;
  final String? subscribedRoomId;
  final String? subscribedSensorId;

  const RealtimeSensorState({
    this.status = RealtimeConnectionStatus.disconnected,
    this.clientId,
    this.errorMessage,
    this.sensorValues = const {},
    this.subscribedRoomId,
    this.subscribedSensorId,
  });

  static RealtimeSensorState initial() => const RealtimeSensorState();

  RealtimeSensorState copyWith({
    RealtimeConnectionStatus? status,
    String? clientId,
    String? errorMessage,
    Map<String, RealtimeSensorData>? sensorValues,
    String? subscribedRoomId,
    String? subscribedSensorId,
  }) {
    return RealtimeSensorState(
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      errorMessage: errorMessage,
      sensorValues: sensorValues ?? this.sensorValues,
      subscribedRoomId: subscribedRoomId ?? this.subscribedRoomId,
      subscribedSensorId: subscribedSensorId ?? this.subscribedSensorId,
    );
  }

  RealtimeSensorData? getSensorValue(String sensorId) => sensorValues[sensorId];

  bool get isActive =>
      status == RealtimeConnectionStatus.connected ||
      status == RealtimeConnectionStatus.subscribed;

  bool get isConnecting =>
      status == RealtimeConnectionStatus.connecting ||
      status == RealtimeConnectionStatus.reconnecting;

  @override
  List<Object?> get props =>
      [status, clientId, errorMessage, sensorValues, subscribedRoomId, subscribedSensorId];
}
