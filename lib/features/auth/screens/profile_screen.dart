import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_screen.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Hàm để lấy thông tin quyền lợi dựa trên cấp bậc
  Map<String, String> _getTierInfo(String tier) {
    switch (tier.toLowerCase()) {
      case 'demo':
        return {
          'Signal time': '8h-17h',
          'Lot/week': '0.05',
          'Signal quantity': '7-8 signals per day',
        };
      case 'vip':
        return {
          'Signal time': '8h-17h',
          'Lot/week': '0.3',
          'Signal quantity': 'full',
        };
      case 'elite':
        return {
          'Signal time': 'fulltime',
          'Lot/week': '0.5',
          'Signal quantity': 'full',
        };
      default: // Free tier
        return {
          'Signal time': 'N/A',
          'Lot/week': 'N/A',
          'Signal quantity': 'N/A',
        };
    }
  }

  // Hàm để mở URL
  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final userTier = userProvider.userTier ?? 'free';
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // --- Thông tin User ---
                CircleAvatar(
                  radius: 40,
                  backgroundImage: currentUser?.photoURL != null ? NetworkImage(currentUser!.photoURL!) : null,
                  child: currentUser?.photoURL == null ? const Icon(Icons.person, size: 40) : null,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentUser?.displayName ?? 'Your Name',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        userTier.toUpperCase(),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Text(
                  currentUser?.email ?? 'your.email@example.com',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // --- Quyền lợi ---
                ...tierInfo.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )),
                const SizedBox(height: 30),

                // --- Nút Upgrade ---
                _UpgradeCard(),
                const SizedBox(height: 20),

                // --- Nút liên hệ và Đăng xuất ---
                _buildActionButton(
                  text: 'Contact Us 24/7',
                  onPressed: () {
                    // TODO: Thêm link hoặc hành động liên hệ
                  },
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  text: 'Logout',
                  onPressed: () async {
                    await AuthService().signOut();
                  },
                ),
                const Spacer(),

                // --- Mạng xã hội ---
                const Text('Follow Minvest', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialIcon(iconPath: 'assets/images/facebook_logo.png', url: 'https://facebook.com'),
                    const SizedBox(width: 20),
                    _SocialIcon(iconPath: 'assets/images/tiktok_logo.png', url: 'https://tiktok.com'),
                    const SizedBox(width: 20),
                    _SocialIcon(iconPath: 'assets/images/youtube_logo.png', url: 'https://youtube.com'),
                    const SizedBox(width: 20),
                    _SocialIcon(iconPath: 'assets/images/telegram_logo.png', url: 'https://telegram.org'),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget cho thẻ Upgrade
class _UpgradeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 32),
          const SizedBox(height: 8),
          const Text(
            'UPGRADE YOUR ACCOUNT',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'To access more resources',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UpgradeScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            ),
            child: const Text('UPGRADE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// Widget cho các nút hành động
Widget _buildActionButton({required String text, required VoidCallback onPressed}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF151a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.blueAccent),
        ),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

// Widget cho icon mạng xã hội
class _SocialIcon extends StatelessWidget {
  final String iconPath;
  final String url;

  const _SocialIcon({required this.iconPath, required this.url});

  // Hàm để mở URL
  Future<void> _launchURL() async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Could not launch the url
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launchURL,
      child: Image.asset(iconPath, height: 32, width: 32),
    );
  }
}