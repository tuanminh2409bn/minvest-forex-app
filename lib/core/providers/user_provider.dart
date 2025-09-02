// lib/core/providers/user_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum UserDataStatus {
  initial,
  loading,
  fromCache,
  fromServer,
  error
}

class UserProvider with ChangeNotifier {
  String? _userTier;
  String? _verificationStatus;
  String? _verificationError;
  String? _role;
  bool _isSuspended = false;
  String? _suspensionReason;
  UserDataStatus _status = UserDataStatus.initial;

  String? get userTier => _userTier;
  String? get verificationStatus => _verificationStatus;
  String? get verificationError => _verificationError;
  String? get role => _role;
  bool get isSuspended => _isSuspended;
  String? get suspensionReason => _suspensionReason;
  UserDataStatus get status => _status;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  void listenToUserData(User firebaseUser) {
    _userSubscription?.cancel();
    _status = UserDataStatus.loading;
    // Không cần notifyListeners() ngay đây, để tránh rebuild không cần thiết

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      final bool isFromCache = snapshot.metadata.isFromCache;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _userTier = data['subscriptionTier'];
        _verificationStatus = data['verificationStatus'];
        _verificationError = data['verificationError'];
        _role = data['role'] ?? 'user';
        _isSuspended = data['isSuspended'] ?? false;
        _suspensionReason = data['suspensionReason'];
        _status = isFromCache ? UserDataStatus.fromCache : UserDataStatus.fromServer;
      } else {
        _resetState();
        _status = UserDataStatus.fromServer;
      }
      notifyListeners();
    }, onError: (error) {
      print("Lỗi khi lắng nghe dữ liệu người dùng: $error");
      _status = UserDataStatus.error;
      _resetState();
      notifyListeners();
    });
  }

  // ▼▼▼ HÀM ĐÃ ĐƯỢC SỬA LỖI ▼▼▼
  Future<void> stopListeningAndReset() async {
    // Chờ cho stream được hủy hoàn toàn
    await _userSubscription?.cancel();
    _userSubscription = null;
    _resetState();
    _status = UserDataStatus.initial;
    notifyListeners();
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
    _userSubscription?.cancel();
    super.dispose();
  }
}