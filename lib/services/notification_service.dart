import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _channelId = 'joongshim_uji_channel';
  static const String _channelName = '중심 유지 알림';
  static const String _channelDesc = '유지 비중 기록 리마인더';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  // ────────────────────────────────────────────────────────
  // Firestore 로그 헬퍼
  // ────────────────────────────────────────────────────────

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// 알람 이벤트 로그 ('scheduled' | 'fired' | 'error')
  Future<void> logAlarmEvent({
    required String event,
    String? errorMessage,
    Map<String, dynamic>? extra,
  }) async {
    if (kIsWeb) return;
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('alarm_logs')
          .add({
        'event': event,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'error': errorMessage,
        ...?extra,
      });
    } catch (e) {
      debugPrint('[로그] alarm_logs 저장 실패: $e');
    }
  }

  /// 에러 로그 저장
  Future<void> logError({
    required String location,
    required dynamic error,
    StackTrace? stackTrace,
  }) async {
    if (kIsWeb) return;
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('error_logs')
          .add({
        'location': location,
        'error': error.toString(),
        'stackTrace': stackTrace?.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
    } catch (e) {
      debugPrint('[로그] error_logs 저장 실패: $e');
    }
  }

  // ────────────────────────────────────────────────────────
  // 초기화
  // ────────────────────────────────────────────────────────

  Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[알림] 탭됨 id=${response.id}, payload=${response.payload}');
      },
    );

    if (Platform.isAndroid) {
      // 알림 채널 생성 (중요도 MAX)
      await _androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );

      // POST_NOTIFICATIONS 권한 요청 (Android 13+)
      final notifGranted =
          await _androidPlugin?.requestNotificationsPermission();
      debugPrint('[알림] 알림 권한=$notifGranted');
    }
  }

  // ────────────────────────────────────────────────────────
  // 권한
  // ────────────────────────────────────────────────────────

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      final granted = await _androidPlugin?.requestNotificationsPermission();
      return granted ?? true;
    } else if (Platform.isIOS) {
      final iosImpl =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImpl?.requestPermissions(
          alert: true, badge: true, sound: true);
      return granted ?? true;
    }
    return true;
  }

  /// Android 12+ 정밀 알람 권한 여부 확인
  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final result = await _androidPlugin?.canScheduleExactNotifications();
    debugPrint('[알림] canScheduleExactNotifications=$result');
    return result ?? false;
  }

  /// 정밀 알람 권한 요청 → 시스템 설정 화면으로 이동
  Future<void> requestExactAlarmPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _androidPlugin?.requestExactAlarmsPermission();
  }

  /// 현재 예약된 알람 수 조회 (0이면 재등록 필요)
  Future<int> getPendingCount() async {
    if (kIsWeb) return 1; // 웹에서는 항상 '있음'으로 처리
    final pendingList =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    debugPrint('[알림] 현재 예약된 알람 수: ${pendingList.length}');
    return pendingList.length;
  }

  // ────────────────────────────────────────────────────────
  // 알람 예약
  // ────────────────────────────────────────────────────────

  /// 알람 전체 재등록
  Future<void> rescheduleAlarms({
    required int startHour,
    required int endHour,
    required int intervalMinutes,
    required bool alarmOn,
  }) async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = _uid ?? 'unknown';
    final String cacheKey = 'alarm_settings_cache_$uid';
    final String currentSettings = '$startHour|$endHour|$intervalMinutes|$alarmOn';

    if (prefs.getString(cacheKey) == currentSettings) {
      // 기존 알람이 충분히 예약돼 있는지 확인
      final pending = await getPendingCount();
      if (pending > 0) {
        debugPrint('[알림] 설정 변경 없음 + 예약 알람 $pending개 존재 → 건너뜀');
        return;
      }
      debugPrint('[알림] 설정 동일하지만 예약 알람 0개 → 재등록 진행');
    }
    await prefs.setString(cacheKey, currentSettings);

    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('[알림] 기존 알람 전체 취소 및 스케줄 초기화 완료');

    if (!alarmOn) {
      debugPrint('[알림] alarmOn=false → 알람 예약 건너뜀');
      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    int id = 0;
    int scheduledCount = 0;

    // Android: 정밀 알람 권한 확인
    // iOS: 항상 exact 모드 사용 (권한 불필요)
    final bool canExact = Platform.isIOS ? true : await canScheduleExactAlarms();

    // Android 12+: 권한이 없으면 inexact 폴백, 있으면 exactAllowWhileIdle
    // iOS: 항상 matchDateTimeComponents.time 방식으로 정확한 시간 예약
    final AndroidScheduleMode mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint('[알림] 스케줄 모드: ${canExact ? "exact" : "inexact (권한 없음)"}');
    debugPrint('[알림] 알람 범위: $startHour시 ~ $endHour시, ${intervalMinutes}분 간격');

    // 시간-분 쌍 목록 생성
    final List<List<int>> slots = [];
    bool isOvernight = endHour < startHour;

    if (isOvernight) {
      for (int h = startHour; h < 24; h++) {
        slots.add([h, 0]);
        if (intervalMinutes == 30) slots.add([h, 30]);
      }
      for (int h = 0; h < endHour; h++) {
        slots.add([h, 0]);
        if (intervalMinutes == 30) slots.add([h, 30]);
      }
      slots.add([endHour, 0]);
    } else {
      for (int h = startHour; h < endHour; h++) {
        slots.add([h, 0]);
        if (intervalMinutes == 30) slots.add([h, 30]);
      }
      if (endHour < 24) slots.add([endHour, 0]);
    }

    // iOS는 최대 64개 알람 제한 → 초과 시 앞에서부터 잘라냄
    final maxSlots = Platform.isIOS ? 64 : 500;
    final usedSlots = slots.length > maxSlots ? slots.sublist(0, maxSlots) : slots;

    for (final slot in usedSlots) {
      await _scheduleDaily(id++, slot[0], slot[1], now, mode);
      scheduledCount++;
    }

    debugPrint(
        '[알림] 총 $scheduledCount개 알람 예약 완료 ($startHour시~$endHour시, ${intervalMinutes}분 간격)');

    await logAlarmEvent(
      event: 'rescheduled',
      extra: {
        'count': scheduledCount,
        'startHour': startHour,
        'endHour': endHour,
        'intervalMinutes': intervalMinutes,
        'mode': canExact ? 'exact' : 'inexact',
        'isOvernight': isOvernight,
      },
    );
  }

  Future<void> _scheduleDaily(
      int id, int h, int m, tz.TZDateTime now, AndroidScheduleMode mode) async {
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final int hour12 = h % 12 == 0 ? 12 : h % 12;
    final String amPm = h >= 12 ? '오후' : '오전';
    final String minStr = m == 0 ? '정각' : '$m분';
    final String timeStr = '$amPm $hour12시 $minStr';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      visibility: NotificationVisibility.public,
      // Android 14+: fullScreenIntent 없이도 잠금화면 표시
      fullScreenIntent: false,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        '중심 유지 App 리마인더',
        '$timeStr입니다. 유지 비중을 지금 기록하세요!',
        scheduledDate,
        platformDetails,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[알림] 예약 성공 id=$id → $scheduledDate ($timeStr)');
      await logAlarmEvent(
        event: 'scheduled',
        extra: {
          'id': id,
          'hour': h,
          'minute': m,
          'scheduledAt': scheduledDate.toIso8601String()
        },
      );
    } catch (e, st) {
      debugPrint('[알림] 알람 예약 실패 id=$id: $e');
      await logAlarmEvent(
        event: 'error',
        errorMessage: e.toString(),
        extra: {'id': id, 'hour': h, 'minute': m},
      );
      await logError(
        location: 'notification_service._scheduleDaily(h=$h,m=$m)',
        error: e,
        stackTrace: st,
      );
    }
  }
}
