import 'dart:async';
import 'dart:convert';
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
    final resp = await http.get(Uri.parse('$_matrixBaseUrl/_matrix/client/v3/account/whoami?access_token=$token'));
    if (resp.statusCode != 200) throw Exception('Failed to fetch user ID');
    return jsonDecode(resp.body)['user_id'];
  }

  Future<void> _loadRooms(Function(List<Map<String, String>>) onUpdate) async {
    try {
      final token = await _readToken();
      final joinedResp = await http.get(Uri.parse('$_matrixBaseUrl/_matrix/client/v3/joined_rooms?access_token=$token'));
      final ids = (jsonDecode(joinedResp.body)['joined_rooms'] as List).cast<String>();
      final selfId = await _getSelfId();

      final rooms = await Future.wait(ids.map((id) async {
        final name = await _fetchRoomName(id, selfId);
        return {'roomId': id, 'name': name};
      }));

      onUpdate(rooms);
    } catch (_) {
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
}
