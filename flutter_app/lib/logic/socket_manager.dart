import 'dart:async';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef SocketChannelFactory = SocketChannel Function(Uri uri);

abstract interface class SocketChannel {
  Stream<dynamic> get stream;
  StreamSink<dynamic> get sink;
}

class SocketManager {
  SocketManager({SocketChannelFactory? channelFactory, String? socketUrl})
    : _channelFactory = channelFactory ?? _defaultChannelFactory,
      _socketUrl = socketUrl ?? serverUrl;

  static const String serverUrl = 'ws://localhost:8765/ws';

  final SocketChannelFactory _channelFactory;
  final String _socketUrl;
  final StreamController<String> _messagesController =
      StreamController<String>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  SocketChannel? _channel;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Stream<String> get messages => _messagesController.stream;

  Future<void> connect() async {
    if (_isConnected) {
      return;
    }

    final Uri uri = Uri.parse(_socketUrl);
    final SocketChannel channel = _channelFactory(uri);

    _channel = channel;
    _isConnected = true;
    _subscription = channel.stream.listen(
      (dynamic data) {
        if (data is String) {
          _messagesController.add(data);
          return;
        }

        _messagesController.addError(
          StateError('Expected text websocket payload, got ${data.runtimeType}.'),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _messagesController.addError(error, stackTrace);
      },
      onDone: () {
        _isConnected = false;
        _subscription = null;
        _channel = null;
      },
    );
  }

  void send(String message) {
    final SocketChannel? channel = _channel;
    if (!_isConnected || channel == null) {
      throw StateError('Socket is not connected. Call connect() first.');
    }

    channel.sink.add(message);
  }

  Future<void> disconnect() async {
    final StreamSubscription<dynamic>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();

    final SocketChannel? channel = _channel;
    _channel = null;
    _isConnected = false;
    await channel?.sink.close();
  }

  Future<void> dispose() async {
    await disconnect();
    await _messagesController.close();
  }

  static SocketChannel _defaultChannelFactory(Uri uri) {
    return _WebSocketChannelAdapter(IOWebSocketChannel.connect(uri));
  }
}

class _WebSocketChannelAdapter implements SocketChannel {
  const _WebSocketChannelAdapter(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  StreamSink<dynamic> get sink => _channel.sink;
}
