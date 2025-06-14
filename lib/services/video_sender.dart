import 'dart:io';
import 'package:cross_platform_chat_app/constants/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VideoSenderService {
  static Future<void> sendVideo({
    required File videoFile,
    required String accessToken,
    required String roomId,
  }) async {
    final uploadUrl = Uri.parse('$matrixBaseUrl/_matrix/media/r0/upload?access_token=$accessToken');

    // ✅ Dosyayı byte olarak oku
    final bytes = await videoFile.readAsBytes();

    // ✅ Doğrudan raw binary olarak POST isteği at
    final response = await http.post(
      uploadUrl,
      headers: {
        'Content-Type': 'application/octet-stream', // ÖNEMLİ
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw Exception('Video yükleme başarısız: ${response.body}');
    }

    final jsonResponse = jsonDecode(response.body);
    final mxcUri = jsonResponse['content_uri'];
    if (mxcUri == null) {
      throw Exception('Matrix content_uri bulunamadı.');
    }

    // Videoyu odaya mesaj olarak gönder
    final sendUrl = Uri.parse('$matrixBaseUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message?access_token=$accessToken');
    final payload = {
      'msgtype': 'm.video',
      'body': videoFile.path.split('/').last, // dosya adı
      'url': mxcUri,
      'info': {
        'mimetype': 'video/mp4',
        'size': await videoFile.length(),
      }
    };

    final sendResponse = await http.post(
      sendUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (sendResponse.statusCode != 200) {
      throw Exception('Video mesajı gönderme başarısız: ${sendResponse.body}');
    }
  }
}
