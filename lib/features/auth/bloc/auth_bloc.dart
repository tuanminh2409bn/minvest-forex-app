// lib/features/auth/bloc/auth_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Import material để dùng ChangeNotifier
import 'package:minvest_forex_app/core/exceptions/auth_exceptions.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart'; // Import UserProvider
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';
import 'package:minvest_forex_app/features/notifications/providers/notification_provider.dart';


part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _userSubscription;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthState.unknown()) {
    _userSubscription = _authService.authStateChanges.listen(
          (user) => add(AuthStateChanged(user)),
    );

    on<AuthStateChanged>(_onAuthStateChanged);
    on<SignOutRequested>(_onSignOutRequested);
    on<SignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<SignInWithFacebookRequested>(_onSignInWithFacebookRequested);
    on<SignInWithAppleRequested>(_onSignInWithAppleRequested);
  }

  // ▼▼▼ SỬA LẠI HÀM NÀY ▼▼▼
  Future<void> _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) async {
    print("AuthBloc: Yêu cầu đăng xuất. Bắt đầu dọn dẹp provider...");

    // ▼▼▼ LOGIC DỌN DẸP TỔNG QUÁT HƠN ▼▼▼
    for (var provider in event.providersToReset) {
      if (provider is UserProvider) {
        await provider.stopListeningAndReset();
      }
      // Thêm trường hợp cho NotificationProvider
      if (provider is NotificationProvider) {
        await provider.stopListeningAndReset();
      }
    }
    // ▲▲▲ KẾT THÚC SỬA ĐỔI ▲▲▲

    print("AuthBloc: Dọn dẹp provider hoàn tất.");
    emit(const AuthState.loggingOut());
    print("AuthBloc: Đã phát ra trạng thái loggingOut.");
    await Future.delayed(const Duration(milliseconds: 50));
    print("AuthBloc: Thực hiện đăng xuất khỏi Firebase.");
    await _authService.signOut();
  }
  // ▲▲▲ KẾT THÚC SỬA ĐỔI ▲▲▲

  void _onAuthStateChanged(AuthStateChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(AuthState.authenticated(event.user!));
    } else {
      if (state.errorMessage == null) {
        emit(const AuthState.unauthenticated());
      }
    }
  }

  // ... các hàm signIn... giữ nguyên ...
  Future<void> _handleSignIn(Future<void> Function() signInMethod, Emitter<AuthState> emit) async {
    try {
      await signInMethod();
    } on SuspendedAccountException catch (e) {
      emit(AuthState.unauthenticated(errorMessage: e.reason));
    } catch (e) {
      emit(AuthState.unauthenticated(errorMessage: e.toString()));
    }
  }

  Future<void> _onSignInWithGoogleRequested(
      SignInWithGoogleRequested event, Emitter<AuthState> emit) async {
    await _handleSignIn(_authService.signInWithGoogle, emit);
  }

  Future<void> _onSignInWithFacebookRequested(
      SignInWithFacebookRequested event, Emitter<AuthState> emit) async {
    await _handleSignIn(_authService.signInWithFacebook, emit);
  }

  Future<void> _onSignInWithAppleRequested(
      SignInWithAppleRequested event, Emitter<AuthState> emit) async {
    await _handleSignIn(_authService.signInWithApple, emit);
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}