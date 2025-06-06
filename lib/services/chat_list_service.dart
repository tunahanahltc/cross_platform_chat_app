// lib/services/chat_list_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cross_platform_chat_app/constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ChatListService {
  final String _matrixBaseUrl = matrixBaseUrl;
  final _storage = const FlutterSecureStorage();
  Timer? _poller;

  Future<void> startPolling(Function(List<Map<String, String>>) onUpdate) async {
    await _loadRooms(onUpdate);
    _poller = Timer.periodic(
      const Duration(seconds: 5),
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
          final lastMessageInfo = await _getLastMessageInfo(id);
          final unreadCount = await _getUnreadCount(id); // 🆕 Unread çekiyoruz
          return {
            'roomId': id,
            'name': name,
            'platform': platform,
            'lastMessage': lastMessageInfo['body'] ?? '',
            'lastMessageTimestamp': lastMessageInfo['timestamp'] ?? '',
            'unreadCount': unreadCount.toString(), // 🆕
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

      // 🌟 Son mesaj tarihine göre en yeni üstte
      rooms.sort((a, b) {
        final tsA = int.tryParse(a['lastMessageTimestamp'] ?? '') ?? 0;
        final tsB = int.tryParse(b['lastMessageTimestamp'] ?? '') ?? 0;
        return tsB.compareTo(tsA);
      });

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
              return proto['id'];
            }
          }
        }
      }
      return 'matrix';
    } catch (e) {
      return 'matrix';
    }
  }

  Future<Map<String, String>> _getLastMessageInfo(String roomId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final url = '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/messages?access_token=$token&dir=b&limit=1';

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return {'body': '', 'timestamp': ''};
      final data = jsonDecode(resp.body);
      final events = (data['chunk'] as List).cast<Map<String, dynamic>>();
      final msgEvent = events.firstWhere(
            (e) => e['type'] == 'm.room.message' && e['content']?['msgtype'] == 'm.text',
        orElse: () => {},
      );
      if (msgEvent.isEmpty) return {'body': '', 'timestamp': ''};

      final body = msgEvent['content']?['body'] ?? '';
      final timestamp = msgEvent['origin_server_ts']?.toString() ?? '';

      return {'body': body, 'timestamp': timestamp};
    } catch (e) {
      return {'body': '', 'timestamp': ''};
    }
  }

  Future<int> _getUnreadCount(String roomId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final url = '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/unread_notifications?access_token=$token';

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return 0;
      final data = jsonDecode(resp.body);
      final count = data['notification_count'] ?? 0;
      return count;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAsRead(String roomId) async {
    try {
      final token = await _readToken();
      final encodedId = Uri.encodeComponent(roomId);
      final url = '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/read_markers?access_token=$token';

      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "m.fully_read": "",
          "m.read": ""
        }),
      );

      if (resp.statusCode != 200) {
        debugPrint('Mark as read failed: ${resp.body}');
      }
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  Future<void> saveLastReadTimestamp(String roomId, int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('read_ts_$roomId', timestamp);
  }

  Future<int> getLastReadTimestamp(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('read_ts_$roomId') ?? 0;
  }

  Future<int> getUnreadCountManual(String roomId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final url =
        '$_matrixBaseUrl/_matrix/client/r0/rooms/$encodedId/messages?access_token=$token&dir=b&limit=50';

    try {
      // 1. Kim olduğunu öğren
      final whoamiResp = await http.get(
        Uri.parse('$_matrixBaseUrl/_matrix/client/v3/account/whoami?access_token=$token'),
      );
      if (whoamiResp.statusCode != 200) return 0;
      final me = jsonDecode(whoamiResp.body);
      final selfId = me['user_id']; // Örn: @tunahan12:localhost

      // 2. Mesajları çek
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return 0;
      final data = jsonDecode(resp.body);
      final events = (data['chunk'] as List).cast<Map<String, dynamic>>();

      // 3. Son okunma zamanını al
      final prefs = await SharedPreferences.getInstance();
      final readTs = prefs.getInt('read_ts_$roomId') ?? 0;

      // 4. Yeni ve başkası tarafından atılmış mesajları say
      int unreadCount = 0;
      for (final event in events) {
        final sender = event['sender'];
        final timestamp = event['origin_server_ts'];

        if (timestamp != null && timestamp > readTs && sender != selfId) {
          unreadCount++;
        }
      }

      return unreadCount;
    } catch (e) {
      return 0;
    }
  }


}
