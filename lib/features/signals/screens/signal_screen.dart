import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/signals/services/signal_service.dart';
import 'package:minvest_forex_app/features/signals/widgets/signal_card.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Signals"),
        centerTitle: false,
        // TODO: Thêm nút chuông và các bộ lọc
      ),
      body: Column(
        children: [
          _buildFilterToggle(),
          Expanded(
            child: userTier == 'free'
                ? _buildFreeUserView(context)
                : _buildSignalList(userTier),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị danh sách tín hiệu
  Widget _buildSignalList(String userTier) {
    return StreamBuilder<QuerySnapshot>(
      // --- SỬA LỖI 1: Truyền userTier vào service ---
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
              // --- SỬA LỖI 2: Cung cấp signalIndex ---
              signalIndex: index,
            );
          },
        );
      },
    );
  }

  // Giao diện cho tài khoản Free, hiển thị các card bị khóa
  Widget _buildFreeUserView(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // Hiển thị một vài card bị khóa để minh họa
              _buildLockedCardPlaceholder(),
              _buildLockedCardPlaceholder(),
            ],
          ),
        ),
        // Nút Upgrade lớn ở dưới cùng
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.workspace_premium, color: Colors.black),
            label: const Text(
              "Upgrade to see more",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              // TODO: Điều hướng đến trang nâng cấp
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        )
      ],
    );
  }

  // Widget card bị khóa mẫu
  Widget _buildLockedCardPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D3436).withOpacity(0.8),
            const Color(0xFF1E272E).withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.lock_outline, color: Colors.amber, size: 24),
          Column(
            children: [
              Text("UPGRADE", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              Text("to unlock all signals", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
        ],
      ),
    );
  }

  // Widget bộ lọc LIVE/END
  Widget _buildFilterToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLive = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isLive ? Colors.blue.shade700 : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Center(child: Text("LIVE", style: TextStyle(fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLive = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isLive ? Colors.blue.shade700 : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Center(child: Text("END", style: TextStyle(fontWeight: FontWeight.bold))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}