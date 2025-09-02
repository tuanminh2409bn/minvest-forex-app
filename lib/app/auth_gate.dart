// lib/app/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:minvest_forex_app/app/main_screen.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/auth/bloc/auth_bloc.dart';
import 'package:minvest_forex_app/features/auth/screens/welcome/welcome_screen.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';
import 'package:minvest_forex_app/features/notifications/providers/notification_provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  void _showErrorDialog(BuildContext context, String message) {
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
      listener: (context, state) {
        final userProvider = context.read<UserProvider>();
        final notificationProvider = context.read<NotificationProvider>();

        if (state.status == AuthStatus.authenticated && state.user != null) {
          print("AuthGate: User authenticated. Bắt đầu lắng nghe các provider...");
          userProvider.listenToUserData(state.user!);

          // ▼▼▼ SỬA LỖI Ở ĐÂY: Gọi hàm không cần tham số ▼▼▼
          notificationProvider.startListening();

        } else if (state.status == AuthStatus.unauthenticated) {
          print("AuthGate: User unauthenticated. Dừng lắng nghe các provider...");
          userProvider.stopListeningAndReset();
          notificationProvider.stopListeningAndReset();

          if (state.errorMessage != null) {
            _showErrorDialog(context, state.errorMessage!);
          }
        }
      },
      builder: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          return const MainScreen();
        } else if (state.status == AuthStatus.loggingOut) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1117),
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}