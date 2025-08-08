// lib/features/notifications/providers/notification_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:minvest_forex_app/features/notifications/models/notification_model.dart';
import 'package:minvest_forex_app/features/notifications/services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _unreadCountSubscription;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  NotificationProvider() {
    // Bắt đầu lắng nghe ngay khi provider được tạo
    _listenToNotifications();
  }

  void _listenToNotifications() {
    // Hủy các listener cũ để tránh rò rỉ bộ nhớ
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();

    // Lắng nghe danh sách thông báo
    _notificationsSubscription = _notificationService.getNotifications().listen((notificationsList) {
      _notifications = notificationsList;
      notifyListeners(); // Thông báo cho UI build lại
    });

    // Lắng nghe số lượng thông báo chưa đọc
    _unreadCountSubscription = _notificationService.getUnreadNotificationCount().listen((count) {
      _unreadCount = count;
      notifyListeners(); // Thông báo cho UI build lại (cập nhật dấu chấm đỏ)
    });
  }

  // Hàm được gọi khi người dùng mở màn hình thông báo
  Future<void> markAllNotificationsAsRead() async {
    await _notificationService.markAllAsRead();
    // Sau khi đánh dấu đã đọc, unreadCount sẽ tự động cập nhật về 0
    // nhờ vào listener ở trên, không cần gọi notifyListeners() ở đây.
  }

  @override
  void dispose() {
    // Rất quan trọng: Hủy tất cả các listener khi provider bị hủy
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.dispose();
  }
}