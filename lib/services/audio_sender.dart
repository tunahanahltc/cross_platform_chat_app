import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../constants/constants.dart';

class AudioSenderService {
  static final _storage = const FlutterSecureStorage();

  /// [onUploaded] ⇒ içerik sunucuya başarıyla yüklendiğinde çağrılır
  static Future<void> sendVoiceMessage(
      String filePath,
      String roomId,
      String senderId, {
        Function(String contentUri)? onUploaded,
      }) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final contentUri = await _uploadToMatrix(bytes, file.path.split('/').last);

    if (contentUri == null) return;

    // callback çalıştır
    if (onUploaded != null) {
      onUploaded(contentUri);
    }

    final accessToken = await getAccessToken();
    final uri = Uri.parse(
      '$matrixBaseUrl/_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/send/m.room.message?access_token=$accessToken',
    );

    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'msgtype': 'm.audio',
        'body': 'Voice message',
        'url': contentUri,
        'info': {
          'mimetype': 'audio/mpeg',
          'size': bytes.length,
        }
      }),
    );
  }

  static Future<String?> _uploadToMatrix(List<int> bytes, String filename) async {
    final accessToken = await getAccessToken();
    final uploadUri = Uri.parse(
        '$matrixBaseUrl/_matrix/media/v3/upload?filename=$filename&access_token=$accessToken');

    final response = await http.post(
      uploadUri,
      headers: {'Content-Type': 'audio/ogg'},
      body: bytes,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content_uri'];
    }

    return null;
  }

  static Future<String> getAccessToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('Access token bulunamadı!');
    return token;
  }
}
