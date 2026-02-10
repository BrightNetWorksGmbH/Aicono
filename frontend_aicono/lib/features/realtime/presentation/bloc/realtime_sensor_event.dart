part of 'realtime_sensor_bloc.dart';

abstract class RealtimeSensorEvent extends Equatable {
  const RealtimeSensorEvent();

  @override
  List<Object?> get props => [];
}

class RealtimeSensorConnectRequested extends RealtimeSensorEvent {
  final String token;

  const RealtimeSensorConnectRequested(this.token);

  @override
  List<Object?> get props => [token];
}

class RealtimeSensorSubscribeToRoom extends RealtimeSensorEvent {
  final String roomId;

  const RealtimeSensorSubscribeToRoom(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class RealtimeSensorSubscribeToSensor extends RealtimeSensorEvent {
  final String sensorId;

  const RealtimeSensorSubscribeToSensor(this.sensorId);

  @override
  List<Object?> get props => [sensorId];
}

class RealtimeSensorDisconnectRequested extends RealtimeSensorEvent {
  const RealtimeSensorDisconnectRequested();
}

class RealtimeSensorReconnectRequested extends RealtimeSensorEvent {
  const RealtimeSensorReconnectRequested();
}

class RealtimeSensorConnectionStateChanged extends RealtimeSensorEvent {
  final RealtimeConnectionState connectionState;

  const RealtimeSensorConnectionStateChanged(this.connectionState);

  @override
  List<Object?> get props => [connectionState];
}
