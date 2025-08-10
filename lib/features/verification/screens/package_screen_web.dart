import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:minvest_forex_app/features/verification/models/payment_method.dart';
import 'package:minvest_forex_app/features/verification/screens/bank_transfer_screen.dart';

class PackageScreen extends StatefulWidget {
  final PaymentMethod paymentMethod;
  const PackageScreen({super.key, required this.paymentMethod});
  @override
  State<PackageScreen> createState() => _PackageScreenState();
}

class _PackageScreenState extends State<PackageScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  Map<String, ProductDetails> _products = {};
  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String _loadingError = '';
  final Set<String> _kIds = {'elite_1_month', 'elite_12_months'};

  @override
  void initState() {
    super.initState();
    // Web chỉ hỗ trợ VNPay, nên không cần init IAP store
    if (widget.paymentMethod == PaymentMethod.vnPay) {
      setState(() => _isLoading = false);
    } else {
      // Xử lý trường hợp không mong muốn
      setState(() {
        _isLoading = false;
        _loadingError = "In-app purchases are not supported on the web version.";
      });
    }
  }

  @override
  void dispose() {
    // Không cần cancel subscription vì không khởi tạo
    super.dispose();
  }

  // Các hàm IAP vẫn giữ lại để tránh lỗi biên dịch nếu có chia sẻ code
  void _listenToPurchaseUpdated(List<PurchaseDetails> list) {}
  Future<void> _verifyPurchase(PurchaseDetails d) async {}
  void _handlePurchase(ProductDetails d) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('PACKAGE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
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
                : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _buildVnPayContent(),
              ),
            ),
          ),
          if (_isPurchasing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang xử lý giao dịch...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVnPayContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 720) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildVnPayCard1Month()),
                const SizedBox(width: 32),
                Expanded(child: _buildVnPayCard12Months()),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              _buildVnPayCard1Month(),
              const SizedBox(height: 24),
              _buildVnPayCard12Months(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVnPayCard1Month() {
    return _PackageCard(
      tier: 'ELITE', duration: '1 month', price: '\$78',
      features: const ['Receive all signals of the day', 'Analyze the reason for entering the order', 'High-precision AI signal'],
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BankTransferScreen(amountUSD: 78, orderInfo: 'Thanh toan goi Elite 1 thang'))),
    );
  }

  Widget _buildVnPayCard12Months() {
    return _PackageCard(
      tier: 'ELITE', duration: '12 months', price: '\$460',
      features: const ['Receive all signals of the day', 'Analyze the reason for entering the order', 'High-precision AI signal'],
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BankTransferScreen(amountUSD: 460, orderInfo: 'Thanh toan goi Elite 12 thang'))),
    );
  }
}

// ▼▼▼ WIDGET _PackageCard ĐÃ ĐƯỢC THIẾT KẾ LẠI HOÀN TOÀN ▼▼▼
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
              mainAxisSize: MainAxisSize.min, // QUAN TRỌNG: Ngăn thẻ bị kéo dài
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
                    _buildActionButton(text: 'START NOW', onPressed: onPressed, isPrimary: true),
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
          child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isEnabled ? Colors.white : Colors.grey)),
        ),
      ),
    ),
  );
}
