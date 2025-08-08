import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_screen.dart';

class SignalDetailScreen extends StatelessWidget {
  final Signal signal;
  final String userTier;

  const SignalDetailScreen({
    super.key,
    required this.signal,
    required this.userTier,
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
      return [
        if (path1 != null) path1,
        if (path2 != null) path2,
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    // ▼▼▼ SỬA LẠI ĐIỀU KIỆN XEM REASON ▼▼▼
    final bool canViewReason = userTier == 'elite';
    final List<String> flagPaths = _getFlagPathsFromSymbol(signal.symbol);

    String statusText;
    Color statusColor;

    if (signal.status == 'running') {
      if (signal.result == 'TP1 Hit' || signal.result == 'TP2 Hit') {
        statusText = signal.result!;
        statusColor = Colors.tealAccent.shade400;
      } else if (signal.isMatched) {
        statusText = 'MATCHED';
        statusColor = Colors.greenAccent.shade400;
      } else {
        statusText = 'NOT MATCHED';
        statusColor = Colors.amber.shade400;
      }
    } else {
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
        default:
          statusColor = Colors.blueGrey.shade200;
          break;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        title: Row(
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
            const SizedBox(width: 10),
            Text(
              signal.symbol,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildDetailCard(context, canViewReason, statusText, statusColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, bool canViewReason, String statusText, Color statusColor) {
    final int decimalPlaces = 2;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151a2e),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            'Status',
            statusText,
            valueColor: statusColor,
          ),
          _buildInfoRow('Sent on', DateFormat('HH:mm dd/MM/yyyy').format(signal.createdAt.toDate())),
          const Divider(height: 30, color: Colors.blueGrey),
          _buildPriceRow('Entry price', signal.entryPrice.toStringAsFixed(decimalPlaces), signal.result),
          _buildPriceRow('Stop loss', signal.stopLoss.toStringAsFixed(decimalPlaces), signal.result),
          _buildPriceRow('Take profit 1', signal.takeProfits.isNotEmpty ? signal.takeProfits[0].toStringAsFixed(decimalPlaces) : '—', signal.result),
          _buildPriceRow('Take profit 2', signal.takeProfits.length > 1 ? signal.takeProfits[1].toStringAsFixed(decimalPlaces) : '—', signal.result),
          _buildPriceRow('Take profit 3', signal.takeProfits.length > 2 ? signal.takeProfits[2].toStringAsFixed(decimalPlaces) : '—', signal.result),
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

  // --- CÁC WIDGET CON BÊN DƯỚI GIỮ NGUYÊN KHÔNG ĐỔI ---
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

  Widget _buildPriceRow(String title, String value, String? result) {
    Icon? statusIcon;
    final String lowerResult = result?.toLowerCase() ?? '';
    final String lowerTitle = title.replaceAll(' ', '').toLowerCase();

    if (signal.status == 'closed' || lowerResult.contains('hit')) {
      if (lowerTitle == 'stoploss' && lowerResult == 'slhit') {
        statusIcon = const Icon(Icons.cancel, color: Color(0xFFDA3633), size: 18);
      }
      if (lowerTitle.startsWith('takeprofit')) {
        final tpNumber = int.tryParse(lowerTitle.replaceAll('takeprofit', ''));
        if (tpNumber != null && lowerResult.startsWith('tp') && lowerResult.endsWith('hit')) {
          final hitTpNumber = int.tryParse(lowerResult.replaceAll('hit', '').replaceAll('tp', ''));
          if (hitTpNumber != null && tpNumber <= hitTpNumber) {
            statusIcon = const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18);
          }
        }
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
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
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
    // ...
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Upgrade your account to Elite to view the analysis and reasons for entering the order.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, height: 1.5, fontSize: 14),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          width: double.infinity,
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
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: Ink(
              decoration: BoxDecoration(
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
                    const Text("Upgrade to see more", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}