// lib/services/download_image.dart

import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constants/constants.dart';

class ImageDownloader {
  static final _storage = const FlutterSecureStorage();

  static String _mxcToUrl(String mxcUrl) {
    final cleaned = mxcUrl.replaceFirst('mxc://', '');
    return '$matrixBaseUrl/_matrix/media/v3/download/$cleaned';
  }

  static String _getFileExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    return (dotIndex >= 0 && dotIndex < filename.length - 1)
        ? filename.substring(dotIndex + 1)
        : '';
  }

  static Future<String?> downloadIfNeeded(
      String mxcUrl, String messageId, String filename, String accessToken) async {
    final ext = _getFileExtension(filename);
    final uniqueFilename = '$messageId${ext.isNotEmpty ? '.$ext' : ''}';

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$uniqueFilename';
    final file = File(filePath);

    if (await file.exists()) return filePath;

    final uri = Uri.parse('${_mxcToUrl(mxcUrl)}?access_token=$accessToken');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } else {
      print("⚠️ Görsel indirme hatası: ${response.statusCode} - ${response.body}");
      return null;
    }
  }
}
