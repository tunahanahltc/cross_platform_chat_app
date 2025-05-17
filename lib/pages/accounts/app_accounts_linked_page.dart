import 'package:cross_platform_chat_app/models/bluesky_logout.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/blueskyLoginDialog.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  bool _isBlueSkyConnected = false;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadConnectionState();
  }

  Future<void> _loadConnectionState() async {
    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('bsky_connected') ?? false;
    final username  = prefs.getString('bsky_username') ?? '';
    setState(() {
      _isBlueSkyConnected = connected;
      _username = username;
      print(_username);
    });
  }

  void _onBlueSkyLoginPressed(String? email) {
    showDialog(
      context: context,
      builder: (_) => BlueSkyLoginDialog(email: email),
    ).then((_) {
      // Dialog kapandıktan sonra bağlantı durumu yeniden yüklenir
      _loadConnectionState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String? email = user?.email;

    return Scaffold(
      body: Center(
        child: Column(
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
              child:Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                SizedBox(width: 20,),
                SizedBox(
                  width: 100,
                  child: Text(
                    "BlueSky",
                    style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize: 20),
                  )
                ),
                SizedBox(width: 20),
// build içinde
                  SizedBox(
                    height: 50,
                    width: 175,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isBlueSkyConnected ? Colors.red : Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (_isBlueSkyConnected) {
                          // logout işlemi
                          await logoutUser(_username);
                          await _loadConnectionState(); // hemen güncelle
                        } else {
                          // login dialog’u aç, true gelirse state'i güncelle
                          final loggedIn = await showDialog<bool>(
                            context: context,
                            builder: (_) => BlueSkyLoginDialog(email: email),
                          );
                          if (loggedIn == true) {
                            await _loadConnectionState();
                          }
                        }
                      },
                      child: Text(_isBlueSkyConnected ? 'Çıkış Yap' : 'Giriş Yap'),
                    ),
                  )
              ],
              )
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
                       "Telegram",
                       style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize: 20),
                     )
                 ),
                 SizedBox(width: 20,),
                 SizedBox(
                   height: 50,
                   width: 175,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.blueAccent,
                       foregroundColor: Colors.white,
                     ),
                     onPressed: () {
                       // Telegram login dialog/metodunu çağır
                     },
                     child: const Text("Giriş Yap"),
                   ),
                 ),
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
                    height: 50,
                    width: 175,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Telegram login dialog/metodunu çağır
                      },
                      child: const Text("Giriş Yap"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
