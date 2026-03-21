import 'package:flutter/material.dart';

class AppTheme {
  // 핵심 브랜드 컬러
  static const Color deepNavy = Colors.black;          // ← 배경 검정
  static const Color softIndigo = Color(0xFF7A8CC3);
  static const Color mutedTeal = Color(0xFF44AABB);

  // UI 텍스트 및 서브 컬러
  static const Color textWhite = Color(0xFFDDEEFF);
  static const Color textGray = Color(0xFF8C9EAE);
  static const Color bgCard = Color(0xFF1A1A1A);       // ← 카드도 짙은 검정 계열
  static const Color timelineBg = Color(0xFF222222);   // ← 타임라인 배경
  static const Color yellowAccent = Color(0xFFFACC15);
  static const Color activeGreen = Color(0xFF34D399);

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deepNavy,
      primaryColor: mutedTeal,
      fontFamily: 'Apple SD Gothic Neo',
      appBarTheme: const AppBarTheme(
        backgroundColor: deepNavy,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF111111),
        selectedItemColor: mutedTeal,
        unselectedItemColor: softIndigo,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: mutedTeal,
        foregroundColor: deepNavy,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textWhite, fontSize: 48, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textWhite, fontSize: 20, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: textWhite, fontSize: 16),
        bodyMedium: TextStyle(color: textGray, fontSize: 14),
      ),
    );
  }
}
