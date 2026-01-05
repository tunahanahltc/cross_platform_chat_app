import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

class InstagramService {
  final String homeserverUrl;
  final String botMxid = '@instagrambot:localhost';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  InstagramService({required this.homeserverUrl});

  Future<String> _getAccessToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) return token;
    throw Exception('Matrix token bulunamadı');
  }

  Future<String> createDmRoom() async {
    final token = await _getAccessToken();
    final resp = await http.post(
      Uri.parse('$homeserverUrl/_matrix/client/v3/createRoom?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'invite': [botMxid], 'is_direct': true}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Oda oluşturulamadı: ${resp.body}');
    }
    return jsonDecode(resp.body)['room_id'];
  }

  Future<void> sendMessage(String roomId, String body) async {
    final token = await _getAccessToken();
    final resp = await http.post(
      Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/send/m.room.message?access_token=$token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'msgtype': 'm.text', 'body': body}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Mesaj gönderilemedi: ${resp.body}');
    }
  }

  Future<void> _cleanupRoom(String roomId) async {
    final token = await _getAccessToken();
    await http.post(Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/leave?access_token=$token'));
    await http.post(Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/forget?access_token=$token'));
  }

  Future<void> logout() async {
    final token = await _getAccessToken();
    final roomId = await createDmRoom();
    try {
      final syncResp = await http.get(Uri.parse('$homeserverUrl/_matrix/client/v3/sync?access_token=$token'));
      final fromToken = jsonDecode(syncResp.body)['next_batch'];

      await Future.delayed(const Duration(seconds: 2));
      await sendMessage(roomId, '!meta list-logins');
      await Future.delayed(const Duration(seconds: 2));

      String? loginId;
      for (int i = 0; i < 10; i++) {
        final msgResp = await http.get(
          Uri.parse('$homeserverUrl/_matrix/client/v3/rooms/$roomId/messages?access_token=$token&dir=f&limit=20&from=$fromToken'),
        );
        final events = jsonDecode(msgResp.body)['chunk'] as List;
        for (var event in events) {
          if (event['type'] != 'm.room.message') continue;
          final content = event['content'];
          final formatted = content['formatted_body'];
          final text = formatted ?? content['body'];
          if (text != null && RegExp(r'<code>\d{10,}<\/code>').hasMatch(text)) {
            final match = RegExp(r'<code>(\d{10,})<\/code>').firstMatch(text);
            loginId = match?.group(1);
            showToast('Instagram login ID: $loginId');
            break;
          }
        }
        if (loginId != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      if (loginId != null) {
        await sendMessage(roomId, '!instagram logout $loginId');
        showToast('Logout gönderildi: $loginId');
      } else {
        showToast('Login ID bulunamadı.');
      }
      // 4. Çıkış komutunu gönder
      await sendMessage(roomId, '!meta logout $loginId');
      showToast('Çıkış komutu gönderildi: $loginId');
    } catch (e) {
      showToast('Hata: $e');
    } finally {
      await _cleanupRoom(roomId);
    }
  }

  Future<bool> connect(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InstagramLoginDialog(service: this),
    );
    return result ?? false;
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

class _InstagramLoginDialog extends StatefulWidget {
  final InstagramService service;
  const _InstagramLoginDialog({Key? key, required this.service}) : super(key: key);

  @override
  State<_InstagramLoginDialog> createState() => _InstagramLoginDialogState();
}

class _InstagramLoginDialogState extends State<_InstagramLoginDialog> {
  late InAppWebViewController _webController;
  bool _busy = false;
  bool _sent = false;
  String? _roomId;

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
              ),
              initialUrlRequest: URLRequest(url: WebUri('https://www.instagram.com/accounts/login/')),
              onLoadStop: (ctrl, url) async {
                if (_busy || _sent || url == null) return;
                final cookies = await CookieManager.instance().getCookies(url: url);
                final sessionid = cookies.firstWhere((c) => c.name == 'sessionid', orElse: () => Cookie(name: '', value: '')).value;
                final csrftoken = cookies.firstWhere((c) => c.name == 'csrftoken', orElse: () => Cookie(name: '', value: '')).value;
                final mid = cookies.firstWhere((c) => c.name == 'mid', orElse: () => Cookie(name: '', value: '')).value;
                final igDid = cookies.firstWhere((c) => c.name == 'ig_did', orElse: () => Cookie(name: '', value: '')).value;
                final dsUserId = cookies.firstWhere((c) => c.name == 'ds_user_id', orElse: () => Cookie(name: '', value: '')).value;

                if ([sessionid, csrftoken, mid, igDid, dsUserId].every((v) => v.isNotEmpty)) {
                  _sent = true;
                  await _performMatrixExchange(sessionid, csrftoken, mid, igDid, dsUserId);
                }

              },
            ),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (!_busy)
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _performMatrixExchange(String sessionid, String csrftoken, String mid, String igDid, String dsUserId) async {
    setState(() => _busy = true);
    try {
      _roomId ??= await widget.service.createDmRoom();
      await widget.service.sendMessage(_roomId!, '!meta login');
      await Future.delayed(const Duration(seconds: 2));

      final jsonBody = jsonEncode({
        'sessionid': sessionid,
        'csrftoken': csrftoken,
        'mid': mid,
        'ig_did': igDid,
        'ds_user_id': dsUserId,
      });

      await widget.service.sendMessage(_roomId!, '!meta $jsonBody');
      await Future.delayed(const Duration(seconds: 2));
      await widget.service._cleanupRoom(_roomId!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

}
