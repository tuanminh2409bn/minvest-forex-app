import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  String? _userTier;
  String? _verificationStatus;
  String? _verificationError;

  String? get userTier => _userTier;
  String? get verificationStatus => _verificationStatus;
  String? get verificationError => _verificationError;

  UserProvider() {
    _listenToUserChanges();
  }

  void _listenToUserChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            _userTier = data['subscriptionTier'];
            _verificationStatus = data['verificationStatus'];
            _verificationError = data['verificationError'];
          } else {
            _resetState();
          }
          notifyListeners();
        });
      } else {
        _resetState();
        notifyListeners();
      }
    });
  }

  void _resetState() {
    _userTier = null;
    _verificationStatus = null;
    _verificationError = null;
  }

  void clearVerificationStatus() {
    if (_verificationStatus == 'failed') {
      _verificationStatus = null;
      _verificationError = null;
    }
  }
}