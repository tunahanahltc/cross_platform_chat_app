import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class WhatsAppService {
  final String matrixBaseUrl;
  final String whatsappBotMxid;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  WhatsAppService({
    required this.matrixBaseUrl,
    required this.whatsappBotMxid,
  });

  Future<String> _readToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('Access token bulunamadı');
    return token;
  }

  Future<String> _getSelfId() async {
    final token = await _readToken();
    final resp = await http.get(
      Uri.parse('$matrixBaseUrl/_matrix/client/v3/account/whoami'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(resp.body);
    return data['user_id'];
  }

  Future<String> _getOrCreateRoomWithBot() async {
    final token = await _readToken();
    final selfId = await _getSelfId();

    // Check existing rooms
    final joinedResp = await http.get(
      Uri.parse('$matrixBaseUrl/_matrix/client/v3/joined_rooms'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final rooms = List<String>.from(
        jsonDecode(joinedResp.body)['joined_rooms']);

    for (final roomId in rooms) {
      final membersResp = await http.get(
        Uri.parse(
            '$matrixBaseUrl/_matrix/client/v3/rooms/$roomId/joined_members'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final members = (jsonDecode(membersResp.body)['joined'] as Map<
          String,
          dynamic>).keys.toList();
      if (members.contains(whatsappBotMxid)) {
        return roomId;
      }
    }

    // Create room if not found
    final createResp = await http.post(
      Uri.parse('$matrixBaseUrl/_matrix/client/v3/createRoom'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "invite": [whatsappBotMxid],
        "is_direct": true,
        "preset": "trusted_private_chat",
      }),
    );

    final data = jsonDecode(createResp.body);
    return data['room_id'];
  }

  Future<void> sendLoginCommand() async {
    final token = await _readToken();
    final roomId = await _getOrCreateRoomWithBot();
    await http.post(
      Uri.parse(
          '$matrixBaseUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "msgtype": "m.text",
        "body": "!wa login",
      }),
    );
    await Future.delayed(Duration(seconds: 2));
    await http.post(
      Uri.parse(
          '$matrixBaseUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "msgtype": "m.text",
        "body": "!wa login phone",
      }),
    );
  }

  Future<void> sendPhoneNumber(String phone) async {
    final token = await _readToken();
    final roomId = await _getOrCreateRoomWithBot();
    await http.post(
      Uri.parse(
          '$matrixBaseUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "msgtype": "m.text",
        "body": phone,
      }),
    );
  }

  Future<String?> getLastBotMessage() async {
    final token = await _readToken();
    final roomId = await _getOrCreateRoomWithBot();

    final resp = await http.get(
      Uri.parse('$matrixBaseUrl/_matrix/client/v3/rooms/$roomId/messages?dir=b&limit=10'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final messages = jsonDecode(resp.body)['chunk'];
    for (var msg in messages) {
      if (msg['sender'] != whatsappBotMxid || msg['type'] != 'm.room.message') continue;

      final content = msg['content'];
      final formatted = content['formatted_body'];
      final body = content['body'];

      final text = formatted ?? body ?? '';

      // Kod regex: hem `ABCD-1234` gibi harf-rakam içeren hem de <code>...</code> içinde
      final match = RegExp(r'<code>([\w\-]+)<\/code>').firstMatch(text);
      if (match != null) {
        return match.group(1); // örnek: S6VT-ZRWF
      }
    }

    return null;
  }

}
