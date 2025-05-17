import 'package:cross_platform_chat_app/pages/accounts/login.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:flutter_gradient_animation_text/flutter_gradient_animation_text.dart';

import '../home/home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Login())//const HomePage()),
      );
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orangeAccent, // Arka plan rengi
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/splash_animation.json',
              width: 200,
              height: 200,
              repeat: true,
              fit: BoxFit.contain,
            ),
            // rainbow text
            GradientAnimationText(
              text: Text('CHATTY', style: TextStyle(fontSize: 50,fontFamily:'MyTitleFont' )),
              colors: [
                Color(0xff8f00ff), // violet
                Colors.white,
                Colors.blue,
                Colors.yellow,


              ],
              duration: Duration(seconds: 5),
            ),
          ],
        ),
      ),
    );
  }
}


