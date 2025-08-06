// features/signals/screens/signal_screen_web.dart

import 'package:flutter/material.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/signals/services/signal_service.dart';
import 'package:minvest_forex_app/features/signals/widgets/signal_card.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_screen.dart';
import 'package:minvest_forex_app/services/notification_service.dart';
import 'package:minvest_forex_app/features/notifications/screens/notification_screen.dart';
import 'package:provider/provider.dart';

class SignalScreen extends StatefulWidget {
  const SignalScreen({super.key});

  @override
  State<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends State<SignalScreen> {
  // --- TOÀN BỘ LOGIC STATE ĐƯỢC GIỮ NGUYÊN ---
  bool _isLive = true;
  final SignalService _signalService = SignalService();

  @override
  void initState() {
    super.initState();
    NotificationService().initialize();
  }

  bool _isVipWithinGoldenHours() {
    final now = DateTime.now();
    final nowInVietnam = now.toUtc().add(const Duration(hours: 7));
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
              // Header với Tabs và Filters không thay đổi
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTabs(),
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen())),
                    ),
                  ],
                ),
              ),
              _buildFilters(),
              Expanded(
                child: _buildContent(userTier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CÁC HÀM BUILD KHÁC ĐỀU GIỮ NGUYÊN ---
  Widget _buildContent(String userTier) {
    if (_isLive && userTier == 'vip' && !_isVipWithinGoldenHours()) {
      return _buildUpgradeViewForVip();
    }
    return _buildSignalList(userTier);
  }

  // ▼▼▼ THAY ĐỔI QUAN TRỌNG NHẤT NẰM Ở ĐÂY ▼▼▼
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
        if (_isLive && userTier == 'demo' && signals.length > 8) {
          itemCount = 9;
        }

        // BỌC LISTVIEW TRONG CENTER VÀ CONTAINER ĐỂ GIỚI HẠN CHIỀU RỘNG
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800), // Chiều rộng tối đa của danh sách
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (_isLive && userTier == 'demo' && index == 8) {
                  return _buildUpgradeButton();
                }

                final signal = signals[index];
                final bool isLocked = (_isLive && userTier == 'demo' && index >= 8);

                // Truyền SignalCard như bình thường
                return SignalCard(
                  signal: signal,
                  userTier: userTier,
                  isLocked: isLocked,
                );
              },
            ),
          ),
        );
      },
    );
  }


  Widget _buildUpgradeViewForVip() {
    // ... (Giữ nguyên code của bạn)
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_off_outlined, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 20),
          const Text("Out of Golden Hours", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text("VIP signals are available from 8:00 AM to 5:00 PM (GMT+7).\nUpgrade to Elite to get signals 24/24!", style: TextStyle(fontSize: 16, color: Colors.grey[400]), textAlign: TextAlign.center),
          const SizedBox(height: 30),
          _buildUpgradeButton(),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton() {
    // ... (Giữ nguyên code của bạn)
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
    // ... (Giữ nguyên code của bạn)
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
    // ... (Giữ nguyên code của bạn)
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

  Widget _buildFilters() {
    // ... (Giữ nguyên code của bạn)
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GradientFilterButton(text: "SYMBOL", onPressed: () {}),
          _GradientFilterButton(text: "AI SIGNAL", onPressed: () {}),
        ],
      ),
    );
  }
}

class _GradientFilterButton extends StatelessWidget {
  // ... (Giữ nguyên code của bạn)
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