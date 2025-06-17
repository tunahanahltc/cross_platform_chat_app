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

  // Gizlenen odalar ve son event ID’leri
  final Set<String> _hiddenRooms = {};
  final Map<String, String> _hiddenRoomsLastEvent = {};

  /// Başlat: her 5 saniyede bir _loadRooms çalıştırır
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

  /// Odayı geçici olarak gizler; yeni mesaj gelene kadar listede görünmez.
  Future<void> hideRoomUntilNewMessage(String roomId) async {
    _hiddenRooms.add(roomId);
    final info = await _getLastMessageInfo(roomId);
    _hiddenRoomsLastEvent[roomId] = info['event_id'] ?? '';
  }

  /// Sunucudan unuttur ve uygulamadan gizle
  Future<void> removeRoom(String roomId) async {
    // 1) Önce odadan ayrıl
    await _leaveRoomOnServer(roomId);

    // 2) Sonra unuttur
    await _forgetRoomOnServer(roomId);

    // 3) Uygulamada gizle
    _hiddenRooms.add(roomId);
    _hiddenRoomsLastEvent.remove(roomId);

    // 4) Kalıcı read marker kaydını temizle
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_event_id_$roomId');
  }

// Sunucudan leave için helper
  Future<void> _leaveRoomOnServer(String roomId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final uri = Uri.parse(
        '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/leave?access_token=$token'
    );
    final resp = await http.post(uri, headers: {'Content-Type':'application/json'});
    if (resp.statusCode != 200) {
      throw Exception('Failed to leave room: ${resp.body}');
    }
  }


  Future<void> _forgetRoomOnServer(String roomId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final uri = Uri.parse(
      '$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/forget?access_token=$token',
    );
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to forget room: ${response.body}');
    }
  }

  Future<void> _loadRooms(Function(List<Map<String, String>>) onUpdate) async {
    try {
      final token = await _readToken();
      final selfId = await _getSelfId();

      final syncResp = await http.get(
        Uri.parse('$_matrixBaseUrl/_matrix/client/v3/sync?timeout=0&access_token=$token'),
      );
      if (syncResp.statusCode != 200) throw Exception('Sync failed');

      final syncData = jsonDecode(syncResp.body);
      final joinedRooms = syncData['rooms']['join'] as Map<String, dynamic>;

      final rooms = await Future.wait(joinedRooms.entries.map((entry) async {
        final roomId = entry.key;

        // Gizli odaysa, event değişti mi kontrol et
        if (_hiddenRooms.contains(roomId)) {
          final info = await _getLastMessageInfo(roomId);
          if ((info['event_id'] ?? '') == _hiddenRoomsLastEvent[roomId]) {
            return null; // hâlâ gizli
          } else {
            // yeni mesaj gelmiş, tekrar göster
            _hiddenRooms.remove(roomId);
            _hiddenRoomsLastEvent.remove(roomId);
          }
        }

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

      final filtered = rooms.whereType<Map<String, String>>().toList();
      filtered.sort((a, b) {
        final tsA = int.tryParse(a['lastMessageTimestamp'] ?? '') ?? 0;
        final tsB = int.tryParse(b['lastMessageTimestamp'] ?? '') ?? 0;
        return tsB.compareTo(tsA);
      });

      onUpdate(filtered);
    } catch (e) {
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
    final resp = await http.get(
      Uri.parse('$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/state?access_token=$token'),
    );
    if (resp.statusCode == 200) {
      final allStates = jsonDecode(resp.body) as List;
      for (final state in allStates) {
        if (state['type'] == 'm.bridge') {
          final proto = state['content']?['protocol'];
          if (proto is Map && proto['id'] is String) return proto['id'];
        }
      }
    }
    return 'matrix';
  }

  Future<Map<String, String>> _getLastMessageInfo(String roomId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final resp = await http.get(
      Uri.parse('$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/messages'
          '?access_token=$token&dir=b&limit=1'),
    );
    if (resp.statusCode != 200) return {};
    final data = jsonDecode(resp.body);
    final events = (data['chunk'] as List).cast<Map<String, dynamic>>();

    final msgEvent = events.firstWhere(
          (e) =>
      e['type'] == 'm.room.message' &&
          e['content'] != null &&
          (e['content']['msgtype'] == 'm.text' ||
              e['content']['msgtype'] == 'm.image' ||
              e['content']['msgtype'] == 'm.file' ||
              e['content']['msgtype'] == 'm.audio' ||
              e['content']['msgtype'] == 'm.video'),
      orElse: () => {},
    );

    // Tür etiketi
    final msgType = msgEvent['content']?['msgtype'];
    String displayBody;
    switch (msgType) {
      case 'm.text':
        displayBody = msgEvent['content']?['body'] ?? '';
        break;
      case 'm.image':
        displayBody = '[Görsel]';
        break;
      case 'm.video':
        displayBody = '[Video]';
        break;
      case 'm.audio':
        displayBody = '[Ses]';
        break;
      case 'm.file':
        displayBody = '[Dosya]';
        break;
      default:
        displayBody = '';
    }

    return {
      'body': displayBody,
      'timestamp': msgEvent['origin_server_ts']?.toString() ?? '',
      'event_id': msgEvent['event_id'] ?? '',
    };
  }



  Future<int> _countUnreadMessages(String roomId, String lastReadEventId) async {
    final token = await _readToken();
    final encodedId = Uri.encodeComponent(roomId);
    final resp = await http.get(
      Uri.parse('$_matrixBaseUrl/_matrix/client/v3/rooms/$encodedId/messages?access_token=$token&dir=b&limit=50'),
    );
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
