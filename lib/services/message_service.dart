// lib/services/message_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_entry.dart';

/// Bluesky için Firestore tabanlı mesaj servisi
class BlueskyMessageProvider {
  static const _base = 'users_my_app';
  static const _platform = 'bluesky';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Kullanıcının altında kaç chat varsa, ChatEntry listesi olarak akıtır.
  Stream<List<ChatEntry>> watchChatEntries(String userEmail) {
    return _db
        .collectionGroup('messages')
        .snapshots()
        .map((snapshot) {
      final chatIds = <String>{};
      for (var doc in snapshot.docs) {
        final chatRef = doc.reference.parent.parent;
        final userRef = chatRef?.parent.parent;
        if (chatRef != null && userRef?.id == userEmail) {
          chatIds.add(chatRef.id);
        }
      }
      return chatIds
          .map((id) => ChatEntry(id: id, platform: _platform))
          .toList();
    });
  }

  /// Belirli bir chat’in içindeki mesajları dinler.
  Stream<List<BlueskyMessage>> watchMessages(
      String userEmail, String chatId) {
    return _db
        .collection(_base)
        .doc(userEmail)
        .collection(_platform)
        .doc(chatId)
        .collection('messages')
        .orderBy('sent_at', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return BlueskyMessage(
          id: doc.id,
          sender: data['sender'] as String? ?? '',
          receiver: data['receiver'] as String? ?? '',
          sentAt: DateTime.parse(data['sent_at'] as String),
          text: data['text'] as String? ?? '',
        );
      }).toList();
    });
  }
  Future<String?> getChatUserId(String userEmail, String chatId) async {
    try {
      final doc = await _db
          .collection(_base)
          .doc(userEmail)
          .collection(_platform)
          .doc(chatId)
          .get();

      if (!doc.exists) return null;
      // 1) .data() ile tüm map’i alıp
      final data = doc.data();
      return data?['userId'] as String?;
      // veya 2) doğrudan .get()
      // return doc.get('userId') as String?;
    } catch (e) {
      print('getChatUserId error: $e');
      return null;
    }
  }
}


/// Zaman damgası tipi tanımı
typedef Timestamp = dynamic;

/// Bluesky mesaj modeli
class BlueskyMessage {
  final String id;
  final String sender;
  final String receiver;
  final DateTime sentAt;
  final String text;

  BlueskyMessage({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.sentAt,
    required this.text,
  });
}
