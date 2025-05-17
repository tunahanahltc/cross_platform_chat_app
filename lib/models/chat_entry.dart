/// lib/models/chat_entry.dart
class ChatEntry {
  final String id;
  final String platform; // örn. 'bluesky', 'telegram', ...

  ChatEntry({
    required this.id,
    required this.platform,
  });
}
