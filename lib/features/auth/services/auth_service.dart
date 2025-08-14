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
import 'dart:convert';
import 'dart:math';
import 'dart:io';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

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

  // =======================================================================
  // === HÀM XỬ LÝ TRUNG TÂM (PHIÊN BẢN HOÀN THIỆN NHẤT) ===
  // =======================================================================
  Future<User?> _handleSuccessfulSignIn(UserCredential userCredential, {
    // Dữ liệu gốc đáng tin cậy từ các nhà cung cấp
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
          // LOGIC ƯU TIÊN VÀNG: Lấy email từ nguồn đáng tin cậy nhất trước.
          final email = googleEmail // 1. Ưu tiên Google
              ?? appleEmail // 2. Ưu tiên Apple
              ?? facebookUserData?['email'] // 3. Ưu tiên Facebook
              ?? user.email; // 4. Cuối cùng mới dùng của Firebase (dự phòng)

          // Tương tự, lấy tên từ nguồn đáng tin cậy nhất
          final displayName = appleFullName
              ?? facebookUserData?['name']
              ?? user.displayName;

          final photoURL = facebookUserData?['picture']?['data']?['url'] ?? user.photoURL;

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
        } else {
          // Nếu document đã tồn tại, chỉ kiểm tra xem tài khoản có bị khóa không
          if (userDoc.data()?['isSuspended'] == true) {
            throw SuspendedAccountException(userDoc.data()?['suspensionReason'] ?? 'Vui lòng liên hệ quản trị viên.');
          }
        }
      });
    } on SuspendedAccountException {
      await signOut();
      rethrow;
    } catch (e) {
      print("Lỗi nghiêm trọng trong transaction tạo user: $e");
      await signOut();
      return null;
    }

    // Luôn cập nhật session sau khi đã đảm bảo hồ sơ tồn tại và hợp lệ
    if (!kIsWeb) {
      await _updateUserSession();
    }

    return user;
  }

  Future<void> _updateUserSession() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final deviceId = await DeviceInfoService.getDeviceId();
      if (fcmToken == null || deviceId == null) return;
      final callable = FirebaseFunctions.instanceFor(region: "asia-southeast1").httpsCallable('manageUserSession');
      await callable.call({'deviceId': deviceId, 'fcmToken': fcmToken});
      print('Cập nhật session thành công!');
    } catch (e) {
      print('Lỗi khi cập nhật session: $e');
    }
  }

  // =======================================================================
  // === CÁC PHƯƠNG THỨC ĐĂNG NHẬP (PHIÊN BẢN HOÀN THIỆN NHẤT) ===
  // =======================================================================

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // Người dùng đã hủy

      // LẤY TẠI NGUỒN: Lấy email trực tiếp từ Google.
      final String? googleEmail = googleUser.email;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);

      // Truyền dữ liệu gốc vào hàm xử lý
      return await _handleSuccessfulSignIn(userCredential, googleEmail: googleEmail);
    } on SuspendedAccountException {
      rethrow;
    } catch (e) {
      print('Lỗi đăng nhập Google: $e');
      return null;
    }
  }

  Future<User?> signInWithFacebook() async {
    try {
      UserCredential userCredential;
      Map<String, dynamic>? facebookUserData;

      if (kIsWeb) {
        userCredential = await _firebaseAuth.signInWithPopup(FacebookAuthProvider());
        // Lưu ý: Lấy Facebook User Data trên web phức tạp hơn, có thể cần gọi Graph API sau khi đăng nhập.
        // Tạm thời bỏ qua để giữ luồng đơn giản, vì lỗi chính nằm trên mobile.
      } else {
        final LoginResult result = await FacebookAuth.instance.login(
          permissions: ['public_profile', 'email'],
        );
        if (result.status != LoginStatus.success) return null;

        // LẤY TẠI NGUỒN: Lấy dữ liệu trực tiếp từ Facebook.
        facebookUserData = await FacebookAuth.instance.getUserData(
          fields: "name,email,picture.width(200)",
        );

        final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
        userCredential = await _firebaseAuth.signInWithCredential(credential);
      }

      // Truyền dữ liệu gốc vào hàm xử lý
      return await _handleSuccessfulSignIn(userCredential, facebookUserData: facebookUserData);
    } on SuspendedAccountException {
      rethrow;
    } catch (e) {
      print('Lỗi đăng nhập Facebook: $e');
      return null;
    }
  }

  Future<User?> signInWithApple() async {
    try {
      UserCredential userCredential;
      String? appleEmail;
      String? appleFullName;

      if (kIsWeb) {
        final appleProvider = AppleAuthProvider();
        userCredential = await _firebaseAuth.signInWithPopup(appleProvider);
      } else if (Platform.isIOS || Platform.isMacOS) {
        final rawNonce = _generateNonce();
        final nonce = _sha256(rawNonce);

        // LẤY TẠI NGUỒN: Lấy thông tin trực tiếp từ Apple.
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
        );
        userCredential = await _firebaseAuth.signInWithCredential(oAuthCredential);
      } else {
        throw UnsupportedError('Đăng nhập Apple không được hỗ trợ trên thiết bị này.');
      }

      // Truyền dữ liệu gốc vào hàm xử lý
      return await _handleSuccessfulSignIn(userCredential, appleEmail: appleEmail, appleFullName: appleFullName);
    } on SuspendedAccountException {
      rethrow;
    } catch (e) {
      print('Lỗi đăng nhập Apple: $e');
      return null;
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