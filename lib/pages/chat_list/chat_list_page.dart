// lib/pages/chat_list_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import '../../services/message_service.dart';
import '../../models/chat_entry.dart';

class ChatListPage extends StatelessWidget {
  final BlueskyMessageProvider provider;

  ChatListPage({Key? key, BlueskyMessageProvider? provider})
      : provider = provider ?? BlueskyMessageProvider(),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sohbetler'),
      ),
      body: StreamBuilder<List<ChatEntry>>(
        stream: provider.watchChatEntries(userEmail),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return const Center(child: Text('Hiç sohbet yok.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final chat = entries[i];

              // Platform adına göre asset seçimi:
              String assetPath;
              switch (chat.platform) {
                case 'bluesky':
                  assetPath = 'assets/bluesky-icon.png';
                  break;
                case 'telegram':
                  assetPath = 'assets/telegram-icon.png';
                  break;
                default:
                  assetPath = 'assets/default-icon.png';
              }

              final platformLabel = chat.platform[0].toUpperCase() + chat.platform.substring(1);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 16),
                  leading: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: Image.asset(
                          assetPath,
                          height: 32,
                          width: 32,
                        ),
                      ),
                      const SizedBox(height: 4,width: 10,),
                      Text(
                        chat.platform,
                        style: const TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                  title: Text(
                    chat.id,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          chatId: chat.id,
                          chatTitle: chat.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
