// lib/app/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:minvest_forex_app/app/main_screen.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart'; // Import UserProvider
import 'package:minvest_forex_app/features/auth/bloc/auth_bloc.dart';
import 'package:minvest_forex_app/features/auth/screens/welcome/welcome_screen.dart';
import 'package:minvest_forex_app/services/session_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Lấy UserProvider từ context
        final userProvider = context.read<UserProvider>();

        if (state.status == AuthStatus.authenticated) {
          // Cập nhật session
          print("AuthGate: User authenticated. Updating session...");
          SessionService().updateUserSession();

          // Ra lệnh cho UserProvider bắt đầu lắng nghe dữ liệu
          if (state.user != null) {
            print("AuthGate: Telling UserProvider to start listening for user ${state.user!.uid}");
            userProvider.listenToUserData(state.user!);
          }

        } else if (state.status == AuthStatus.unauthenticated) {
          // Khi người dùng đăng xuất
          print("AuthGate: User unauthenticated. Telling UserProvider to stop listening.");
          // Ra lệnh cho UserProvider dừng lắng nghe và reset trạng thái
          userProvider.stopListeningAndReset();
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            return const MainScreen();
          } else {
            return const WelcomeScreen();
          }
        },
      ),
    );
  }
}