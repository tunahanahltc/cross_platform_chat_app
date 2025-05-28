// lib/pages/chat_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';

final String _matrixBaseUrl = matrixBaseUrl;

class ChatPage extends StatefulWidget {
  final String chatId;
  final String chatTitle;

  const ChatPage({Key? key, required this.chatId, required this.chatTitle}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _storage = const FlutterSecureStorage();
  List<types.Message> _messages = [];
  late types.User _currentUser;
  String? _selfId;
  bool _loading = true;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<String> _readToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('No access token');
    return token;
  }

  Future<void> _initializeChat() async {
    final token = await _readToken();
    final whoamiResp = await http.get(
      Uri.parse('$matrixBaseUrl/_matrix/client/v3/account/whoami?access_token=$token'),
    );
    if (whoamiResp.statusCode != 200) {
      throw Exception('Whoami failed: ${whoamiResp.body}');
    }
    final me = jsonDecode(whoamiResp.body) as Map<String, dynamic>;
    _selfId = me['user_id'] as String;
    _currentUser = types.User(id: _selfId!);

    await _loadMessages();
    _poller = Timer.periodic(const Duration(seconds: 2), (_) => _loadMessages());
  }

  Future<void> _loadMessages() async {
    final token = await _readToken();
    final roomIdEnc = Uri.encodeComponent(widget.chatId);
    final resp = await http.get(
      Uri.parse(
        '$matrixBaseUrl/_matrix/client/v3/rooms/$roomIdEnc/messages?access_token=$token&dir=b&limit=50',
      ),
    );
    if (resp.statusCode != 200) {
      throw Exception('Fetch messages failed: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final events = (data['chunk'] as List).cast<Map<String, dynamic>>();

    final msgs = events.where((e) => e['type'] == 'm.room.message').map((e) {
      final content = e['content'] as Map<String, dynamic>;
      if (content['msgtype'] != 'm.text') return null;
      final sender = e['sender'] as String;
      final author = sender == _selfId ? _currentUser : types.User(id: sender);
      return types.TextMessage(
        author: author,
        id: e['event_id'] as String? ?? e['origin_server_ts'].toString(),
        text: content['body'] as String? ?? '',
        createdAt: e['origin_server_ts'] as int? ?? 0,
      );
    }).whereType<types.TextMessage>().toList()
      ..sort((b, a) => a.createdAt!.compareTo(b.createdAt?? 0));

    setState(() {
      _messages = msgs;
      _loading = false;
    });
  }

  void _handleSendPressed(types.PartialText message) async {
    final token = await _readToken();
    final roomIdEnc = Uri.encodeComponent(widget.chatId);
    final resp = await http.post(
      Uri.parse(
        '$matrixBaseUrl/_matrix/client/v3/rooms/$roomIdEnc/send/m.room.message?access_token=$token',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'msgtype': 'm.text', 'body': message.text}),
    );
    if (resp.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: ${resp.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Chat(
        messages: _messages,
        onSendPressed: _handleSendPressed,
        user: _currentUser,
        showUserAvatars: true,
        showUserNames: true,
      ),
    );
  }
}
