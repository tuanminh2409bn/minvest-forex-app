import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:minvest_forex_app/features/verification/screens/bank_transfer_screen.dart';


class PackageScreen extends StatelessWidget {
  const PackageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'PACKAGE',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              _PackageCard(
                tier: 'ELITE',
                duration: '1 month',
                price: '\$78',
                features: const [
                  'Receive all signals of the day',
                  'Analyze the reason for entering the order',
                  'High-precision AI signal',
                ],
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BankTransferScreen(
                        amountUSD: 78,
                        orderInfo: 'Thanh toan goi Elite 1 thang',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _PackageCard(
                tier: 'ELITE',
                duration: '12 month',
                price: '\$460',
                features: const [
                  'Receive all signals of the day',
                  'Analyze the reason for entering the order',
                  'High-precision AI signal',
                ],
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BankTransferScreen(
                        amountUSD: 460,
                        orderInfo: 'Thanh toan goi Elite 12 thang',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final String tier;
  final String duration;
  final String price;
  final List<String> features;
  final VoidCallback onPressed;

  const _PackageCard({
    required this.tier,
    required this.duration,
    required this.price,
    required this.features,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // YÊU CẦU: ĐỔI MÀU GRADIENT CỦA THẺ
            gradient: const LinearGradient(
              colors: [
                Color(0xFF157CC9),
                Color(0xFF2A43B9),
                Color(0xFFC611CE),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC611CE).withOpacity(0.5),
                blurRadius: 25.0,
                spreadRadius: 5.0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.diamond_outlined, color: Colors.amber, size: 22),
                  const SizedBox(width: 8),
                  Text(tier, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(duration, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(feature, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      price,
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.amber),
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildActionButton(
                    text: 'START NOW',
                    onPressed: onPressed,
                    isPrimary: true,
                  ),
                ],
              ),
            ],
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
          gradient: isEnabled && isPrimary
              ? const LinearGradient(
            colors: [Color(0xFF172AFE), Color(0xFF3C4BFE), Color(0xFF5E69FD)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
              : null,
          color: isEnabled && !isPrimary ? const Color(0xFF151a2e) : null,
          borderRadius: BorderRadius.circular(12),
          border: isEnabled && !isPrimary ? Border.all(color: Colors.blueAccent) : null,
        ),
        child: Container(
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isEnabled ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    ),
  );
}