// lib/core/providers/user_provider.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  String? _userTier;
  String? _verificationStatus;
  String? _verificationError;
  String? _role;
  bool _isSuspended = false;
  String? _suspensionReason;

  String? get userTier => _userTier;
  String? get verificationStatus => _verificationStatus;
  String? get verificationError => _verificationError;
  String? get role => _role;
  bool get isSuspended => _isSuspended;
  String? get suspensionReason => _suspensionReason;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  UserProvider() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    // ▼▼▼ LOGIC ĐÃ ĐƯỢC LÀM AN TOÀN HƠN ▼▼▼

    // 1. Luôn hủy listener cũ ngay từ đầu để tránh rò rỉ.
    await _userSubscription?.cancel();

    if (firebaseUser == null) {
      // 2. Nếu người dùng đã đăng xuất, reset trạng thái ngay lập tức và thoát.
      _resetState();
      notifyListeners();
      return;
    }

    // 3. Chỉ tạo listener mới khi chắc chắn có người dùng đã đăng nhập.
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _userTier = data['subscriptionTier'];
        _verificationStatus = data['verificationStatus'];
        _verificationError = data['verificationError'];
        _role = data['role'] ?? 'user';
        _isSuspended = data['isSuspended'] ?? false;
        _suspensionReason = data['suspensionReason'];
      } else {
        _resetState();
      }
      notifyListeners();
    });
  }

  void _resetState() {
    _userTier = null;
    _verificationStatus = null;
    _verificationError = null;
    _role = null;
    _isSuspended = false;
    _suspensionReason = null;
  }

  void clearVerificationStatus() {
    if (_verificationStatus == 'failed') {
      _verificationStatus = null;
      _verificationError = null;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }
}