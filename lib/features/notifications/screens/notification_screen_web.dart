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
  // --- DỮ LIỆU MẪU (Đã bổ sung đa dạng cặp tiền) ---
  final List<NotificationItem> _notifications = [
    NotificationItem(
      title: 'New Signal: BUY XAU/USD',
      body: 'Entry price at 2350.50. Check the app for SL and TP levels.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    NotificationItem(
      title: 'Signal Update: EUR/USD TP1 Hit!',
      body: 'Your trade on EUR/USD has reached Take Profit 1. Consider moving SL to entry.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: true,
    ),
    NotificationItem(
      title: 'New Signal: SELL GBP/JPY',
      body: 'A selling opportunity has been identified for GBP/JPY.',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    NotificationItem(
      title: 'Welcome to Minvest!',
      body: 'Thank you for joining. Explore our signals and start your trading journey.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    NotificationItem(
      title: 'Signal Closed: AUD/USD',
      body: 'The previous signal for AUD/USD has been closed.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];
  // --- KẾT THÚC DỮ LIỆU MẪU ---

  // --- LOGIC HIỂN THỊ CỜ (TÁI SỬ DỤNG TỪ SIGNAL_CARD) ---

  // Map chứa đường dẫn cờ.
  static const Map<String, String> _currencyFlags = {
    'AUD': 'assets/images/aud_flag.png',
    'CHF': 'assets/images/chf_flag.png',
    'EUR': 'assets/images/eur_flag.png',
    'GBP': 'assets/images/gbp_flag.png',
    'JPY': 'assets/images/jpy_flag.png',
    'NZD': 'assets/images/nzd_flag.png',
    'USD': 'assets/images/us_flag.png',
    'XAU': 'assets/images/crown_icon.png',
  };

  // Hàm trích xuất symbol từ tiêu đề thông báo
  String? _extractSymbolFromTitle(String title) {
    // Biểu thức chính quy tìm một chuỗi có dạng 3 chữ cái, dấu gạch chéo, 3 chữ cái
    final RegExp regex = RegExp(r'([A-Z]{3}\/[A-Z]{3})');
    final Match? match = regex.firstMatch(title.toUpperCase());
    return match?.group(0); // Trả về chuỗi khớp, ví dụ "EUR/USD"
  }

  // Hàm lấy cặp cờ từ symbol
  List<String> _getFlagPathsFromSymbol(String? symbol) {
    if (symbol == null) return [];

    final parts = symbol.toUpperCase().split('/');
    if (parts.length == 2) {
      final path1 = _currencyFlags[parts[0]];
      final path2 = _currencyFlags[parts[1]];
      return [
        if (path1 != null) path1,
        if (path2 != null) path2,
      ];
    }
    return [];
  }

  // --- KẾT THÚC LOGIC HIỂN THỊ CỜ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // === THAY ĐỔI 1: SỬA MÀU APPBAR ===
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
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
        // === THAY ĐỔI 2: CO GIÃN GIAO DIỆN ===
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900), // Giới hạn chiều rộng
            child: _notifications.isEmpty
                ? const Center(
              child: Text(
                'No notifications yet.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationTile(notification);
              },
            ),
          ),
        ),
      ),
    );
  }

  // Widget để hiển thị một thông báo (ĐÃ CẬP NHẬT)
  Widget _buildNotificationTile(NotificationItem notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.transparent : const Color(0xFF152A55).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
      ),
      child: ListTile(
        // Thay thế icon tĩnh bằng widget động
        leading: _buildLeadingIcon(notification),
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

  // Widget mới để quyết định hiển thị cờ hay icon mặc định
  Widget _buildLeadingIcon(NotificationItem notification) {
    final symbol = _extractSymbolFromTitle(notification.title);
    final flagPaths = _getFlagPathsFromSymbol(symbol);

    // Nếu tìm thấy cờ, hiển thị chúng
    if (flagPaths.isNotEmpty) {
      return SizedBox(
        width: 42,
        height: 28,
        child: Stack(
          children: List.generate(flagPaths.length, (index) {
            return Positioned(
              left: index * 14.0,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey.shade800,
                backgroundImage: AssetImage(flagPaths[index]),
              ),
            );
          }),
        ),
      );
    }

    // Nếu không, hiển thị icon chuông mặc định
    return CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.1),
      child: const Icon(Icons.notifications, color: Colors.blueAccent),
    );
  }
}
