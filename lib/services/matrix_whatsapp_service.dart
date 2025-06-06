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

  Future<String> _createRoomWithBot(String botMxid) async {
    final token = await _readToken();

    final createResp = await http.post(
      Uri.parse('$matrixBaseUrl/_matrix/client/v3/createRoom'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "invite": [botMxid],
        "is_direct": true,
        "preset": "trusted_private_chat",
      }),
    );

    if (createResp.statusCode != 200) {
      throw Exception("Oda oluşturulamadı: ${createResp.body}");
    }

    final data = jsonDecode(createResp.body);
    return data['room_id'];
  }


  Future<String> sendLoginCommand() async {
    final token = await _readToken();
    final roomId = await _createRoomWithBot(whatsappBotMxid);
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
    return roomId;
  }

  Future<void> sendPhoneNumber(String phone, String roomId) async {
    final token = await _readToken();
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

  Future<String?> getLastBotMessage(String roomId) async {
    final token = await _readToken();

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


  Future<void> logoutFromWhatsApp() async {
    final token = await _readToken();
    final roomId = await _createRoomWithBot(whatsappBotMxid);

    // 1. !wa list-logins komutu gönder
    await http.post(
      Uri.parse('$matrixBaseUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "msgtype": "m.text",
        "body": "!wa list-logins",
      }),
    );

    // 2. Botun cevap vermesi için 1 saniye bekle
    await Future.delayed(Duration(seconds: 1));

    // 3. Son mesajları çek
    final resp = await http.get(
      Uri.parse('$matrixBaseUrl/_matrix/client/v3/rooms/$roomId/messages?dir=b&limit=10'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final messages = jsonDecode(resp.body)['chunk'];
    String? loginId;

    for (var msg in messages) {
      if (msg['sender'] != whatsappBotMxid || msg['type'] != 'm.room.message') continue;

      final content = msg['content'];
      final formatted = content['formatted_body'];
      final body = content['body'];

      final text = formatted ?? body ?? '';

      // Hem plain hem HTML için <code>LOGINID</code> yakalama
      final match = RegExp(r'<code>([\w\-]+)<\/code>').firstMatch(text);
      if (match != null) {
        loginId = match.group(1);
        break;
      }

      // Yedek: düz metinden yakala (örneğin: Login ID: 123456)
      final fallbackMatch = RegExp(r'Login ID:\s*(\d+)').firstMatch(text);
      if (fallbackMatch != null) {
        loginId = fallbackMatch.group(1);
        break;
      }
    }

    if (loginId == null) {
      print("⚠️ Login ID bulunamadı.");
      return;
    }

    // 4. logout komutunu gönder
    final logoutCommand = "!wa logout $loginId";

    await http.post(
      Uri.parse('$matrixBaseUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "msgtype": "m.text",
        "body": logoutCommand,
      }),
    );

    print("✅ Çıkış komutu gönderildi: $logoutCommand");
  }

}
