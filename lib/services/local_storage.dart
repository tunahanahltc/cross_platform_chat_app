// lib/services/local_storage.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:path_provider/path_provider.dart';

class LLocalStorage {
  static Future<String> _getRoomFilePath(String roomId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/messages_$roomId.json';
  }

  static Future<List<types.Message>> getMessages(String roomId) async {
    final path = await _getRoomFilePath(roomId);
    final file = File(path);
    if (!file.existsSync()) return [];

    final content = await file.readAsString();
    final decoded = jsonDecode(content) as List<dynamic>;
    return decoded.map((m) => _decodeMessage(m)).whereType<types.Message>().toList();
  }

  static Future<void> saveMessages(String roomId, List<types.Message> messages) async {
    final existing = await getMessages(roomId);
    final all = {...{for (var m in existing) m.id!: m}, ...{for (var m in messages) m.id!: m}};
    final jsonList = all.values.map(_encodeMessage).toList();

    final path = await _getRoomFilePath(roomId);
    final file = File(path);
    await file.writeAsString(jsonEncode(jsonList));
  }

  static Future<void> saveSingleMessage(String roomId, types.Message message) async {
    await saveMessages(roomId, [message]);
  }

  static Future<bool> messageExists(String roomId, String messageId) async {
    final messages = await getMessages(roomId);
    return messages.any((m) => m.id == messageId);
  }

  static Map<String, dynamic> _encodeMessage(types.Message msg) {
    if (msg is types.TextMessage) {
      return {
        'id': msg.id,
        'type': 'text',
        'text': msg.text,
        'createdAt': msg.createdAt,
        'author': msg.author.id,
      };
    } else if (msg is types.FileMessage) {
      return {
        'id': msg.id,
        'type': 'file',
        'name': msg.name,
        'uri': msg.uri,
        'mimeType': msg.mimeType,
        'size': msg.size,
        'createdAt': msg.createdAt,
        'author': msg.author.id,
      };
    }
    return {}; // unsupported
  }

  static types.Message? _decodeMessage(dynamic data) {
    if (data['type'] == 'text') {
      return types.TextMessage(
        id: data['id'],
        text: data['text'],
        createdAt: data['createdAt'],
        author: types.User(id: data['author']),
      );
    } else if (data['type'] == 'file') {
      return types.FileMessage(
        id: data['id'],
        name: data['name'],
        uri: data['uri'],
        mimeType: data['mimeType'],
        size: data['size'],
        createdAt: data['createdAt'],
        author: types.User(id: data['author']),
      );
    }
    return null;
  }
}

