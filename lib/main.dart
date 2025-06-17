// lib/main.dart

import 'package:cross_platform_chat_app/pages/accounts/login.dart';
import 'package:cross_platform_chat_app/pages/chat_list/chat_page.dart';
import 'package:cross_platform_chat_app/pages/home/home_page.dart';
import 'package:cross_platform_chat_app/pages/profile/profile_page.dart';
import 'package:cross_platform_chat_app/pages/splash/splash_page.dart';
import 'package:cross_platform_chat_app/services/fcm_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_colors.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FCMService.initFCM();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
    _setupNotificationHandlers();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString('theme_mode')) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    setState(() {});
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', {
      ThemeMode.light: 'light',
      ThemeMode.dark: 'dark',
      ThemeMode.system: 'system',
    }[mode]!);
  }

  void toggleTheme() {
    setState(() {
      _themeMode =
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      _saveTheme(_themeMode);
    });

    // hemen alt nav-bar stilini de güncelle
    final newBrightness =
    _themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: AppColors.primaryy(newBrightness),
        systemNavigationBarIconBrightness:
        newBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }


  void _setupNotificationHandlers() {
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) _openChatFromNotification(msg.data);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _openChatFromNotification(msg.data);
    });
  }

  void _openChatFromNotification(Map<String, dynamic> data) {
    final roomId = data['room_id'];
    final title  = data['chat_title'];
    final plat   = data['platform'];
    if (roomId != null && title != null) {
      Future.microtask(() {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatPage(
              chatId: roomId,
              chatTitle: title,
              platform: plat,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Chatty',
      themeMode: _themeMode,

      // Light Tema
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primaryy(Brightness.light),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: AppColors.primaryy(Brightness.light),
          background: Colors.white,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.text(Brightness.light),
          displayColor: AppColors.text(Brightness.light),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primaryy(Brightness.light),
          foregroundColor: AppColors.text(Brightness.light),
        ),
      ),

      // Dark Tema
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.primaryy(Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryy(Brightness.dark),
          background: const Color(0xFF121212),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: AppColors.text(Brightness.dark),
          displayColor: AppColors.text(Brightness.dark),
        ),
        appBarTheme: AppBarTheme(

          backgroundColor: AppColors.primaryy(Brightness.dark),
          foregroundColor: AppColors.text(Brightness.dark),
        ),
      ),
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            systemNavigationBarColor: AppColors.primaryy(brightness),
            systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          ),
        );
        return child!;
      },
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
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return snap.hasData ? const HomePage() : const SplashScreen();
      },
    );
  }
}
