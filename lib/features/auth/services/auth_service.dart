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
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: "asia-southeast1");

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
    bool isAnonymous = false, // MỚI: Thêm cờ để nhận biết đăng nhập ẩn danh
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
          if (isAnonymous) {
            // MỚI: Xử lý cho người dùng ẩn danh
            transaction.set(userDocRef, {
              'uid': user.uid,
              'email': 'guest_${user.uid}@minvest.com',
              'displayName': 'Guest',
              'photoURL': null,
              'createdAt': Timestamp.now(),
              'subscriptionTier': 'free',
              'role': 'guest', // Gán vai trò là 'guest'
              'isSuspended': false,
            });
          } else {
            // Logic cũ cho người dùng đăng nhập qua mạng xã hội
            String? email = googleEmail ?? appleEmail ?? facebookUserData?['email'] ?? user.email;
            final displayName = appleFullName ?? facebookUserData?['name'] ?? user.displayName;
            final photoURL = facebookUserData?['picture']?['data']?['url'] ?? user.photoURL;

            if (email == null && user.providerData.any((p) => p.providerId == 'apple.com')) {
              email = '${user.uid}@appleid.placeholder.com';
            }

            if (email == null) {
              throw Exception("Không thể lấy được địa chỉ email. Vui lòng thử lại.");
            }

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
          }
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

    // Người dùng ẩn danh không cần token FCM hay session phức tạp
    if (!isAnonymous) {
      await _updateUserSession();
    }
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

      final callable = _functions.httpsCallable('manageUserSession');
      await callable.call({'deviceId': deviceId, 'fcmToken': fcmToken});
      print('AuthService: Cập nhật session thành công!');
    } catch (e) {
      print('AuthService: Lỗi khi cập nhật session: $e');
    }
  }

  // MỚI BẮT ĐẦU: Phương thức đăng nhập ẩn danh
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _firebaseAuth.signInAnonymously();
      return await _handleSuccessfulSignIn(userCredential, isAnonymous: true);
    } catch (e) {
      print('Lỗi đăng nhập ẩn danh: $e');
      rethrow;
    }
  }
  // MỚI KẾT THÚC

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

  // MỚI BẮT ĐẦU: Phương thức xóa tài khoản và dữ liệu
  Future<void> deleteAccountAndData() async {
    try {
      final callable = _functions.httpsCallable('deleteUserAccount');
      final result = await callable.call();
      print('Cloud function deleteUserAccount được gọi thành công: ${result.data}');
      // Sau khi function thực thi, user sẽ tự động bị đăng xuất do auth state thay đổi
      // Nhưng chúng ta vẫn gọi signOut ở client để đảm bảo dọn dẹp ngay lập tức
      await signOut();
    } on FirebaseFunctionsException catch (e) {
      print('Lỗi khi gọi cloud function: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Lỗi không xác định khi xóa tài khoản: $e');
      rethrow;
    }
  }
// MỚI KẾT THÚC
}