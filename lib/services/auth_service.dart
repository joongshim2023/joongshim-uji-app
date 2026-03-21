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
      // Android/iOS: google_sign_in 7.x 새 API
      // GoogleSignIn.instance.initialize()는 main.dart에서 호출해야 함
      final result = await GoogleSignIn.instance.authenticate();
      // idToken만으로 Firebase 인증 (accessToken 불필요)
      final idToken = result.authentication.idToken;
      if (idToken == null) throw Exception('Google 로그인 실패: idToken을 가져올 수 없습니다.');

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _auth.signInWithCredential(credential);
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      // 모바일에서만 GoogleSignIn signOut (웹에서는 initialize 안 됨)
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }
}
