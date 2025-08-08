// lib/features/auth/bloc/auth_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _userSubscription;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthState.unknown()) {
    // Lắng nghe sự thay đổi trạng thái đăng nhập từ Firebase
    _userSubscription = _authService.authStateChanges.listen(
          (user) => add(AuthStateChanged(user)),
    );

    on<AuthStateChanged>(_onAuthStateChanged);
    on<SignOutRequested>(_onSignOutRequested);
  }

  void _onAuthStateChanged(AuthStateChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(AuthState.authenticated(event.user!));
    } else {
      emit(const AuthState.unauthenticated());
    }
  }

  void _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) {
    // BLoC sẽ gọi hàm signOut mà không cần context
    _authService.signOut();
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}