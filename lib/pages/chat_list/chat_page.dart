// lib/pages/chat_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/message_service.dart';
import 'package:http/http.dart' as http;

class ChatPage extends StatefulWidget {
  final String chatId;       // Firestore chat document ID
  final String chatTitle;    // Başlık, örneğin kişi adı veya grup adı

  const ChatPage({
    Key? key,
    required this.chatId,
    required this.chatTitle,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<types.Message> _messages = [];
  late final BlueskyMessageProvider _provider;
  late final types.User _currentUser;
  types.User? _peerUser;
  String? _peerId;
  bool _loading = true;
  late final String _userEmail;
  static const _backendUrl = 'http://64.226.102.154:8010/send_message';

  @override
  void initState() {
    super.initState();
    _provider = BlueskyMessageProvider();

    // DB path için oturum açmış kullanıcı email'ini al
    final authUser = FirebaseAuth.instance.currentUser;
    _userEmail = authUser?.email ?? '';
    // Flutter Chat UI'da bizim kullanıcı olarak email kullanalım
    _currentUser = types.User(id: _userEmail);

    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Firestore'dan peer userId alanını al
    _peerId = await _provider.getChatUserId(_userEmail, widget.chatId);
    if (_peerId != null) {
      _peerUser = types.User(id: _peerId!);
    }

    // Mesaj akışını başlat
    _provider.watchMessages(_userEmail, widget.chatId).listen((msgs) {
      final chatMsgs = msgs.map((m) {
        // m.sender değerini peerId ile karşılaştır
        final isPeer = m.sender == _peerId;
        final types.User author;
        if (!isPeer) {
          author = (_peerUser ?? types.User(id: m.sender));
        } else {
          author = _currentUser;
        }
        return types.TextMessage(
          author: author,
          id: m.id,
          text: m.text,
          createdAt: m.sentAt.millisecondsSinceEpoch,
        );
      }).toList().reversed.toList();

      setState(() {
        _messages = chatMsgs;
        _loading = false;
      });
    });
  }

  Future<void> _sendMessageToBackend(String text) async {
    // Kullanıcının Bluesky kullanıcı adını SharedPreferences'tan al
    final prefs = await SharedPreferences.getInstance();
    final bskyUsername = prefs.getString('bsky_username') ?? '';
    if (bskyUsername.isEmpty) {
      throw Exception('BlueSky kullanıcı adı bulunamadı.');
    }

    final uri = Uri.parse(_backendUrl);
    final payload = {
      'user_name':     bskyUsername,
      'target_handle': widget.chatTitle,
      'text':          text,
    };

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      final err = body['detail'] ?? resp.body;
      throw Exception('Mesaj gönderilemedi: $err');
    }
  }

  void _handleSendPressed(types.PartialText message) {
    _sendMessageToBackend(message.text).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gönderme hatası: $e')),
      );
    });
    // Yerelde setState çağrısına gerek yok; Firestore akışı dinleniyor
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.chatTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Chat(
          messages: _messages,
          onSendPressed: _handleSendPressed,
          user: _currentUser,
          showUserAvatars: true,
          showUserNames: true,

          theme: DefaultChatTheme(
            backgroundColor: Colors.white54 ,
            inputBackgroundColor: Colors.white,
            inputTextColor: Colors.black,
            primaryColor: Colors.amber.shade800,
            secondaryColor: Colors.cyanAccent.shade200,
            inputContainerDecoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey, width: 1),
              borderRadius: BorderRadius.circular(25),
            ),            inputBorderRadius: BorderRadius.circular(60),
            inputMargin: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 50),
            inputPadding:
            const EdgeInsets.symmetric(horizontal: 30,vertical: 5),
          ),
          ),
    );
  }
}