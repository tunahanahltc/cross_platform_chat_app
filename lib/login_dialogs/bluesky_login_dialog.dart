import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/matrix_bluesky_service.dart';
import '../../theme/app_colors.dart';

class BlueskyLoginDialog extends StatefulWidget {
  final BlueskyMatrixService service;
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
  final TextEditingController _usernameController    = TextEditingController();
  final TextEditingController _appPasswordController = TextEditingController();
  String? _botResponse;
  bool   _loading     = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _appPasswordController.dispose();
    super.dispose();
  }

  Future<void> _startLogin() async {
    final fullUsername = _usernameController.text.trim();
    final appPassword  = _appPasswordController.text.trim();
    if (fullUsername.isEmpty || appPassword.isEmpty) {
      setState(() => _botResponse = 'Lütfen tüm alanları doldurun.');
      return;
    }

    // domain ayrıştırma
    final parts = fullUsername.split('.');
    final domain = parts.length >= 2
        ? parts.sublist(parts.length - 2).join('.')
        : fullUsername;

    setState(() {
      _loading     = true;
      _botResponse = null;
    });

    try {
      final roomId = await widget.service.createDmRoomWithBluesky(widget.botMatrixId);
      await Future.delayed(const Duration(seconds: 2));

      await widget.service.sendMessage(roomId, "!bsky login");
      await Future.delayed(const Duration(seconds: 2));
      await widget.service.sendMessage(roomId, "!bsky $domain");
      await Future.delayed(const Duration(seconds: 2));
      await widget.service.sendMessage(roomId, "!bsky $fullUsername");
      await Future.delayed(const Duration(seconds: 2));
      await widget.service.sendMessage(roomId, "!bsky $appPassword");

      await Future.delayed(const Duration(seconds: 2));
      final lastBotMsg = await widget.service.getLastBotMessage(roomId);
      setState(() => _botResponse = lastBotMsg ?? 'Bot’tan yanıt alınamadı.');

      if (lastBotMsg != null && lastBotMsg.contains("Successfully logged in")) {
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.of(context).pop(true);
        });
      }
    } catch (e) {
      setState(() => _botResponse = 'Hata: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final bgColor       = AppColors.primaryy(brightness);
    final primary       = AppColors.primaryy(brightness);
    final textColor     = AppColors.text(brightness);
    final fieldBg       = AppColors.primaryy(brightness);
    final fieldBorder   = AppColors.text(brightness);
    final toastBg       = brightness == AppColors.primaryy(brightness);

    return AlertDialog(
      backgroundColor: bgColor,
      title: Text(
        "Bluesky Giriş",
        style: TextStyle(color: textColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_loading && _botResponse == null) ...[
            TextField(
              controller: _usernameController,
              cursorColor: primary,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: fieldBg,
                labelText: "Kullanıcı Adı (xxx.yyy.zzz)",
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _appPasswordController,
              obscureText: true,
              cursorColor: primary,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: fieldBg,
                labelText: "App Şifresi",
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
            ),
          ],
          if (_loading) ...[
            const SizedBox(height: 20),
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 20),
          ],
          if (_botResponse != null) ...[
            const SizedBox(height: 16),
            Text("Bot Cevabı:", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_botResponse!, textAlign: TextAlign.center, style: TextStyle(color: textColor)),
          ],
        ],
      ),
      actions: [
        if (!_loading && _botResponse == null)
          TextButton(
            onPressed: _startLogin,
            style: TextButton.styleFrom(foregroundColor: primary),
            child: Text("Giriş Yap", style: TextStyle(color: primary)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: textColor),
          child: Text("Kapat", style: TextStyle(color: textColor)),
        ),
      ],
    );
  }
}
