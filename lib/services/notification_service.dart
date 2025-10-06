// lib/services/notification_service.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:minvest_forex_app/firebase_options.dart';

// --- BƯỚC 1: TẠO MỘT INSTANCE CỦA PLUGIN THÔNG BÁO CỤC BỘ Ở TOP-LEVEL ---
final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Kênh thông báo cho Android (đưa ra ngoài để cả background handler cũng dùng được)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'minvest_channel_id', // id
  'Minvest Forex Signals', // title
  description: 'Kênh nhận thông báo tín hiệu từ Minvest.', // description
  importance: Importance.max,
  playSound: true,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Bạn vẫn cần dòng này để các plugin khác (nếu có) có thể hoạt động ở chế độ nền.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Chỉ cần log lại là đủ. Không cần làm gì khác để hiển thị thông báo.
  debugPrint("🔥 [FCM_SERVICE] Background message handled (no local notification needed).");
  debugPrint("   - Message data: ${message.data}");
  if (message.notification != null) {
    debugPrint("   - Message also contained a notification: ${message.notification!.title}");
  }
}


// PHẦN CLASS SERVICE GIỮ NGUYÊN NHƯ TRƯỚC
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  bool _isInitialized = false;

  Future<void> initialize({
    required Function(Map<String, dynamic>) onNotificationTapped,
  }) async {
    if (_isInitialized) {
      debugPrint("✅ [FCM_SERVICE] NotificationService đã được khởi tạo trước đó.");
      return;
    }
    debugPrint("🚀 [FCM_SERVICE] Bắt đầu khởi tạo NotificationService...");

    await _requestPermissions();

    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _createAndroidChannel();

    await _initializeLocalNotifications(onNotificationTapped);

    _setupMessageListeners(onNotificationTapped);

    _isInitialized = true;
    debugPrint("✅ [FCM_SERVICE] Khởi tạo NotificationService thành công!");
  }

  Future<void> _requestPermissions() async {
    debugPrint("🔐 [FCM_SERVICE] Đang xin quyền nhận thông báo...");
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint("🔐 [FCM_SERVICE] Trạng thái quyền: ${settings.authorizationStatus}");
  }

  Future<void> _createAndroidChannel() async {
    if (!kIsWeb) {
      debugPrint("📡 [FCM_SERVICE] Đang tạo kênh thông báo cho Android...");
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      debugPrint("📡 [FCM_SERVICE] Đã tạo kênh '${channel.id}' thành công.");
    }
  }

  Future<void> _initializeLocalNotifications(
      Function(Map<String, dynamic>) onNotificationTapped) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint("⚫️ [FCM_SERVICE] Local notification tapped with payload: ${response.payload}");
        if (response.payload != null && response.payload!.isNotEmpty) {
          onNotificationTapped({'signalId': response.payload});
        }
      },
    );
  }

  void _setupMessageListeners(Function(Map<String, dynamic>) onNotificationTapped) {
    debugPrint("🎧 [FCM_SERVICE] Đang cài đặt các trình lắng nghe tin nhắn...");

    // ▼▼▼ THAY ĐỔI Ở ĐÂY ▼▼▼
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("🟢 [FCM_SERVICE] Foreground message received: ${message.data}");

      // Lấy title và body từ message.notification thay vì message.data
      final RemoteNotification? notification = message.notification;
      final String? title = notification?.title;
      final String? body = notification?.body;

      if (title != null && body != null) {
        _showLocalNotification(
          title: title,
          body: body,
          payload: message.data['signalId'] ?? '',
        );
      }
    });
    // ▲▲▲ KẾT THÚC THAY ĐỔI ▲▲▲

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("🔵 [FCM_SERVICE] Background message tapped: ${message.data}");
      onNotificationTapped(message.data);
    });

    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("🔴 [FCM_SERVICE] Terminated message tapped: ${message.data}");
        onNotificationTapped(message.data);
      }
    });
  }

  void _showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) {
    _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
    debugPrint("📱 [FCM_SERVICE] Hiển thị thông báo cục bộ thành công.");
  }

  Future<String?> getFcmToken() async {
    try {
      String? token;
      if (kIsWeb) {
        token = await _firebaseMessaging.getToken(
          vapidKey: "BF1kL9v7A-1bOSz642aCWoZEKvFpjKvkMQuTPd_GXBLxNakYt6apNf9Aa25hGk1QJP0VFrCVRx4B9mO8h5gBUA8",
        );
      } else {
        token = await _firebaseMessaging.getToken();
      }
      debugPrint("🔑 [FCM_SERVICE] FCM Token: $token");
      return token;
    } catch (e) {
      debugPrint("🚨 [FCM_SERVICE] Lỗi khi lấy FCM Token: $e");
      return null;
    }
  }
}