import 'package:flutter/material.dart';
import 'package:minvest_forex_app/features/auth/screens/welcome/welcome_screen_mobile.dart';
import 'package:minvest_forex_app/features/admin/screens/admin_panel_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_screen.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:minvest_forex_app/features/auth/bloc/auth_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Could not launch the url
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true && context.mounted) {
      context.read<AuthBloc>().add(SignOutRequested());
    }
  }


  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final userTier = userProvider.userTier ?? 'free';
    final userRole = userProvider.role ?? 'user';
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
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
                    currentUser?.email ?? 'your.email@gmail.com',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 30),

                  ...tierInfo.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  )),
                  const SizedBox(height: 30),

                  _UpgradeCard(),
                  const SizedBox(height: 20),

                  if (userRole == 'admin')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildActionButton(
                        text: 'Admin Panel',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminPanelScreen(),
                            ),
                          );
                        },
                      ),
                    ),

                  _buildActionButton(
                    text: 'Contact Us 24/7',
                    onPressed: () {
                      _launchURL('https://zalo.me/0969156969');
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    text: 'Logout',
                    onPressed: () {
                      // Gọi hàm xử lý đã tách
                      _handleLogout(context);
                    },
                  ),
                  const SizedBox(height: 40),

                  const Text('Follow Minvest', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialIcon(iconPath: 'assets/images/facebook_logo.png', url: 'https://www.facebook.com/minvest.vn'),
                      const SizedBox(width: 20),
                      _SocialIcon(iconPath: 'assets/images/tiktok_logo.png', url: 'https://www.tiktok.com/@minvest.minh'),
                      const SizedBox(width: 20),
                      _SocialIcon(iconPath: 'assets/images/youtube_logo.png', url: 'https://www.youtube.com/@minvestvn'),
                      const SizedBox(width: 20),
                      _SocialIcon(iconPath: 'assets/images/telegram_logo.png', url: 'https://t.me/Minvestchungkhoan', size: 32),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF157CC9),
            Color(0xFF2A43B9),
            Color(0xFFC611CE),
          ],
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

Widget _buildActionButton({required String text, required VoidCallback onPressed}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0C0938), Color(0xFF141A4C), Color(0xFF1D2B62)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    ),
  );
}

class _SocialIcon extends StatelessWidget {
  final String iconPath;
  final String url;
  final double size;

  const _SocialIcon({
    required this.iconPath,
    required this.url,
    this.size = 32.0,
  });

  Future<void> _launchURL() async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launchURL,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(4.0),
        child: Image.asset(
          iconPath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
