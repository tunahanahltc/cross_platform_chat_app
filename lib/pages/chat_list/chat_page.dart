// lib/pages/chat_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/constants.dart';
import '../../models/image_message_widget.dart';
import '../../services/download_image.dart';
import '../../services/local_storage.dart';
import '../../services/message_sync_service.dart';
import '../../services/audio_sender.dart';
import '../../services/voice_recorder.dart';
import '../../services/audio_downloader.dart';
import '../../services/image_sender.dart';
import 'audio_message_builder.dart';
import '../../services/video_sender.dart';
import '../../models/video_message_widget.dart';
import '../../services/video_downloader.dart';


final String _matrixBaseUrl = matrixBaseUrl;

class ChatPage extends StatefulWidget {
  final String chatId;
  final String chatTitle;

  const ChatPage({Key? key, required this.chatId, required this.chatTitle})
      : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _storage = const FlutterSecureStorage();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<types.Message> _messages = [];
  late types.User _currentUser;
  String? _selfId;
  bool _loading = true;
  Timer? _poller;

  bool _isRecording = false;
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _recordDuration = "00:00";

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    if (_isRecording) _timer.cancel();
    super.dispose();
  }

  Future<String> _readToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('No access token');
    return token;
  }

  Future<void> _initializeChat() async {
    final token = await _readToken();
    // Doğru interpolasyon: çift tırnak ve $ işaretleri direkt kullanıldı
    final whoamiResp = await http.get(
      Uri.parse(
          '$_matrixBaseUrl/_matrix/client/v3/account/whoami?access_token=$token'),
    );
    if (whoamiResp.statusCode != 200) {
      throw Exception('Whoami failed: ${whoamiResp.body}');
    }
    final me = jsonDecode(whoamiResp.body);
    _selfId = me['user_id'];
    _currentUser = types.User(id: _selfId!);

    final storedMessages = await LLocalStorage.getMessages(widget.chatId);
    setState(() {
      _messages = storedMessages;
      _messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
      _loading = false; // Burada artık false olacak
    });

    _poller = Timer.periodic(const Duration(seconds: 2), (_) async {
      final newMsgs = await MessageSyncService.pollAndSyncMessages(
        roomId: widget.chatId,
        accessToken: token,
        currentUserId: _selfId!,
      );
      if (newMsgs.isNotEmpty) {
        setState(() {
          _messages = [...newMsgs, ..._messages];
          _messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
        });
      }
    });
  }

  void _handleSendAudioMessage(String path) async {
    final timestamp = DateTime
        .now()
        .millisecondsSinceEpoch;
    final localId = 'local_audio_$timestamp';

    setState(() {
      _messages.add(
        types.FileMessage(
          author: _currentUser,
          id: localId,
          name: 'Sesli Mesaj',
          size: 0,
          uri: path,
          mimeType: 'audio/ogg',
          createdAt: timestamp,
        ),
      );
      _messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    });

    await AudioSenderService.sendVoiceMessage(
      path,
      widget.chatId,
      _currentUser.id,
    );
  }

  void _handleSendImageMessage(File imageFile) async {
    final timestamp = DateTime
        .now()
        .millisecondsSinceEpoch;
    final localId = 'local_image_$timestamp';

    setState(() {
      _messages.add(
        types.FileMessage(
          author: _currentUser,
          id: localId,
          name: 'Görsel',
          size: imageFile.lengthSync(),
          uri: imageFile.path,
          mimeType: 'image/jpeg',
          createdAt: timestamp,
        ),
      );
      _messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    });

    final token = await _readToken();
    await ImageSenderService.sendImage(
      imageFile: imageFile,
      accessToken: token,
      roomId: widget.chatId,
    );
  }

  void _showVideoPicker() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Gönder'),
        content: const Text('Videoyu nereden seçmek istiyorsun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Kamera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Galeri'),
          ),
        ],
      ),
    );

    if (source == null) return;
    final picked = await picker.pickVideo(source: source);
    if (picked != null) {
      _handleSendVideoMessage(File(picked.path));
    }
  }

  void _handleSendVideoMessage(File videoFile) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final localId = 'local_video_$timestamp';

    setState(() {
      _messages.add(
        types.FileMessage(
          author: _currentUser,
          id: localId,
          name: 'Video',
          size: videoFile.lengthSync(),
          uri: videoFile.path,
          mimeType: 'video/mp4',
          createdAt: timestamp,
        ),
      );
      _messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    });

    final token = await _readToken();

    try {
      await VideoSenderService.sendVideo(
        videoFile: videoFile,
        accessToken: token,
        roomId: widget.chatId,
      );
    } catch (e) {
      print("Video gönderimi sırasında hata oluştu: $e");
    }
  }
  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Fotoğraf Gönder'),
              onTap: () {
                Navigator.pop(context);
                _showImagePicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video Gönder'),
              onTap: () {
                Navigator.pop(context);
                _showVideoPicker();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePicker() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Fotoğraf Gönder'),
            content: const Text('Fotoğrafı nereden seçmek istiyorsun?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                child: const Text('Kamera'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                child: const Text('Galeri'),
              ),
            ],
          ),
    );

    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      _handleSendImageMessage(File(picked.path));
    }
  }

  void _handleSendPressed(types.PartialText message) async {
    final token = await _readToken();
    final roomIdEnc = Uri.encodeComponent(widget.chatId);
    final timestamp = DateTime
        .now()
        .millisecondsSinceEpoch;
    final localId = 'local_$timestamp';

    setState(() {
      _messages.add(
        types.TextMessage(
          author: _currentUser,
          id: localId,
          text: message.text,
          createdAt: timestamp,
        ),
      );
      _messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    });

    await http.post(
      Uri.parse(
          '$_matrixBaseUrl/_matrix/client/v3/rooms/$roomIdEnc/send/m.room.message?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'msgtype': 'm.text', 'body': message.text}),
    );

    _textController.clear();
  }

  void _startRecording() async {
    setState(() {
      _isRecording = true;
    });
    _stopwatch = Stopwatch()
      ..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {});
    await VoiceRecorderService.startRecording();
  }

  void _stopRecording() async {
    _timer.cancel();
    _stopwatch.stop();
    setState(() => _isRecording = false);
    final path = await VoiceRecorderService.stopRecording();
    if (path != null) {
      _handleSendAudioMessage(path);
    }
  }

  Widget _buildImageMessage(types.FileMessage msg) {
    // Eğer uri yerel bir dosya yoluysa (başında “/” var), direkt göster:
    if (msg.uri.startsWith('/')) {
      return ImageMessageWidget(
        localPath: msg.uri,
        isMe: msg.author.id == _selfId,
      );
    }

    // Aksi halde, mxc://… şeklindeki uzaktaki resmi indir ve öyle göster:
    return FutureBuilder<String?>(
      future: _storage.read(key: 'access_token').then((token) {
        if (token == null) return null;
        return ImageDownloader.downloadIfNeeded(
          msg.uri,               // muhtemelen "mxc://..." şeklinde
          msg.id,
          msg.name ?? 'image.jpg',
          token,
        );
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return ImageMessageWidget(
          localPath: snapshot.data!,
          isMe: msg.author.id == _selfId,
        );
      },
    );
  }


  Widget _buildTextBubble(types.TextMessage msg) {
    final isMe = msg.author.id == _selfId;
    final time = msg.createdAt != null
        ? DateFormat('HH:mm').format(
        DateTime.fromMillisecondsSinceEpoch(msg.createdAt!))
        : '';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: isMe
            ? const EdgeInsets.only(left: 50, right: 2, bottom: 2, top: 2)
            : const EdgeInsets.only(left: 2, right: 50, bottom: 2, top: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isMe ? Colors.amber : Colors.grey.shade300,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 16 : 25),
            topRight: Radius.circular(isMe ? 25 : 16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment
              .start,
          children: [
            Text(msg.text,
                style: const TextStyle(color: Colors.black, fontSize: 16)),
            const SizedBox(height: 4),
            Text(time,
                style: const TextStyle(color: Colors.black54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMessage(types.FileMessage msg) {
    final isAudio = msg.mimeType?.startsWith('audio/') ?? false;
    final isVideo = msg.mimeType?.startsWith('video/') ?? false;

    // 🎧 Ses mesajı ise
    if (isAudio) {
      if (msg.uri.startsWith('/')) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: AudioMessageBubble(
            localPath: msg.uri,
            isMe: msg.author.id == _selfId,
          ),
        );
      }

      return AudioMessageWithDownloader(
        uri: msg.uri,
        msgId: msg.id,
        name: msg.name,
        isMe: msg.author.id == _selfId,
      );
    }

    // 🎥 Video mesajı ise
    if (isVideo) {
      if (msg.uri.startsWith('/')) {
        return VideoMessageWidget(
          localPath: msg.uri,
          isMe: msg.author.id == _selfId,
        );
      }

      return FutureBuilder<String?>(
        future: _storage.read(key: 'access_token').then((token) {
          if (token == null) return null;
          return VideoDownloader.downloadIfNeeded(
            msg.uri,
            msg.id,
            msg.name ?? 'video.mp4',
            token,
          );
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }
          return VideoMessageWidget(
            localPath: snapshot.data!,
            isMe: msg.author.id == _selfId,
          );
        },
      );
    }

    // 🎯 Ne ses ne video ise gösterme
    return const SizedBox.shrink();
  }

  Widget _buildMessageWidget(types.Message message) {
    if (message is types.TextMessage) {
      return _buildTextBubble(message);
    }
    if (message is types.FileMessage) {
      final isImage = message.mimeType?.startsWith('image/') ?? false;
      if (isImage) return _buildImageMessage(message);
      return _buildFileMessage(message);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        scrolledUnderElevation: 0.5,
        title: Text(widget.chatTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // Arka plan (isteğe bağlı)
          Positioned.fill(
            child: Image.asset(
              'assets/backgroundImage.png',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              // 🟢 Burada ListView.builder yer alıyor
              Expanded(
                child: ListView.builder(
                  key: const PageStorageKey<String>('chat_list'),
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];

                    return KeyedSubtree(
                      key: ValueKey(message.id), // 💥 Önemli! Her mesajı benzersiz yapar
                      child: _buildMessageWidget(message),
                    );
                  },
                ),
              ),


              // 🟢 Mesaj yazma alanı, ses/görsel gönderme butonları buraya gelecek
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                child: SafeArea(
                  child: StatefulBuilder(
                    builder: (context, setInnerState) {
                      return Row(
                        children: [
                          _isRecording
                              ? Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.mic,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Kayıt yapılıyor...",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () async {
                                      _timer.cancel();
                                      _stopwatch.stop();
                                      await VoiceRecorderService
                                          .stopRecording();
                                      setInnerState(() => _isRecording = false);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                              : Expanded(
                            child: TextField(
                              controller: _textController,
                              onChanged: (val) {
                                setState(() {}); // Buton ikonunu güncelle
                              },
                              onSubmitted: (txt) {
                                if (txt
                                    .trim()
                                    .isEmpty) return;
                                _handleSendPressed(
                                  types.PartialText(text: txt),
                                );
                              },
                              textInputAction: TextInputAction.send,
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Mesaj yazın...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.attach_file),
                            onPressed: _showMediaOptions,
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              final txt = _textController.text.trim();
                              if (txt.isNotEmpty) {
                                _handleSendPressed(types.PartialText(text: txt));
                                _textController.clear();
                                setState(() {}); // ikon güncelle
                              }
                            },
                            onLongPressStart: (_) {
                              final txt = _textController.text.trim();
                              if (txt.isEmpty) {
                                _startRecording();
                              }
                            },
                            onLongPressEnd: (_) {
                              final txt = _textController.text.trim();
                              if (txt.isEmpty) {
                                _stopRecording();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isRecording ? Colors.redAccent : Colors.amber, // 🔥
                                borderRadius: BorderRadius.circular(50),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                _textController.text.trim().isNotEmpty ? Icons.send : Icons.mic,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AudioMessageWithDownloader extends StatefulWidget {
  final String uri;
  final String msgId;
  final String name;
  final bool isMe;

  const AudioMessageWithDownloader({
    Key? key,
    required this.uri,
    required this.msgId,
    required this.name,
    required this.isMe,
  }) : super(key: key);

  @override
  State<AudioMessageWithDownloader> createState() =>
      _AudioMessageWithDownloaderState();
}

class _AudioMessageWithDownloaderState
    extends State<AudioMessageWithDownloader> {
  String? _localPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await AudioDownloader.downloadIfNeeded(
      widget.uri,
      widget.msgId,
      widget.name,
    );
    if (mounted) {
      setState(() {
        _localPath = path;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      );
    }

    if (_localPath == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: AudioMessageBubble(localPath: _localPath!, isMe: widget.isMe),
    );
  }
}