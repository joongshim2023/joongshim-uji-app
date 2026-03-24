import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'privacy_policy_screen.dart';
import '../theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/auth_service.dart';
import '../services/energy_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  final EnergyService _energy = EnergyService();

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
            Expanded(child: Text(title, style: const TextStyle(color: AppTheme.textWhite, fontSize: 16))),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppTheme.textGray, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: AppTheme.mutedTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(color: AppTheme.textWhite, fontSize: 16))),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppTheme.textGray, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: AppTheme.mutedTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  int _startHour = 7;
  int _endHour = 24;
  int _alarmInterval = 60;
  bool _alarmOn = true; // 신규 유저 기본값 ON
  // ignore: unused_field (시계형 복원 시 재사용)
  String _inputType = 'bar';
  bool _isLoading = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${info.version} (${info.buildNumber})';
      });
    }
  }

  Future<void> _loadSettings() async {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      var data = await _energy.getUserSettings(uid);
      setState(() {
         _startHour = data['startHour'] ?? 7;
         _endHour = data['endHour'] ?? 24;
         _alarmInterval = data['alarmInterval'] ?? 60;
         _alarmOn = data['alarmOn'] ?? true; // 저장된 값 없으면 기본 ON
         _inputType = data['inputType'] ?? 'bar';
         _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _energy.updateUserSettings(uid, {key: value});
      if (key != 'inputType') {
        NotificationService().rescheduleAlarms(
          startHour: key == 'startHour' ? value : _startHour,
          endHour: key == 'endHour' ? value : _endHour,
          intervalMinutes: key == 'alarmInterval' ? value : _alarmInterval,
          alarmOn: key == 'alarmOn' ? value : _alarmOn,
        );
      }
    }
  }

  void _showHourPicker(String title, int currentValue, int min, int max, Function(int) onSelected, {bool isEndHour = false}) {
    showDialog(
      context: context,
      builder: (_) {
        int tempVal = currentValue;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isOvernight = isEndHour && tempVal < _startHour;
            return AlertDialog(
              backgroundColor: AppTheme.bgCard,
              title: Text(title, style: const TextStyle(color: AppTheme.textWhite)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: tempVal,
                    dropdownColor: AppTheme.timelineBg,
                    style: const TextStyle(color: AppTheme.activeGreen),
                    items: List.generate(max - min + 1, (i) => i + min).map((h) {
                      bool overnight = isEndHour && h < _startHour;
                      return DropdownMenuItem(
                        value: h,
                        child: Text(overnight ? '$h시 (다음날)' : '$h시'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() {
                        tempVal = val;
                        isOvernight = isEndHour && val < _startHour;
                      });
                    },
                  ),
                  if (isOvernight)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.softIndigo.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: AppTheme.softIndigo),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '기상 $_startHour시 ~ 다음날 새벽 ${tempVal}시까지 활동 시간으로 설정됩니다.',
                                style: const TextStyle(color: AppTheme.softIndigo, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: AppTheme.textGray))),
                TextButton(onPressed: () {
                  onSelected(tempVal);
                  Navigator.pop(context);
                }, child: const Text('저장', style: TextStyle(color: AppTheme.mutedTeal))),
              ]
            );
          }
        );
      }
    );
  }

  void _showIntervalPicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('알림 주기 선택', style: TextStyle(color: AppTheme.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('30분마다 알림', style: TextStyle(color: AppTheme.textWhite)),
              onTap: () {
                setState(() => _alarmInterval = 30);
                _updateSetting('alarmInterval', 30);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('60분마다 알림', style: TextStyle(color: AppTheme.textWhite)),
              onTap: () {
                setState(() => _alarmInterval = 60);
                _updateSetting('alarmInterval', 60);
                Navigator.pop(context);
              },
            ),
          ]
        )
      )
    );
  }

  // TODO: 시계형 복원 시 아래 주석 해제
  // void _showInputTypePicker() {
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       backgroundColor: AppTheme.bgCard,
  //       title: const Text('입력 방식 선택', style: TextStyle(color: AppTheme.textWhite)),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           ListTile(
  //             title: const Text('바 (위아래 드래그)', style: TextStyle(color: AppTheme.textWhite)),
  //             onTap: () {
  //               setState(() => _inputType = 'bar');
  //               _updateSetting('inputType', 'bar');
  //               Navigator.pop(context);
  //             },
  //           ),
  //           ListTile(
  //             title: const Text('시계 (원형 드래그)', style: TextStyle(color: AppTheme.textWhite)),
  //             onTap: () {
  //               setState(() => _inputType = 'clock');
  //               _updateSetting('inputType', 'clock');
  //               Navigator.pop(context);
  //             },
  //           ),
  //         ]
  //       )
  //     )
  //   );
  // }

  void _showProfile() {
    String? email = _auth.currentUser?.email;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('프로필', style: TextStyle(color: AppTheme.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('현재 연동된 이메일 계정', style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
            const SizedBox(height: 8),
            Text(email ?? '알 수 없는 계정', style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mutedTeal),
                onPressed: () async {
                  if (email != null) {
                    try {
                      await _auth.sendPasswordReset(email);
                      Navigator.pop(dialogContext);
                      _showInfoDialog('이메일 발송 완료', '비밀번호 변경 링크가 $email 으로 발송되었습니다.\n메일함을 확인해주세요.');
                    } catch (e) {
                      Navigator.pop(dialogContext);
                      _showErrorDialog('발송 실패', '오류가 발생했습니다.\n$e');
                    }
                  }
                },
                child: const Text('이메일로 비밀번호 재설정 링크 받기', style: TextStyle(color: AppTheme.deepNavy, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppTheme.textGray, height: 1),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(dialogContext);
                _showDeleteAccountDialog();
              },
              child: const Text(
                '계정 삭제',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.redAccent,
                ),
              ),
            ),
          ]
        ),
      )
    );
  }

  /// 계정 삭제 플로우:
  /// 1단계: 경고 + "계정 삭제" 확인 다이얼로그
  /// 2단계: 이메일/비밀번호 사용자는 비밀번호 재입력, 소셜 로그인 사용자는 재인증 안내
  /// 3단계: 실제 삭제 실행
  Future<void> _showDeleteAccountDialog() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 제공자 판별 (email, google.com, apple.com)
    final providers = user.providerData.map((p) => p.providerId).toList();
    final isEmailUser = providers.contains('password');

    // 1단계: 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('계정 삭제', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '계정을 삭제하면 모든 기록 데이터(daily_logs, 알람 기록, 설정)가 영구적으로 삭제됩니다.\n\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(color: AppTheme.textGray, fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: AppTheme.textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제 진행', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 2단계: 사용자 유형별 재인증
    if (isEmailUser) {
      // 이메일 사용자 → 비밀번호 재입력
      final pwdCtrl = TextEditingController();
      bool obscure = true;
      final reauthConfirmed = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            backgroundColor: AppTheme.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('비밀번호 확인', style: TextStyle(color: AppTheme.textWhite)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('계정 삭제를 위해 현재 비밀번호를 입력해주세요.', style: TextStyle(color: AppTheme.textGray, fontSize: 14)),
                const SizedBox(height: 16),
                TextField(
                  controller: pwdCtrl,
                  obscureText: obscure,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    hintStyle: const TextStyle(color: AppTheme.textGray),
                    filled: true,
                    fillColor: AppTheme.deepNavy,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textGray, size: 18),
                      onPressed: () => setS(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소', style: TextStyle(color: AppTheme.textGray)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('확인', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
      if (reauthConfirmed != true || !mounted) return;

      try {
        final email = user.email!;
        await _auth.reauthenticateWithPassword(email, pwdCtrl.text.trim());
      } catch (e) {
        if (mounted) _showErrorDialog('인증 실패', '비밀번호가 올바르지 않습니다.\n다시 확인해주세요.');
        return;
      }
    } else {
      // 소셜 로그인 사용자 → 해당 provider로 재인증
      final isGoogleUser = providers.contains('google.com');
      final isAppleUser = providers.contains('apple.com');

      // 재인증 안내 다이얼로그
      final reauthConfirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isGoogleUser ? 'Google 계정 재인증' : 'Apple 계정 재인증',
            style: const TextStyle(color: AppTheme.textWhite),
          ),
          content: Text(
            isGoogleUser
                ? '계정 삭제를 위해 Google 계정으로 다시 인증해야 합니다.\n계속하시겠습니까?'
                : '계정 삭제를 위해 Apple 계정으로 다시 인증해야 합니다.\n계속하시겠습니까?',
            style: const TextStyle(color: AppTheme.textGray, fontSize: 14, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: AppTheme.textGray)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('인증 진행', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (reauthConfirmed != true || !mounted) return;

      try {
        if (isGoogleUser) {
          await _auth.reauthenticateWithGoogle();
        } else if (isAppleUser) {
          await _auth.reauthenticateWithApple();
        }
      } catch (e) {
        final msg = e.toString();
        if (mounted) {
          if (msg.contains('canceled') || msg.contains('cancelled') || msg.contains('1001')) {
            return; // 사용자가 취소한 경우
          }
          _showErrorDialog('재인증 실패', '인증 중 오류가 발생했습니다.\n다시 시도해주세요.');
        }
        return;
      }
    }

    // 3단계: 실제 삭제
    if (!mounted) return;
    setState(() {});
    try {
      await _auth.deleteAccount();
      // signOut 후 authStateChanges가 null을 emit하여 자동으로 로그인 화면으로 이동
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        if (msg.contains('requires-recent-login')) {
          _showErrorDialog('재로그인 필요', '보안을 위해 앱을 재시작하여 다시 로그인 후 계정 삭제를 시도해주세요.');
        } else {
          _showErrorDialog('삭제 실패', '오류가 발생했습니다.\n$msg');
        }
      }
    }
  }

  Future<void> _exportTXT(DateTime start, DateTime end) async {
    if (_auth.currentUser == null) return;
    String uid = _auth.currentUser!.uid;

    try {
      final snapshot = await _energy.getLogsStream(uid, start, end).first;
      StringBuffer buf = StringBuffer();
      buf.writeln('===== 중심 유지 App 활동 기록 =====');
      buf.writeln('기간: ${DateFormat('yyyy-MM-dd').format(start)} ~ ${DateFormat('yyyy-MM-dd').format(end)}');
      buf.writeln('생성일: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      buf.writeln('================================');
      buf.writeln();

      var docs = snapshot.docs.toList();
      docs.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      for (var doc in docs) {
        var data = doc.data() as Map<String, dynamic>;
        String date = data['date'].toString();
        int startH = data['startHour'] ?? 7;
        int endH = data['endHour'] ?? 24;
        int totalMin = data['totalActiveMinutes'] ?? 0;
        num eff = data['efficiencyPct'] ?? 0;
        buf.writeln('[$date]');
        buf.writeln('  활동 시간: $startH:00 ~ $endH:00');
        buf.writeln('  유지 시간: ${totalMin}분');
        buf.writeln('  유지율:   $eff%');
        buf.writeln();
      }

      if (docs.isEmpty) {
        buf.writeln('해당 기간에 기록된 데이터가 없습니다.');
      }

      // 임시 디렉토리에 실제 .txt 파일 저장 후 공유 (일부 앱에서 XFile.fromData 인식 불가 문제 해결)
      final dir = await getTemporaryDirectory();
      final fileName = 'uji_logs_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.txt';
      final filePath = '${dir.path}/$fileName';
      final ioFile = File(filePath);
      await ioFile.writeAsString(buf.toString(), encoding: utf8);

      final xFile = XFile(filePath, mimeType: 'text/plain', name: fileName);
      await Share.shareXFiles([xFile], subject: '중심유지 App 활동 기록');
    } catch (e) {
      _showErrorDialog('내보내기 실패', '파일 생성 중 오류가 발생했습니다.\n$e');
    }
  }

  void _showExportPopup() {
    DateTime start = DateTime.now().subtract(const Duration(days: 30));
    DateTime end = DateTime.now();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: const Text('기록 범위 선택', style: TextStyle(color: AppTheme.textWhite)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('추출할 데이터의 시작 날짜와 종료 날짜를 선택하세요.', style: TextStyle(color: AppTheme.textGray)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: Text(DateFormat('yyyy-MM-dd').format(start), style: const TextStyle(color: AppTheme.activeGreen)),
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context, initialDate: start, firstDate: DateTime(2000), lastDate: end,
                          builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.mutedTeal)), child: child!),
                        );
                        if (picked != null) setDialogState(() => start = picked);
                      }
                    ),
                    const Text('~', style: TextStyle(color: AppTheme.textWhite)),
                    TextButton(
                      child: Text(DateFormat('yyyy-MM-dd').format(end), style: const TextStyle(color: AppTheme.activeGreen)),
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context, initialDate: end, firstDate: start, lastDate: DateTime.now(),
                          builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.mutedTeal)), child: child!),
                        );
                        if (picked != null) setDialogState(() => end = picked);
                      }
                    ),
                  ],
                ),
              ]
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: AppTheme.textGray))),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _exportTXT(start, end);
                },
                child: const Text('내보내기 (TXT)', style: TextStyle(color: AppTheme.mutedTeal, fontWeight: FontWeight.bold))
              ),
            ]
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator(color: AppTheme.mutedTeal)));
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("기본 설정", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textWhite)),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader("나의 리듬 (기본값)"),
                _buildListTile(
                  icon: Icons.wb_sunny_outlined, 
                  title: "기본 기상 시간", 
                  trailingText: "$_startHour:00",
                  onTap: () => _showHourPicker("기상 시간 (기본값)", _startHour, 0, _endHour - 1, (val) {
                    setState(() => _startHour = val);
                    _updateSetting('startHour', val);
                  }),
                ),
                _buildListTile(
                  icon: Icons.nightlight_round, 
                  title: "기본 취침 시간", 
                  trailingText: _endHour < _startHour ? '$_endHour:00 (다음날)' : '$_endHour:00',
                  onTap: () => _showHourPicker("취침 시간 (기본값)", _endHour, 0, 24, (val) {
                    setState(() => _endHour = val);
                    _updateSetting('endHour', val);
                  }, isEndHour: true),
                ),
                // TODO: 시계형 복원 시 아래 항목 주석 해제
                // _buildListTile(
                //   icon: Icons.touch_app_outlined, 
                //   title: "리스트 입력 화면 방식", 
                //   trailingText: _inputType == 'bar' ? "바형" : "시계형",
                //   onTap: _showInputTypePicker,
                // ),
                const SizedBox(height: 16),
                _buildSectionHeader("알림 시스템"),
                _buildListTile(
                  icon: Icons.notifications_active_outlined,
                  title: "알림 켜기",
                  isSwitch: true,
                  value: _alarmOn,
                  onSwitch: (val) async {
                    if (val) {
                      // 1. POST_NOTIFICATIONS 권한 요청 (Android 13+)
                      await NotificationService().requestNotificationPermission();

                      // 2. 정밀 알람 권한 확인 (Android 12+)
                      final canExact = await NotificationService().canScheduleExactAlarms();
                      if (!canExact && mounted) {
                        // 권한 없으면 안내 다이얼로그
                        // ignore: use_build_context_synchronously
                        final goSettings = await showDialog<bool>(
                          // ignore: use_build_context_synchronously
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppTheme.bgCard,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Row(
                              children: [
                                Icon(Icons.alarm_outlined, color: Color(0xFFFBBF24), size: 22),
                                SizedBox(width: 8),
                                Text('정밀 알람 권한 필요', style: TextStyle(color: AppTheme.textWhite, fontSize: 16)),
                              ],
                            ),
                            content: const Text(
                              '30분/60분 간격으로 정확히 알림을 받으려면\n"알람 및 리마인더" 권한이 필요합니다.\n\n설정 > 앱 > 중심유지 >\n알람 및 리마인더 → 허용',
                              style: TextStyle(color: AppTheme.textGray, fontSize: 14, height: 1.6),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('나중에', style: TextStyle(color: AppTheme.textGray)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('설정으로 이동', style: TextStyle(color: AppTheme.mutedTeal, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                        if (goSettings == true) {
                          await NotificationService().requestExactAlarmPermission();
                        }
                      }
                    }
                    setState(() => _alarmOn = val);
                    _updateSetting('alarmOn', val);
                  },
                ),
                if (_alarmOn) 
                  _buildListTile(
                    icon: Icons.timer_outlined, 
                    title: "알람 간격", 
                    trailingText: "$_alarmInterval분",
                    onTap: _showIntervalPicker,
                  ),
                const SizedBox(height: 16),
                _buildSectionHeader("계정 및 데이터"),
                _buildListTile(icon: Icons.person_outline, title: "프로필", onTap: _showProfile),
                _buildListTile(icon: Icons.text_snippet_outlined, title: "기록 내보내기 (TXT)", onTap: _showExportPopup),
                _buildListTile(
                  icon: Icons.policy_outlined,
                  title: "개인정보처리방침",
                  onTap: () async {
                    if (kIsWeb) {
                      // 웹에서는 새 탭으로 열기 (WebView 미지원)
                      final uri = Uri.parse('https://jh-pages.notion.site/App-328baf99869180429bedd807255a6145');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    } else {
                      // 모바일: 앱 내 WebView 화면으로 이동
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildSectionHeader("계정 관리"),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.textWhite),
                  title: const Text("로그아웃", style: TextStyle(color: AppTheme.textWhite, fontSize: 15)),
                  onTap: () async {
                    try {
                      await _auth.signOut();
                    } catch (e) {
                      _showErrorDialog('로그아웃 실패', '오류가 발생했습니다.\n$e');
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildSectionHeader("앱 정보"),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.mutedTeal),
                  title: const Text("버전 정보", style: TextStyle(color: AppTheme.textWhite, fontSize: 15)),
                  trailing: Text(
                    _appVersion,
                    style: const TextStyle(color: AppTheme.textGray, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(title, style: const TextStyle(color: AppTheme.softIndigo, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? trailingText,
    bool isSwitch = false,
    bool value = false,
    Function(bool)? onSwitch,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.mutedTeal),
      title: Text(title, style: const TextStyle(color: AppTheme.textWhite, fontSize: 15)),
      trailing: isSwitch 
          ? Switch(value: value, onChanged: onSwitch, activeColor: AppTheme.mutedTeal)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingText != null) Text(trailingText, style: const TextStyle(color: AppTheme.textGray)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppTheme.textGray, size: 20),
              ],
            ),
      onTap: onTap,
    );
  }
}
