// lib/features/signals/screens/signal_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/signals/services/signal_service.dart';
import 'package:minvest_forex_app/features/signals/widgets/signal_card.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_screen.dart';
import 'package:provider/provider.dart';

class SignalScreen extends StatefulWidget {
  const SignalScreen({super.key});

  @override
  State<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends State<SignalScreen> {
  bool _isLive = true;
  final SignalService _signalService = SignalService();

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userTier = userProvider.userTier ?? 'free';

    // YÊU CẦU: Bỏ AppBar
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
              // Đặt các thành phần của AppBar cũ vào đây
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTabs(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_none),
                    ),
                  ],
                ),
              ),
              _buildFilters(),
              Expanded(
                child: userTier == 'free'
                    ? _buildFreeUserView(context)
                    : _buildSignalList(userTier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreeUserView(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height - 150, // Điều chỉnh chiều cao linh hoạt
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            _buildLockedCardPlaceholder(),
            _buildLockedCardPlaceholder(),
            const Spacer(flex: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UpgradeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF172AFE),
                          Color(0xFF3C4BFE),
                          Color(0xFF5E69FD),
                        ],
                        stops: [0.0, 0.5, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/crown_icon.png',
                            height: 50,
                            width: 50,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Upgrade to see more",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedCardPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151a2e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipOval(
                child: Image.asset('assets/images/us_flag.png', height: 22, width: 22, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              const Text("XAU/USD", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF238636),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("MUA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
              ),
              const Spacer(),
              const Text("NOT MATCHED", style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          const Divider(height: 16, color: Colors.blueGrey),
          Row(
            children: [
              _buildUpgradeItem("Entry"),
              _buildUpgradeItem("SL"),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildUpgradeItem("TP1"),
              _buildUpgradeItem("TP2"),
              _buildUpgradeItem("TP3"),
            ],
          ),
          const SizedBox(height: 8),
          // SỬA LỖI OVERFLOW TRIỆT ĐỂ
          Row(
            children: [
              const Text("20:03 07/08", style: TextStyle(color: Colors.grey, fontSize: 11)),
              const Spacer(),
              Row(
                children: const [
                  Text("see details", style: TextStyle(color: Color(0xFF5865F2), fontSize: 11)),
                  Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF5865F2)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeItem(String title) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Upgrade", style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 2),
              Image.asset(
                'assets/images/crown_icon.png',
                height: 30,
                width: 30,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 60,
              height: 32,
              child: _buildTabItem("LIVE", _isLive, () => setState(() => _isLive = true))
          ),
          SizedBox(
              width: 60,
              height: 32,
              child: _buildTabItem("END", !_isLive, () => setState(() => _isLive = false))
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
            colors: [
              Color(0xFF172AFE),
              Color(0xFF3C4BFE),
              Color(0xFF5E69FD),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            )),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GradientFilterButton(
            text: "SYMBOL",
            onPressed: () {},
          ),
          _GradientFilterButton(
            text: "AI SIGNAL",
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSignalList(String userTier) {
    return StreamBuilder<QuerySnapshot>(
      stream: _isLive
          ? _signalService.getRunningSignals(userTier: userTier)
          : _signalService.getClosedSignals(userTier: userTier),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No signals available.'));
        }
        final signalsDocs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: signalsDocs.length,
          itemBuilder: (context, index) {
            final signal = Signal.fromFirestore(signalsDocs[index]);
            return SignalCard(
              signal: signal,
              userTier: userTier,
              signalIndex: index,
            );
          },
        );
      },
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
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.withOpacity(0.5)),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
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