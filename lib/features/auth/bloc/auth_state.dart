// lib/features/auth/bloc/auth_state.dart
part of 'auth_bloc.dart';

// ▼▼▼ THÊM TRẠNG THÁI MỚI ▼▼▼
enum AuthStatus { unknown, authenticated, unauthenticated, loggingOut }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState._({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
  });

  const AuthState.unknown() : this._();

  const AuthState.authenticated(User user)
      : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated({String? errorMessage})
      : this._(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  // ▼▼▼ THÊM CONSTRUCTOR CHO TRẠNG THÁI MỚI ▼▼▼
  const AuthState.loggingOut() : this._(status: AuthStatus.loggingOut);

  @override
  List<Object?> get props => [status, user, errorMessage];
}