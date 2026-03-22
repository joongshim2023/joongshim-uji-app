import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmailPassword(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      // 웹: popup 방식
      GoogleAuthProvider authProvider = GoogleAuthProvider();
      authProvider.setCustomParameters({'prompt': 'select_account'});
      return await _auth.signInWithPopup(authProvider);
    } else {
      // Android/iOS: google_sign_in 7.x
      final result = await GoogleSignIn.instance.authenticate();
      final idToken = result.authentication.idToken;
      if (idToken == null) throw Exception('Google 로그인 실패: idToken을 가져올 수 없습니다.');
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _auth.signInWithCredential(credential);
    }
  }

  Future<void> signOut() async {
    // Firebase signOut을 먼저 즉시 실행 (Android 지연 방지)
    await _auth.signOut();
    if (!kIsWeb) {
      // GoogleSignIn signOut은 백그라운드로 처리 (UI 블로킹 방지)
      GoogleSignIn.instance.signOut().catchError((_) {});
    }
  }
}
