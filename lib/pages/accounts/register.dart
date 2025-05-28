import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cross_platform_chat_app/constants/constants.dart';
import 'package:http/http.dart' as http;

// Android emulator için localhost yerine 10.0.2.2 kullanın.

class Register extends StatefulWidget {
  const Register({Key? key}) : super(key: key);

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: ListView(
          children: <Widget>[
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
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
            const Text(
              'Sign up',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            _buildTextField(nameController, 'Name'),
            const SizedBox(height: 10),
            _buildTextField(surnameController, 'Surname'),
            const SizedBox(height: 10),
            _buildTextField(emailController, 'E-mail', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _buildTextField(passwordController, 'Password', obscureText: true),
            const SizedBox(height: 20),
            _loading
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
              height: 50,
              child: ElevatedButton(
                child: const Text('Register'),
                onPressed: () async {
                  final email = emailController.text.trim();
                  final pass = passwordController.text.trim();
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        labelText: label,
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
}
