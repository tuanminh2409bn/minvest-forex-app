// lib/app/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:minvest_forex_app/app/main_screen.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/auth/bloc/auth_bloc.dart';
import 'package:minvest_forex_app/features/auth/screens/welcome/welcome_screen.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  void _showErrorDialog(BuildContext context, String message) {
    // Xóa tiền tố "Exception: " để thông báo thân thiện hơn
    final displayMessage = message.startsWith('Exception: ') ? message.substring(11) : message;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.error),
        content: Text(displayMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      // ▼▼▼ LISTENER SẼ XỬ LÝ LOGIC NỀN VÀ HIỂN THỊ DIALOG ▼▼▼
      listener: (context, state) {
        final userProvider = context.read<UserProvider>();

        if (state.status == AuthStatus.authenticated && state.user != null) {
          print("AuthGate: User authenticated. Telling UserProvider to start listening for user ${state.user!.uid}");
          userProvider.listenToUserData(state.user!);
        } else if (state.status == AuthStatus.unauthenticated) {
          print("AuthGate: User unauthenticated. Telling UserProvider to stop listening.");
          userProvider.stopListeningAndReset();

          // Nếu có lỗi, hiển thị dialog
          if (state.errorMessage != null) {
            _showErrorDialog(context, state.errorMessage!);
          }
        }
      },
      // ▼▼▼ BUILDER CHỈ CÓ NHIỆM VỤ DỰNG GIAO DIỆN ▼▼▼
      builder: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          return const MainScreen();
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}