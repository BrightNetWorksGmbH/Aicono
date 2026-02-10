import 'dart:async';
import 'package:frontend_aicono/features/realtime/domain/entities/realtime_connection_state.dart';

/// Repository for real-time sensor data via WebSocket.
/// Manages connection lifecycle, subscriptions, and data streams.
abstract class RealtimeRepository {
  /// Stream of connection/sensor state updates.
  Stream<RealtimeConnectionState> get stateStream;

  /// Current state (latest emitted).
  RealtimeConnectionState get currentState;

  /// Connect to the WebSocket with the given JWT token.
  /// Call when user navigates to a room/sensor page.
  Future<void> connect(String token);

  /// Subscribe to real-time updates for a room.
  /// Must be called after [connect] and receiving connected confirmation.
  Future<void> subscribeToRoom(String roomId);

  /// Subscribe to real-time updates for a single sensor.
  Future<void> subscribeToSensor(String sensorId);

  /// Unsubscribe from room or sensor.
  Future<void> unsubscribe({String? roomId, String? sensorId});

  /// Disconnect and clean up. Call when user leaves the page.
  Future<void> disconnect();

  /// Retry connection after failure (e.g., network error).
  Future<void> reconnect();
}
