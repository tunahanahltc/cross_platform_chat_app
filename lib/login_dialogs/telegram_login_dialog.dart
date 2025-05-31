import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/matrix_telegram_service.dart';

class TelegramLoginDialog extends StatefulWidget {
  final String matrixUser;
  final WhatsappMatrixService matrixService;
  const TelegramLoginDialog({Key? key, required this.matrixUser, required this.matrixService}) : super(key: key);

  @override
  State<TelegramLoginDialog> createState() => _TelegramLoginDialogState();
}

class _TelegramLoginDialogState extends State<TelegramLoginDialog> {
  int _step = 1;
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _roomId;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Telegram Giriş'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_step == 1)
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Telefon (+90...)'),
              keyboardType: TextInputType.phone,
            )
          else
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'SMS Kod'),
              keyboardType: TextInputType.number,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _next,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_step == 1 ? 'Telefon Gönder' : 'Kod Gönder'),
        ),
      ],
    );
  }

  Future<void> _next() async {
    setState(() => _busy = true);
    try {
      if (_step == 1) {
        _roomId ??= await widget.matrixService.createDmRoom();
        await Future.delayed(const Duration(seconds: 1));
        await widget.matrixService.sendMessage(_roomId!, 'login');
        await Future.delayed(const Duration(seconds: 1));
        await widget.matrixService.sendMessage(_roomId!, _phoneCtrl.text);
        setState(() => _step = 2);
      } else {
        _roomId ??= await widget.matrixService.createDmRoom();
        await Future.delayed(const Duration(seconds: 1));
        await widget.matrixService.sendMessage(_roomId!, _codeCtrl.text);
        await widget.matrixService.leaveRoom(_roomId!);
        await widget.matrixService.forgetRoom(_roomId!);
        Navigator.pop(context, true);
      }
    } catch (e) {
      showToast('Hata: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  void showToast(String mesaj) {
    Fluttertoast.showToast(
      msg: mesaj,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}
