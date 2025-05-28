// twitter_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

/// Twitter bridge için genel servis sınıfı.
class TwitterService {
  final String homeserverUrl;
  final String botMxid = '@twitterbot:localhost';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  TwitterService({required this.homeserverUrl});

  /// Mevcut access_token'ı alır veya hata atar.
  Future<String> _getAccessToken() async {
    String? token = await _storage.read(key: 'access_token');
    if (token != null) return token;
    final user = await _storage.read(key: 'matrixUsername');
    final pass = await _storage.read(key: 'matrixPassword');
    if (user == null || pass == null) {
      throw Exception('Kaydedilmiş Matrix kimlik bilgisi yok');
    }
    throw Exception('Matrix token bulunamadı');
  }

  /// Yeni bir DM odası oluşturur.
  Future<String> createDmRoom() async {
    final token = await _getAccessToken();
    debugPrint('[TwitterService] createDmRoom token: $token');
    final resp = await http.post(
      Uri.parse(
          '$homeserverUrl/_matrix/client/v3/createRoom?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'invite': [botMxid], 'is_direct': true}),
    );
    debugPrint('[TwitterService] createRoom response: ${resp.statusCode} ${resp
        .body}');
    if (resp.statusCode != 200) {
      throw Exception('Oda oluşturulamadı: ${resp.body}');
    }
    final roomId = jsonDecode(resp.body)['room_id'] as String;
    debugPrint('[TwitterService] Oluşan roomId: $roomId');
    return roomId;
  }

  /// Odayı terk eder ve siler.
  Future<void> _cleanupRoom(String roomId) async {
    final token = await _getAccessToken();
    await http.post(
      Uri.parse(
          '$homeserverUrl/_matrix/client/v3/rooms/$roomId/leave?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
    );
    await http.post(
      Uri.parse(
          '$homeserverUrl/_matrix/client/v3/rooms/$roomId/forget?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
    );
    debugPrint('[TwitterService] Room $roomId cleaned up');
  }

  /// Mesaj gönderir.
  Future<void> sendMessage(String roomId, String body) async {
    final token = await _getAccessToken();
    debugPrint('[TwitterService] sendMessage to $roomId: $body');
    final resp = await http.post(
      Uri.parse(
          '$homeserverUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'msgtype': 'm.text', 'body': body}),
    );
    debugPrint('[TwitterService] sendMessage response: ${resp.statusCode} ${resp
        .body}');
    if (resp.statusCode != 200) {
      throw Exception('Mesaj gönderilemedi: ${resp.body}');
    }
  }

  /// Twitter login akışını başlatır.
  Future<bool> connect(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TwitterLoginDialog(service: this),
    );
    return result ?? false;
  }

  Future<void> logout() async {
    final token = await _getAccessToken();
    final roomId = await createDmRoom();

    try {
      // 1. Sync → fromToken al
      final syncResp = await http.get(
        Uri.parse('$homeserverUrl/_matrix/client/v3/sync?access_token=$token'),
      );
      final fromToken = jsonDecode(syncResp.body)['next_batch'];

      // 2. Bot gelsin
      await Future.delayed(const Duration(seconds: 2));
      await sendMessage(roomId, '!twitter list-logins');

      // 3. Cevap bekle
      await Future.delayed(const Duration(seconds: 2));

      String? loginId;
      for (int i = 0; i < 10; i++) {
        final msgResp = await http.get(
          Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/messages'
              '?access_token=$token&dir=f&limit=20&from=$fromToken'),
        );

        final events = jsonDecode(msgResp.body)['chunk'] as List;
        for (var event in events) {
          if (event['type'] != 'm.room.message') continue;

          final content = event['content'];
          final msgtype = content['msgtype'];
          final formatted = content['formatted_body'];
          final body = content['body'];
          final text = formatted ?? body;

          if ((msgtype == 'm.text' || msgtype == 'm.notice') &&
              text != null &&
              RegExp(r'<code>\d{10,}<\/code>').hasMatch(text)) {
            final match = RegExp(r'<code>(\d{10,})<\/code>').firstMatch(text);
            loginId = match?.group(1);
            showToast('Login ID bulundu: $loginId');
            break;
          }
        }

        if (loginId != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      if (loginId == null) {
        showToast('Login ID bulunamadı.');
        return;
      }

      // 4. Çıkış komutunu gönder
      await sendMessage(roomId, '!twitter logout $loginId');
      showToast('Çıkış komutu gönderildi: $loginId');
    } catch (e) {
      showToast('Hata: $e');
    } finally {
      await _cleanupRoom(roomId);
    }
  }



  void showToast(String mesaj) {
    Fluttertoast.showToast(
      msg: mesaj,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }


}
/// Gömülü WebView dialog'u
class _TwitterLoginDialog extends StatefulWidget {
  final TwitterService service;
  const _TwitterLoginDialog({Key? key, required this.service}) : super(key: key);

  @override
  State<_TwitterLoginDialog> createState() => _TwitterLoginDialogState();
}

class _TwitterLoginDialogState extends State<_TwitterLoginDialog> {
  late InAppWebViewController _webController;
  bool _busy = false;
  bool _sent = false;
  String? _roomId;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.8,
        child: Stack(
          children: [
            InAppWebView(
              onWebViewCreated: (ctrl) => _webController = ctrl,
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                thirdPartyCookiesEnabled: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
              ),
              initialUrlRequest: URLRequest(url: WebUri('https://twitter.com/login')),
              onLoadStop: (ctrl, url) async {
                if (_busy || _sent || url == null) return;

                final cookies = await CookieManager.instance().getCookies(url: url);
                for (var c in cookies) {
                  debugPrint('Cookie: ${c.name} = ${c.value}');
                }

                final ct0 = cookies.firstWhere((c) => c.name == 'ct0', orElse: () => Cookie(name: '', value: '')).value;
                final auth = cookies.firstWhere((c) => c.name == 'auth_token', orElse: () => Cookie(name: '', value: '')).value;

                if (ct0.isNotEmpty && auth.isNotEmpty) {
                  _sent = true;
                  await _performMatrixExchange(ct0, auth);
                }
              },
            ),
            if (_busy)
              const Center(child: CircularProgressIndicator()),
            if (!_busy)
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _performMatrixExchange(String ct0, String auth) async {
    setState(() => _busy = true);
    try {
      _roomId ??= await widget.service.createDmRoom();
      await widget.service.sendMessage(_roomId!, '!twitter login');
      await Future.delayed(const Duration(seconds: 2));
      final jsonBody = jsonEncode({'ct0': ct0, 'auth_token': auth});
      await widget.service.sendMessage(_roomId!, '!twitter $jsonBody');
      await Future.delayed(const Duration(seconds: 2)); // çerezden sonra 2 sn bekle
      await widget.service._cleanupRoom(_roomId!);
      if (mounted) Navigator.of(context).pop(true); // otomatik kapanış
    } catch (e) {
      debugPrint('Matrix exchange hata: $e');
      if (mounted) Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }
}
