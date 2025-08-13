// lib/app/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:minvest_forex_app/app/main_screen.dart';
import 'package:minvest_forex_app/features/auth/bloc/auth_bloc.dart';
import 'package:minvest_forex_app/features/auth/screens/welcome/welcome_screen.dart';
import 'package:minvest_forex_app/services/session_service.dart'; // Import service mới

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // BlocListener sẽ "lắng nghe" sự thay đổi trạng thái mà không cần build lại UI
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Khi trạng thái chuyển thành `authenticated`
        if (state.status == AuthStatus.authenticated) {
          // Gọi hàm cập nhật session.
          // Chúng ta không cần `await` ở đây vì việc cập nhật có thể chạy ngầm
          // mà không cần chặn người dùng vào màn hình chính.
          print("AuthGate: User authenticated. Updating session...");
          SessionService().updateUserSession();
        }
      },
      // BlocSelector chỉ build lại UI khi status thay đổi (giữ nguyên logic cũ của bạn)
      child: BlocSelector<AuthBloc, AuthState, AuthStatus>(
        selector: (state) => state.status,
        builder: (context, status) {
          if (status == AuthStatus.authenticated) {
            return const MainScreen();
          } else {
            return const WelcomeScreen();
          }
        },
      ),
    );
  }
}
