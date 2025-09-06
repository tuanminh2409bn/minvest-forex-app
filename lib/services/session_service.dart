// lib/services/session_service.dart

import 'dart:io' show Platform;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:minvest_forex_app/services/device_info_service.dart';

class SessionService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  Future<void> updateUserSession() async {
    String? fcmToken;
    bool isSimulator = false;

    try {
      // 1. Cố gắng lấy FCM Token (bước này là tùy chọn, không làm gián đoạn luồng)
      if (kIsWeb) {
        const String vapidKey =
            "BF1kL9v7A-1bOSz642aCWoZEKvFpjKvkMQuTPd_GXBLxNakYt6apNf9Aa25hGk1QJP0VFrCVRx4B9mO8h5gBUA8";

        // =============================================================
        // === SỬA LỖI TẠI ĐÂY: BỌC getToken TRONG TRY-CATCH RIÊNG ===
        // =============================================================
        try {
          fcmToken = await _firebaseMessaging.getToken(vapidKey: vapidKey);
        } catch (e) {
          print('SessionService (Web): Không lấy được FCM token (có thể do người dùng từ chối). Lỗi: $e');
          // Không làm gì cả, cứ để fcmToken là null và tiếp tục.
        }

      } else { // Logic cho Mobile
        if (Platform.isIOS) {
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken == null) {
            isSimulator = true;
            print('SessionService (iOS): Không thể lấy APNS token, có thể là máy ảo.');
          }
        }

        if (!isSimulator) {
          fcmToken = await _firebaseMessaging.getToken();
        }
      }

      // 2. Luôn luôn lấy Device ID (bước này là bắt buộc)
      final deviceId = await DeviceInfoService.getDeviceId();
      print(
          'SessionService: Chuẩn bị cập nhật session với DeviceID: $deviceId và FCM Token: ${fcmToken ?? "N/A"}');

      // 3. Luôn luôn gọi Cloud Function
      // Backend của chúng ta đã được sửa để chấp nhận fcmToken có thể là null.
      final callable = _functions.httpsCallable('manageUserSession');
      await callable.call({'deviceId': deviceId, 'fcmToken': fcmToken});
      print('SessionService: Đã gọi manageUserSession thành công.');

    } catch (e) {
      // Khối catch này giờ chỉ bắt các lỗi không mong muốn khác.
      print('SessionService: Lỗi không xác định khi cập nhật session: $e');
    }
  }
}