// accounts_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/constants.dart';
import '../../login_dialogs/telegram_login_dialog.dart';
import '../../login_dialogs/twitter_login_dialog.dart';
import '../../services/matrix_telegram_service.dart';
import '../../login_dialogs/twitter_login_dialog.dart';
import 'package:cross_platform_chat_app/constants/constants.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Android emulator için localhost yerine 10.0.2.2 kullanın.

//final String _matrixBaseUrl = matrixBaseUrl;

class AccountsPage extends StatefulWidget {
  const AccountsPage({Key? key}) : super(key: key);

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {

  final _matrixService = TelegramMatrixService(homeserverUrl: matrixBaseUrl);
  final _twitterService = TwitterService(homeserverUrl: matrixBaseUrl);

  String _matrixUser = '';
  bool _tgConnected = false;
  bool _twConnected = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    setState(() {
      _matrixUser = doc.data()?['matrixUser'] ?? '';
      _tgConnected = doc.data()?['telegramConnected'] ?? false;
      _twConnected = doc.data()?['twitterConnected'] ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Logged in as: $_matrixUser'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loginTelegram,
              child: Text(_tgConnected ? 'Telegram Çıkış' : 'Telegram Giriş'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loginTwitter,
              child: Text(_twConnected ? 'Twitter Çıkış' : 'Twitter Giriş'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginTelegram() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => TelegramLoginDialog(
        matrixUser: _matrixUser,
        matrixService: _matrixService,
      ),
    );

    if (success == true) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'telegramConnected': true}, SetOptions(merge: true));
      _loadUser();
    }
  }
  Future<void> _loginTwitter() async {
    if (_twConnected) {
      try {
        await _twitterService.logout();
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'twitterConnected': false}, SetOptions(merge: true));
        setState(() => _twConnected = false);
        showToast('Twitter bağlantısı kesildi.');
      } catch (e) {
        showToast('Çıkış hatası: $e');
      }
      return;
    }

    try {
      final connected = await _twitterService.connect(context);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'twitterConnected': connected}, SetOptions(merge: true));
      setState(() => _twConnected = connected);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Twitter bağlantı hatası: $e')),
      );
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


