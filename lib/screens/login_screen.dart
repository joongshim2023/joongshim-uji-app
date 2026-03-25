import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwdFocusNode = FocusNode();

  bool _isLogin = true;
  bool _saveEmail = false;
  bool _isLoading = false;
  bool _obscurePassword = true; // 비밀번호 숨김 상태
  Timer? _showPasswordTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _showPasswordTimer?.cancel();
    _pwdFocusNode.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  // 비밀번호 표시 토글: 5초 후 자동 숨김
  void _toggleShowPassword() {
    _showPasswordTimer?.cancel();
    setState(() => _obscurePassword = false);
    _showPasswordTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _obscurePassword = true);
    });
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('saved_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      if (mounted) {
        setState(() {
          _emailCtrl.text = savedEmail;
          _saveEmail = true;
        });
      }
    }
  }

  // 에러 팝업 공통 함수
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(color: AppTheme.textWhite, fontSize: 16)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(color: AppTheme.textGray, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인',
                style: TextStyle(
                    color: AppTheme.mutedTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 성공 팝업
  void _showInfoDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF34D399), size: 22),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(color: AppTheme.textWhite, fontSize: 16)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(color: AppTheme.textGray, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인',
                style: TextStyle(
                    color: AppTheme.mutedTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Firebase / Google 에러 코드를 한국어로 변환
  String _parseFirebaseError(dynamic e) {
    String msg = e.toString();
    if (msg.contains('user-not-found')) return '등록되지 않은 이메일입니다.';
    if (msg.contains('wrong-password') || msg.contains('invalid-credential'))
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    if (msg.contains('email-already-in-use')) return '이미 사용 중인 이메일입니다.';
    if (msg.contains('invalid-email')) return '이메일 형식이 올바르지 않습니다.';
    if (msg.contains('weak-password'))
      return '비밀번호가 너무 간단합니다. 영문자와 숫자를 포함하여 6자 이상 설정하세요.';
    if (msg.contains('too-many-requests'))
      return '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
    if (msg.contains('network-request-failed')) return '네트워크 연결을 확인해주세요.';
    // Google Sign-In: SHA-1 미등록 → Credential Manager가 cancelled로 반환
    if (msg.contains('GoogleSignInException') && msg.contains('cancelled')) {
      return 'Google 로그인 설정 오류입니다.\n\nFirebase Console에 Play 스토어 서명 SHA-1이 등록되지 않았습니다.\n\n[해결 방법]\n① Google Play Console → 설정 → 앱 서명\n   → "앱 서명 키 인증서" SHA-1 복사\n② Firebase Console → 프로젝트 설정\n   → Android 앱 → 디지털 지문 추가';
    }
    if (msg.contains('clientConfigurationError'))
      return 'Google 로그인 설정 오류입니다. Firebase Console에서 SHA-1을 등록해주세요.';
    return '오류가 발생했습니다.\n$msg';
  }

  bool _validatePassword(String pwd) {
    if (pwd.length < 6) return false;
    bool hasLetter = pwd.contains(RegExp(r'[a-zA-Z]'));
    bool hasDigit = pwd.contains(RegExp(r'\d'));
    return hasLetter && hasDigit;
  }

  Future<void> _submit() async {
    String email = _emailCtrl.text.trim();
    String pwd = _pwdCtrl.text.trim();

    if (email.isEmpty || pwd.isEmpty) {
      _showErrorDialog('입력 오류', '이메일과 비밀번호를 모두 입력해주세요.');
      return;
    }

    if (!_isLogin && !_validatePassword(pwd)) {
      _showErrorDialog('비밀번호 오류', '비밀번호는 영문자와 숫자를 모두 포함하여 6자 이상이어야 합니다.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _authService.signInWithEmailPassword(email, pwd);
      } else {
        await _authService.registerWithEmailPassword(email, pwd);
      }

      final prefs = await SharedPreferences.getInstance();
      if (_saveEmail) {
        await prefs.setString('saved_email', email);
      } else {
        await prefs.remove('saved_email');
      }
    } catch (e) {
      _showErrorDialog(
        _isLogin ? '로그인 실패' : '회원가입 실패',
        _parseFirebaseError(e),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('sign_in_canceled') ||
          msg.contains('sign_in_cancelled') ||
          msg.contains('The user canceled the sign-in flow')) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _showErrorDialog('Google 로그인 실패', _parseFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _appleLogin() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithApple();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('canceled') ||
          msg.contains('cancelled') ||
          msg.contains('1001')) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _showErrorDialog('Apple 로그인 실패', '오류가 발생했습니다.\n$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    String email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('이메일 필요', '위쪽 이메일 입력칸에 이메일을 먼저 입력해주세요.');
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      _showInfoDialog(
          '이메일 발송 완료', '비밀번호 재설정 링크가 $email 으로 발송되었습니다.\n메일함을 확인해주세요.');
    } catch (e) {
      _showErrorDialog('발송 실패', _parseFirebaseError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icon.png', width: 120, height: 120),
              const SizedBox(height: 16),
              const Text("중심 유지 App",
                  style: TextStyle(
                      color: AppTheme.mutedTeal,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),

              TextField(
                controller: _emailCtrl,
                style: const TextStyle(color: AppTheme.textWhite),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_pwdFocusNode),
                decoration: InputDecoration(
                  hintText: '이메일',
                  hintStyle: const TextStyle(color: AppTheme.textGray),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwdCtrl,
                focusNode: _pwdFocusNode,
                obscureText: _obscurePassword,
                style: const TextStyle(color: AppTheme.textWhite),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_isLoading) _submit();
                },
                decoration: InputDecoration(
                  hintText: '비밀번호 (알파벳+숫자 6자 이상)',
                  hintStyle: const TextStyle(color: AppTheme.textGray),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.textGray,
                      size: 20,
                    ),
                    tooltip: '비밀번호 표시 (5초)',
                    onPressed: _obscurePassword ? _toggleShowPassword : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Theme(
                    data: Theme.of(context)
                        .copyWith(unselectedWidgetColor: AppTheme.textGray),
                    child: Checkbox(
                      value: _saveEmail,
                      checkColor: AppTheme.deepNavy,
                      activeColor: AppTheme.mutedTeal,
                      onChanged: (val) {
                        setState(() => _saveEmail = val ?? false);
                      },
                    ),
                  ),
                  const Text('이메일 저장',
                      style: TextStyle(color: AppTheme.textGray)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mutedTeal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : Text(_isLogin ? '로그인' : '회원가입',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('비밀번호 찾기',
                        style: TextStyle(color: AppTheme.textGray)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? '처음이신가요? 회원가입' : '이미 계정이 있나요? 로그인',
                        style: const TextStyle(color: AppTheme.softIndigo)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _googleLogin,
                  icon: const Icon(Icons.g_mobiledata,
                      color: AppTheme.textWhite, size: 24),
                  label: const Text('Google 계정으로 로그인',
                      style: TextStyle(color: AppTheme.textWhite)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.textGray),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              // Apple Sign-In: iOS/macOS 에서만 표시
              if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _appleLogin,
                    icon: const Icon(Icons.apple,
                        color: AppTheme.textWhite, size: 22),
                    label: const Text('Apple 계정으로 로그인',
                        style: TextStyle(color: AppTheme.textWhite)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.textGray),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
