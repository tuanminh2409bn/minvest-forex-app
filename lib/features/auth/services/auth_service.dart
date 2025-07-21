import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

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
        // SỬA LỖI Ở ĐÂY: Dùng accessToken.tokenString
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

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FacebookAuth.instance.logOut();
    await _firebaseAuth.signOut();
  }
}