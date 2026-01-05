import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initFCM() async {
    await _messaging.requestPermission();

    // 🔔 Foreground mesajlar
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      Map<String, dynamic> data = message.data;

      if (notification != null) {
        final payload = data['room_id'] ?? '';
        showLocalNotification(notification.title!, notification.body!, payload: payload);
      }
    });

    // 🔁 Bildirime tıklanınca çalışacak kısım
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          navigatorKey.currentState?.pushNamed(
            '/chat',
            arguments: {
              'roomId': payload,
            },
          );
        }
      },
    );


    // 🔕 Uygulama arka planda açılırken bildirime tıklama
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final roomId = message.data['room_id'];
      if (roomId != null) {
        navigatorKey.currentState?.pushNamed(
          '/chat',
          arguments: {
            'roomId': roomId,
          },
        );
      }
    });
  }

  static void showLocalNotification(String title, String body, {String? payload}) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    _localNotifications.show(0, title, body, notificationDetails, payload: payload);
  }
}
