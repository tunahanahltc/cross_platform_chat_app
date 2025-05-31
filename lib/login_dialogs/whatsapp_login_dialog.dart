import 'package:flutter/material.dart';
import '../services/matrix_whatsapp_service.dart';

class WhatsAppLoginDialog extends StatefulWidget {
  final WhatsAppService service;

  const WhatsAppLoginDialog({super.key, required this.service});

  @override
  State<WhatsAppLoginDialog> createState() => _WhatsAppLoginDialogState();
}

class _WhatsAppLoginDialogState extends State<WhatsAppLoginDialog> {
  final TextEditingController _phoneController = TextEditingController();
  String? _botCode;
  bool _loading = false;

  Future<void> _startLogin() async {
    setState(() => _loading = true);

    try {
      await widget.service.sendLoginCommand();
      await Future.delayed(const Duration(seconds: 1));
      await widget.service.sendPhoneNumber(_phoneController.text);

      await Future.delayed(const Duration(seconds: 2));
      final botMsg = await widget.service.getLastBotMessage();
      setState(() => _botCode = botMsg ?? 'Kod bulunamadı');
    } catch (e) {
      setState(() => _botCode = 'Hata: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("WhatsApp Giriş"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_loading && _botCode == null) ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Telefon Numarası",
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
          if (_botCode != null) ...[
            const SizedBox(height: 20),
            Text(
              "Kod:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                _botCode!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
      actions: [
        if (!_loading && _botCode == null) ...[
          TextButton(
            onPressed: _startLogin,
            child: const Text("Gönder"),
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
