// lib/core/providers/user_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// THÊM IMPORT NÀY
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';

enum UserDataStatus {
  initial,
  loading,
  fromCache,
  fromServer,
  error
}

class UserProvider with ChangeNotifier {
  // THÊM MỚI: AuthService là nguồn xác thực duy nhất
  final AuthService _authService;

  String? _uid;
  String? _userTier;
  String? _verificationStatus;
  String? _verificationError;
  String? _role;
  UserDataStatus _status = UserDataStatus.initial;
  bool _requiresDowngradeAcknowledgement = false;
  String? _downgradeReason;

  String? get userTier => _userTier;
  String? get verificationStatus => _verificationStatus;
  String? get verificationError => _verificationError;
  String? get role => _role;
  UserDataStatus get status => _status;
  bool get requiresDowngradeAcknowledgement => _requiresDowngradeAcknowledgement;
  String? get downgradeReason => _downgradeReason;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  // THÊM MỚI: Subscription để lắng nghe trạng thái đăng nhập
  StreamSubscription<User?>? _authStateSubscription;

  // THAY ĐỔI LỚN: Constructor giờ đây nhận AuthService
  UserProvider({required AuthService authService}) : _authService = authService {
    // Tự động lắng nghe sự thay đổi trạng thái đăng nhập ngay khi được tạo
    _authStateSubscription = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  // Hàm này sẽ được gọi tự động khi người dùng đăng nhập hoặc đăng xuất
  void _onAuthStateChanged(User? firebaseUser) {
    if (firebaseUser != null) {
      // Nếu có user, bắt đầu lắng nghe document của họ
      _listenToUserDocument(firebaseUser.uid);
    } else {
      // Nếu không có user (đã đăng xuất), dọn dẹp
      stopListeningAndReset();
    }
  }

  // Đổi tên hàm `listenToUserData` thành `_listenToUserDocument` để rõ ràng hơn
  void _listenToUserDocument(String uid) {
    _uid = uid;
    _userSubscription?.cancel();
    _status = UserDataStatus.loading;
    notifyListeners(); // Thông báo trạng thái loading

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      final bool isFromCache = snapshot.metadata.isFromCache;
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _userTier = data['subscriptionTier'];
        _verificationStatus = data['verificationStatus'];
        _verificationError = data['verificationError'];
        _role = data['role'] ?? 'user';
        _requiresDowngradeAcknowledgement = data['requiresDowngradeAcknowledgement'] ?? false;
        _downgradeReason = data['downgradeReason'];
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

  Future<void> acknowledgeDowngrade() async {
    if (_uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(_uid!).update({
          'requiresDowngradeAcknowledgement': FieldValue.delete(),
        });
        _requiresDowngradeAcknowledgement = false;
        notifyListeners();
      } catch (e) {
        print("Lỗi khi xác nhận hạ cấp: $e");
      }
    }
  }

  Future<void> stopListeningAndReset() async {
    await _userSubscription?.cancel();
    _userSubscription = null;
    _resetState();
    _status = UserDataStatus.initial;
    notifyListeners();
  }

  void _resetState() {
    _uid = null;
    _userTier = null;
    _verificationStatus = null;
    _verificationError = null;
    _role = null;
    _requiresDowngradeAcknowledgement = false;
    _downgradeReason = null;
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
    _authStateSubscription?.cancel(); // Dọn dẹp subscription mới
    super.dispose();
  }
}