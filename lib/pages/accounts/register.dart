import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cross_platform_chat_app/constants/constants.dart';
import 'package:http/http.dart' as http;

import '../../main.dart';
import '../../theme/app_colors.dart';

class Register extends StatefulWidget {
  const Register({Key? key}) : super(key: key);

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final nameController     = TextEditingController();
  final surnameController  = TextEditingController();
  bool _loading            = false;

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
            // Sağ üst tema toggle
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

            // Geri + Başlık
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Chatty',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontFamily: "MyTitleFont",
                    fontSize: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Sign up',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: textColor),
            ),
            const SizedBox(height: 20),

            // Ad
            _buildTextField(
              controller: nameController,
              label: 'Name',
              brightness: brightness,
              fillColor: fieldBg,
              borderColor: fieldBorder,
            ),
            const SizedBox(height: 10),

            // Soyad
            _buildTextField(
              controller: surnameController,
              label: 'Surname',
              brightness: brightness,
              fillColor: fieldBg,
              borderColor: fieldBorder,
            ),
            const SizedBox(height: 10),

            // E-posta
            _buildTextField(
              controller: emailController,
              label: 'E-mail',
              brightness: brightness,
              fillColor: fieldBg,
              borderColor: fieldBorder,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),

            // Şifre
            _buildTextField(
              controller: passwordController,
              label: 'Password',
              obscureText: true,
              brightness: brightness,
              fillColor: fieldBg,
              borderColor: fieldBorder,
            ),
            const SizedBox(height: 20),

            // Kayıt Butonu
            _loading
                ? Center(child: CircularProgressIndicator(color: primary))
                : SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary(brightness),
                  foregroundColor: AppColors.text(brightness),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final email = emailController.text.trim();
                  final pass  = passwordController.text.trim();
                  if (!EmailValidator.validate(email)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid email format')),
                    );
                    return;
                  }
                  setState(() => _loading = true);
                  await _registerMatrixThenFirebase(email, pass);
                  setState(() => _loading = false);
                },
                child: const Text('Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    required Brightness brightness,
    required Color fillColor,
    required Color borderColor,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final primary   = AppColors.primaryy(brightness);
    final textColor = AppColors.text(brightness);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }

  Future<void> _registerMatrixThenFirebase(String email, String password) async {
    // 1) Matrix sunucusuna kayıt
    final mxUser = email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final uri = Uri.parse('$matrixBaseUrl/_matrix/client/v3/register?kind=user');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': mxUser,
        'password': password,
        'auth': {'type': 'm.login.dummy'},
      }),
    );

    if (resp.statusCode == 200) {
      // 2) Firebase kaydı
      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await FirebaseFirestore.instance
            .collection('usersInformation')
            .doc(credential.user!.uid)
            .set({
          'name': nameController.text.trim(),
          'surname': surnameController.text.trim(),
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered on Matrix & Firebase!')),
        );
        Navigator.pop(context);
      } on FirebaseAuthException catch (e) {
        String msg;
        if (e.code == 'weak-password') msg = 'Şifre çok zayıf.';
        else if (e.code == 'email-already-in-use') msg = 'Bu e-posta zaten kullanılıyor.';
        else msg = 'Firebase error: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firebase unknown error: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Matrix registration failed: ${resp.body}')),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    surnameController.dispose();
    super.dispose();
  }
}
