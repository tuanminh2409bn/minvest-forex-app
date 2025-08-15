// package_screen_web.dart (ĐÃ SỬA LỖI HOÀN CHỈNH)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:minvest_forex_app/features/verification/models/payment_method.dart';
import 'package:minvest_forex_app/features/verification/screens/bank_transfer_screen.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';

class PackageScreen extends StatefulWidget {
  final PaymentMethod paymentMethod;
  const PackageScreen({super.key, required this.paymentMethod});
  @override
  State<PackageScreen> createState() => _PackageScreenState();
}

class _PackageScreenState extends State<PackageScreen> {
  bool _isLoading = true;
  String _loadingError = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = AppLocalizations.of(context)!;
      if (widget.paymentMethod == PaymentMethod.vnPay) {
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _isLoading = false;
          _loadingError = l10n.iapNotSupportedOnWeb;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.packageTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadingError.isNotEmpty
            ? Center(child: Text(_loadingError, style: const TextStyle(color: Colors.red)))
            : Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: _buildVnPayContent(l10n),
          ),
        ),
      ),
    );
  }

  Widget _buildVnPayContent(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 720) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildVnPayCard1Month(l10n)),
                const SizedBox(width: 32),
                Expanded(child: _buildVnPayCard12Months(l10n)),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              _buildVnPayCard1Month(l10n),
              const SizedBox(height: 24),
              _buildVnPayCard12Months(l10n),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVnPayCard1Month(AppLocalizations l10n) {
    return _PackageCard(
      tier: l10n.tierElite, duration: l10n.duration1Month, price: '\$78',
      features: [l10n.featureReceiveAllSignals, l10n.featureAnalyzeReason, l10n.featureHighPrecisionAI],
      // <<< SỬA ĐỔI QUAN TRỌNG NẰM Ở ĐÂY >>>
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BankTransferScreen(
        amountUSD: 78,
        orderInfo: l10n.orderInfo1Month,
        productId: 'elite_1_month_vnpay', // Thêm dòng này
      ))),
    );
  }

  Widget _buildVnPayCard12Months(AppLocalizations l10n) {
    return _PackageCard(
      tier: l10n.tierElite, duration: l10n.duration12Months, price: '\$460',
      features: [l10n.featureReceiveAllSignals, l10n.featureAnalyzeReason, l10n.featureHighPrecisionAI],
      // <<< SỬA ĐỔI QUAN TRỌNG NẰM Ở ĐÂY >>>
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BankTransferScreen(
        amountUSD: 460,
        orderInfo: l10n.orderInfo12Months,
        productId: 'elite_12_months_vnpay', // Thêm dòng này
      ))),
    );
  }
}

// _PackageCard và _buildActionButton giữ nguyên, không cần thay đổi
class _PackageCard extends StatelessWidget {
  final String tier;
  final String duration;
  final String price;
  final List<String> features;
  final VoidCallback? onPressed;

  const _PackageCard({
    required this.tier,
    required this.duration,
    required this.price,
    required this.features,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF157CC9), Color(0xFF2A43B9), Color(0xFFC611CE)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFFC611CE).withOpacity(0.4), blurRadius: 20.0, offset: const Offset(0, 10)),
          BoxShadow(color: const Color(0xFF157CC9).withOpacity(0.4), blurRadius: 20.0, offset: const Offset(0, -10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              color: Colors.black.withOpacity(0.1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.diamond_outlined, color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    Text(tier, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                      child: Text(duration, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 32),
                ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 2.0), child: Icon(Icons.check, color: Colors.greenAccent, size: 16)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(feature, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4))),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(price, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.amber)),
                    const Spacer(),
                    _buildActionButton(text: l10n.startNow, onPressed: onPressed, isPrimary: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildActionButton({required String text, required VoidCallback? onPressed, required bool isPrimary}) {
  final bool isEnabled = onPressed != null;
  return SizedBox(
    height: 45,
    width: 140,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        disabledBackgroundColor: Colors.grey.withOpacity(0.2),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: isEnabled && isPrimary ? const LinearGradient(colors: [Color(0xFF172AFE), Color(0xFF3C4BFE), Color(0xFF5E69FD)], begin: Alignment.centerLeft, end: Alignment.centerRight) : null,
          color: isEnabled && !isPrimary ? const Color(0xFF151a2e) : null,
          borderRadius: BorderRadius.circular(12),
          border: isEnabled && !isPrimary ? Border.all(color: Colors.blueAccent) : null,
        ),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isEnabled ? Colors.white : Colors.grey)),
        ),
      ),
    ),
  );
}