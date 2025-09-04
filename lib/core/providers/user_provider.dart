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
  String? _uid; // THÊM MỚI: Lưu UID của user hiện tại
  String? _userTier;
  String? _verificationStatus;
  String? _verificationError;
  String? _role;
  UserDataStatus _status = UserDataStatus.initial;

  // THAY ĐỔI 1: Xóa các trường cũ và thêm các trường mới
  bool _requiresDowngradeAcknowledgement = false;
  String? _downgradeReason;

  String? get userTier => _userTier;
  String? get verificationStatus => _verificationStatus;
  String? get verificationError => _verificationError;
  String? get role => _role;
  UserDataStatus get status => _status;

  // THAY ĐỔI 2: Thêm getters cho các trường mới
  bool get requiresDowngradeAcknowledgement => _requiresDowngradeAcknowledgement;
  String? get downgradeReason => _downgradeReason;


  StreamSubscription<DocumentSnapshot>? _userSubscription;

  void listenToUserData(User firebaseUser) {
    _uid = firebaseUser.uid; // THÊM MỚI: Lưu lại UID
    _userSubscription?.cancel();
    _status = UserDataStatus.loading;

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

        // THAY ĐỔI 3: Đọc dữ liệu từ các trường mới
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

  // THAY ĐỔI 4: Hàm mới để người dùng xác nhận
  /// Cập nhật Firestore để xóa cờ yêu cầu xác nhận.
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

    // Reset các trường mới
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
    super.dispose();
  }
}