import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class LiveSession extends ChangeNotifier {
  WebSocketChannel? _channel;
  String _roomCode = '';
  String _username = '';
  bool _connected = false;
  List<String> _participants = [];

  void Function(Map<String, dynamic> stroke)? onStroke;
  void Function()? onUndo;
  void Function()? onClear;
  void Function(String text)? onTextUpdate;
  void Function(String user)? onUserJoined;
  void Function(String user)? onUserLeft;

  bool get connected => _connected;
  String get roomCode => _roomCode;
  List<String> get participants => _participants;

  Future<String> createRoom() async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('http://100.115.250.84:8766/api/rooms/new'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close();
    _roomCode = jsonDecode(body)['code'];
    return _roomCode;
  }

  Future<bool> joinRoom(String code, String username) async {
    _roomCode = code;
    _username = username;
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://100.115.250.84:8766/ws/$code/$username'),
      );
      _connected = true;

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data) as Map<String, dynamic>;
          switch (msg['type']) {
            case 'init':
              _participants = List<String>.from(msg['users'] ?? []);
              notifyListeners();
              break;
            case 'stroke':
              onStroke?.call(msg['stroke']);
              break;
            case 'undo':
              onUndo?.call();
              break;
            case 'clear':
              onClear?.call();
              break;
            case 'text_update':
              onTextUpdate?.call(msg['text']);
              break;
            case 'user_joined':
              onUserJoined?.call(msg['user']);
              break;
            case 'user_left':
              onUserLeft?.call(msg['user']);
              break;
          }
        },
        onDone: () { _connected = false; notifyListeners(); },
        onError: (_) { _connected = false; notifyListeners(); },
      );
      notifyListeners();
      return true;
    } catch (e) {
      _connected = false;
      notifyListeners();
      return false;
    }
  }

  void sendStroke(Map<String, dynamic> stroke) {
    _channel?.sink.add(jsonEncode({"type": "stroke", "stroke": stroke}));
  }

  void sendUndo() {
    _channel?.sink.add(jsonEncode({"type": "undo"}));
  }

  void sendClear() {
    _channel?.sink.add(jsonEncode({"type": "clear"}));
  }

  void sendTextUpdate(String text) {
    _channel?.sink.add(jsonEncode({"type": "text_update", "text": text}));
  }

  void leaveRoom() {
    _channel?.sink.close();
    _connected = false;
    _participants.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    leaveRoom();
    super.dispose();
  }
}
