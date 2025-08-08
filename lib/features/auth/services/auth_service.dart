import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:minvest_forex_app/services/device_info_service.dart';
import 'package:minvest_forex_app/core/exceptions/auth_exceptions.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Hàm quản lý phiên đăng nhập 1 thiết bị
  Future<void> _updateUserSession() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final deviceId = await DeviceInfoService.getDeviceId();

      if (fcmToken == null || deviceId == null) {
        print('Không thể lấy được fcmToken hoặc deviceId.');
        return;
      }

      final callable = FirebaseFunctions.instanceFor(region: "asia-southeast1")
          .httpsCallable('manageUserSession');

      await callable.call(<String, dynamic>{
        'deviceId': deviceId,
        'fcmToken': fcmToken,
      });

      print('Cập nhật session thành công!');

    } catch (e) {
      print('Lỗi khi cập nhật session: $e');
    }
  }

  // === CÁC HÀM SIGN-IN ĐÃ ĐƯỢC SỬA LẠI HOÀN CHỈNH ===

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // Người dùng hủy đăng nhập

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // KIỂM TRA TÀI KHOẢN BỊ KHÓA VÀ NÉM EXCEPTION
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()?['isSuspended'] == true) {
          final reason = userDoc.data()?['suspensionReason'] ?? 'Vui lòng liên hệ quản trị viên.';
          await signOut(); // Đăng xuất thầm lặng để xóa trạng thái
          throw SuspendedAccountException(reason); // Ném ra lỗi để UI bắt
        }

        if (userCredential.additionalUserInfo!.isNewUser) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid, 'email': user.email, 'displayName': user.displayName,
            'createdAt': Timestamp.now(), 'subscriptionTier': 'free', 'role': 'user', 'isSuspended': false, 'role': 'user',
          });
        }
        await _updateUserSession();
      }
      return user;
    } on SuspendedAccountException {
      rethrow; // Ném lại để UI bắt được chính xác lỗi này
    } catch (e) {
      print('Lỗi đăng nhập Google: $e');
      // Không ném lại lỗi chung, để UI chỉ cần biết là thất bại
      return null;
    }
  }

  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) return null;

      final AccessToken accessToken = result.accessToken!;
      final OAuthCredential credential = FacebookAuthProvider.credential(accessToken.tokenString);
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // KIỂM TRA TÀI KHOẢN BỊ KHÓA
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()?['isSuspended'] == true) {
          final reason = userDoc.data()?['suspensionReason'] ?? 'Vui lòng liên hệ quản trị viên.';
          await signOut();
          throw SuspendedAccountException(reason);
        }

        if (userCredential.additionalUserInfo!.isNewUser) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid, 'email': user.email, 'displayName': user.displayName,
            'createdAt': Timestamp.now(), 'subscriptionTier': 'free', 'role': 'user', 'isSuspended': false, 'role': 'user',
          });
        }
        await _updateUserSession();
      }
      return user;
    } on SuspendedAccountException {
      rethrow;
    } catch (e) {
      print('Lỗi đăng nhập Facebook: $e');
      return null;
    }
  }

  Future<User?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(scopes: [
        AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName,
      ]);
      final oAuthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(oAuthCredential);
      final User? user = userCredential.user;

      if (user != null) {
        // KIỂM TRA TÀI KHOẢN BỊ KHÓA
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()?['isSuspended'] == true) {
          final reason = userDoc.data()?['suspensionReason'] ?? 'Vui lòng liên hệ quản trị viên.';
          await signOut();
          throw SuspendedAccountException(reason);
        }

        if (userCredential.additionalUserInfo!.isNewUser) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid, 'email': user.email,
            'displayName': user.displayName ?? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim(),
            'createdAt': Timestamp.now(), 'subscriptionTier': 'free', 'role': 'user', 'isSuspended': false, 'role': 'user',
          });
        }
        await _updateUserSession();
      }
      return user;
    } on SuspendedAccountException {
      rethrow;
    } catch (e) {
      print('Lỗi đăng nhập Apple: $e');
      return null;
    }
  }

  // HÀM SIGN OUT ĐÃ TRỞ LẠI KHÔNG CẦN CONTEXT
  Future<void> signOut() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return;
      }

      // Ngắt kết nối khỏi các nhà cung cấp mạng xã hội
      for (final provider in user.providerData) {
        switch (provider.providerId) {
          case 'google.com':
            await GoogleSignIn().signOut();
            print("Disconnected and Signed out from Google");
            break;
          case 'facebook.com':
            await FacebookAuth.instance.logOut();
            break;
          case 'apple.com':
            break;
        }
      }
    } catch (e) {
      print("Error during social sign out: $e");
    } finally {
      // Luôn luôn đăng xuất khỏi Firebase cuối cùng
      await _firebaseAuth.signOut();
      print("Signed out from Firebase");
    }
  }
}