import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'energy_service.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'ko';

  String get currentLanguage => _currentLanguage;

  LanguageProvider({String initialLanguage = 'ko'}) {
    _currentLanguage = initialLanguage;
    _loadLanguage();
    
    // 로그인 상태가 변경될 때마다 Firestore와 동기화
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _syncWithFirestore(user.uid);
      }
    });
  }

  Future<void> _syncWithFirestore(String uid) async {
    try {
      final settings = await EnergyService().getUserSettings(uid);
      if (settings != null && settings.containsKey('language')) {
        String dbLang = settings['language'];
        if (dbLang != _currentLanguage) {
          _currentLanguage = dbLang;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('language_code', dbLang);
          notifyListeners();
        }
      }
    } catch (e) {
      // 오류 무시
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language_code') ?? 'ko';
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;
    _currentLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await EnergyService().updateUserSettings(user.uid, {'language': languageCode});
      } catch (e) {
        // 오류 무시
      }
    }
    notifyListeners();
  }
}
