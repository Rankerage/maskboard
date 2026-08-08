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

  // 실시간 콜백 - 포인트 단위로
  void Function(double x, double y, String user, String strokeId)? onRemotePoint;
  void Function(String strokeId, String user)? onRemoteStrokeEnd;
  void Function(String user)? onRemoteUndo;
  void Function(String user)? onRemoteClear;
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
              _sharedText = msg['text'] ?? '';
              final strokes = msg['strokes'] != null ? List<Map<String, dynamic>>.from(msg['strokes']) : <Map<String, dynamic>>[];
              onInit?.call(strokes, _sharedText);
              notifyListeners();
              break;
            case 'point':
              onRemotePoint?.call(
                (msg['x'] as num).toDouble(),
                (msg['y'] as num).toDouble(),
                msg['user'] ?? '',
                msg['strokeId'] ?? '',
              );
              break;
            case 'stroke_end':
              onRemoteStrokeEnd?.call(msg['strokeId'] ?? '', msg['user'] ?? '');
              break;
            case 'undo':
              onRemoteUndo?.call(msg['user'] ?? '');
              break;
            case 'clear':
              onRemoteClear?.call(msg['user'] ?? '');
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

  // 포인트 단위 전송
  void sendPoint(double x, double y, String strokeId, Color color, double width, String tool) {
    if (!_connected) return;
    _channel?.sink.add(jsonEncode({
      "type": "point",
      "x": x, "y": y,
      "strokeId": strokeId,
      "color": color.value,
      "width": width,
      "tool": tool,
    }));
  }

  void sendStrokeEnd(String strokeId) {
    if (!_connected) return;
    _channel?.sink.add(jsonEncode({"type": "stroke_end", "strokeId": strokeId}));
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
