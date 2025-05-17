import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ChatStorage {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cached_chats.json');
  }

  static Future<void> saveChats(List<Map<String, dynamic>> chats) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(chats));
  }

  static Future<List<Map<String, dynamic>>> readChats() async {
    try {
      final file = await _getFile();
      final content = await file.readAsString();
      final List decoded = jsonDecode(content);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
