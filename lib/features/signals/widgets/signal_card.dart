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

  // --- CÁC HÀM LOGIC CỦA BẠN GIỮ NGUYÊN ---
  static const Map<String, String> _currencyFlags = {
    'AUD': 'assets/images/aud_flag.png', 'CHF': 'assets/images/chf_flag.png',
    'EUR': 'assets/images/eur_flag.png', 'GBP': 'assets/images/gbp_flag.png',
    'JPY': 'assets/images/jpy_flag.png', 'NZD': 'assets/images/nzd_flag.png',
    'USD': 'assets/images/us_flag.png', 'XAU': 'assets/images/crown_icon.png',
  };

  List<String> _getFlagPathsFromSymbol(String symbol) {
    final parts = symbol.toUpperCase().split('/');
    if (parts.length == 2) {
      final path1 = _currencyFlags[parts[0]];
      final path2 = _currencyFlags[parts[1]];
      return [ if (path1 != null) path1, if (path2 != null) path2 ];
    }
    return [];
  }
  // --- KẾT THÚC HÀM LOGIC ---

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isLocked) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const UpgradeScreen()));
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

  // Widget _buildCardHeader giữ nguyên như file bạn đã cung cấp
  Widget _buildCardHeader() {
    final bool isBuy = signal.type.toLowerCase() == 'buy';
    final Color signalColor = isBuy ? const Color(0xFF238636) : const Color(0xFFDA3633);
    final List<String> flagPaths = _getFlagPathsFromSymbol(signal.symbol);
    String statusText;
    Color statusColor;
    if (signal.status == 'running') {
      statusText = signal.isMatched ? 'MATCHED' : 'NOT MATCHED';
      statusColor = signal.isMatched ? Colors.greenAccent : Colors.amber;
    } else {
      statusText = signal.result?.toUpperCase() ?? 'CLOSED';
      statusColor = Colors.grey;
    }
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
                  child: CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade800, backgroundImage: AssetImage(flagPaths[index])),
                );
              }),
            ),
          ),
        const SizedBox(width: 8),
        Text(signal.symbol, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: signalColor, borderRadius: BorderRadius.circular(20)),
          child: Text(signal.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white)),
        ),
        const Spacer(),
        Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ▼▼▼ HÀM NÀY ĐÃ ĐƯỢC NÂNG CẤP HOÀN CHỈNH ▼▼▼
  Widget _buildSignalData() {
    const int decimalPlaces = 2;
    final String? result = signal.result;

    return Column(
      children: [
        Row(
          children: [
            _buildInfoColumn("Entry", signal.entryPrice.toStringAsFixed(decimalPlaces)),
            _buildInfoColumn(
              "SL",
              signal.stopLoss.toStringAsFixed(decimalPlaces),
              valueColor: Colors.red,
              // Logic hiển thị icon
              icon: _getStatusIcon('SL', result),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildInfoColumn(
              "TP1",
              signal.takeProfits.isNotEmpty ? signal.takeProfits[0].toStringAsFixed(decimalPlaces) : "---",
              valueColor: Colors.green,
              icon: _getStatusIcon('TP1', result),
            ),
            _buildInfoColumn(
              "TP2",
              signal.takeProfits.length > 1 ? signal.takeProfits[1].toStringAsFixed(decimalPlaces) : "---",
              valueColor: Colors.green,
              icon: _getStatusIcon('TP2', result),
            ),
            _buildInfoColumn(
              "TP3",
              signal.takeProfits.length > 2 ? signal.takeProfits[2].toStringAsFixed(decimalPlaces) : "---",
              valueColor: Colors.green,
              icon: _getStatusIcon('TP3', result),
            ),
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

  // ▼▼▼ THÊM HÀM HELPER NÀY VÀO ▼▼▼
  Widget? _getStatusIcon(String title, String? result) {
    if (result == null || result.isEmpty || signal.status != 'closed') return null;

    final lowerResult = result.toLowerCase();
    final lowerTitle = title.toLowerCase();

    // Xử lý SL Hit
    if (lowerTitle == 'sl' && lowerResult == 'sl hit') {
      return const Icon(Icons.cancel, color: Colors.red, size: 14);
    }

    // Xử lý các TP Hit
    if (lowerTitle.startsWith('tp')) {
      final tpNumber = int.tryParse(lowerTitle.replaceAll('tp', ''));
      if (tpNumber == null) return null;

      if (lowerResult.startsWith('tp') && lowerResult.endsWith('hit')) {
        final hitTpNumber = int.tryParse(lowerResult.replaceAll(' hit', '').replaceAll('tp', ''));
        if (hitTpNumber != null && tpNumber <= hitTpNumber) {
          return const Icon(Icons.check_circle, color: Colors.green, size: 14);
        }
      }
    }
    return null;
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