import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 🌟 Saat formatlamak için gerekli
import '../../services/chat_list_service.dart';
import 'chat_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// debug icin

class ChatListPage extends StatefulWidget {
  final String searchQuery;

  const ChatListPage({Key? key, required this.searchQuery}) : super(key: key);

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  Function(List<Map<String, String>>)? _updateRooms;
  final ChatListService _chatService = ChatListService();
  List<Map<String, String>> _rooms = [];
  List<String> selectedPlatforms = [];
  List<String> allUnselectedPlatforms = ['telegram','twitter','instagramgo','whatsapp','bluesky'];
  bool _loading = true;

  final Map<String, String> platformAssets = {
    'telegram': 'assets/telegram.png',
    'twitter': 'assets/twitter.png',
    'instagramgo': 'assets/instagram.png',
    'whatsapp': 'assets/whatsapp.png',
    'bluesky': 'assets/bluesky-icon.png',
  };

  final Map<String, String> platformNames = {
    'telegram': 'Telegram',
    'twitter': 'Twitter',
    'instagramgo': 'Instagram',
    'whatsapp': 'WhatsApp',
    'bluesky': 'BlueSky',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _chatService.startPolling((rooms) {
      if (!mounted) return;
      setState(() {
        _rooms = rooms.map((room) => Map<String, String>.from(room)).toList();
        _loading = false;
      });
      _updateRooms = (newRooms) {
        setState(() {
          _rooms = newRooms.map((room) => Map<String, String>.from(room)).toList();
        });
      };
    });

  }

  // debug kodu
  Future<void> debugPrintTokenAndRoom() async {
    final storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    print('DEBUG - ACCESS TOKEN: $token');

    if (_rooms.isNotEmpty) {
      print('DEBUG - ROOM ID: ${_rooms.first['roomId']}');
    }
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  // 🆕 Timestamp formatlama
  String formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final milliseconds = int.parse(timestamp);
      final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
      return DateFormat('HH:mm').format(dateTime); // 🌟 Saat:Dakika formatı
    } catch (e) {
      return '';
    }
  }

  // Filtrelenmiş sohbetler
  List<Map<String, String>> get filteredRooms {
    var tempRooms = _rooms;

    if (selectedPlatforms.isNotEmpty) {
      tempRooms = tempRooms.where((room) => selectedPlatforms.contains(room['platform'])).toList();
    }

    if (widget.searchQuery.isNotEmpty) {
      tempRooms = tempRooms.where((room) {
        final name = room['name']?.toLowerCase() ?? '';
        final query = widget.searchQuery.toLowerCase();
        return name.contains(query);
      }).toList();
    }
    if(selectedPlatforms.isEmpty){
      tempRooms = tempRooms.where((room) => allUnselectedPlatforms.contains(room['platform'])).toList();

    }
    return tempRooms;
  }

  void togglePlatform(String platform) {
    setState(() {
      if (selectedPlatforms.contains(platform)) {
        selectedPlatforms.remove(platform);
      } else {
        selectedPlatforms.add(platform);
      }
    });
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
      body: Column(
        children: [
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: platformAssets.entries.map((entry) {
                final platform = entry.key;
                return PlatformButton(
                  platform: platform,
                  assetPath: entry.value,
                  platformName: platformNames[platform] ?? platform,
                  isSelected: selectedPlatforms.contains(platform),
                  onTap: () => togglePlatform(platform),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: filteredRooms.map(_buildRoomTile).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTile(Map<String, String> room) {
    final unreadCount = int.tryParse(room['unreadCount'] ?? '0') ?? 0;
    final time = formatTime(room['lastMessageTimestamp']);

    return Card(
      color: Colors.white,
      shadowColor: Colors.grey.shade200,
      elevation: 1.8,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: AssetImage(platformAssets[room['platform']] ?? ''),
          backgroundColor: Colors.white,
        ),
        title: Text(room['name'] ?? ''),
        subtitle: Text(
          room['lastMessage'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(time, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text(unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        onTap: () async {
          final lastEventId = room['lastEventId'] ?? '';
          await _chatService.markAsRead(roomId: room['roomId']!, eventId: lastEventId);

          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatPage(chatId: room['roomId']!, chatTitle: room['name']!),
          ));

          await _chatService.refreshNow((newRooms) {
            if (!mounted) return;
            setState(() {
              _rooms = newRooms;
            });
          });
        },
      ),
    );
  }
}

class PlatformButton extends StatelessWidget {
  final String platform;
  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;
  final String platformName;

  const PlatformButton({
    Key? key,
    required this.platform,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
    required this.platformName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(assetPath, width: 24, height: 24),
            const SizedBox(width: 8),
            Text(
              platformName,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
