import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_platform_chat_app/pages/accounts/register.dart';
import 'package:cross_platform_chat_app/pages/home/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cross_platform_chat_app/constants/constants.dart';

import '../../main.dart';
import '../../theme/app_colors.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage            = const FlutterSecureStorage();
  bool _loading             = false;
  late Client _matrixClient;

  @override
  void initState() {
    super.initState();
    _matrixClient = Client('Chatty');
  }

  Future<void> logoutAllOtherDevicesExceptCurrent(String accessToken, String baseUrl) async {
    final devicesUrl = Uri.parse('$baseUrl/_matrix/client/v3/devices');
    final res = await http.get(
      devicesUrl,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode != 200) throw Exception('Failed to get devices');

    final devices = jsonDecode(res.body)['devices'];
    // En son kullanılan cihaz (bu cihaz olmalı)
    String? currentDeviceId;
    int maxSeen = 0;
    for (var d in devices) {
      final ts = d['last_seen_ts'] ?? 0;
      if (ts > maxSeen) {
        maxSeen = ts;
        currentDeviceId = d['device_id'];
      }
    }

    for (var d in devices) {
      final deviceId = d['device_id'];
      if (deviceId != currentDeviceId) {
        final deleteUrl = Uri.parse('$baseUrl/_matrix/client/v3/devices/$deviceId');
        await http.delete(
          deleteUrl,
          headers: {'Authorization': 'Bearer $accessToken'},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final bgColor     = AppColors.primaryy(brightness);
    final primary     = AppColors.primaryy(brightness);
    final textColor   = AppColors.text(brightness);
    final fieldBg     = AppColors.primaryy(brightness);
    final fieldBorder = AppColors.text(brightness);

    return Scaffold(
      backgroundColor: bgColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Sağ üst tema düğmesi
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    brightness == Brightness.dark
                        ? Icons.wb_sunny_outlined
                        : Icons.nights_stay_outlined,
                    color: textColor,
                  ),
                  onPressed: () => MyApp.of(context).toggleTheme(),
                ),
              ],
            ),

            const SizedBox(height: 40),
            _buildHeader(textColor),
            const SizedBox(height: 40),
            // Input Fields
            _buildTextField(
              controller: _emailController,
              label: 'User Name or E-mail',
              brightness: brightness,
              fillColor: fieldBg,
              borderColor: fieldBorder,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: true,
              brightness: brightness,
              fillColor: fieldBg,
              borderColor: fieldBorder,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(foregroundColor: primary),
                child:  Text('Forgot Password?', style: TextStyle(color: AppColors.text(brightness)),),
              ),
            ),
            const SizedBox(height: 24),
            // Login Button
            _loading
                ? Center(child: CircularProgressIndicator(color: primary))
                : SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary(brightness),
                  foregroundColor: AppColors.text(brightness),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _onLoginPressed,
                child: const Text('Login'),
              ),
            ),
            const SizedBox(height: 24),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Doesn’t have an account?',
                  style: TextStyle(color: textColor),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Register()),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.text(brightness)),
                  child: const Text(' Sign up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Column(
      children: [
        Text(
          'Chatty',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 40,
            fontFamily: 'MyTitleFont',
          ),
        ),
        const SizedBox(height: 8),
        Text('Sign in', style: TextStyle(fontSize: 20, color: textColor)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    required Brightness brightness,
    required Color fillColor,
    required Color borderColor,
  }) {
    final primary   = AppColors.secondary(brightness);
    final textColor = AppColors.text(brightness);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      cursorColor: primary,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.text(brightness), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.text(brightness), width: 2),
        ),
      ),
    );
  }


  Future<void> _onLoginPressed() async {
    final email = _emailController.text.trim();
    final userLocalpart = email
        .split('@')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final pass = _passwordController.text.trim();
    if (email.isEmpty || pass.isEmpty) return;

    setState(() => _loading = true);

    // 1) Matrix login
    try {
      await _matrixClient.checkHomeserver(Uri.parse(matrixBaseUrl));
      await _matrixClient.login(
        LoginType.mLoginPassword,
        password: pass,
        identifier: AuthenticationUserIdentifier(user: userLocalpart),
      );

      final accessToken = _matrixClient.accessToken!;
      await logoutAllOtherDevicesExceptCurrent(accessToken, matrixBaseUrl);

      await _storage.write(key: 'matrixUsername', value: userLocalpart);
      await _storage.write(key: 'matrixPassword', value: pass);
      await _storage.write(key: 'access_token', value: accessToken);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Matrix login failed: $e')),
      );
      setState(() => _loading = false);
      return;
    }

    // 2) Firebase Auth
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final matrixToken = await _storage.read(key: 'access_token');
      final matrixUsername = '@$userLocalpart:localhost';
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (firebaseUser != null && matrixToken != null && fcmToken != null) {
        // 3) Firestore update
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
          'username': matrixUsername,
          'access_token': matrixToken,
          'fcm_token': fcmToken,
          'is_online': true,
          'platform': 'android',
          'last_login': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 4) FCM token refresh listener
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcm_token': newToken});
        }
      });

      // 5) Navigate to Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Bir hata oluştu';
      if (e.code == 'user-not-found') {
        message = 'Kullanıcı bulunamadı.';
      } else if (e.code == 'wrong-password') {
        message = 'Şifre yanlış.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      setState(() => _loading = false);
    }
  }
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
