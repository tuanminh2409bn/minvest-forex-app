import 'package:flutter/material.dart';

// Model đơn giản để đại diện cho một thông báo
class NotificationItem {
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // --- DỮ LIỆU MẪU ---
  // Trong thực tế, bạn sẽ lấy danh sách này từ Firestore hoặc một service quản lý thông báo
  final List<NotificationItem> _notifications = [
    NotificationItem(
      title: 'New Signal: BUY XAU/USD',
      body: 'Entry price at 2150.50. Check the app for SL and TP levels.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    NotificationItem(
      title: 'Signal Update: EUR/USD TP1 Hit!',
      body: 'Your trade on EUR/USD has reached Take Profit 1. Consider moving SL to entry.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: true,
    ),
    NotificationItem(
      title: 'Welcome to Minvest!',
      body: 'Thank you for joining. Explore our signals and start your trading journey.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];
  // --- KẾT THÚC DỮ LIỆU MẪU ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            return _buildNotificationTile(notification);
          },
        ),
      ),
    );
  }

  // Widget để hiển thị một thông báo
  Widget _buildNotificationTile(NotificationItem notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.transparent : const Color(0xFF152A55).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.1),
          child: const Icon(Icons.notifications, color: Colors.blueAccent),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        subtitle: Text(
          notification.body,
          style: const TextStyle(color: Colors.white70),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          setState(() {
            notification.isRead = true;
          });
          // TODO: Điều hướng đến màn hình chi tiết tín hiệu nếu cần
        },
      ),
    );
  }
}