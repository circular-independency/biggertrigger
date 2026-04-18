import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef SocketChannelFactory = SocketChannel Function(Uri uri);

abstract interface class SocketChannel {
  Future<void> get ready;
  Stream<dynamic> get stream;
  StreamSink<dynamic> get sink;
}

/// Thin websocket transport used by the app session controller.
///
/// This class only owns:
/// - socket lifecycle
/// - JSON serialization/deserialization
/// - a typed event stream for incoming server messages
///
/// Higher-level gameplay state stays in `GameSessionController`.
class SocketManager {
  SocketManager({SocketChannelFactory? channelFactory})
    : _channelFactory = channelFactory ?? _defaultChannelFactory;

  static const String serverUrlOverride = String.fromEnvironment('SOCKET_URL');

  final SocketChannelFactory _channelFactory;
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  SocketChannel? _channel;
  bool _isConnected = false;
  String? _socketUrl;

  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>> get events => _eventsController.stream;
  String? get socketUrl => _socketUrl;

  /// Opens the websocket connection to [socketUrl].
  Future<void> connect(String socketUrl) async {
    if (_isConnected) {
      return;
    }

    final String normalizedUrl = normalizeSocketUrl(socketUrl);
    final Uri uri = Uri.parse(normalizedUrl);
    final SocketChannel channel = _channelFactory(uri);

    _subscription = channel.stream.listen(
      _handleIncomingData,
      onError: (Object error, StackTrace stackTrace) {
        _eventsController.addError(error, stackTrace);
      },
      onDone: () {
        _isConnected = false;
        _subscription = null;
        _channel = null;
        _eventsController.add(<String, dynamic>{'type': 'socket_closed'});
      },
    );

    try {
      await channel.ready;
      _channel = channel;
      _socketUrl = normalizedUrl;
      _isConnected = true;
    } catch (error, stackTrace) {
      await _subscription?.cancel();
      _subscription = null;
      _channel = null;
      _socketUrl = null;
      _isConnected = false;
      _eventsController.addError(error, stackTrace);
      rethrow;
    }
  }

  /// Sends a JSON event to the server.
  void sendJson(Map<String, Object?> message) {
    final SocketChannel? channel = _channel;
    if (!_isConnected || channel == null) {
      throw StateError('Socket is not connected. Call connect() first.');
    }

    channel.sink.add(jsonEncode(message));
  }

  /// Closes the active websocket connection.
  Future<void> disconnect() async {
    final StreamSubscription<dynamic>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();

    final SocketChannel? channel = _channel;
    _channel = null;
    _socketUrl = null;
    _isConnected = false;
    await channel?.sink.close();
  }

  /// Releases transport resources.
  Future<void> dispose() async {
    await disconnect();
    await _eventsController.close();
  }

  /// Turns a human-entered host string into a valid websocket URL.
  static String normalizeSocketUrl(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return defaultSocketUrl();
    }

    if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
      return trimmed;
    }

    return 'ws://$trimmed';
  }

  /// Default URL used when the user has not saved a server address yet.
  static String defaultSocketUrl() {
    if (serverUrlOverride.isNotEmpty) {
      return serverUrlOverride;
    }

    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8765';
    }

    return 'ws://localhost:8765';
  }

  void _handleIncomingData(dynamic data) {
    if (data is! String) {
      _eventsController.addError(
        StateError('Expected text websocket payload, got ${data.runtimeType}.'),
      );
      return;
    }

    final Object decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) {
      _eventsController.addError(
        StateError('Expected JSON object payload, got ${decoded.runtimeType}.'),
      );
      return;
    }

    _eventsController.add(decoded);
  }

  static SocketChannel _defaultChannelFactory(Uri uri) {
    return _WebSocketChannelAdapter(IOWebSocketChannel.connect(uri));
  }
}

class _WebSocketChannelAdapter implements SocketChannel {
  const _WebSocketChannelAdapter(this._channel);

  final WebSocketChannel _channel;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  StreamSink<dynamic> get sink => _channel.sink;
}
