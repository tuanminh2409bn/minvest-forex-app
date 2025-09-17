// lib/services/notification_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:minvest_forex_app/services/device_info_service.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Hàm khởi tạo toàn bộ dịch vụ
  Future<void> initialize() async {
    // 1. Xin quyền nhận thông báo
    await _firebaseMessaging.requestPermission();

    // 2. Lấy FCM Token và gọi hàm quản lý session
    await getTokenAndManageSession();

    // 3. Cấu hình để hiển thị thông báo khi app đang mở (foreground)
    if (!kIsWeb) {
      await _initializeLocalNotifications();
      _listenForForegroundMessages();
    }
  }

  // Hàm lấy token và gọi Cloud Function `manageUserSession`
  Future<void> getTokenAndManageSession() async {
    String? fcmToken;
    try {
      if (kIsWeb) {
        const String vapidKey =
            "BF1kL9v7A-1bOSz642aCWoZEKvFpjKvkMQuTPd_GXBLxNakYt6apNf9Aa25hGk1QJP0VFrCVRx4B9mO8h5gBUA8";
        fcmToken = await _firebaseMessaging.getToken(vapidKey: vapidKey);
      } else {
        fcmToken = await _firebaseMessaging.getToken();
      }

      if (fcmToken == null) {
        print('Không thể lấy được FCM token.');
        return;
      }

      print('Platform: ${kIsWeb ? "Web" : "Mobile"}, FCM Token: $fcmToken');

      final deviceId = await DeviceInfoService.getDeviceId();
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('manageUserSession');
      await callable.call({'deviceId': deviceId, 'fcmToken': fcmToken});

      print('Đã gọi manageUserSession thành công để cập nhật token.');
    } catch (e) {
      print('Lỗi trong quá trình lấy và quản lý token: $e');
    }
  }

  // Lắng nghe tin nhắn khi app đang mở
  void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Got a message whilst in the foreground!");
      print("Message data: ${message.data}");

      final notificationData = message.data;
      if (notificationData['title'] != null && notificationData['body'] != null) {
        // Hàm này chỉ có trách nhiệm hiển thị, không điều hướng
        _showLocalNotification(
          notificationData['title']!,
          notificationData['body']!,
        );
      }
    });
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }
}