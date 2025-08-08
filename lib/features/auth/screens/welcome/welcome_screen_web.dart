// lib/features/auth/screens/welcome/welcome_screen_web.dart

import 'package:flutter/material.dart';
import 'package:minvest_forex_app/core/providers/language_provider.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';
import 'package:provider/provider.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Chúng ta vẫn giữ nguyên logic khởi tạo service và provider
    final authService = AuthService();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      body: Container(
        // Giữ nguyên background gradient đẹp mắt của bạn
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        // SỬ DỤNG LAYOUTBUILDER ĐỂ QUYẾT ĐỊNH LAYOUT
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Đặt ra một "breakpoint", ví dụ 800px.
            // Nếu chiều ngang lớn hơn 800px, dùng layout cho web.
            if (constraints.maxWidth > 800) {
              return _buildWebLayout(context, authService, languageProvider);
            }
            // Nếu không, dùng layout cho màn hình hẹp (tương tự mobile).
            else {
              return _buildMobileLayout(context, authService, languageProvider);
            }
          },
        ),
      ),
    );
  }

  // --- LAYOUT CHO MÀN HÌNH RỘNG (WEB) ---
  Widget _buildWebLayout(BuildContext context, AuthService authService, LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 32.0),
      child: Row(
        children: [
          // **Cột bên trái: Logo và thông tin**
          Expanded(
            flex: 2, // Cho cột này chiếm nhiều không gian hơn
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome to', style: TextStyle(fontSize: 24, color: Colors.white)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Image.asset(
                    'assets/images/minvest_logo.png',
                    height: 180,
                  ),
                ),
                const Text(
                  'Enhance your trading with intelligent signals.',
                  style: TextStyle(fontSize: 20, color: Colors.white, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 64),
          const VerticalDivider(color: Colors.white24, thickness: 1),
          const SizedBox(width: 64),

          // **Cột bên phải: Form đăng nhập**
          Expanded(
            flex: 1, // Cột này chiếm ít không gian hơn
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Sign in', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 32),
                _SocialSignInButton(
                  icon: Image.asset('assets/images/google_logo.png', height: 24, width: 24),
                  text: 'Continue by Google',
                  onPressed: () => authService.signInWithGoogle(),
                ),
                const SizedBox(height: 16),
                _SocialSignInButton(
                  icon: Image.asset('assets/images/facebook_logo.png', height: 24, width: 24),
                  text: 'Continue by Facebook',
                  onPressed: () => authService.signInWithFacebook(),
                ),
                const SizedBox(height: 16),
                _SocialSignInButton(
                  icon: const Icon(Icons.apple, color: Colors.white, size: 24),
                  text: 'Continue by Apple',
                  onPressed: () => authService.signInWithApple(),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- LAYOUT CHO MÀN HÌNH HẸP (TƯƠNG TỰ MOBILE) ---
  // Về cơ bản, đây là code gốc của bạn, được tách ra thành một hàm riêng.
  Widget _buildMobileLayout(BuildContext context, AuthService authService, LanguageProvider languageProvider) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nút chọn ngôn ngữ vẫn giữ nguyên
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
            const Text('Welcome to', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.white)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Image.asset('assets/images/minvest_logo.png', height: 150),
            ),
            const Text('Enhance your trading with intelligent signals.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white, height: 1.5)),
            const SizedBox(height: 50),
            const Text('Sign in', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            _SocialSignInButton(
              icon: Image.asset('assets/images/google_logo.png', height: 24, width: 24),
              text: 'Continue by Google',
              onPressed: () => authService.signInWithGoogle(),
            ),
            const SizedBox(height: 16),
            _SocialSignInButton(
              icon: Image.asset('assets/images/facebook_logo.png', height: 24, width: 24),
              text: 'Continue by Facebook',
              onPressed: () => authService.signInWithFacebook(),
            ),
            const SizedBox(height: 16),
            _SocialSignInButton(
              icon: const Icon(Icons.apple, color: Colors.white, size: 24),
              text: 'Continue by Apple',
              onPressed: () => authService.signInWithApple(),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

// Widget _SocialSignInButton không cần thay đổi, chúng ta giữ nguyên để tái sử dụng
class _SocialSignInButton extends StatelessWidget {
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