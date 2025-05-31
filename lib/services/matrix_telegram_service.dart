import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class WhatsappMatrixService {
  final String homeserverUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  WhatsappMatrixService({required this.homeserverUrl});
  /// Matrix login: fetches and stores access_token securely
  Future<void> matrixLogin(String user, String password) async {
    final response = await http.post(
      Uri.parse('$homeserverUrl/_matrix/client/v3/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'm.login.password',
        'user': user,
        'password': password,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Matrix login failed: ${response.body}');
    }
    final data = jsonDecode(response.body);
    await _storage.write(key: 'access_token', value: data['access_token']);
    await _storage.write(key: 'matrixUsername', value: user);
    await _storage.write(key: 'matrixPassword', value: password);
    final roomId = await createDmRoom(); // telegram botla oda oluştur
    await Future.delayed(Duration(seconds: 5));
    await forgetRoom(roomId); // 5 saniye sonra odayı sil
  }

  /// Ensure we have an access token, using saved credentials if needed
  Future<String> _getAccessToken() async {
    String? token = await _storage.read(key: 'access_token');
    if (token != null) return token;
    final user = await _storage.read(key: 'matrixUsername');
    final pass = await _storage.read(key: 'matrixPassword');
    if (user == null || pass == null) {
      throw Exception('No stored Matrix credentials');
    }
    await matrixLogin(user, pass);
    token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('Failed to obtain access token');
    return token;
  }



  /// Always create a fresh DM room with the telegram bot
  Future<String> createDmRoom() async {
    final token = await _getAccessToken();
    final createResp = await http.post(
      Uri.parse('$homeserverUrl/_matrix/client/v3/createRoom?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'invite': ['@telegrambot:localhost'],
        'is_direct': true,
      }),
    );
    if (createResp.statusCode != 200) {
      throw Exception('Create DM room failed: ${createResp.body}');
    }
    return jsonDecode(createResp.body)['room_id'] as String;
  }

  /// Forget (delete from account) a room
  Future<void> forgetRoom(String roomId) async {
    final token = await _getAccessToken();
    final resp = await http.post(
      Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/forget?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Forget room failed: ${resp.body}');
    }
  }
  /// Leave a room
  Future<void> leaveRoom(String roomId) async {
    final token = await _getAccessToken();
    final resp = await http.post(
      Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/leave?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Leave room failed: ${resp.body}');
    }
  }

  /// Send a text message to a room
  Future<void> sendMessage(String roomId, String message) async {
    final token = await _getAccessToken();
    final resp = await http.post(
      Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'msgtype': 'm.text', 'body': message}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Send message failed: ${resp.body}');
    }
  }

  /// Logout: clear stored token
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
  }
}
