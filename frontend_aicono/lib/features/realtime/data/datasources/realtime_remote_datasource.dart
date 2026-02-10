import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:frontend_aicono/features/realtime/domain/entities/realtime_connection_state.dart';
import 'package:frontend_aicono/features/realtime/domain/entities/realtime_sensor_entity.dart';

/// WebSocket datasource for real-time sensor data.
/// Handles connection, subscription messages, and parsing server responses.
abstract class RealtimeRemoteDataSource {
  Stream<RealtimeConnectionState> get stateStream;
  RealtimeConnectionState get currentState;
  Future<void> connect(String token);
  Future<void> subscribeToRoom(String roomId);
  Future<void> subscribeToSensor(String sensorId);
  Future<void> unsubscribe({String? roomId, String? sensorId});
  Future<void> disconnect();
  Future<void> reconnect();
}

class RealtimeRemoteDataSourceImpl implements RealtimeRemoteDataSource {
  final String baseUrl;
  final int maxReconnectAttempts;
  final Duration reconnectDelay;

  WebSocketChannel? _channel;
  final _stateController = StreamController<RealtimeConnectionState>.broadcast();
  RealtimeConnectionState _state = const RealtimeConnectionState();
  String? _token;
  String? _pendingRoomId;
  String? _pendingSensorId;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _isManualDisconnect = false;

  RealtimeRemoteDataSourceImpl({
    required this.baseUrl,
    this.maxReconnectAttempts = 5,
    this.reconnectDelay = const Duration(seconds: 3),
  });

  @override
  Stream<RealtimeConnectionState> get stateStream => _stateController.stream;

  @override
  RealtimeConnectionState get currentState => _state;

  String _buildWebSocketUrl(String token) {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final host = uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    final path = uri.path.isEmpty || uri.path == '/'
        ? '/realtime'
        : uri.path.endsWith('/')
            ? '${uri.path}realtime'
            : '${uri.path}/realtime';
    return '$scheme://$host$port$path?token=${Uri.encodeComponent(token)}';
  }

  void _emit(RealtimeConnectionState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  Future<void> connect(String token) async {
    if (_state.status == RealtimeConnectionStatus.connecting) return;
    if (_state.isActive && _token == token) return;

    _isManualDisconnect = false;
    _token = token;

    _emit(_state.copyWith(
      status: RealtimeConnectionStatus.connecting,
      errorMessage: null,
    ));

    try {
      final url = _buildWebSocketUrl(token);
      if (kDebugMode) {
        print('[REALTIME] Connecting to WebSocket...');
      }

      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[REALTIME] Connection error: $e');
      }
      _emit(_state.copyWith(
        status: RealtimeConnectionStatus.error,
        errorMessage: _userFriendlyError(e),
      ));
    }
  }

  void _onMessage(dynamic data) {
    try {
      final json = data is String ? jsonDecode(data) : data;
      if (json is! Map<String, dynamic>) return;

      final type = json['type'] as String?;
      switch (type) {
        case 'connected':
          _handleConnected(json);
          break;
        case 'initial_state':
          _handleInitialState(json);
          break;
        case 'subscribe_success':
          _handleSubscribeSuccess(json);
          break;
        case 'sensor_update':
          _handleSensorUpdate(json);
          break;
        case 'error':
          _handleError(json);
          break;
        default:
          if (kDebugMode) {
            print('[REALTIME] Unknown message type: $type');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[REALTIME] Parse error: $e');
      }
    }
  }

  void _handleConnected(Map<String, dynamic> json) {
    _reconnectAttempt = 0;
    _emit(_state.copyWith(
      status: RealtimeConnectionStatus.connected,
      clientId: json['clientId']?.toString(),
      errorMessage: null,
    ));

    if (_pendingRoomId != null) {
      _sendSubscribe(roomId: _pendingRoomId);
      _pendingRoomId = null;
    } else if (_pendingSensorId != null) {
      _sendSubscribe(sensorId: _pendingSensorId);
      _pendingSensorId = null;
    }
  }

  void _handleInitialState(Map<String, dynamic> json) {
    final sensorsJson = json['sensors'] as List<dynamic>? ?? [];
    final Map<String, RealtimeSensorData> updated = Map.from(_state.sensorValues);

    for (final s in sensorsJson) {
      if (s is Map<String, dynamic>) {
        final sensorId = s['sensorId']?.toString();
        if (sensorId == null) continue;
        final value = (s['value'] is num) ? (s['value'] as num).toDouble() : 0.0;
        final unit = (s['unit'] ?? '').toString();
        final ts = s['timestamp']?.toString();
        DateTime timestamp = DateTime.now();
        if (ts != null) {
          timestamp = DateTime.tryParse(ts) ?? timestamp;
        }
        updated[sensorId] = RealtimeSensorData(
          sensorId: sensorId,
          value: value,
          unit: unit,
          timestamp: timestamp,
        );
      }
    }

    _emit(_state.copyWith(sensorValues: updated));
  }

  void _handleSubscribeSuccess(Map<String, dynamic> json) {
    _emit(_state.copyWith(
      status: RealtimeConnectionStatus.subscribed,
      subscribedRoomId: json['roomId']?.toString(),
      subscribedSensorId: json['sensorId']?.toString(),
    ));
  }

  void _handleSensorUpdate(Map<String, dynamic> json) {
    final sensorId = json['sensorId']?.toString();
    if (sensorId == null) return;
    final value = (json['value'] is num) ? (json['value'] as num).toDouble() : 0.0;
    final unit = (json['unit'] ?? '').toString();
    final ts = json['timestamp']?.toString();
    DateTime timestamp = DateTime.now();
    if (ts != null) {
      timestamp = DateTime.tryParse(ts) ?? timestamp;
    }

    final updated = Map<String, RealtimeSensorData>.from(_state.sensorValues);
    updated[sensorId] = RealtimeSensorData(
      sensorId: sensorId,
      value: value,
      unit: unit,
      timestamp: timestamp,
    );
    _emit(_state.copyWith(sensorValues: updated));
  }

  void _handleError(Map<String, dynamic> json) {
    final message = json['message']?.toString() ?? 'Unknown error';
    _emit(_state.copyWith(
      status: RealtimeConnectionStatus.error,
      errorMessage: message,
    ));
  }

  void _onError(dynamic error) {
    if (kDebugMode) {
      print('[REALTIME] WebSocket error: $error');
    }
    if (_isManualDisconnect) return;
    _scheduleReconnect();
  }

  void _onDone() {
    if (kDebugMode) {
      print('[REALTIME] WebSocket closed');
    }
    _channel = null;
    if (_isManualDisconnect) {
      _emit(const RealtimeConnectionState());
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempt >= maxReconnectAttempts || _token == null) {
      _emit(_state.copyWith(
        status: RealtimeConnectionStatus.error,
        errorMessage: 'Connection lost. Please refresh the page.',
        reconnectAttempt: _reconnectAttempt,
      ));
      return;
    }

    _reconnectAttempt++;
    _emit(_state.copyWith(
      status: RealtimeConnectionStatus.reconnecting,
      reconnectAttempt: _reconnectAttempt,
    ));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () async {
      if (_token != null && !_isManualDisconnect) {
        await connect(_token!);
        if (_state.subscribedRoomId != null) {
          _pendingRoomId = _state.subscribedRoomId;
        } else if (_state.subscribedSensorId != null) {
          _pendingSensorId = _state.subscribedSensorId;
        }
      }
    });
  }

  String _userFriendlyError(dynamic e) {
    final s = e.toString().toLowerCase();
    if (s.contains('connection refused') || s.contains('failed host lookup')) {
      return 'Cannot connect to server. Check your network.';
    }
    if (s.contains('401') || s.contains('unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    return 'Connection failed. Please try again.';
  }

  void _sendSubscribe({String? roomId, String? sensorId}) {
    if (_channel == null) return;
    final map = <String, dynamic>{
      'type': 'subscribe',
      if (roomId != null) 'roomId': roomId,
      if (sensorId != null) 'sensorId': sensorId,
    };
    _channel!.sink.add(jsonEncode(map));
  }

  void _sendUnsubscribe({String? roomId, String? sensorId}) {
    if (_channel == null) return;
    final map = <String, dynamic>{
      'type': 'unsubscribe',
      if (roomId != null) 'roomId': roomId,
      if (sensorId != null) 'sensorId': sensorId,
    };
    _channel!.sink.add(jsonEncode(map));
  }

  @override
  Future<void> subscribeToRoom(String roomId) async {
    if (roomId.isEmpty) return;

    if (_state.status != RealtimeConnectionStatus.connected &&
        _state.status != RealtimeConnectionStatus.subscribed) {
      _pendingRoomId = roomId;
      return;
    }

    _sendSubscribe(roomId: roomId);
    _emit(_state.copyWith(subscribedRoomId: roomId, subscribedSensorId: null));
  }

  @override
  Future<void> subscribeToSensor(String sensorId) async {
    if (sensorId.isEmpty) return;

    if (_state.status != RealtimeConnectionStatus.connected &&
        _state.status != RealtimeConnectionStatus.subscribed) {
      _pendingSensorId = sensorId;
      return;
    }

    _sendSubscribe(sensorId: sensorId);
    _emit(_state.copyWith(subscribedSensorId: sensorId, subscribedRoomId: null));
  }

  @override
  Future<void> unsubscribe({String? roomId, String? sensorId}) async {
    _sendUnsubscribe(roomId: roomId, sensorId: sensorId);
    _emit(_state.copyWith(
      subscribedRoomId: roomId != null ? null : _state.subscribedRoomId,
      subscribedSensorId: sensorId != null ? null : _state.subscribedSensorId,
    ));
  }

  @override
  Future<void> disconnect() async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pendingRoomId = null;
    _pendingSensorId = null;

    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'disconnect'}));
        await _channel!.sink.close();
      } catch (_) {}
      _channel = null;
    }

    _emit(const RealtimeConnectionState());
  }

  @override
  Future<void> reconnect() async {
    _reconnectAttempt = 0;
    if (_token != null) {
      await connect(_token!);
      if (_state.subscribedRoomId != null) {
        _pendingRoomId = _state.subscribedRoomId;
      } else if (_state.subscribedSensorId != null) {
        _pendingSensorId = _state.subscribedSensorId;
      }
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    disconnect();
    _stateController.close();
  }
}
