import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrl = 'http://64.226.102.154:8001';

/// Kullanıcı adını backend’e gönderip çıkış işlemi yapar.
/// Başarılıysa yerel oturum bilgisini temizler.
Future<void> logoutUser(String username) async {
  final uri = Uri.parse('$_baseUrl/logout');
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'user_name': username}),
  );

  if (response.statusCode == 200) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bsky_connected');
    // isterseniz diğer anahtarları da silebilirsiniz:
    // await prefs.remove('bsky_username');
  } else {
    final error = jsonDecode(response.body)['detail'] ?? response.body;
    throw Exception('Logout başarısız: $error');
  }
}
