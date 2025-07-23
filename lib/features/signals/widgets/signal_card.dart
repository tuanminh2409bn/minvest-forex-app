// lib/features/signals/widgets/signal_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/signals/screens/signal_detail_screen.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_screen.dart';

class SignalCard extends StatelessWidget {
  final Signal signal;
  final String userTier;
  final int signalIndex;

  const SignalCard({
    super.key,
    required this.signal,
    required this.userTier,
    required this.signalIndex,
  });

  @override
  Widget build(BuildContext context) {
    final bool shouldObfuscate = userTier == 'demo' && signalIndex >= 8;

    return GestureDetector(
      onTap: () {
        if (userTier != 'free' && !shouldObfuscate) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SignalDetailScreen(signal: signal)),
          );
        } else if (shouldObfuscate) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UpgradeScreen()),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF151a2e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            _buildCardHeader(),
            const Divider(height: 16, color: Colors.blueGrey),
            shouldObfuscate ? _buildUpgradeView() : _buildSignalData(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader() {
    final bool isBuy = signal.type.toLowerCase() == 'buy';
    final Color signalColor = isBuy ? const Color(0xFF238636) : const Color(0xFFDA3633);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipOval(
          child: Image.asset('assets/images/us_flag.png', height: 22, width: 22, fit: BoxFit.cover),
        ),
        const SizedBox(width: 8),
        Text(signal.symbol, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: signalColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(signal.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white)),
        ),
        const Spacer(),
        Text(
          signal.isMatched ? "MATCHED" : "NOT MATCHED",
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSignalData() {
    return Column(
      children: [
        Row(
          children: [
            _buildInfoColumn("Entry", signal.entryPrice.toStringAsFixed(1)),
            // YÊU CẦU: Thêm icon dấu X đỏ cho SL
            _buildInfoColumn(
              "SL",
              signal.stopLoss.toStringAsFixed(1),
              valueColor: Colors.red,
              icon: const Icon(Icons.cancel, color: Colors.red, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // YÊU CẦU: Thêm icon dấu tích xanh cho TP1
            _buildInfoColumn(
              "TP1",
              signal.takeProfits.isNotEmpty ? signal.takeProfits[0].toStringAsFixed(1) : "---",
              valueColor: Colors.green,
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 14),
            ),
            _buildInfoColumn("TP2", signal.takeProfits.length > 1 ? signal.takeProfits[1].toStringAsFixed(1) : "---", valueColor: Colors.green),
            _buildInfoColumn("TP3", signal.takeProfits.length > 2 ? signal.takeProfits[2].toStringAsFixed(1) : "---", valueColor: Colors.green),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(DateFormat('HH:mm dd/MM/yyyy').format(signal.createdAt.toDate()), style: const TextStyle(color: Colors.white, fontSize: 11)),
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
    );
  }

  Widget _buildUpgradeView() {
    return Column(
      children: [
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
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Login to see more...", style: TextStyle(color: Colors.grey, fontSize: 11)),
            Row(
              children: [
                Text("Upgrade Now", style: TextStyle(color: Color(0xFF5865F2), fontSize: 11, fontWeight: FontWeight.bold)),
                Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF5865F2)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpgradeItem(String title) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Upgrade", style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 2),
              Image.asset('assets/images/crown_icon.png', height: 30, width: 30),
            ],
          )
        ],
      ),
    );
  }

  // Widget con hiển thị thông tin giá đã được nâng cấp
  Widget _buildInfoColumn(String title, String value, {Color? valueColor, Widget? icon}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? Colors.white)),
              // Hiển thị icon nếu được cung cấp
              if (icon != null) ...[
                const SizedBox(width: 4),
                icon,
              ]
            ],
          )
        ],
      ),
    );
  }
}