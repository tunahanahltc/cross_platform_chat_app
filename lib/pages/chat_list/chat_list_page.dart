import 'package:flutter/material.dart';
import '../../services/chat_list_service.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatListService _chatService = ChatListService();
  List<Map<String, String>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _chatService.startPolling((rooms) {
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_rooms.isEmpty) {
      return const Scaffold(body: Center(child: Text('Henüz hiçbir sohbet yok.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sohbetler')),
      body: ListView(
        children: _rooms.map((room) => _buildRoomTile(room)).toList(),
      ),
    );
  }

  Widget _buildRoomTile(Map<String, String> room) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.chat)),
        title: Text(room['name']!),
        subtitle: Text(room['roomId']!),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                chatId: room['roomId']!,
                chatTitle: room['name']!,
              ),
            ),
          );
        },
      ),
    );
  }
}
