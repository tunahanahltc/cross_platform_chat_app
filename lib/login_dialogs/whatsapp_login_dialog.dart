import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
      String botId = await widget.service.sendLoginCommand();
      await Future.delayed(const Duration(seconds: 1));
      await widget.service.sendPhoneNumber(_phoneController.text, botId);

      await Future.delayed(const Duration(seconds: 2));
      final botMsg = await widget.service.getLastBotMessage(botId);
      setState(() => _botCode = botMsg ?? 'Kod bulunamadı');
    } catch (e) {
      setState(() => _botCode = 'Hata: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Geri tuşunu da engelle
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "WhatsApp Giriş",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
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
                    const Text(
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
                    const SizedBox(height: 20),
                    const Text(
                      "Giriş yaptınız mı?",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final storage = FlutterSecureStorage();
                            await storage.write(key: 'whatsappConnected', value: 'false');
                            Navigator.pop(context);
                          },
                          child: const Text("Hayır"),
                        ),
                        TextButton(
                          onPressed: () async {
                            final storage = FlutterSecureStorage();
                            await storage.write(key: 'whatsappConnected', value: 'true');
                            Navigator.pop(context);
                          },
                          child: const Text("Evet"),
                        ),
                      ],
                    ),
                  ],
                  if (!_loading && _botCode == null) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _startLogin,
                        child: const Text("Gönder"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Sağ üstte kapatma (X) ikonu
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
