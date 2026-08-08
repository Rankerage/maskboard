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
  String _sharedText = '';

  // 실시간 콜백
  void Function(Map<String, dynamic> stroke, String user)? onRemoteStroke;
  void Function()? onRemoteUndo;
  void Function()? onRemoteClear;
  void Function(String text, String user)? onRemoteTextUpdate;
  void Function(String user)? onUserJoined;
  void Function(String user)? onUserLeft;
  void Function(List<Map<String, dynamic>> strokes, String text)? onInit;

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
      _channel = WebSocketChannel.connect(Uri.parse('ws://100.115.250.84:8766/ws/$code/$username'));
      _connected = true;

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data) as Map<String, dynamic>;
          switch (msg['type']) {
            case 'init':
              _participants = List<String>.from(msg['users'] ?? []);
              final strokes = msg['strokes'] != null ? List<Map<String, dynamic>>.from(msg['strokes']) : <Map<String, dynamic>>[];
              _sharedText = msg['text'] ?? '';
              onInit?.call(strokes, _sharedText);
              notifyListeners();
              break;
            case 'stroke':
              onRemoteStroke?.call(msg['stroke'], msg['user'] ?? '');
              break;
            case 'undo':
              onRemoteUndo?.call();
              break;
            case 'clear':
              onRemoteClear?.call();
              break;
            case 'text_update':
              _sharedText = msg['text'] ?? '';
              onRemoteTextUpdate?.call(_sharedText, msg['user'] ?? '');
              notifyListeners();
              break;
            case 'user_joined':
              _participants = List<String>.from(msg['users'] ?? []);
              onUserJoined?.call(msg['user'] ?? '');
              notifyListeners();
              break;
            case 'user_left':
              _participants = List<String>.from(msg['users'] ?? []);
              onUserLeft?.call(msg['user'] ?? '');
              notifyListeners();
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
    if (!_connected) return;
    _channel?.sink.add(jsonEncode({"type": "stroke", "stroke": stroke}));
  }

  void sendUndo() {
    if (!_connected) return;
    _channel?.sink.add(jsonEncode({"type": "undo"}));
  }

  void sendClear() {
    if (!_connected) return;
    _channel?.sink.add(jsonEncode({"type": "clear"}));
  }

  void sendTextUpdate(String text) {
    if (!_connected) return;
    _sharedText = text;
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
