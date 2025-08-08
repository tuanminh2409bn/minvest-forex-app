// lib/features/signals/screens/signal_screen_web.dart

import 'package:flutter/material.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/signals/services/signal_service.dart';
import 'package:minvest_forex_app/features/signals/widgets/signal_card.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_screen.dart';
import 'package:minvest_forex_app/features/notifications/screens/notification_screen.dart';
import 'package:provider/provider.dart';
import 'package:minvest_forex_app/features/notifications/providers/notification_provider.dart';

class SignalScreen extends StatefulWidget {
  const SignalScreen({super.key});

  @override
  State<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends State<SignalScreen> {
  bool _isLive = true;
  final SignalService _signalService = SignalService();

  bool _isWithinGoldenHours() {
    final nowInVietnam = DateTime.now().toUtc().add(const Duration(hours: 7));
    return nowInVietnam.hour >= 8 && nowInVietnam.hour < 17;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userTier = userProvider.userTier ?? 'demo';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    _buildTabs(),
                    const SizedBox(width: 40),
                    _buildFilters(),
                    const Spacer(),
                    Consumer<NotificationProvider>(
                      builder: (context, notificationProvider, child) {
                        final bool hasUnread = notificationProvider.unreadCount > 0;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_none, size: 28),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const NotificationScreen()),
                                );
                              },
                            ),
                            if (hasUnread)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  height: 9,
                                  width: 9,
                                  decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      border: Border.fromBorderSide(BorderSide(color: Color(0xFF0D1117), width: 1.5))
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildContent(userTier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(String userTier) {
    if (_isLive && (userTier == 'vip' || userTier == 'demo') && !_isWithinGoldenHours()) {
      return _buildOutOfHoursView(userTier);
    }
    return _buildSignalList(userTier);
  }

  // ▼▼▼ HÀM NÀY ĐƯỢC NÂNG CẤP ĐỂ DÙNG LAYOUT BLOG FEED ▼▼▼
  Widget _buildSignalList(String userTier) {
    return StreamBuilder<List<Signal>>(
      stream: _signalService.getSignals(isLive: _isLive, userTier: userTier),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No signals available.'));
        }

        final signals = snapshot.data!;
        int itemCount = signals.length;
        bool Function(int) isLockedCallback;

        switch (userTier) {
          case 'free':
            itemCount = signals.length > 2 ? 2 : signals.length;
            isLockedCallback = (index) => true;
            break;
          case 'demo':
            if (_isLive && signals.length > 8) {
              itemCount = 9;
            }
            isLockedCallback = (index) => _isLive && index >= 8;
            break;
          default:
            isLockedCallback = (index) => false;
            break;
        }

        // SỬ DỤNG ListView bọc trong Center và ConstrainedBox
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700), // Chiều rộng của feed
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (userTier == 'demo' && _isLive && index == 8) {
                  return _buildUpgradeButton();
                }

                final signal = signals[index];
                final bool isLocked = isLockedCallback(index);

                return SignalCard(
                  signal: signal,
                  userTier: userTier,
                  isLocked: isLocked,
                  textScaleFactor: 1.1, // Tăng 10% kích thước chữ trên web
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ▼▼▼ HÀM NÀY ĐƯỢC SỬA LẠI CHO GỌN GÀNG ▼▼▼
  Widget _buildFilters() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GradientFilterButton(text: "SYMBOL", onPressed: () {}),
        const SizedBox(width: 20), // Tạo khoảng cách cố định
        _GradientFilterButton(text: "AI SIGNAL", onPressed: () {}),
      ],
    );
  }

  // --- CÁC HÀM VÀ WIDGET CON KHÁC GIỮ NGUYÊN ---
  Widget _buildOutOfHoursView(String userTier) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_off_outlined, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 20),
          const Text(
            "Out of Golden Hours",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            userTier == 'vip'
                ? "VIP signals are available from 8:00 AM to 5:00 PM (GMT+7).\nUpgrade to Elite to get signals 24/24!"
                : "Demo signals are available from 8:00 AM to 5:00 PM (GMT+7).\nUpgrade your account for more benefits!",
            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildUpgradeButton(),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UpgradeScreen())),
          style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF172AFE), Color(0xFF3C4BFE), Color(0xFF5E69FD)], stops: [0.0, 0.5, 1.0], begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/crown_icon.png', height: 24, width: 24),
                  const SizedBox(width: 8),
                  const Text("Upgrade Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 60, height: 32, child: _buildTabItem("LIVE", _isLive, () => setState(() => _isLive = true))),
          SizedBox(width: 60, height: 32, child: _buildTabItem("END", !_isLive, () => setState(() => _isLive = false))),
        ],
      ),
    );
  }

  Widget _buildTabItem(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(colors: [Color(0xFF172AFE), Color(0xFF3C4BFE), Color(0xFF5E69FD)], begin: Alignment.centerLeft, end: Alignment.centerRight) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
      ),
    );
  }
}

class _GradientFilterButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _GradientFilterButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.withOpacity(0.5)),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}