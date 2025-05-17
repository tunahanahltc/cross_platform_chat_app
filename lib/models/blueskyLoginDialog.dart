import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BlueSkyLoginDialog extends StatefulWidget {
  final String? email;
  const BlueSkyLoginDialog({
    Key? key,
    required this.email,    // ← burada this.email
  }) : super(key: key);

  @override
  State<BlueSkyLoginDialog> createState() => _BlueSkyLoginDialogState();
}

class _BlueSkyLoginDialogState extends State<BlueSkyLoginDialog> {

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController appPasswordController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    final username = usernameController.text.trim();
    final appPassword = appPasswordController.text.trim();

    if (username.isEmpty || appPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurun.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final uri = Uri.parse('http://64.226.102.154:8001/login');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "app_user_email": widget.email,  // ya burayı da dinamik yapabilirsin
          "user_name": username,
          "app_password": appPassword,
        }),
      );

// ...
      if (response.statusCode == 200) {
        // dialog’u kapatırken true döndür
        Navigator.of(context).pop(true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Giriş başarılı!")),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('bsky_connected', true);
        await prefs.setString('bsky_username', username);
      }
// ...
        else {
        final error = jsonDecode(response.body)['detail'] ?? response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $error")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("İstek sırasında hata: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("BlueSky Giriş"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/bluesky-icon.png',
              height: 80,
              color: Colors.blueAccent,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                hintText: "test.bsky.social",
                labelText: "Kullanıcı Adı",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: appPasswordController,
              decoration: const InputDecoration(
                labelText: "App Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text("İptal"),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Text("Giriş Yap"),
        ),
      ],
    );
  }
}
