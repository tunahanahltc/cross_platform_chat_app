import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/constants.dart';
import '../../login_dialogs/telegram_login_dialog.dart';
import '../../login_dialogs/twitter_login_dialog.dart';
import '../../login_dialogs/instagram_login_dialog.dart';
import '../../login_dialogs/whatsapp_login_dialog.dart';
import '../../services/matrix_telegram_service.dart';
import '../../services/matrix_whatsapp_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({Key? key}) : super(key: key);

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _matrixService = WhatsappMatrixService(homeserverUrl: matrixBaseUrl);
  final _twitterService = TwitterService(homeserverUrl: matrixBaseUrl);
  final _instagramService = InstagramService(homeserverUrl: matrixBaseUrl);

  String _matrixUser = '';
  bool _tgConnected = false;
  bool _twConnected = false;
  bool _instaConnected = false;
  bool _waConnected = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _matrixUser = doc.data()?['matrixUser'] ?? '';
      _tgConnected = doc.data()?['telegramConnected'] ?? false;
      _twConnected = doc.data()?['twitterConnected'] ?? false;
      _instaConnected = doc.data()?['instaConnected'] ?? false;
      _waConnected = doc.data()?['whatsappConnected'] ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize: 20),
                      )
                  ),
                  SizedBox(width: 20),
                  SizedBox(
                    height: 50,
                    width: 175,
                    child:             ElevatedButton(
                      onPressed: _loginTelegram,
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
                        style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize: 20),
                      )
                  ),
                  SizedBox(width: 20,),
                  SizedBox(
                    height: 50,
                    width: 175,
                    child:ElevatedButton(
                      onPressed: _loginTwitter,
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
                        style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize: 20),
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
                        style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize: 20),
                      )
                  ),
              SizedBox(width: 20,),
              SizedBox(
                width: 175,
                height: 50,
                child:ElevatedButton(
                  onPressed: _loginWhatsapp,
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
            )

          ],
        ),
      ),
    );
  }

  Future<void> _loginTelegram() async {
    final success = await showDialog<bool>(
      context: context,
      builder:
          (_) => TelegramLoginDialog(
            matrixUser: _matrixUser,
            matrixService: _matrixService,
          ),
    );

    if (success == true) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'telegramConnected': true,
      }, SetOptions(merge: true));
      _loadUser();
    }
  }

  Future<void> _loginTwitter() async {
    if (_twConnected) {
      try {
        await _twitterService.logout();
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'twitterConnected': false,
        }, SetOptions(merge: true));
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
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'twitterConnected': connected,
      }, SetOptions(merge: true));
      setState(() => _twConnected = connected);
    } catch (e) {
      showToast('Twitter bağlantı hatası: $e');
    }
  }

  Future<void> _loginInstagram() async {
    if (_instaConnected) {
      try {
        await _instagramService.logout();
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'instaConnected': false,
        }, SetOptions(merge: true));
        setState(() => _instaConnected = false);
        showToast('Instagram bağlantısı kesildi.');
      } catch (e) {
        showToast('Çıkış hatası: $e');
      }
      return;
    }

    try {
      final connected = await _instagramService.connect(context);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'instaConnected': connected,
      }, SetOptions(merge: true));
      setState(() => _instaConnected = connected);
    } catch (e) {
      showToast('Instagram bağlantı hatası: $e');
    }
  }

  Future<void> _loginWhatsapp() async {
    final success = await showDialog<bool>(
      context: context,
      builder:
          (_) => WhatsAppLoginDialog(
            service: WhatsAppService(
              matrixBaseUrl: matrixBaseUrl,
              whatsappBotMxid: "@whatsappbot:localhost",
            ),
          ),
    );

    if (success == true) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'whatsappConnected': true,
      }, SetOptions(merge: true));
      _loadUser();
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
