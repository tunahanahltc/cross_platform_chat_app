import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

class ChatListService {
  final String _matrixBaseUrl = matrixBaseUrl;
  final _storage = const FlutterSecureStorage();
  Timer? _poller;

  Future<void> startPolling(Function(List<Map<String, String>>) onUpdate) async {
    await _loadRooms(onUpdate);
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _loadRooms(onUpdate));
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
    final resp = await http.get(Uri.parse('$_matrixBaseUrl/_matrix/client/v3/account/whoami?access_token=$token'));
    if (resp.statusCode != 200) throw Exception('Failed to fetch user ID');
    return jsonDecode(resp.body)['user_id'];
  }

  Future<void> _loadRooms(Function(List<Map<String, String>>) onUpdate) async {
    try {
      final token = await _readToken();
      final selfId = await _getSelfId();

      final syncResp = await http.get(Uri.parse('$_matrixBaseUrl/_matrix/client/v3/sync?timeout=0&access_token=$token'));
      if (syncResp.statusCode != 200) throw Exception('Sync failed');

      final syncData = jsonDecode(syncResp.body);
      final joinedRooms = syncData['rooms']['join'] as Map<String, dynamic>;

      final rooms = await Future.wait(joinedRooms.entries.map((entry) async {
        final roomId = entry.key;
        try {
          final name = await _fetchRoomName(roomId, selfId);
          final platform = await _getBridgeProtocol(roomId);
          final lastMessageInfo = await _getLastMessageInfo(roomId);
          final lastEventId = lastMessageInfo['event_id'] ?? '';
          final lastTimestamp = lastMessageInfo['timestamp'] ?? '';

          final storedEventId = await _getLastReadEventId(roomId);
          final unreadCount = await _countUnreadMessages(roomId, storedEventId);

          return {
            'roomId': roomId,
            'name': name.replaceAll(RegExp(r'\s*\(.*?\)'), ''),
            'platform': platform,
            'lastMessage': lastMessageInfo['body'] ?? '',
            'lastMessageTimestamp': lastTimestamp,
            'unreadCount': unreadCount.toString(),
            'lastEventId': lastEventId,
          };
        } catch (_) {
          return {
            'roomId': roomId,
            'name': 'Bilinmeyen Oda',
            'platform': 'matrix',
          };
        }
      }));

      rooms.sort((a, b) {
        final tsA = int.tryParse(a['lastMessageTimestamp'] ?? '') ?? 0;
        final tsB = int.tryParse(b['lastMessageTimestamp'] ?? '') ?? 0;
        return tsB.compareTo(tsA);
      });

      onUpdate(rooms);
    } catch (e) {
      onUpdate([]);
    }
  }

  Future<String> _fetchRoomName(String roomId, String selfId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);

    final nameResp = await http.get(Uri.parse('$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/state/m.room.name?access_token=$token'));
    if (nameResp.statusCode == 200) {
      final name = jsonDecode(nameResp.body)['name'];
      if (name != null && name.isNotEmpty) return name;
    }

    final memResp = await http.get(Uri.parse('$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/joined_members?access_token=$token'));
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
            if (proto is Map && proto['id'] is String) return proto['id'];
          }
        }
      }
    } catch (_) {}
    return 'matrix';
  }

  Future<Map<String, String>> _getLastMessageInfo(String roomId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final url = '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/messages?access_token=$token&dir=b&limit=1';

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return {};
      final data = jsonDecode(resp.body);
      final events = (data['chunk'] as List).cast<Map<String, dynamic>>();
      final msgEvent = events.firstWhere(
            (e) => e['type'] == 'm.room.message' && e['content']?['msgtype'] == 'm.text',
        orElse: () => {},
      );
      return {
        'body': msgEvent['content']?['body'] ?? '',
        'timestamp': msgEvent['origin_server_ts']?.toString() ?? '',
        'event_id': msgEvent['event_id'] ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  Future<int> _countUnreadMessages(String roomId, String lastReadEventId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final url = '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/messages?access_token=$token&dir=b&limit=50';

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return 0;
      final data = jsonDecode(resp.body);
      final events = (data['chunk'] as List).cast<Map<String, dynamic>>();

      int count = 0;
      for (final e in events) {
        if (e['type'] == 'm.room.message' && e['sender'] != await _getSelfId()) {
          if (e['event_id'] == lastReadEventId) break;
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveLastReadEventId(String roomId, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_event_id_$roomId', eventId);
  }

  Future<String> _getLastReadEventId(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_event_id_$roomId') ?? '';
  }

  Future<void> markAsRead({
    required String roomId,
    required String eventId,
  }) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final url = '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/read_markers?access_token=$token';

    final resp = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"m.read": eventId, "m.fully_read": eventId}),
    );

    if (resp.statusCode == 200) {
      await saveLastReadEventId(roomId, eventId);
    }
  }

  Future<void> refreshNow(Function(List<Map<String, String>>) onUpdate) async {
    await _loadRooms(onUpdate);
  }
}
