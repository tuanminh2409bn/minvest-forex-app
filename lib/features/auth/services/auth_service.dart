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
        // Người dùng đã đăng xuất rồi, không cần làm gì thêm.
        return;
      }

      // Lặp qua tất cả các nhà cung cấp mà người dùng đã liên kết
      for (final provider in user.providerData) {
        switch (provider.providerId) {
          case 'google.com':
          // Chỉ đăng xuất Google nếu người dùng đã đăng nhập bằng Google
            await GoogleSignIn().signOut();
            print("Signed out from Google");
            break;
          case 'facebook.com':
          // Chỉ đăng xuất Facebook nếu người dùng đã đăng nhập bằng Facebook
          // Thêm kiểm tra accessToken để chắc chắn
            final accessToken = await FacebookAuth.instance.accessToken;
            if (accessToken != null) {
              await FacebookAuth.instance.logOut();
              print("Signed out from Facebook");
            }
            break;
          case 'apple.com':
          // Đăng nhập bằng Apple không yêu cầu một lệnh signOut riêng biệt từ client.
          // Việc signOut khỏi Firebase là đủ.
            print("Apple user signing out (handled by Firebase signOut)");
            break;
        }
      }
    } catch (e) {
      // Ghi lại lỗi nếu có, nhưng không dừng quá trình đăng xuất
      print("Error during social sign out: $e");
    } finally {
      // QUAN TRỌNG: Luôn đăng xuất khỏi Firebase ở cuối cùng,
      // bất kể các bước trên thành công hay thất bại.
      await _firebaseAuth.signOut();
      print("Signed out from Firebase");
    }
  }
}
