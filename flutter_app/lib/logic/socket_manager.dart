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

class SocketLobbyUser {
  const SocketLobbyUser({
    required this.hp,
    required this.alive,
    required this.ready,
  });

  final int hp;
  final bool alive;
  final bool ready;
}

class SocketStartPayload {
  const SocketStartPayload({
    required this.embeddingsByUser,
    required this.healthByUser,
  });

  final Map<String, List<List<double>>> embeddingsByUser;
  final Map<String, int> healthByUser;
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
  final StreamController<Map<String, SocketLobbyUser>> _usersController =
      StreamController<Map<String, SocketLobbyUser>>.broadcast();
  final StreamController<SocketStartPayload> _startController =
      StreamController<SocketStartPayload>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  SocketChannel? _channel;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Stream<String> get messages => _messagesController.stream;

  Stream<Map<String, SocketLobbyUser>> get usersUpdates => _usersController.stream;
  Stream<SocketStartPayload> get startUpdates => _startController.stream;

  void handleData(String strData) {
    final dynamic decoded = jsonDecode(strData);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final String? type = decoded['type'] as String?;
    switch (type) {
      case 'join':
        break;
      case 'users':
        final dynamic rawUsers = decoded['data'];
        if (rawUsers is! Map) {
          return;
        }


        final Map<String, SocketLobbyUser> users = <String, SocketLobbyUser>{};
        rawUsers.forEach((dynamic key, dynamic value) {
          if (key is! String || value is! Map) {
            return;
          }

          users[key] = SocketLobbyUser(
            hp: _toInt(value['hp'], fallback: 100),
            alive: _toBool(value['alive'], fallback: true),
            ready: _toBool(value['ready'], fallback: false),
          );
        });

        _usersController.add(users);
        break;
      case 'hit':
        final String hitter = decoded['from']?.toString() ?? 'Unknown';
        _messagesController.add('[$hitter] hit you');
        break;
      case 'start':
        final dynamic rawEmbeddings = decoded['embeddings'];
        if (rawEmbeddings is! Map) {
          _messagesController.addError(
            StateError('Invalid start payload: embeddings map is missing.'),
          );
          return;
        }
        final dynamic rawHealth = decoded['health'];
        if (rawHealth is! Map) {
          _messagesController.addError(
            StateError('Invalid start payload: health map is missing.'),
          );
          return;
        }

        final Map<String, List<List<double>>> embeddingsByUser =
            <String, List<List<double>>>{};
        final Map<String, int> healthByUser = <String, int>{};
        rawEmbeddings.forEach((dynamic key, dynamic value) {
          if (key is! String || value is! List) {
            return;
          }

          final List<List<double>> parsedEmbeddings = <List<double>>[];
          for (final dynamic embedding in value) {
            if (embedding is! List) {
              continue;
            }

            final List<double> vector = <double>[];
            for (final dynamic n in embedding) {
              if (n is num) {
                vector.add(n.toDouble());
              }
            }
            if (vector.isNotEmpty) {
              parsedEmbeddings.add(vector);
            }
          }

          embeddingsByUser[key] = parsedEmbeddings;
        });

        rawHealth.forEach((dynamic key, dynamic value) {
          if (key is! String || value is! num) {
            return;
          }
          healthByUser[key] = value.toInt();
        });

        _startController.add(
          SocketStartPayload(
            embeddingsByUser: embeddingsByUser,
            healthByUser: healthByUser,
          ),
        );
        break;
      default:
        break;
    }
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    return fallback;
  }

  Future<String> _getUsername() async {
    if (_username != null && _username!.trim().isNotEmpty) {
      return _username!;
    }

    final String stored = (await UserPreferencesManager.getUsername())?.trim() ?? '';
    _username = stored.isEmpty ? 'COMMANDER_01' : stored;
    return _username!;
  }

  Future<void> sendReady({required bool ready}) async {
    final String username = await _getUsername();
    final String message = jsonEncode(<String, dynamic>{
      'type': 'ready',
      'username': username,
      'ready': ready,
    });
    send(message);
  }

  Future<void> sendEmbedding({
    required List<dynamic> embeddings,
  }) async {
    final String username = await _getUsername();
    final String message = jsonEncode(<String, dynamic>{
      'type': 'embedding',
      'username': username,
      'embeddings': embeddings,
    });
    send(message);
  }

  void sendShoot({required String targetUser}) {
    final String message = jsonEncode(<String, dynamic>{
      'type': 'shoot',
      'user': targetUser,
    });
    send(message);
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
          try {
            handleData(data);
          } catch (error, stackTrace) {
            _messagesController.addError(error, stackTrace);
          }
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
        _messagesController.addError(
          StateError('Connection to server was lost.'),
        );
      },
    );

    try {
      await _getUsername();
      await channel.ready;
      _channel = channel;
      _isConnected = true;

      final String message = jsonEncode(<String, dynamic>{
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
    await _usersController.close();
    await _startController.close();
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
