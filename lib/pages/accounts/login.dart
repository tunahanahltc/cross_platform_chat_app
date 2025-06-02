import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_platform_chat_app/pages/accounts/register.dart';
import 'package:cross_platform_chat_app/pages/home/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cross_platform_chat_app/constants/constants.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _loading = false;
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: ListView(
          children: <Widget>[
            const SizedBox(height: 5),
            _buildHeader(),
            const SizedBox(height: 20),
            _buildInputFields(),
            const SizedBox(height: 20),
            _buildButtons(context),
            const SizedBox(height: 20),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: const [
        Text('Chatty',
            style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 40,
                fontFamily: 'MyTitleFont')),
        Text('Sign in', style: TextStyle(fontSize: 20)),
      ],
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        _buildTextField(controller: _emailController, label: 'User Name or E-mail'),
        const SizedBox(height: 10),
        _buildTextField(
            controller: _passwordController, label: 'Password', obscureText: true),
        const SizedBox(height: 10),
        TextButton(onPressed: () {}, child: const Text('Forgot Password')),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : SizedBox(
      height: 50,
      child: ElevatedButton(
        child: const Text('Login'),
        onPressed: () async {
          final email = _emailController.text.trim();
          final userLocalpart = email
              .split('@')
              .first
              .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
          final pass = _passwordController.text.trim();
          if (email.isEmpty || pass.isEmpty) return;

          setState(() => _loading = true);

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

          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: pass,
            );
            final firebaseUser = FirebaseAuth.instance.currentUser;
            final token = await _storage.read(key: 'access_token');
            if (firebaseUser != null) {
              await FirebaseFirestore.instance
                  .collection('matrix_telegram_users')
                  .doc(firebaseUser.uid)
                  .set({
                'matrixUser': userLocalpart,
                'token': token,
              }, SetOptions(merge: true));
            }

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
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Does not have account?'),
        TextButton(
          child: const Text('Sign up', style: TextStyle(fontSize: 20)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Register()),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
  }) =>
      TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
          ),
          labelText: label,
        ),
      );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
