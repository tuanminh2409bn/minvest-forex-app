// lib/features/signals/screens/signal_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_screen.dart';
import 'package:provider/provider.dart';

class SignalDetailScreen extends StatelessWidget {
  final Signal signal;

  const SignalDetailScreen({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final userTier = Provider.of<UserProvider>(context, listen: false).userTier;
    final bool canViewReason = userTier == 'elite';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset('assets/images/us_flag.png', height: 24, width: 24, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            Text(signal.symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
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
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildDetailCard(context, canViewReason),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, bool canViewReason) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151a2e),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Status', signal.status.toUpperCase(),
              valueColor: signal.status == 'running' ? Colors.amber : Colors.grey),
          _buildInfoRow('Sent on', DateFormat('HH:mm dd/MM/yyyy').format(signal.createdAt.toDate())),
          const Divider(height: 30, color: Colors.blueGrey),
          // YÊU CẦU: Sửa định dạng số
          _buildPriceRow('Entry price', signal.entryPrice.toStringAsFixed(1), signal.result),
          _buildPriceRow('Stop loss', signal.stopLoss.toStringAsFixed(1), signal.result),
          _buildPriceRow('Take profit 1', signal.takeProfits.isNotEmpty ? signal.takeProfits[0].toStringAsFixed(1) : '—', signal.result),
          _buildPriceRow('Take profit 2', signal.takeProfits.length > 1 ? signal.takeProfits[1].toStringAsFixed(1) : '—', signal.result),
          _buildPriceRow('Take profit 3', signal.takeProfits.length > 2 ? signal.takeProfits[2].toStringAsFixed(1) : '—', signal.result),
          const Divider(height: 30, color: Colors.blueGrey),
          const Text(
            'REASON',
            style: TextStyle(color: Color(0xFF5865F2), fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          canViewReason
              ? Text(
            signal.reason ?? 'No reason provided for this signal.',
            style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 14),
          )
              : _buildUpgradeToView(context),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor ?? Colors.white)),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String title, String value, String? status) {
    Color valueColor = Colors.white;
    Icon? statusIcon;
    String titleNormalized = title.replaceAll(' ', '').toLowerCase();

    if (status != null && status.isNotEmpty) {
      if (status.toLowerCase().contains(titleNormalized + 'hit')) {
        valueColor = const Color(0xFF238636);
        statusIcon = const Icon(Icons.check_circle, color: Color(0xFF238636), size: 18);
      } else if (status.toLowerCase() == 'slhit' && titleNormalized == 'stoploss') {
        valueColor = const Color(0xFFDA3633);
        statusIcon = const Icon(Icons.cancel, color: Color(0xFFDA3633), size: 18);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Row(
            children: [
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
              if (statusIcon != null) ...[
                const SizedBox(width: 8),
                statusIcon,
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeToView(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Upgrade your account to Elite to view the analysis and reasons for entering the order.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 20),
          // --- BẮT ĐẦU ĐOẠN CODE ĐÃ SỬA ---
          SizedBox(
            height: 50, // Đặt chiều cao cho nút
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UpgradeScreen()),
                );
              },
              // Bỏ padding và màu nền ở đây
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  // Áp dụng gradient bạn yêu cầu
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF172AFE),
                      Color(0xFF3C4BFE),
                      Color(0xFF5E69FD),
                    ],
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
                      Image.asset('assets/images/crown_icon.png', height: 30, width: 30),
                      const SizedBox(width: 8),
                      const Text("Upgrade to see more"),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}