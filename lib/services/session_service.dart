import 'dart:io' show Platform; // Thêm import để kiểm tra nền tảng (iOS/Android)
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:minvest_forex_app/services/device_info_service.dart';

class SessionService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  // Hàm này sẽ được gọi mỗi khi người dùng đăng nhập thành công
  Future<void> updateUserSession() async {
    String? fcmToken;

    try {
      // 1. Lấy FCM Token cho nền tảng tương ứng
      if (kIsWeb) {
        const String vapidKey = "BF1kL9v7A-1bOSz642aCWoZEKvFpjKvkMQuTPd_GXBLxNakYt6apNf9Aa25hGk1QJP0VFrCVRx4B9mO8h5gBUA8";
        fcmToken = await _firebaseMessaging.getToken(vapidKey: vapidKey);
      } else {
        // **Đây là phần thay đổi quan trọng**
        // CHỈ TRÊN iOS: Yêu cầu APNS token trước để đảm bảo nó đã sẵn sàng.
        if (Platform.isIOS) {
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          print('SessionService: APNS Token cho iOS là: $apnsToken');
        }

        // Sau khi đã yêu cầu APNS, việc lấy FCM token sẽ an toàn hơn.
        fcmToken = await _firebaseMessaging.getToken();
      }

      if (fcmToken == null) {
        print('SessionService: Không thể lấy được FCM token.');
        return;
      }

      // 2. Lấy Device ID
      final deviceId = await DeviceInfoService.getDeviceId();

      print('SessionService: Cập nhật session với DeviceID: $deviceId và FCM Token: $fcmToken');

      // 3. Gọi Cloud Function để cập nhật session và đăng xuất thiết bị cũ
      final callable = _functions.httpsCallable('manageUserSession');
      await callable.call({'deviceId': deviceId, 'fcmToken': fcmToken});

      print('SessionService: Đã gọi manageUserSession thành công.');

    } catch (e) {
      print('SessionService: Lỗi khi cập nhật session: $e');
    }
  }
}