

// lib/services/message_sync_service.dart

import 'dart:convert';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;
import '../constants/constants.dart';
import 'download_image.dart';
import 'local_storage.dart';

class MessageSyncService {
  static Future<List<types.Message>> pollAndSyncMessages({
    required String roomId,
    required String accessToken,
    required String currentUserId,
  }) async {

    final roomIdEnc = Uri.encodeComponent(roomId);
    final url = '$matrixBaseUrl/_matrix/client/v3/rooms/$roomIdEnc/messages?access_token=$accessToken&dir=b&limit=30';

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) return [];

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final events = (data['chunk'] as List).cast<Map<String, dynamic>>();
    final List<types.Message> newMessages = [];

    for (final e in events) {
      if (e['type'] != 'm.room.message') continue;
      final content = e['content'] as Map<String, dynamic>;
      final sender = e['sender'] as String;
      final msgType = content['msgtype'];
      final id = e['event_id'].toString();
      final createdAt = e['origin_server_ts'] as int? ?? 0;

      if (await LLocalStorage.messageExists(roomId, id)) continue;

      final author = types.User(id: sender);
      types.Message? msg;

      if (msgType == 'm.text') {
        msg = types.TextMessage(
          id: id,
          author: author,
          text: content['body'] ?? '',
          createdAt: createdAt,
        );
      } else if (msgType == 'm.audio' || msgType == 'm.file') {
        final mxcUrl = content['url'];
        if (mxcUrl != null) {
          msg = types.FileMessage(
            id: id,
            author: author,
            name: content['body'] ?? 'Dosya',
            size: content['info']?['size'] ?? 0,
            uri: mxcUrl,
            mimeType: content['info']?['mimetype'] ?? 'application/octet-stream',
            createdAt: createdAt,
          );
        }
      }
      else if (msgType == 'm.image') {
        final mxcUrl = content['url'];
        final filename = content['body'] ?? 'image.jpg';
        final mimeType = content['info']?['mimetype'] ?? 'image/jpeg';
        final size = content['info']?['size'] ?? 0;

        if (mxcUrl != null) {
          final downloadedPath = await ImageDownloader.downloadIfNeeded(
            mxcUrl,
            id,
            filename,
            accessToken,
          );

          if (downloadedPath != null) {
            msg = types.FileMessage(
              id: id,
              author: author,
              name: filename,
              size: size,
              uri: downloadedPath, // LOCAL path
              mimeType: mimeType,
              createdAt: createdAt,
            );
          }
        }
      }
      if (msg != null) {
        await LLocalStorage.saveSingleMessage(roomId, msg);
        if (sender != currentUserId) {
          newMessages.add(msg);
        }
      }
    }

    return newMessages;
  }
}
