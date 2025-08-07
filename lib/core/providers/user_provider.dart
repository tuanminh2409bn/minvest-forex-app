// lib/core/providers/user_provider.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  // Các thuộc tính cũ
  String? _userTier;
  String? _verificationStatus;
  String? _verificationError;

  // ▼▼▼ THÊM CÁC THUỘC TÍNH MỚI ▼▼▼
  String? _role;
  bool _isSuspended = false;
  String? _suspensionReason;

  // Getters cho các thuộc tính cũ
  String? get userTier => _userTier;
  String? get verificationStatus => _verificationStatus;
  String? get verificationError => _verificationError;

  // ▼▼▼ THÊM GETTERS CHO CÁC THUỘC TÍNH MỚI ▼▼▼
  String? get role => _role;
  bool get isSuspended => _isSuspended;
  String? get suspensionReason => _suspensionReason;


  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  UserProvider() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _resetState();
      _userSubscription?.cancel();
    } else {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          // Lấy dữ liệu cũ
          _userTier = data['subscriptionTier'];
          _verificationStatus = data['verificationStatus'];
          _verificationError = data['verificationError'];

          // ▼▼▼ LẤY DỮ LIỆU CHO CÁC TRƯỜNG MỚI ▼▼▼
          _role = data['role'] ?? 'user'; // Mặc định là 'user' nếu chưa có
          _isSuspended = data['isSuspended'] ?? false; // Mặc định là 'false' nếu chưa có
          _suspensionReason = data['suspensionReason']; // Có thể null

        } else {
          _resetState();
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _resetState() {
    _userTier = null;
    _verificationStatus = null;
    _verificationError = null;
    // ▼▼▼ RESET CÁC TRẠNG THÁI MỚI KHI LOGOUT ▼▼▼
    _role = null;
    _isSuspended = false;
    _suspensionReason = null;
  }

  // Hàm này của bạn giữ nguyên
  void clearVerificationStatus() {
    if (_verificationStatus == 'failed') {
      _verificationStatus = null;
      _verificationError = null;
      // Không cần notifyListeners() ở đây trừ khi bạn muốn cập nhật UI ngay lập tức
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }
}