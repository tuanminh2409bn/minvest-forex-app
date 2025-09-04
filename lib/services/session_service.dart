//lib/services/session_service.dart

import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:minvest_forex_app/services/device_info_service.dart';

class SessionService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  Future<void> updateUserSession() async {
    String? fcmToken;

    try {
      // 1. Lấy FCM Token
      if (kIsWeb) {
        const String vapidKey = "BF1kL9v7A-1bOSz642aCWoZEKvFpjKvkMQuTPd_GXBLxNakYt6apNf9Aa25hGk1QJP0VFrCVRx4B9mO8h5gBUA8";
        fcmToken = await _firebaseMessaging.getToken(vapidKey: vapidKey);
      } else {
        // Chỉ trên iOS, thực hiện kiểm tra APNS token
        if (Platform.isIOS) {
          // Thử lấy APNS token. Trên máy ảo, nó sẽ là null.
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          print('SessionService: APNS Token là: $apnsToken');

          // Nếu đang chạy trên máy ảo và không có APNS token, chúng ta không cần làm gì thêm.
          // Đoạn mã này giúp ứng dụng không bị lỗi trên simulator.
          if (apnsToken == null) {
            print('SessionService: Không thể lấy APNS token. Có thể bạn đang chạy trên máy ảo. Bỏ qua bước lấy FCM token.');
            // Trên máy ảo, chúng ta có thể dừng ở đây để tránh lỗi không cần thiết
            // Nếu bạn vẫn muốn tiếp tục để test logic khác, có thể comment dòng return này đi.
            return;
          }
        }

        // Chỉ khi có APNS token (trên máy thật), chúng ta mới lấy FCM token
        fcmToken = await _firebaseMessaging.getToken();
      }

      if (fcmToken == null) {
        print('SessionService: Không thể lấy được FCM token.');
        return;
      }

      // 2. Lấy Device ID
      final deviceId = await DeviceInfoService.getDeviceId();
      print('SessionService: Cập nhật session với DeviceID: $deviceId và FCM Token: $fcmToken');

      // 3. Gọi Cloud Function
      final callable = _functions.httpsCallable('manageUserSession');
      await callable.call({'deviceId': deviceId, 'fcmToken': fcmToken});
      print('SessionService: Đã gọi manageUserSession thành công.');

    } catch (e) {
      // Bắt lỗi cụ thể hơn
      if (e is FirebaseException && e.code == 'apns-token-not-set') {
        print('SessionService: Lỗi đã được dự đoán trên máy ảo: $e');
      } else {
        print('SessionService: Lỗi không xác định khi cập nhật session: $e');
      }
    }
  }
}