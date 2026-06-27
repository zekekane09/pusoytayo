import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:pusoy_tayo/core/constants/api_endpoints.dart';
import 'package:pusoy_tayo/core/network/api_client.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

final socketClientProvider = Provider<SocketClient>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SocketClient(apiClient);
});

class SocketClient {
  final ApiClient _apiClient;
  final _logger = Logger();
  io.Socket? _socket;
  final _eventControllers = <String, StreamController<dynamic>>{};
  bool _isConnected = false;

  SocketClient(this._apiClient);

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    final token = await _apiClient.getAccessToken();
    if (token == null) {
      _logger.w('No token available for socket connection');
      return;
    }

    _socket = io.io(
      ApiEndpoints.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _logger.i('Socket connected');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _logger.i('Socket disconnected');
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      _logger.e('Socket connection error: $error');
    });

    _socket!.onReconnect((_) {
      _isConnected = true;
      _logger.i('Socket reconnected');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
  }

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  Stream<T> on<T>(String event) {
    if (!_eventControllers.containsKey(event)) {
      final controller = StreamController<dynamic>.broadcast();
      _socket?.on(event, (data) => controller.add(data));
      _eventControllers[event] = controller;
    }
    return _eventControllers[event]!.stream.cast<T>();
  }

  void off(String event) {
    _socket?.off(event);
    _eventControllers[event]?.close();
    _eventControllers.remove(event);
  }

  void once(String event, void Function(dynamic) callback) {
    _socket?.once(event, callback);
  }
}
