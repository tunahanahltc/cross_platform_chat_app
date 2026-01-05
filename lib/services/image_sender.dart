// lib/services/image_sender.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';

import '../constants/constants.dart';

class ImageSenderService {
  static Future<bool> sendImage({
    required File imageFile,
    required String accessToken,
    required String roomId,
  }) async {
    try {
      final fileName = p.basename(imageFile.path);
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final fileBytes = await imageFile.readAsBytes();

      // 1. Upload to Synapse
      final uploadUrl = '$matrixBaseUrl/_matrix/media/v3/upload?filename=$fileName';
      final uploadResp = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': mimeType,
        },
        body: fileBytes,
      );

      if (uploadResp.statusCode != 200) {
        print('⛔ Upload failed: ${uploadResp.statusCode} ${uploadResp.body}');
        return false;
      }

      final contentUri = jsonDecode(uploadResp.body)['content_uri'];
      final encodedRoomId = Uri.encodeComponent(roomId);

      // 2. Send image message
      final sendUrl = '$matrixBaseUrl/_matrix/client/v3/rooms/$encodedRoomId/send/m.room.message?access_token=$accessToken';
      final imageMessage = {
        'msgtype': 'm.image',
        'body': fileName,
        'url': contentUri,
        'info': {
          'mimetype': mimeType,
          'size': await imageFile.length(),
        },
      };

      final sendResp = await http.post(
        Uri.parse(sendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(imageMessage),
      );

      if (sendResp.statusCode != 200) {
        print('⛔ Message send failed: ${sendResp.statusCode} ${sendResp.body}');
        return false;
      }

      print('✅ Fotoğraf başarıyla gönderildi.');
      return true;
    } catch (e) {
      print('🚨 Hata oluştu (image send): $e');
      return false;
    }
  }
}
