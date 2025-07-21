import 'package:flutter/material.dart';
import 'package:minvest_forex_app/core/providers/language_provider.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1117), Color(0xFF7A7F85), Color.fromARGB(255, 20, 29, 110)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              children: [
                // --- THAY ĐỔI 2: Thêm Padding để dịch lá cờ xuống ---
                Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: PopupMenuButton<Locale>(
                        onSelected: (Locale locale) => languageProvider.setLocale(locale),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: Locale('en'), child: Text('English')),
                          const PopupMenuItem(value: Locale('vi'), child: Text('Tiếng Việt')),
                        ],
                        child: Consumer<LanguageProvider>(
                          builder: (context, provider, child) {
                            // --- THAY ĐỔI 3: Chuyển cờ sang hình chữ nhật ---
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(4.0),
                              child: Image.asset(
                                provider.locale?.languageCode == 'vi'
                                    ? 'assets/images/vn_flag.png'
                                    : 'assets/images/us_flag.png',
                                height: 24,
                                width: 36,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        )
                    ),
                  ),
                ),
                const Spacer(),
                const Text('Welcome to', style: TextStyle(fontSize: 18, color: Colors.white)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  // --- THAY ĐỔI 1: Tăng kích thước logo ---
                  child: Image.asset('assets/images/minvest_logo.png', height: 80),
                ),
                const Text(
                  'Enhance your trading with intelligent signals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: 50),
                const Text('Sign in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                _SocialSignInButton(
                  iconPath: 'assets/images/google_logo.png',
                  text: 'Continue by Google',
                  onPressed: () => authService.signInWithGoogle(),
                ),
                const SizedBox(height: 16),

                // Nút Apple sẽ chỉ hoạt động trên iOS nhưng vẫn hiển thị
                SignInWithAppleButton(
                  onPressed: () {
                    if (Platform.isIOS || Platform.isMacOS) {
                      authService.signInWithApple();
                    }
                  },
                  // --- THAY ĐỔI 4: Đổi style nút Apple cho phù hợp ---
                  style: SignInWithAppleButtonStyle.white,
                  borderRadius: BorderRadius.circular(12),
                  height: 48,
                ),
                const SizedBox(height: 16),

                _SocialSignInButton(
                  iconPath: 'assets/images/facebook_logo.png',
                  text: 'Continue by Facebook',
                  onPressed: () => authService.signInWithFacebook(),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialSignInButton extends StatelessWidget {
  final String iconPath;
  final String text;
  final VoidCallback onPressed;

  const _SocialSignInButton({
    required this.iconPath,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Image.asset(iconPath, height: 30, width: 30),
      label: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        // --- THAY ĐỔI 4: Đổi màu nút sang màu xanh mờ ---
        backgroundColor: Colors.blue.withOpacity(0.10),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}