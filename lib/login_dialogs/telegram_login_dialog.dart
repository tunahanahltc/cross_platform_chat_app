import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/matrix_telegram_service.dart';
import '../../theme/app_colors.dart';

class TelegramLoginDialog extends StatefulWidget {
  final String matrixUser;
  final TelegramMatrixService matrixService;
  const TelegramLoginDialog({
    Key? key,
    required this.matrixUser,
    required this.matrixService,
  }) : super(key: key);

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
        'Telegram Giriş',
        style: TextStyle(color: textColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_step == 1)
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              cursorColor: primary,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: fieldBg,
                labelText: 'Telefon (+90...)',
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
            )
          else
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              cursorColor: primary,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: fieldBg,
                labelText: 'SMS Kod',
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
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: primary),
          child: Text('İptal', style: TextStyle(color: primary)),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: textColor,
          ),
          child: _busy
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: textColor,
            ),
          )
              : Text(
            _step == 1 ? 'Telefon Gönder' : 'Kod Gönder',
            style: TextStyle(color: textColor),
          ),
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
      _showToast('Hata: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _showToast(String mesaj) {
    final brightness = Theme.of(context).brightness;
    final toastBg    = brightness == Brightness.dark ? Colors.white24 : Colors.black26;
    Fluttertoast.showToast(
      msg: mesaj,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: toastBg,
      textColor: AppColors.text(brightness),
      fontSize: 16.0,
    );
  }
}
