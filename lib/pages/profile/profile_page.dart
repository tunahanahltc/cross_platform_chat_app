import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Yeni eklenenlar:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cross_platform_chat_app/constants/constants.dart';

import '../../theme/app_colors.dart';
import '../accounts/login.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<Map<String, dynamic>?> _getUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('usersInformation')
        .doc(uid)
        .get();
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.primaryy(brightness),
      appBar: AppBar(
        backgroundColor: AppColors.primaryy(brightness),
        title: const Text("Profil"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _logoutFromBoth(context);
            },
            tooltip: "Çıkış Yap",
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Kullanıcı bilgileri bulunamadı."));
          }

          final data = snapshot.data!;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final formattedDate = createdAt != null
              ? DateFormat('dd.MM.yyyy – HH:mm').format(createdAt)
              : 'Bilinmiyor';

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: const AssetImage('assets/default_avatar.png')
                  ),
                ),
                const SizedBox(height: 20),
                _profileRow("Ad", data['name']),
                _profileRow("Soyad", data['surname']),
                _profileRow("E-posta", data['email']),
                _profileRow("Kayıt Tarihi", formattedDate),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _logoutFromBoth(context);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Çıkış Yap"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Future<void> _logoutFromBoth(BuildContext context) async {
    final storage = const FlutterSecureStorage();
    final user = FirebaseAuth.instance.currentUser;

    // 1) Synapse (Matrix) logout
    try {
      final accessToken = await storage.read(key: 'access_token');
      if (accessToken != null) {
        final logoutUrl = Uri.parse('$matrixBaseUrl/_matrix/client/v3/logout');
        final res = await http.post(
          logoutUrl,
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        if (res.statusCode != 200) {
          debugPrint('Matrix logout hata: ${res.statusCode} ${res.body}');
        }
      }

      await storage.delete(key: 'matrixUsername');
      await storage.delete(key: 'matrixPassword');
      await storage.delete(key: 'access_token');
    } catch (e) {
      debugPrint('Matrix logout sırasında hata: $e');
    }

    // 2) Firestore'da is_online = false
    try {
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'is_online': false,
        });
      }
    } catch (e) {
      debugPrint('Firestore güncelleme hatası: $e');
    }

    // 3) FirebaseAuth logout
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('FirebaseAuth logout sırasında hata: $e');
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const Login()),
    );
  }

}
