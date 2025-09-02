// lib/features/auth/bloc/auth_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';

// Import exception của bạn để có thể bắt nó một cách cụ thể
import 'package:minvest_forex_app/core/exceptions/auth_exceptions.dart';

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

  void _onAuthStateChanged(AuthStateChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(AuthState.authenticated(event.user!));
    } else {
      // Chỉ emit unauthenticated nếu state hiện tại không chứa lỗi.
      // Điều này ngăn việc ghi đè thông báo lỗi quan trọng.
      if (state.errorMessage == null) {
        emit(const AuthState.unauthenticated());
      }
    }
  }

  // Helper function để xử lý các hành động đăng nhập
  Future<void> _handleSignIn(Future<void> Function() signInMethod, Emitter<AuthState> emit) async {
    try {
      await signInMethod();
      // Thành công thì không cần emit, authStateChanges sẽ lo.
    } on SuspendedAccountException catch (e) {
      // Bắt lỗi tài khoản bị treo
      emit(AuthState.unauthenticated(errorMessage: e.reason));
    } catch (e) {
      // Bắt tất cả các lỗi khác và hiển thị thông báo của chúng
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

  void _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) {
    _authService.signOut();
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}