// lib/features/signals/widgets/signal_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/signals/screens/signal_detail_screen.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_screen.dart';

class SignalCard extends StatelessWidget {
  final Signal signal;
  final String userTier;
  final bool isLocked;

  const SignalCard({
    super.key,
    required this.signal,
    required this.userTier,
    required this.isLocked,
  });

  // Map chứa đường dẫn cờ. Dễ dàng quản lý và mở rộng.
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

  // Hàm lấy cặp cờ từ symbol
  List<String> _getFlagPathsFromSymbol(String symbol) {
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
    // Hàm build chính giữ nguyên
    return GestureDetector(
      onTap: () {
        if (isLocked) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UpgradeScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SignalDetailScreen(
                  signal: signal,
                  userTier: userTier,
                )),
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
            isLocked ? _buildUpgradeView() : _buildSignalData(),
          ],
        ),
      ),
    );
  }

  // ▼▼▼ HÀM NÀY ĐÃ ĐƯỢC NÂNG CẤP HOÀN CHỈNH ▼▼▼
  Widget _buildCardHeader() {
    final bool isBuy = signal.type.toLowerCase() == 'buy';
    final Color signalColor = isBuy ? const Color(0xFF238636) : const Color(0xFFDA3633);
    final List<String> flagPaths = _getFlagPathsFromSymbol(signal.symbol);

    // --- LOGIC MỚI ĐỂ XỬ LÝ TRẠNG THÁI HIỂN THỊ ---
    String statusText;
    Color statusColor;
    IconData? statusIcon;

    if (signal.status == 'running') { // Các tín hiệu LIVE
      if (signal.result == 'TP1 Hit' || signal.result == 'TP2 Hit') {
        statusText = signal.result!;
        statusColor = Colors.tealAccent.shade400;
        statusIcon = Icons.flag_circle;
      } else if (signal.isMatched) {
        statusText = 'MATCHED';
        statusColor = Colors.greenAccent.shade400;
        statusIcon = Icons.check_circle_outline;
      } else {
        statusText = 'NOT MATCHED';
        statusColor = Colors.amber.shade400;
        statusIcon = Icons.hourglass_empty;
      }
    } else { // Các tín hiệu END
      statusText = signal.result?.toUpperCase() ?? 'CLOSED';
      switch (statusText) {
        case 'SL HIT':
          statusColor = Colors.redAccent;
          break;
        case 'CANCELLED (NEW SIGNAL)':
        case 'CANCELLED':
          statusText = 'CANCELLED';
          statusColor = Colors.grey;
          break;
        default: // TP3 HIT, EXITED, ...
          statusColor = Colors.blueGrey.shade200;
          break;
      }
    }
    // --- KẾT THÚC LOGIC MỚI ---

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (flagPaths.isNotEmpty)
          SizedBox(
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
          ),
        const SizedBox(width: 8),
        Text(signal.symbol,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: signalColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(signal.type.toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.white)),
        ),
        const Spacer(),
        // Hiển thị trạng thái mới
        Row(
          children: [
            if (statusIcon != null)
              Icon(statusIcon, color: statusColor, size: 14),
            if (statusIcon != null) const SizedBox(width: 4),
            Text(
              statusText,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignalData() {
    // ▼▼▼ THAY ĐỔI DUY NHẤT NẰM Ở ĐÂY ▼▼▼
    const int decimalPlaces = 2;

    return Column(
      children: [
        Row(
          children: [
            _buildInfoColumn(
                "Entry", signal.entryPrice.toStringAsFixed(decimalPlaces)),
            _buildInfoColumn(
              "SL",
              signal.stopLoss.toStringAsFixed(decimalPlaces),
              valueColor: Colors.red,
              icon: const Icon(Icons.cancel, color: Colors.red, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildInfoColumn(
              "TP1",
              signal.takeProfits.isNotEmpty
                  ? signal.takeProfits[0].toStringAsFixed(decimalPlaces)
                  : "---",
              valueColor: Colors.green,
              icon:
              const Icon(Icons.check_circle, color: Colors.green, size: 14),
            ),
            _buildInfoColumn(
                "TP2",
                signal.takeProfits.length > 1
                    ? signal.takeProfits[1].toStringAsFixed(decimalPlaces)
                    : "---",
                valueColor: Colors.green),
            _buildInfoColumn(
                "TP3",
                signal.takeProfits.length > 2
                    ? signal.takeProfits[2].toStringAsFixed(decimalPlaces)
                    : "---",
                valueColor: Colors.green),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(DateFormat('HH:mm dd/MM/yyyy').format(signal.createdAt.toDate()),
                style: const TextStyle(color: Colors.white, fontSize: 11)),
            const Spacer(),
            Row(
              children: const [
                Text("see details",
                    style: TextStyle(color: Color(0xFF5865F2), fontSize: 11)),
                Icon(Icons.arrow_forward_ios,
                    size: 11, color: Color(0xFF5865F2)),
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
            Text("Upgrade to see signal details...",
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            Row(
              children: [
                Text("Upgrade Now",
                    style: TextStyle(
                        color: Color(0xFF5865F2),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Icon(Icons.arrow_forward_ios,
                    size: 11, color: Color(0xFF5865F2)),
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
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/lock_icon.png', height: 14, width: 14),
              const SizedBox(width: 4),
              const Text("Locked",
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value,
      {Color? valueColor, Widget? icon}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.white)),
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