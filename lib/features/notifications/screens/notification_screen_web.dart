// lib/features/notifications/screens/notification_screen_web.dart

import 'package:flutter/material.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/notifications/models/notification_model.dart';
import 'package:minvest_forex_app/features/signals/services/signal_service.dart';
import 'package:minvest_forex_app/features/signals/screens/signal_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:minvest_forex_app/features/notifications/providers/notification_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart'; // Import l10n

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().markAllNotificationsAsRead();
    });
  }

  void _onNotificationTap(NotificationModel notification) async {
    if (notification.signalId == null) return;

    final signal = await SignalService().getSignalById(notification.signalId!);
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

  String? _extractSymbolFromTitle(String title) {
    // Cải tiến Regex để bắt cả XAU/USD và các cặp tiền tệ khác
    final RegExp regex = RegExp(r'\b([A-Z]{3}\/[A-Z]{3}|XAU\/USD)\b');
    final Match? match = regex.firstMatch(title.toUpperCase());
    return match?.group(0);
  }

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

  @override
  Widget build(BuildContext context) {
    // Lấy l10n để sử dụng
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        scrolledUnderElevation: 0,
        // === FIX: SỬ DỤNG l10n ĐỂ DỊCH TIÊU ĐỀ ===
        title: Text(l10n.notifications, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                if (provider.notifications.isEmpty) {
                  return Center(
                    // Sử dụng l10n
                    child: Text(l10n.noNotificationsYet, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
                  itemCount: provider.notifications.length,
                  itemBuilder: (context, index) {
                    final notification = provider.notifications[index];
                    return _buildNotificationTile(notification);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.transparent : const Color(0xFF152A55).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: _buildLeadingIcon(notification),
        title: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(notification.body, style: const TextStyle(color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => _onNotificationTap(notification),
      ),
    );
  }

  Widget _buildLeadingIcon(NotificationModel notification) {
    final symbol = _extractSymbolFromTitle(notification.title);
    final flagPaths = _getFlagPathsFromSymbol(symbol);

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
    return CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.1),
      child: _getIconForType(notification.type),
    );
  }

  Icon _getIconForType(String type) {
    switch (type) {
      case 'new_signal':
        return const Icon(Icons.new_releases, color: Colors.blueAccent);
      case 'signal_matched':
        return const Icon(Icons.check_circle, color: Colors.blueAccent);
      case 'tp1_hit':
      case 'tp2_hit':
      case 'tp3_hit':
        return const Icon(Icons.flag_circle, color: Colors.blueAccent);
      case 'sl_hit':
        return const Icon(Icons.cancel, color: Colors.blueAccent);
      default:
        return const Icon(Icons.notifications, color: Colors.blueAccent);
    }
  }

  // Hàm này không dùng trong UI web nhưng giữ lại không sao
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
