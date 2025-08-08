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
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30),
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
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Welcome to',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Image.asset(
                    'assets/images/minvest_logo.png',
                    height: 150,
                  ),
                ),
                const Text(
                  'Enhance your trading with intelligent signals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: 50),
                const Text(
                  'Sign in',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 24),

                // Nút Google
                _SocialSignInButton(
                  icon: Image.asset('assets/images/google_logo.png', height: 24, width: 24),
                  text: 'Continue by Google',
                  onPressed: () => authService.signInWithGoogle(),
                ),
                const SizedBox(height: 16),

                // Nút Facebook
                _SocialSignInButton(
                  icon: Image.asset('assets/images/facebook_logo.png', height: 24, width: 24),
                  text: 'Continue by Facebook',
                  onPressed: () => authService.signInWithFacebook(),
                ),
                const SizedBox(height: 16),

                // Nút Apple
                  _SocialSignInButton(
                    icon: const Icon(Icons.apple, color: Colors.white, size: 24),
                    text: 'Continue by Apple',
                    onPressed: () => authService.signInWithApple(),
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

// Sửa lại widget _SocialSignInButton để linh hoạt hơn
class _SocialSignInButton extends StatelessWidget {
  // Thay vì dùng `iconPath`, chúng ta dùng thẳng `icon` kiểu Widget
  final Widget icon;
  final String text;
  final VoidCallback onPressed;

  const _SocialSignInButton({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
              colors: [
                Color(0xFF0C0938),
                Color(0xFF141A4C),
                Color(0xFF1D2B62),
              ],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Hiển thị widget icon được truyền vào
                icon,
                const SizedBox(width: 24),
                Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
