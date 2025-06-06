import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Bluesky – Matrix köprüsü üzerinden doğrudan mesaj göndermek ve
/// aynı zamanda bot’tan gelen en son cevabı okumak için güncellenmiş servis.
/// Synapse üzerinde kurulmuş bir “Bluesky bridge” (örneğin mautrix-bluesky benzeri) olduğunu varsayar.
/// [homeserverUrl] parametresi “https://your.homeserver.com” formatında olmalı.
class BlueskyMatrixService {
  final String homeserverUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  BlueskyMatrixService({required this.homeserverUrl});

  /// 1) Matrix’e login olup access_token’ı güvenli depolamaya yazar.
  Future<void> matrixLogin(String user, String password) async {
    final uri = Uri.parse('$homeserverUrl/_matrix/client/v3/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'm.login.password',
        'user': user,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Matrix login başarısız: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String;

    // Güvenli depolamaya yazıyoruz:
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'matrix_username', value: user);
    await _storage.write(key: 'matrix_password', value: password);
  }

  /// 2) Saklanan access_token’ı döner. Yoksa, saklı kullanıcı bilgileriyle yeniden giriş yapar.
  Future<String> _getAccessToken() async {
    String? token = await _storage.read(key: 'access_token');
    if (token != null) return token;

    // Eğer token yoksa, kullanıcı adı/şifre’yi çekip tekrar login olalım:
    final user = await _storage.read(key: 'matrix_username');
    final pass = await _storage.read(key: 'matrix_password');
    if (user == null || pass == null) {
      throw Exception('Matrix kimlik bilgileri bulunamadı!');
    }

    await matrixLogin(user, pass);
    token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('Matrix access token alınamadı!');
    return token;
  }

  /// 3) Bluesky hesabının Matrix ID’si (örn. "@alice_bsky:your.homeserver")
  ///    ile yeni bir DM odası açar ve roomId’yi döner.
  Future<String> createDmRoomWithBluesky(String blueskyMatrixId) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(
      '$homeserverUrl/_matrix/client/v3/createRoom?access_token=$token',
    );

    final body = {
      'invite': [blueskyMatrixId],
      'is_direct': true,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Bluesky DM odası oluşturma başarısız: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['room_id'] as String;
  }

  /// 4) Var olan bir roomId üzerinden mesaj gönderir.
  Future<void> sendMessage(String roomId, String message) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(
      '$homeserverUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message?access_token=$token',
    );

    final body = {
      'msgtype': 'm.text',
      'body': message,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Mesaj gönderme başarısız: ${response.body}');
    }
  }


  /// 6) Odayı “forget” eder: tamamen hafızadan siler.
  Future<void> forgetRoom(String roomId) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(
      '$homeserverUrl/_matrix/client/v3/rooms/$roomId/forget?access_token=$token',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Oda “forget” etme başarısız: ${response.body}');
    }
  }

  /// 7) Odayı bırakır (leave): odadan ayrılma işlemi yapar,
  ///    ancak geçmiş silinmez, sadece bu kullanıcı odadan çıkar.
  Future<void> leaveRoom(String roomId) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(
      '$homeserverUrl/_matrix/client/v3/rooms/$roomId/leave?access_token=$token',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Oda “leave” etme başarısız: ${response.body}');
    }
  }

  Future<String?> getLastBotMessage(String roomId) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(
      '$homeserverUrl/_matrix/client/v3/rooms/$roomId/messages'
          '?access_token=$token&dir=b&limit=1',
    );
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Son mesajı çekme hatası: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final chunk = data['chunk'] as List<dynamic>;
    if (chunk.isEmpty) return null;

    final lastEvent = chunk.first as Map<String, dynamic>;
    if (lastEvent['type'] == 'm.room.message') {
      final content = lastEvent['content'] as Map<String, dynamic>;
      return content['body'] as String?;
    }
    return null;
  }

  Future<void> logoutFromBluesky(String blueskyBotMxid) async {
    final token = await _getAccessToken();

    // 1. Odayı bul veya oluştur
    final roomId = await createDmRoomWithBluesky(blueskyBotMxid);

    // 2. !bsky list-logins komutunu gönder
    await http.post(
      Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "msgtype": "m.text",
        "body": "!bsky list-logins",
      }),
    );
    await Future.delayed(const Duration(seconds: 1));
    final resp = await http.get(
      Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/messages?dir=b&limit=10'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final messages = jsonDecode(resp.body)['chunk'];
    String? loginId;

    for (var msg in messages) {
      if (msg['sender'] != blueskyBotMxid || msg['type'] != 'm.room.message') continue;
      final content = msg['content'];
      final formatted = content['formatted_body'];
      final body = content['body'];
      final text = formatted ?? body ?? '';
      final match = RegExp(r'<code>([\w\-]+)<\/code>').firstMatch(text);
      if (match != null) {
        loginId = match.group(1);
        break;
      }
      final fallbackMatch = RegExp(r'Login ID:\s*([\w\-]+)').firstMatch(text);
      if (fallbackMatch != null) {
        loginId = fallbackMatch.group(1);
        break;
      }
    }
    if (loginId == null) {
      print("⚠️ Bluesky login ID bulunamadı.");
      return;
    }
    final logoutCommand = "!bsky logout $loginId";
    await http.post(
      Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "msgtype": "m.text",
        "body": logoutCommand,
      }),
    );
    print("✅ Bluesky çıkışı gönderildi: $logoutCommand");
  }

}
