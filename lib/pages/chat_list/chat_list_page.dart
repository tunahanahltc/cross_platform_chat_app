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
        _rooms = rooms;
        _loading = false;
      });
      debugPrintTokenAndRoom(); // <-- SETSTATE DIŞINA ÇAĞIRACAĞIZ!
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
              children: filteredRooms.map((room) => _buildRoomTile(room)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Oda kartı
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
            room['lastMessage']?.isNotEmpty == true ? room['lastMessage']! : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // 🆕 Burada saat + unread badge
          trailing: FutureBuilder<int>(
            future: _chatService.getUnreadCountManual(room['roomId']!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox();
              final unreadCount = snapshot.data!;

              if (unreadCount > 0) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      formatTime(room['lastMessageTimestamp']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount.toString(), // 🔥 Kaç tane unread varsa onu yazıyoruz!
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      formatTime(room['lastMessageTimestamp']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          onTap: () async {
            final timestamp = int.tryParse(room['lastMessageTimestamp'] ?? '0') ?? 0;
            await _chatService.saveLastReadTimestamp(room['roomId']!, timestamp);

            await Navigator.push( // <-- await ekledim
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  chatId: room['roomId']!,
                  chatTitle: room['name']!,
                ),
              ),
            );

            setState(() {}); // <-- geri döndüğünde çalışacak
          }
      ),
    );
  }
}

// PlatformButton Widget
class PlatformButton extends StatefulWidget {
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
  _PlatformButtonState createState() => _PlatformButtonState();
}

class _PlatformButtonState extends State<PlatformButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.9;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(widget.assetPath, width: 24, height: 24),
              const SizedBox(width: 8),
              Text(
                widget.platformName,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
