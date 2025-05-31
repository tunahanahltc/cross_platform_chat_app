import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cross_platform_chat_app/constants/constants.dart';

class ChatListService {
  final String _matrixBaseUrl = matrixBaseUrl;
  final _storage = const FlutterSecureStorage();
  Timer? _poller;

  Future<void> startPolling(Function(List<Map<String, String>>) onUpdate) async {
    await _loadRooms(onUpdate);
    _poller = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _loadRooms(onUpdate),
    );
  }

  void dispose() {
    _poller?.cancel();
  }

  Future<String> _readToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('No access token');
    return token;
  }

  Future<String> _getSelfId() async {
    final token = await _readToken();
    final resp = await http.get(
      Uri.parse('$_matrixBaseUrl/_matrix/client/v3/account/whoami?access_token=$token'),
    );
    if (resp.statusCode != 200) throw Exception('Failed to fetch user ID');
    return jsonDecode(resp.body)['user_id'];
  }

  Future<void> _loadRooms(Function(List<Map<String, String>>) onUpdate) async {
    try {
      final token = await _readToken();
      final joinedResp = await http.get(
        Uri.parse('$_matrixBaseUrl/_matrix/client/v3/joined_rooms?access_token=$token'),
      );

      final ids = (jsonDecode(joinedResp.body)['joined_rooms'] as List).cast<String>();
      final selfId = await _getSelfId();

      final rooms = await Future.wait(ids.map((id) async {
        try {
          final name = await _fetchRoomName(id, selfId);
          final platform = await _getBridgeProtocol(id);
          final lastMessage = await _getLastMessagePreview(id);
          return {
            'roomId': id,
            'name': name,
            'platform': platform,
            'lastMessage': lastMessage,
          };

        } catch (e) {
          debugPrint('HATA (oda atlanıyor): $e');
          return {
            'roomId': id,
            'name': 'Bilinmeyen Oda',
            'platform': 'matrix',
          };
        }
      }));

      onUpdate(rooms);
    } catch (e) {
      debugPrint('TÜMÜNDE HATA: $e');
      onUpdate([]);
    }
  }

  Future<String> _fetchRoomName(String roomId, String selfId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);

    final nameResp = await http.get(
      Uri.parse('$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/state/m.room.name?access_token=$token'),
    );
    if (nameResp.statusCode == 200) {
      final name = jsonDecode(nameResp.body)['name'];
      if (name != null && name.isNotEmpty) return name;
    }

    final memResp = await http.get(
      Uri.parse('$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/joined_members?access_token=$token'),
    );
    if (memResp.statusCode == 200) {
      final joined = jsonDecode(memResp.body)['joined'] as Map<String, dynamic>;
      for (var uid in joined.keys) {
        if (uid == selfId) continue;
        final disp = joined[uid]['display_name'];
        return (disp != null && disp.isNotEmpty) ? disp : uid;
      }
    }

    return roomId;
  }

  Future<String> _getBridgeProtocol(String roomId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final url = '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/state?access_token=$token';

    try {
      final resp = await http.get(Uri.parse(url));

      if (resp.statusCode == 200) {
        final allStates = jsonDecode(resp.body) as List;
        for (final state in allStates) {
          if (state['type'] == 'm.bridge') {
            final proto = state['content']?['protocol'];
            if (proto != null && proto is Map && proto['id'] is String) {
              return proto['id']; // ← burada "twitter" gibi bir string döner
            }
          }
        }
      }
      return 'matrix'; // fallback
    } catch (e) {
      return 'matrix';
    }
  }
  Future<String> _getLastMessagePreview(String roomId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final url = '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/messages?access_token=$token&dir=b&limit=1';

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return '';
      final data = jsonDecode(resp.body);
      final events = (data['chunk'] as List).cast<Map<String, dynamic>>();
      final msgEvent = events.firstWhere(
            (e) => e['type'] == 'm.room.message' && e['content']?['msgtype'] == 'm.text',
        orElse: () => {},
      );
      if (msgEvent.isEmpty) return '';
      return msgEvent['content']?['body'] ?? '';
    } catch (e) {
      return '';
    }
  }


}
