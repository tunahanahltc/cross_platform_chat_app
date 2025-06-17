import 'dart:ffi';

import 'package:cross_platform_chat_app/login_dialogs/bluesky_login_dialog.dart';
import 'package:cross_platform_chat_app/services/matrix_bluesky_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../constants/constants.dart';
import '../../login_dialogs/telegram_login_dialog.dart';
import '../../login_dialogs/twitter_login_dialog.dart';
import '../../login_dialogs/instagram_login_dialog.dart';
import '../../login_dialogs/whatsapp_login_dialog.dart';
import '../../services/matrix_telegram_service.dart';
import '../../services/matrix_whatsapp_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../theme/app_colors.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({Key? key}) : super(key: key);

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _storage = const FlutterSecureStorage();
  final _matrixService = TelegramMatrixService(homeserverUrl: matrixBaseUrl);
  final _twitterService = TwitterService(homeserverUrl: matrixBaseUrl);
  final _instagramService = InstagramService(homeserverUrl: matrixBaseUrl);
  final _telegramService = TelegramMatrixService(homeserverUrl: matrixBaseUrl);
  final _blueskyService = BlueskyMatrixService(homeserverUrl: matrixBaseUrl);

  String _matrixUser = '';
  bool _tgConnected = false;
  bool _twConnected = false;
  bool _instaConnected = false;
  bool _waConnected = false;
  bool _bskyConnected = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final matrixUser = await _storage.read(key: 'matrixUsername') ?? '';
    final tg = await _storage.read(key: 'telegramConnected') == 'true';
    final tw = await _storage.read(key: 'twitterConnected') == 'true';
    final insta = await _storage.read(key: 'instaConnected') == 'true';
    final wa = await _storage.read(key: 'whatsappConnected') == 'true';
    final bsky = await _storage.read(key: 'blueskyConnected') == 'true';
    setState(() {
      _matrixUser = matrixUser;
      _tgConnected = tg;
      _twConnected = tw;
      _instaConnected = insta;
      _waConnected = wa;
      _bskyConnected = bsky;
    });
  }


  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor:  AppColors.primaryy(brightness),
      body: Center(
        child: Column(
          //mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
                child: Container(
                    width: double.maxFinite,
                    padding: EdgeInsets.all(26),
                    child: Column(
                      children: [
                        Text("Uyarı:",style: TextStyle(fontWeight: FontWeight.bold),),
                        Text("Platformların bağlanma şekilleri farklılık gösterebilir lütfen "
                            "bağlantı yaparken gösterilecek uyarıları ve gereklilikleri dikkate alınız!")
                      ],
                    )
                )
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20,),
                  SizedBox(
                      width: 100,
                      child: Text(
                        "Telegram",
                        style: TextStyle(color:  AppColors.text(brightness),fontWeight: FontWeight.bold,fontSize: 20),
                      )
                  ),
                  SizedBox(width: 20),
                  SizedBox(
                    height: 50,
                    width: 175,
                    child:ElevatedButton(
                      onPressed: _tgConnected ? _logoutTelegram : _loginTelegram ,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          _tgConnected ? Colors.red : Colors.amber,
                        ),
                      ),
                      child: Text(
                        _tgConnected ? 'Telegram Çıkış' : 'Telegram Giriş',
                        style: TextStyle(
                            color: _tgConnected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w900
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 15),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20,),
                  SizedBox(
                      width: 100,
                      child: Text(
                        "Twitter",
                        style: TextStyle(color: AppColors.text(brightness),fontWeight: FontWeight.bold,fontSize: 20),
                      )
                  ),
                  SizedBox(width: 20,),
                  SizedBox(
                    height: 50,
                    width: 175,
                    child:ElevatedButton(
                      onPressed: _twConnected ? _logoutTwitter : _loginTwitter ,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          _twConnected ? Colors.red : Colors.amber,
                        ),
                      ),
                      child: Text(_twConnected ? 'Twitter Çıkış' : 'Twitter Giriş',
                        style: TextStyle(
                            color: _twConnected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w900
                        ),
                      ),
                    ),
                  )
                ],
              ),

            ),

            SizedBox(height: 15,),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20,),
                  SizedBox(
                    width: 100,
                      child: Text(
                        "Instagram",
                        style: TextStyle(color: AppColors.text(brightness),fontWeight: FontWeight.bold,fontSize: 20),
                      )
                  ),
                  SizedBox(width: 20,),
                  SizedBox(
                    width: 175,
                    height: 50,
                    child:ElevatedButton(
                      onPressed: _loginInstagram,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          _instaConnected ? Colors.red : Colors.amber,
                        ),
                      ),
                      child: Text(
                        _instaConnected ? 'Instagram Çıkış' : 'Instagram Giriş',
                        style: TextStyle(
                            color: _instaConnected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w900
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            SizedBox(height: 15,),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20,),
                  SizedBox(
                      width: 100,
                      child: Text(
                        "Whatsapp",
                        style: TextStyle(color: AppColors.text(brightness),fontWeight: FontWeight.bold,fontSize: 20),
                      )
                  ),
              SizedBox(width: 20,),
              SizedBox(
                width: 175,
                height: 50,
                child:ElevatedButton(
                  onPressed: _waConnected ? _logoutWhatsapp : _loginWhatsapp,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      _waConnected ? Colors.red : Colors.amber,
                    ),
                  ),
                  child: Text(_waConnected ? 'Whatsapp Çıkış' : 'Whatsapp Giriş',
                    style: TextStyle(
                        color: _waConnected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w900
                    ),
                  ),
                ),
              ),
                ]
              ),
            ),
            SizedBox(height: 15,),
            Center(
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20,),
                    SizedBox(
                        width: 100,
                        child: Text(
                          "Bluesky",
                          style: TextStyle(color: AppColors.text(brightness),fontWeight: FontWeight.bold,fontSize: 20),
                        )
                    ),
                    SizedBox(width: 20,),
                    SizedBox(
                      width: 175,
                      height: 50,
                      child:ElevatedButton(
                        onPressed: _bskyConnected ? _logoutBluesky : _loginBluesky,
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            _bskyConnected ? Colors.red : Colors.amber,
                          ),
                        ),
                        child: Text(_bskyConnected ? 'Bluesky Çıkış' : 'Bluesky Giriş',
                          style: TextStyle(
                              color: _bskyConnected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w900
                          ),
                        ),
                      ),
                    ),
                  ]
              ),
            )


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
      await _storage.write(key: 'telegramConnected', value: 'true');
      setState(() => _tgConnected = true);
      showToast('Telegram bağlantısı yapıldı.');
    }
  }

  Future<void> _logoutTelegram() async {
    try {
      await _telegramService.logoutWithTelegramBot(); // DM odası kurup "logout" mesajı gönderir
      await _storage.write(key: 'telegramConnected', value: 'false'); // Storage güncelle
      setState(() => _tgConnected = false); // UI güncelle
      showToast('Telegram bağlantısı kesildi.');
    } catch (e) {
      showToast('Telegram çıkış hatası: $e');
    }
  }
  Future<void> _loginTwitter() async {
    if (_twConnected == false) {
      try {
        final connected = await _twitterService.connect(context);
        await _storage.write(
            key: 'twitterConnected', value: connected.toString());
        setState(() => _twConnected = connected);
      } catch (e) {
        showToast('Twitter bağlantı hatası: $e');
      }
    }
  }
Future<void> _logoutTwitter() async{
  if (_twConnected == true) {
    try {
      await _twitterService.logout();
      await _storage.write(key: 'twitterConnected', value: 'false');
      setState(() => _twConnected = false);
      showToast('Twitter bağlantısı kesildi.');
    } catch (e) {
      showToast('Twitter çıkış hatası: $e');
    }
    return;
  }
}


  Future<void> _loginInstagram() async {
    if (_instaConnected == true) {
      try {
        await _instagramService.logout();
        await _storage.write(key: 'instaConnected', value: 'false');
        setState(() => _instaConnected = false);
        showToast('Instagram bağlantısı kesildi.');
      } catch (e) {
        showToast('Instagram çıkış hatası: $e');
      }
      return;
    }

    try {
      final connected = await _instagramService.connect(context);
      await _storage.write(key: 'instaConnected', value: connected.toString());
      setState(() => _instaConnected = connected);
    } catch (e) {
      showToast('Instagram bağlantı hatası: $e');
    }
  }

  Future<void> _loginWhatsapp() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => WhatsAppLoginDialog(
        service: WhatsAppService(
          matrixBaseUrl: matrixBaseUrl,
          whatsappBotMxid: "@whatsappbot:localhost",
        ),
      ),
    );

    if (success == true) {
      await _storage.write(key: 'whatsappConnected', value: 'true');
      setState(() => _waConnected = true);
      showToast('Whatsapp bağlantısı yapıldı.');
    }
  }
  Future<void> _logoutWhatsapp() async {
    try {
      final service = WhatsAppService(
        matrixBaseUrl: matrixBaseUrl,
        whatsappBotMxid: "@whatsappbot:localhost",
      );

      await service.logoutFromWhatsApp();

      await _storage.write(key: 'whatsappConnected',value: 'false');
      setState(() => _waConnected = false);
      showToast('WhatsApp bağlantısı sonlandırıldı.');
    } catch (e) {
      showToast('Çıkış yapılamadı: $e');
    }
  }


  Future<void> _loginBluesky() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => BlueskyLoginDialog(
        service: BlueskyMatrixService(homeserverUrl: matrixBaseUrl),
        botMatrixId: "@blueskybot:localhost",
      ),
    );

    if (success == true) {
      await _storage.write(key: 'blueskyConnected', value: 'true');
      setState(() => _bskyConnected = true);
      showToast('Bluesky bağlantısı yapıldı.');
    }
  }
  Future<void> _logoutBluesky() async{
    if (_bskyConnected == true) {
      try {
        await _blueskyService.logoutFromBluesky('@blueskybot:localhost');
        await _storage.write(key: 'blueskyConnected', value: 'false');
        setState(() => _bskyConnected = false);
        showToast('Twitter bağlantısı kesildi.');
      } catch (e) {
        showToast('Twitter çıkış hatası: $e');
      }
      return;
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
