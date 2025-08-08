// lib/app/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:minvest_forex_app/app/main_screen.dart';
import 'package:minvest_forex_app/features/auth/bloc/auth_bloc.dart';
import 'package:minvest_forex_app/features/auth/screens/welcome/welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AuthBloc, AuthState, AuthStatus>(
      selector: (state) => state.status,
      builder: (context, status) {
        if (status == AuthStatus.authenticated) {
          return const MainScreen();
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}