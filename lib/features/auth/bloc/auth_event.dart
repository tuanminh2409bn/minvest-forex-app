// lib/features/auth/bloc/auth_event.dart
part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStateChanged extends AuthEvent {
  final User? user;
  const AuthStateChanged(this.user);
  @override
  List<Object?> get props => [user];
}

class SignOutRequested extends AuthEvent {}

// ▼▼▼ Thêm các Event cho từng hành động đăng nhập ▼▼▼
class SignInWithGoogleRequested extends AuthEvent {}
class SignInWithFacebookRequested extends AuthEvent {}
class SignInWithAppleRequested extends AuthEvent {}