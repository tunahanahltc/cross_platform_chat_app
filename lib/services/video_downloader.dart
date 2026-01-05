// lib/services/video_downloader.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/constants.dart'; // matrixBaseUrl için
import 'local_storage.dart'; // dosya kaydetmek için

class VideoDownloader {
  static Future<String?> downloadIfNeeded(
      String mxcUri,
      String messageId,
      String fileName,
      String accessToken,
      ) async {
    // Eğer localde dosya varsa direkt path'i döneriz
    final existing = await LLocalStorage.getDownloadedFilePath(messageId, fileName);
    if (existing != null) return existing;

    // mxc URI'yi gerçek URL'ye çevir
    final url = mxcUri.replaceFirst('mxc://', '$matrixBaseUrl/_matrix/media/r0/download/');

    // HTTP GET isteği
    final resp = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (resp.statusCode == 200) {
      // Videoyu local dosyaya kaydet
      final filePath = await LLocalStorage.saveFile(resp.bodyBytes, messageId, fileName);
      return filePath;
    } else {
      print('Video indirilemedi: ${resp.statusCode} - ${resp.body}');
      return null;
    }
  }
}
