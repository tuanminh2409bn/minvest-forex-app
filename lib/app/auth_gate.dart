// lib/app/auth_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:minvest_forex_app/app/main_screen.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/auth/bloc/auth_bloc.dart';
import 'package:minvest_forex_app/features/auth/screens/welcome/welcome_screen.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';
import 'package:minvest_forex_app/features/notifications/providers/notification_provider.dart';
import 'package:provider/provider.dart';

// THAY ĐỔI 1: Chuyển thành StatefulWidget
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isDowngradeDialogShowing = false;

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

  // THAY ĐỔI 2: Hàm hiển thị dialog xác nhận hạ cấp
  void _showDowngradeDialog(BuildContext context, UserProvider userProvider) {
    // Chỉ hiển thị dialog nếu nó chưa được hiển thị
    if (_isDowngradeDialogShowing) return;

    setState(() {
      _isDowngradeDialogShowing = true;
    });

    showDialog(
      context: context,
      // Ngăn người dùng tắt dialog bằng cách bấm ra ngoài
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        // Ngăn người dùng tắt dialog bằng nút back trên Android
        canPop: false,
        child: AlertDialog(
          title: const Text('Thông báo quan trọng'),
          content: Text(userProvider.downgradeReason ?? 'Tài khoản của bạn đã được chuyển về gói Free.'),
          actions: [
            TextButton(
              onPressed: () async {
                // Gọi hàm xác nhận trong provider
                await userProvider.acknowledgeDowngrade();
                if (mounted) {
                  Navigator.of(dialogContext).pop();
                  setState(() {
                    _isDowngradeDialogShowing = false;
                  });
                }
              },
              child: const Text('Tôi đã hiểu'),
            ),
          ],
        ),
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
          userProvider.listenToUserData(state.user!);
          notificationProvider.startListening();
        } else if (state.status == AuthStatus.unauthenticated) {
          userProvider.stopListeningAndReset();
          notificationProvider.stopListeningAndReset();
          if (state.errorMessage != null) {
            _showErrorDialog(context, state.errorMessage!);
          }
        }
      },
      builder: (context, state) {
        // THAY ĐỔI 3: Bọc Widget bằng Consumer<UserProvider>
        return Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            // Ngay sau khi build, kiểm tra xem có cần hiển thị dialog không
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (userProvider.requiresDowngradeAcknowledgement &&
                  state.status == AuthStatus.authenticated &&
                  mounted) {
                _showDowngradeDialog(context, userProvider);
              }
            });

            // Logic điều hướng giữ nguyên
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
      },
    );
  }
}