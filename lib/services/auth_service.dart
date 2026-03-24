import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      GoogleAuthProvider authProvider = GoogleAuthProvider();
      authProvider.setCustomParameters({'prompt': 'select_account'});
      return await _auth.signInWithPopup(authProvider);
    } else {
      final result = await GoogleSignIn.instance.authenticate();
      final idToken = result.authentication.idToken;
      if (idToken == null) throw Exception('Google 로그인 실패: idToken을 가져올 수 없습니다.');
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _auth.signInWithCredential(credential);
    }
  }

  /// Sign in with Apple (iOS/macOS 전용)
  Future<UserCredential?> signInWithApple() async {
    // sign_in_with_apple 패키지 사용
    final appleProvider = AppleAuthProvider();
    appleProvider.addScope('email');
    appleProvider.addScope('fullName');
    if (kIsWeb) {
      return await _auth.signInWithPopup(appleProvider);
    } else {
      return await _auth.signInWithProvider(appleProvider);
    }
  }

  /// 계정 완전 삭제: Firestore 사용자 데이터 삭제 후 Firebase Auth 계정 삭제
  /// Apple/Google 로그인 사용자는 재인증 필요
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인된 사용자가 없습니다.');

    final uid = user.uid;

    // 1. Firestore 사용자 데이터 삭제 (daily_logs, settings, alarm_logs)
    await _deleteUserFirestoreData(uid);

    // 2. Firebase Auth 계정 삭제 (재인증이 필요할 수 있음 → 호출부에서 처리)
    await user.delete();

    // 3. Google 세션 정리
    if (!kIsWeb) {
      GoogleSignIn.instance.signOut().catchError((_) {});
    }
  }

  /// 이메일/비밀번호 사용자 재인증 (계정 삭제 전 사용)
  Future<void> reauthenticateWithPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인된 사용자가 없습니다.');
    final credential = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  /// Google 사용자 재인증 (계정 삭제 전 사용)
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인된 사용자가 없습니다.');
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      await user.reauthenticateWithPopup(googleProvider);
    } else {
      final result = await GoogleSignIn.instance.authenticate();
      final idToken = result.authentication.idToken;
      if (idToken == null) throw Exception('Google 재인증 실패: idToken 없음');
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await user.reauthenticateWithCredential(credential);
    }
  }

  /// Apple 사용자 재인증 (계정 삭제 전 사용)
  Future<void> reauthenticateWithApple() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인된 사용자가 없습니다.');
    final appleProvider = AppleAuthProvider();
    appleProvider.addScope('email');
    if (kIsWeb) {
      await user.reauthenticateWithPopup(appleProvider);
    } else {
      await user.reauthenticateWithProvider(appleProvider);
    }
  }

  /// Firestore에서 해당 유저의 모든 데이터 삭제
  Future<void> _deleteUserFirestoreData(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    // daily_logs 컬렉션 삭제
    final dailyLogs = await userRef.collection('daily_logs').get();
    for (final doc in dailyLogs.docs) {
      await doc.reference.delete();
    }

    // alarm_logs 컬렉션 삭제
    final alarmLogs = await userRef.collection('alarm_logs').get();
    for (final doc in alarmLogs.docs) {
      await doc.reference.delete();
    }

    // settings 컬렉션 삭제
    final settings = await userRef.collection('settings').get();
    for (final doc in settings.docs) {
      await doc.reference.delete();
    }

    // 유저 도큐먼트 자체 삭제 (있다면)
    await userRef.delete().catchError((_) {});
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      GoogleSignIn.instance.signOut().catchError((_) {});
    }
  }
}
