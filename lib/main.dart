import 'package:cross_platform_chat_app/pages/accounts/login.dart';
import 'package:cross_platform_chat_app/pages/home/home_page.dart';
import 'package:cross_platform_chat_app/pages/profile/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/splash/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // 🔥 Firebase'i başlat
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  if (snapshot.hasData) {
  return const HomePage(); // kullanıcı giriş yapmış
  } else {
  return const SplashScreen(); // kullanıcı çıkış yapmış
  }
  },
  );
  }
}
