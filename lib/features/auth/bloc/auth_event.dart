// lib/features/auth/bloc/auth_event.dart
part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

// Sự kiện khi trạng thái auth thay đổi (e.g., app khởi động)
class AuthStateChanged extends AuthEvent {
  final User? user;
  const AuthStateChanged(this.user);
}

// Sự kiện khi người dùng nhấn nút đăng xuất
class SignOutRequested extends AuthEvent {}