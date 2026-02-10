import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/features/realtime/domain/entities/realtime_connection_state.dart';
import 'package:frontend_aicono/features/realtime/domain/entities/realtime_sensor_entity.dart';
import 'package:frontend_aicono/features/realtime/domain/repositories/realtime_repository.dart';

part 'realtime_sensor_event.dart';
part 'realtime_sensor_state.dart';

class RealtimeSensorBloc extends Bloc<RealtimeSensorEvent, RealtimeSensorState> {
  final RealtimeRepository _repository;
  StreamSubscription<RealtimeConnectionState>? _stateSubscription;

  RealtimeSensorBloc({required RealtimeRepository repository})
      : _repository = repository,
        super(RealtimeSensorState.initial()) {
    _stateSubscription = _repository.stateStream.listen(_onRepositoryState);
    on<RealtimeSensorConnectRequested>(_onConnectRequested);
    on<RealtimeSensorSubscribeToRoom>(_onSubscribeToRoom);
    on<RealtimeSensorSubscribeToSensor>(_onSubscribeToSensor);
    on<RealtimeSensorDisconnectRequested>(_onDisconnectRequested);
    on<RealtimeSensorReconnectRequested>(_onReconnectRequested);
    on<RealtimeSensorConnectionStateChanged>(_onConnectionStateChanged);
  }

  void _onRepositoryState(RealtimeConnectionState connState) {
    add(RealtimeSensorConnectionStateChanged(connState));
  }

  Future<void> _onConnectRequested(
    RealtimeSensorConnectRequested event,
    Emitter<RealtimeSensorState> emit,
  ) async {
    if (event.token.isEmpty) {
      emit(state.copyWith(errorMessage: 'No authentication token.'));
      return;
    }
    await _repository.connect(event.token);
  }

  Future<void> _onSubscribeToRoom(
    RealtimeSensorSubscribeToRoom event,
    Emitter<RealtimeSensorState> emit,
  ) async {
    if (event.roomId.isEmpty) return;
    await _repository.subscribeToRoom(event.roomId);
  }

  Future<void> _onSubscribeToSensor(
    RealtimeSensorSubscribeToSensor event,
    Emitter<RealtimeSensorState> emit,
  ) async {
    if (event.sensorId.isEmpty) return;
    await _repository.subscribeToSensor(event.sensorId);
  }

  Future<void> _onDisconnectRequested(
    RealtimeSensorDisconnectRequested event,
    Emitter<RealtimeSensorState> emit,
  ) async {
    await _repository.disconnect();
  }

  Future<void> _onReconnectRequested(
    RealtimeSensorReconnectRequested event,
    Emitter<RealtimeSensorState> emit,
  ) async {
    await _repository.reconnect();
  }

  void _onConnectionStateChanged(
    RealtimeSensorConnectionStateChanged event,
    Emitter<RealtimeSensorState> emit,
  ) {
    final s = event.connectionState;
    emit(RealtimeSensorState(
      status: s.status,
      clientId: s.clientId,
      errorMessage: s.errorMessage,
      sensorValues: s.sensorValues,
      subscribedRoomId: s.subscribedRoomId,
      subscribedSensorId: s.subscribedSensorId,
    ));
  }

  @override
  Future<void> close() {
    _stateSubscription?.cancel();
    _repository.disconnect();
    return super.close();
  }
}
