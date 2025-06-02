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
      if (!mounted) return;
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
      backgroundColor: Colors.white,

      body: ListView(
        children: _rooms.map((room) => _buildRoomTile(room)).toList(),
      ),
    );
  }

  Widget _buildRoomTile(Map<String, String> room) {
    Widget leading;
    switch (room['platform']) {
      case 'telegram':
        leading = const CircleAvatar(
          backgroundImage: AssetImage('assets/telegram.png'),
          backgroundColor: Colors.white,
        );
        break;
      case 'twitter':
        leading = const CircleAvatar(
          backgroundImage: AssetImage('assets/twitter.png'),
          backgroundColor: Colors.white,
        );
        break;
      case 'bluesky':
        leading = const CircleAvatar(
          backgroundImage: AssetImage('assets/bluesky-icon.png'),
          backgroundColor: Colors.white,
        );
        break;
      case 'instagramgo':
        leading = const CircleAvatar(
          backgroundImage: AssetImage('assets/instagram.png'),
          backgroundColor: Colors.white,
        );
        break;
      case 'whatsapp':
        leading = const CircleAvatar(
          backgroundImage: AssetImage('assets/whatsapp.png'),
          backgroundColor: Colors.white,
        );
        break;
      case 'matrix':
      default:
        leading = const CircleAvatar(
          child: Icon(Icons.message),
        );
    }

    return Card(
      color: Colors.white,
      shadowColor: Colors.grey.shade200,
      elevation: 1.8,

      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: leading,
        title: Text(room['name'] ?? ''),
        subtitle: Text(
          room['lastMessage']?.isNotEmpty == true
              ? room['lastMessage']!
              : '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
