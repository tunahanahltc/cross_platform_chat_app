import 'package:cross_platform_chat_app/pages/accounts/login.dart';
import 'package:cross_platform_chat_app/pages/chat_list/chat_page.dart';
import 'package:cross_platform_chat_app/pages/home/home_page.dart';
import 'package:cross_platform_chat_app/pages/profile/profile_page.dart';
import 'package:cross_platform_chat_app/services/fcm_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/splash/splash_page.dart';

// Bildirimden yönlendirme için global navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FCMService.initFCM(); // 🔔 FCM başlatılıyor
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 1) Cold-start: Uygulama kapalıyken bildirimden açıldıysa
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _openChatFromNotification(message.data);
      }
    });

    // 2) Arka planda: uygulama açık değilken bildirimden tıklama
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openChatFromNotification(message.data);
    });
  }

  void _openChatFromNotification(Map<String, dynamic> data) {
    final roomId = data['room_id'];
    final chatTitle = data['chat_title'];
    if (roomId != null && chatTitle != null) {
      // Navigator.push işlemini, widget tree hazır olduktan sonra tetikle
      Future.microtask(() {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatPage(
              chatId: roomId,
              chatTitle: chatTitle,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Chatty',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomePage();      // Girişli kullanıcı
        } else {
          return const SplashScreen();  // Çıkışlı kullanıcı
        }
      },
    );
  }
}
