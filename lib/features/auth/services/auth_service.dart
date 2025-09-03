// lib/features/auth/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:minvest_forex_app/services/device_info_service.dart';
import 'package:minvest_forex_app/core/exceptions/auth_exceptions.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> _requestTrackingPermission() async {
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<User?> _handleSuccessfulSignIn(UserCredential userCredential, {
    Map<String, dynamic>? facebookUserData,
    String? appleEmail,
    String? appleFullName,
    String? googleEmail,
  }) async {
    final User? user = userCredential.user;
    if (user == null) return null;

    try {
      await _firestore.runTransaction((transaction) async {
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await transaction.get(userDocRef);

        if (!userDoc.exists) {
          // ▼▼▼ LOGIC LẤY EMAIL ĐÃ ĐƯỢC LÀM CHO LINH HOẠT HƠN ▼▼▼
          String? email = googleEmail ?? appleEmail ?? facebookUserData?['email'] ?? user.email;
          final displayName = appleFullName ?? facebookUserData?['name'] ?? user.displayName;
          final photoURL = facebookUserData?['picture']?['data']?['url'] ?? user.photoURL;

          // Nếu email vẫn là null, kiểm tra xem có phải do Apple không cung cấp không
          if (email == null && user.providerData.any((p) => p.providerId == 'apple.com')) {
            print("AuthService: Email từ Apple là null (có thể do máy ảo). Tạo email tạm thời.");
            // Tạo một email tạm thời để vượt qua bước này
            email = '${user.uid}@appleid.placeholder.com';
          }

          // Bây giờ mới kiểm tra lần cuối, nếu vẫn null thì mới là lỗi thực sự
          if (email == null) {
            throw Exception("Không thể lấy được địa chỉ email. Vui lòng thử lại.");
          }
          // ▲▲▲ KẾT THÚC THAY ĐỔI ▲▲▲

          transaction.set(userDocRef, {
            'uid': user.uid,
            'email': email,
            'displayName': displayName,
            'photoURL': photoURL,
            'createdAt': Timestamp.now(),
            'subscriptionTier': 'free',
            'role': 'user',
            'isSuspended': false,
          });
        } else {
          if (userDoc.data()?['isSuspended'] == true) {
            throw SuspendedAccountException(userDoc.data()?['suspensionReason'] ?? 'Vui lòng liên hệ quản trị viên.');
          }
        }
      });
    } catch (e) {
      print("Lỗi trong transaction tạo user: $e");
      rethrow;
    }

    await _updateUserSession();
    return user;
  }

  Future<void> _updateUserSession() async {
    if (kIsWeb) return;
    try {
      String? fcmToken;
      if (Platform.isIOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          print('AuthService: Không thể lấy APNS token (máy ảo), bỏ qua cập nhật session.');
          return;
        }
      }
      fcmToken = await FirebaseMessaging.instance.getToken();
      final deviceId = await DeviceInfoService.getDeviceId();
      if (fcmToken == null) return;

      final callable = FirebaseFunctions.instanceFor(region: "asia-southeast1").httpsCallable('manageUserSession');
      await callable.call({'deviceId': deviceId, 'fcmToken': fcmToken});
      print('AuthService: Cập nhật session thành công!');
    } catch (e) {
      print('AuthService: Lỗi khi cập nhật session: $e');
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final String? googleEmail = googleUser.email;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      return await _handleSuccessfulSignIn(userCredential, googleEmail: googleEmail);
    } catch (e) {
      print('Lỗi đăng nhập Google: $e');
      rethrow;
    }
  }

  Future<User?> signInWithFacebook() async {
    try {
      await _requestTrackingPermission();
      UserCredential userCredential;
      Map<String, dynamic>? facebookUserData;
      if (kIsWeb) {
        userCredential = await _firebaseAuth.signInWithPopup(FacebookAuthProvider());
      } else {
        final LoginResult result = await FacebookAuth.instance.login(
          loginTracking: LoginTracking.enabled,
          permissions: ['public_profile', 'email'],
        );
        if (result.status != LoginStatus.success) return null;
        facebookUserData = await FacebookAuth.instance.getUserData(fields: "name,email,picture.width(200)");
        final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
        userCredential = await _firebaseAuth.signInWithCredential(credential);
      }
      return await _handleSuccessfulSignIn(userCredential, facebookUserData: facebookUserData);
    } catch (e) {
      print('Lỗi đăng nhập Facebook: $e');
      rethrow;
    }
  }

  Future<User?> signInWithApple() async {
    try {
      UserCredential userCredential;
      String? appleEmail;
      String? appleFullName;
      if (kIsWeb) {
        userCredential = await _firebaseAuth.signInWithPopup(AppleAuthProvider());
      } else if (Platform.isIOS || Platform.isMacOS) {
        final rawNonce = _generateNonce();
        final nonce = _sha256(rawNonce);
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
          nonce: nonce,
        );
        appleEmail = appleCredential.email;
        if (appleCredential.givenName != null || appleCredential.familyName != null) {
          appleFullName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
        }
        final oAuthCredential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
          accessToken: appleCredential.authorizationCode,
        );
        userCredential = await _firebaseAuth.signInWithCredential(oAuthCredential);
      } else {
        throw UnsupportedError('Đăng nhập Apple không được hỗ trợ trên thiết bị này.');
      }
      return await _handleSuccessfulSignIn(userCredential, appleEmail: appleEmail, appleFullName: appleFullName);
    } catch (e) {
      print('Lỗi đăng nhập Apple: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await FacebookAuth.instance.logOut();
    } catch (e) {
      print("Lỗi khi đăng xuất khỏi các nhà cung cấp: $e");
    } finally {
      await _firebaseAuth.signOut();
      print("Đã đăng xuất khỏi Firebase");
    }
  }
}