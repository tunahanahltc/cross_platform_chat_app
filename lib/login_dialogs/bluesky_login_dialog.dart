import 'package:flutter/material.dart';
import '../services/matrix_bluesky_service.dart';

class BlueskyLoginDialog extends StatefulWidget {
  /// BlueskyMatrixService örneği. İçinde `createDmRoomWithBluesky`, `sendMessage`
  /// ve `getLastBotMessage` metodlarının tanımlı olduğunu varsayıyoruz.
  final BlueskyMatrixService service;

  /// Synapse üzerindeki Bluesky bot hesabının Matrix ID’si (örneğin "@bsky_bot:your.homeserver").
  final String botMatrixId;

  const BlueskyLoginDialog({
    super.key,
    required this.service,
    required this.botMatrixId,
  });

  @override
  State<BlueskyLoginDialog> createState() => _BlueskyLoginDialogState();
}

class _BlueskyLoginDialogState extends State<BlueskyLoginDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _appPasswordController = TextEditingController();
  String? _botResponse;
  bool _loading = false;

  /// Burada ilk aşamada bot’la DM odası açılıyor. Elde edilen roomId üzerinden
  /// sırasıyla "!bsky login", domain, fullUsername ve appPassword gönderiliyor.
  /// En son da bot’un cevabı `getLastBotMessage(roomId)` ile alınıyor.
  Future<void> _startLogin() async {
    final fullUsername = _usernameController.text.trim();
    final appPassword = _appPasswordController.text.trim();

    if (fullUsername.isEmpty || appPassword.isEmpty) {
      setState(() {
        _botResponse = 'Lütfen kullanıcı adı ve app şifresini girin.';
      });
      return;
    }

    // Bluesky handle’ı "aaaa.bbbb.cccc" formatında, ama bridge bot önce domain'i istiyor:
    final parts = fullUsername.split('.');
    String domain;
    if (parts.length >= 2) {
      domain = parts.sublist(parts.length - 2).join('.');
    } else {
      domain = fullUsername;
    }

    setState(() {
      _loading = true;
      _botResponse = null;
    });

    try {
      // 1) Önce bot’la bir DM odası açalım:
      final roomId = await widget.service
          .createDmRoomWithBluesky(widget.botMatrixId);
      await Future.delayed(const Duration(seconds: 2));
      // 2) "!bsky login" komutunu gönder
      await widget.service.sendMessage(roomId, "!bsky login");
      await Future.delayed(const Duration(seconds: 2));

      // 3) Domain’i gönder (ör. "xxxxxx.yyyy")
      await widget.service.sendMessage(roomId,  "!bsky $domain");
      await Future.delayed(const Duration(seconds: 3));

      // 4) Full kullanıcı adını gönder (ör. "aaaaaaaaa.xxxxxx.yyyy")
      await widget.service.sendMessage(roomId, "!bsky $fullUsername");
      await Future.delayed(const Duration(seconds: 3));

      // 5) App şifresini gönder
      await widget.service.sendMessage(roomId, "!bsky $appPassword");

      // 6) Biraz bekleyip bot’un son cevabını alalım
      await Future.delayed(const Duration(seconds: 2));
      final lastBotMsg = await widget.service.getLastBotMessage(roomId);
      setState(() => _botResponse = lastBotMsg ?? 'Bot’tan cevap alınamadı.');
    } catch (e) {
      setState(() => _botResponse = 'Hata: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Bluesky Giriş"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_loading && _botResponse == null) ...[
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Kullanıcı Adı (örn: aaaaa.bbbb.cccc)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _appPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "App Şifresi",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_loading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
          ],
          if (_botResponse != null) ...[
            const SizedBox(height: 20),
            const Text(
              "Bot Cevabı:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              _botResponse!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
      actions: [
        if (!_loading && _botResponse == null) ...[
          TextButton(
            onPressed: _startLogin,
            child: const Text("Giriş Yap"),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Kapat"),
        ),
      ],
    );
  }
}
