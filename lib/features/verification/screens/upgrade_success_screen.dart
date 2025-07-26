import 'package:flutter/material.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Thêm thư viện này

class UpgradeSuccessScreen extends StatelessWidget {
  const UpgradeSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // SỬA LỖI: Lấy thông tin user trực tiếp từ FirebaseAuth
    final User? currentUser = FirebaseAuth.instance.currentUser;

    // Vẫn lấy cấp bậc từ UserProvider vì đây là thông tin tùy chỉnh
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userTier = userProvider.userTier ?? 'N/A';

    final tierInfo = _getTierInfo(userTier);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              const Text(
                'ACCOUNT VERIFIED SUCCESSFULLY',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF151a2e),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // SỬA LỖI: Dùng thông tin từ currentUser
                        Text(
                          currentUser?.displayName ?? 'Your Name',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            userTier.toUpperCase(),
                            style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // SỬA LỖI: Dùng thông tin từ currentUser
                        Text(
                          currentUser?.email ?? 'your.email@example.com',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                    const Divider(height: 30, color: Colors.blueGrey),
                    _buildBenefitRow('Signal time:', tierInfo['signal_time']!),
                    _buildBenefitRow('Lot/week:', tierInfo['lot_week']!),
                    _buildBenefitRow('Signal Quantity:', tierInfo['signal_qty']!),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  'Return to home page >',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Map<String, String> _getTierInfo(String tier) {
    switch (tier.toLowerCase()) {
      case 'demo':
        return {
          'signal_time': '8h-17h',
          'lot_week': '0.05',
          'signal_qty': '7-8 per day',
        };
      case 'vip':
        return {
          'signal_time': '8h-17h',
          'lot_week': '0.3',
          'signal_qty': 'full',
        };
      case 'elite':
        return {
          'signal_time': 'fulltime',
          'lot_week': '0.5',
          'signal_qty': 'full',
        };
      default:
        return {
          'signal_time': 'N/A',
          'lot_week': 'N/A',
          'signal_qty': 'N/A',
        };
    }
  }
}