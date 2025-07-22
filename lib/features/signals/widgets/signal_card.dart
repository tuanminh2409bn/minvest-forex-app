import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/signals/screens/signal_detail_screen.dart';

class SignalCard extends StatelessWidget {
  final Signal signal;
  final String userTier;
  final int signalIndex; // Thêm chỉ số của tín hiệu

  const SignalCard({
    super.key,
    required this.signal,
    required this.userTier,
    required this.signalIndex,
  });

  String _getFlagAsset(String currency) {
    return 'assets/images/${currency.toLowerCase()}_flag.png';
  }

  @override
  Widget build(BuildContext context) {
    final bool isBuy = signal.type.toLowerCase() == 'buy';
    final Color signalColor = isBuy ? const Color(0xFF00B894) : const Color(0xFFD63031);

    // --- LOGIC MỚI CHO TÀI KHOẢN DEMO ---
    // Che mờ thông tin nếu là tài khoản Demo và tín hiệu thứ 9 trở đi
    final bool shouldObfuscate = userTier == 'demo' && signalIndex >= 8;

    return GestureDetector(
      onTap: () {
        // Chỉ cho phép xem chi tiết nếu không phải tài khoản Free/Demo
        if (userTier != 'free' && !shouldObfuscate) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SignalDetailScreen(signal: signal)),
          );
        }
      },
      child: Container(
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
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 30,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        child: Image.asset(_getFlagAsset(signal.symbol.substring(0, 3)), height: 30, width: 45, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        child: Image.asset(_getFlagAsset(signal.symbol.substring(3, 6)), height: 30, width: 45, fit: BoxFit.cover),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(signal.symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: signalColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    signal.type.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white12),

            // --- HIỂN THỊ DỮ LIỆU HOẶC NÚT UPGRADE ---
            shouldObfuscate ? _buildUpgradeView() : _buildSignalData(signalColor),
          ],
        ),
      ),
    );
  }

  // Giao diện cho tài khoản VIP/Elite
  Widget _buildSignalData(Color signalColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoColumn("Entry", signal.entryPrice.toStringAsFixed(5)),
            _buildInfoColumn("Stop loss", signal.stopLoss.toStringAsFixed(5)),
            _buildInfoColumn("Take profit", signal.takeProfits.isNotEmpty ? signal.takeProfits[0].toStringAsFixed(5) : "---"),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('HH:mm - dd/MM/yyyy').format(signal.createdAt.toDate()),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: signal.isMatched ? signalColor : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                signal.isMatched ? "MATCHED" : "NOT MATCHED",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        )
      ],
    );
  }

  // Giao diện cho tài khoản Demo (bị che mờ)
  Widget _buildUpgradeView() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        const Icon(Icons.lock_outline, color: Colors.amber, size: 24),
        Column(
          children: [
            const Text("UPGRADE", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            Text("to see signal details", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
        const Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
      ],
    );
  }

  Widget _buildInfoColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}