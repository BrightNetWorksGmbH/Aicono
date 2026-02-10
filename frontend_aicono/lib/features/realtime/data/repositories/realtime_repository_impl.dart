import 'dart:async';
import 'package:frontend_aicono/features/realtime/domain/entities/realtime_connection_state.dart';
import 'package:frontend_aicono/features/realtime/domain/repositories/realtime_repository.dart';
import 'package:frontend_aicono/features/realtime/data/datasources/realtime_remote_datasource.dart';

class RealtimeRepositoryImpl implements RealtimeRepository {
  final RealtimeRemoteDataSource _dataSource;

  RealtimeRepositoryImpl({required RealtimeRemoteDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Stream<RealtimeConnectionState> get stateStream => _dataSource.stateStream;

  @override
  RealtimeConnectionState get currentState => _dataSource.currentState;

  @override
  Future<void> connect(String token) => _dataSource.connect(token);

  @override
  Future<void> subscribeToRoom(String roomId) =>
      _dataSource.subscribeToRoom(roomId);

  @override
  Future<void> subscribeToSensor(String sensorId) =>
      _dataSource.subscribeToSensor(sensorId);

  @override
  Future<void> unsubscribe({String? roomId, String? sensorId}) =>
      _dataSource.unsubscribe(roomId: roomId, sensorId: sensorId);

  @override
  Future<void> disconnect() => _dataSource.disconnect();

  @override
  Future<void> reconnect() => _dataSource.reconnect();
}
