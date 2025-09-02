// lib/features/auth/bloc/auth_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minvest_forex_app/core/exceptions/auth_exceptions.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _userSubscription;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthState.unknown()) {
    // Luôn lắng nghe sự thay đổi trạng thái từ Firebase
    _userSubscription = _authService.authStateChanges.listen(
          (user) => add(AuthStateChanged(user)),
    );

    // ▼▼▼ ĐÂY LÀ PHẦN QUAN TRỌNG NHẤT ▼▼▼
    // Đăng ký các hàm xử lý cho từng Event
    on<AuthStateChanged>(_onAuthStateChanged);
    on<SignOutRequested>(_onSignOutRequested);
    on<SignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<SignInWithFacebookRequested>(_onSignInWithFacebookRequested);
    on<SignInWithAppleRequested>(_onSignInWithAppleRequested);
    // ▲▲▲ ĐẢM BẢO CÓ ĐẦY ĐỦ CÁC DÒNG TRÊN ▲▲▲
  }

  void _onAuthStateChanged(AuthStateChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(AuthState.authenticated(event.user!));
    } else {
      if (state.errorMessage == null) {
        emit(const AuthState.unauthenticated());
      }
    }
  }

  Future<void> _onSignInWithGoogleRequested(
      SignInWithGoogleRequested event, Emitter<AuthState> emit) async {
    try {
      await _authService.signInWithGoogle();
    } on SuspendedAccountException catch (e) {
      emit(AuthState.unauthenticated(errorMessage: e.reason));
    } catch (e) {
      emit(const AuthState.unauthenticated(errorMessage: 'Đăng nhập Google thất bại. Vui lòng thử lại.'));
    }
  }

  Future<void> _onSignInWithFacebookRequested(
      SignInWithFacebookRequested event, Emitter<AuthState> emit) async {
    try {
      await _authService.signInWithFacebook();
    } on SuspendedAccountException catch (e) {
      emit(AuthState.unauthenticated(errorMessage: e.reason));
    } catch (e) {
      emit(const AuthState.unauthenticated(errorMessage: 'Đăng nhập Facebook thất bại. Vui lòng thử lại.'));
    }
  }

  Future<void> _onSignInWithAppleRequested(
      SignInWithAppleRequested event, Emitter<AuthState> emit) async {
    try {
      await _authService.signInWithApple();
    } on SuspendedAccountException catch (e) {
      emit(AuthState.unauthenticated(errorMessage: e.reason));
    } catch (e) {
      emit(const AuthState.unauthenticated(errorMessage: 'Đăng nhập Apple thất bại. Vui lòng thử lại.'));
    }
  }

  void _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) {
    _authService.signOut();
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}