import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/logic/user_preferences_manager.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef SocketChannelFactory = SocketChannel Function(Uri uri);

abstract interface class SocketChannel {
  Future<void> get ready;
  Stream<dynamic> get stream;
  StreamSink<dynamic> get sink;
}

class SocketManager {
  SocketManager({SocketChannelFactory? channelFactory, String? socketUrlIn})
    : _channelFactory = channelFactory ?? _defaultChannelFactory,
      _socketUrl = socketUrlIn ?? _resolveDefaultServerUrl();

  // Override with:
  // flutter run --dart-define SOCKET_URL=ws://<host>:8765
  static const String serverUrlOverride = String.fromEnvironment('SOCKET_URL');

  
  String? _username;
  final SocketChannelFactory _channelFactory;
  final String _socketUrl;
  final StreamController<String> _messagesController =
      StreamController<String>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  SocketChannel? _channel;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Stream<String> get messages => _messagesController.stream;


  void handleData(String strData) {
    
    final data = jsonDecode(strData);
    print(data);

    switch (data["type"]) {
      case "join":

        break;
      case "hit":
        
        break;
    }

  }

  Future<String> _getUsername() async {
    _username ??= await UserPreferencesManager.getUsername() ?? "";
    return _username!;
  }


  Future<void> connect() async {
    if (_isConnected) {
      return;
    }


    final Uri uri = Uri.parse(_socketUrl);
    final SocketChannel channel = _channelFactory(uri);

    _subscription = channel.stream.listen(
      (dynamic data) {
        if (data is String) {
          handleData(data);
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

    try {
      await _getUsername();
      await channel.ready;
      _channel = channel;
      _isConnected = true;

      final message = jsonEncode({
        'type': 'join',
        'username': _username,
      });
      send(message);

    } catch (error, stackTrace) {
      await _subscription?.cancel();
      _subscription = null;
      _channel = null;
      _isConnected = false;
      _messagesController.addError(error, stackTrace);
      rethrow;
    }
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

  static String _resolveDefaultServerUrl() {
    if (serverUrlOverride.isNotEmpty) {
      return serverUrlOverride;
    }

    // Android emulator reaches host machine via 10.0.2.2, not localhost.
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8765';
    }

    return 'ws://localhost:8765';
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
