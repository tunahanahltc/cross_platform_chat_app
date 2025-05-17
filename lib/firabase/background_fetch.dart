import 'package:cloud_firestore/cloud_firestore.dart';
import 'firabase.dart';
final username = 'tunahanahlatci_bsky_social';

Future<void> backgroundTask() async {
  try {
    final firestore = FirebaseFirestore.instance;

    final List<String> chatIds = [
      '3loblhuzgio2z',
      // Diğer chat ID'leri...
    ];

    List<Map<String, dynamic>> allMessages = [];

    for (final chatId in chatIds) {
      final messagesSnapshot = await firestore
          .collection('users_my_app')
          .doc(username)
          .collection('bluesky')
          .doc('chats')
          .collection(chatId)
          .get();

      for (final doc in messagesSnapshot.docs) {
        final msg = doc.data();
        msg['chat_id'] = chatId;
        msg['message_id'] = doc.id;

        // 🔥 LOGCAT'E YAZDIR
        print('📨 Mesaj (chat: $chatId): $msg');

        allMessages.add(msg);
      }
    }

    await ChatStorage.saveChats(allMessages);
    print('✅ ${allMessages.length} mesaj yerel dosyaya kaydedildi');
  } catch (e) {
    print('❗ Firebase okuma hatası: $e');
  }
}
