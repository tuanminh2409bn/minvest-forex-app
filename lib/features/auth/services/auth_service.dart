import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // --- CÁC HÀM SIGN-IN GIỮ NGUYÊN NHƯ CỦA BẠN ---
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null && userCredential.additionalUserInfo!.isNewUser) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'createdAt': Timestamp.now(),
          'subscriptionTier': 'free',
        });
      }
      return user;
    } catch (e) {
      print('Lỗi đăng nhập Google: $e');
      return null;
    }
  }

  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final OAuthCredential credential = FacebookAuthProvider.credential(accessToken.tokenString);
        final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null && userCredential.additionalUserInfo!.isNewUser) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid, 'email': user.email, 'displayName': user.displayName,
            'createdAt': Timestamp.now(), 'subscriptionTier': 'free',
          });
        }
        return user;
      } else { return null; }
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

      if (user != null && userCredential.additionalUserInfo!.isNewUser) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid, 'email': user.email,
          'displayName': user.displayName ?? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim(),
          'createdAt': Timestamp.now(), 'subscriptionTier': 'free',
        });
      }
      return user;
    } catch (e) {
      print('Lỗi đăng nhập Apple: $e');
      return null;
    }
  }

  // --- HÀM SIGN OUT ĐÃ ĐƯỢC SỬA LẠI HOÀN CHỈNH ---
  Future<void> signOut() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return;
      }

      for (final provider in user.providerData) {
        switch (provider.providerId) {
        // ▼▼▼ SỬA ĐOẠN CODE TRONG CASE NÀY ▼▼▼
          case 'google.com':
          // Thêm lệnh disconnect() để xóa hoàn toàn session của Google
          // trên client. Đây là bước quan trọng nhất.
            await GoogleSignIn().disconnect();

            // Bạn vẫn có thể gọi thêm signOut() để chắc chắn.
            await GoogleSignIn().signOut();
            print("Disconnected and Signed out from Google");
            break;
        // ▲▲▲ KẾT THÚC PHẦN SỬA ĐỔI ▲▲▲

          case 'facebook.com':
            final accessToken = await FacebookAuth.instance.accessToken;
            if (accessToken != null) {
              await FacebookAuth.instance.logOut();
              print("Signed out from Facebook");
            }
            break;
          case 'apple.com':
            print("Apple user signing out (handled by Firebase signOut)");
            break;
        }
      }
    } catch (e) {
      print("Error during social sign out: $e");
    } finally {
      // Luôn đăng xuất khỏi Firebase ở cuối cùng
      await _firebaseAuth.signOut();
      print("Signed out from Firebase");
    }
  }
}
