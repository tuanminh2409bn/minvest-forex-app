// lib/features/notifications/screens/notification_screen_mobile.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/notifications/models/notification_model.dart';
import 'package:minvest_forex_app/features/signals/services/signal_service.dart';
import 'package:minvest_forex_app/features/signals/screens/signal_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:minvest_forex_app/features/notifications/providers/notification_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {

  @override
  void initState() {
    super.initState();
    // ▼▼▼ LOGIC CỐT LÕI: ĐÁNH DẤU ĐÃ ĐỌC KHI MỞ MÀN HÌNH ▼▼▼
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().markAllNotificationsAsRead();
    });
  }

  // Hàm điều hướng khi nhấn vào thông báo
  void _onNotificationTap(NotificationModel notification) async {
    if (notification.signalId == null) return;

    final signal = await SignalService().getSignalById(notification.signalId!);
    // Lấy userTier một cách an toàn
    final userTier = context.read<UserProvider>().userTier ?? 'free';

    if (signal != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignalDetailScreen(
            signal: signal,
            userTier: userTier,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.notifications.isEmpty) {
            return const Center(
              child: Text(
                'Không có thông báo nào.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.notifications.length,
            itemBuilder: (context, index) {
              final notification = provider.notifications[index];
              final timeAgo = _formatTimestamp(notification.timestamp);

              return ListTile(
                onTap: () => _onNotificationTap(notification),
                leading: CircleAvatar(
                  backgroundColor: notification.isRead
                      ? Colors.blueGrey.withOpacity(0.3)
                      : const Color(0xFF5865F2),
                  child: _getIconForType(notification.type),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  '${notification.body}\n$timeAgo',
                  style: TextStyle(
                    color: notification.isRead ? Colors.grey.shade500 : Colors.grey.shade300,
                  ),
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }

  Icon _getIconForType(String type) {
    switch (type) {
      case 'new_signal':
        return const Icon(Icons.new_releases, color: Colors.white, size: 20);
      case 'signal_matched':
        return const Icon(Icons.check_circle_outline, color: Colors.white, size: 20);
      case 'tp1_hit':
      case 'tp2_hit':
      case 'tp3_hit':
        return const Icon(Icons.flag_circle_outlined, color: Colors.white, size: 20);
      case 'sl_hit':
        return const Icon(Icons.cancel_outlined, color: Colors.white, size: 20);
      default:
        return const Icon(Icons.notifications, color: Colors.white, size: 20);
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    final Duration diff = DateTime.now().difference(date);
    if (diff.inDays > 1) {
      return '${diff.inDays} ngày trước';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}