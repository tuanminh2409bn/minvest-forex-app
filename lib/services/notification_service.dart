import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Hàm khởi tạo toàn bộ dịch vụ
  Future<void> initialize() async {
    // 1. Xin quyền nhận thông báo trên iOS & Android 13+
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // 2. Lấy FCM Token và lưu vào Firestore
    await _saveFcmTokenToFirestore();

    // 3. Cấu hình để hiển thị thông báo khi app đang mở (foreground)
    await _initializeLocalNotifications();

    // 4. Lắng nghe các tin nhắn Data-Only khi app đang mở
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Got a message whilst in the foreground!");
      print("Message data: ${message.data}");

      final notificationData = message.data;
      if (notificationData['title'] != null && notificationData['body'] != null) {
        _showLocalNotification(
          notificationData['title']!,
          notificationData['body']!,
        );
      }
    });

    // 5. Xử lý khi người dùng nhấn vào thông báo (khi app đang tắt hoặc dưới nền)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      // TODO: Điều hướng người dùng đến màn hình chi tiết tín hiệu
      // Dựa vào `message.data['signalId']`
    });
  }

  // Hàm hiển thị thông báo cục bộ
  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'high_importance_channel', // ID của channel
      'High Importance Notifications', // Tên channel
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0, // ID của thông báo
      title,
      body,
      platformChannelSpecifics,
      // payload: 'item x' // Dữ liệu đính kèm nếu cần
    );
  }

  // Hàm cấu hình ban đầu cho local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // Dùng icon mặc định của app

    // Cần cấu hình thêm cho iOS nếu bạn làm sau này
    // final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      // iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }


  // Hàm lấy token và lưu vào Firestore
  Future<void> _saveFcmTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Lấy FCM token của thiết bị
    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken == null) {
      print('Không thể lấy được FCM token.');
      return;
    }

    print('FCM Token của thiết bị: $fcmToken');

    // Lưu token vào document của người dùng
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': fcmToken});
      print('Đã lưu FCM token vào Firestore thành công.');
    } catch (e) {
      print('Lỗi khi lưu FCM token: $e');
    }
  }
}