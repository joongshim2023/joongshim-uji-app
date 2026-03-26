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
      debugPrint('[알림] 설정 변경 없음 → 불필요한 알람 재생성 건너뜀 (기존 스케줄 유지)');
      return;
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

    // 정밀 알람 권한 확인
    final bool canExact = await canScheduleExactAlarms();

    // Android 12+: SCHEDULE_EXACT_ALARM + USE_EXACT_ALARM 중 하나 필요
    // 권한 없으면 inexact 로 폴백 (몇 분 지연 가능)
    final AndroidScheduleMode mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint('[알림] 스케줄 모드: ${canExact ? "exact" : "inexact (권한 없음)"}');
    debugPrint('[알림] 알람 범위: $startHour시 ~ $endHour시, ${intervalMinutes}분 간격');

    // 자정 초과 여부 확인 (기상시간 > 취침시간인 경우)
    bool isOvernight = endHour < startHour;

    if (isOvernight) {
      // 기상시간부터 자정까지
      for (int h = startHour; h < 24; h++) {
        await _scheduleDaily(id++, h, 0, now, mode);
        scheduledCount++;
        if (intervalMinutes == 30) {
          await _scheduleDaily(id++, h, 30, now, mode);
          scheduledCount++;
        }
      }
      // 자정부터 취침시간까지
      for (int h = 0; h < endHour; h++) {
        await _scheduleDaily(id++, h, 0, now, mode);
        scheduledCount++;
        if (intervalMinutes == 30) {
          await _scheduleDaily(id++, h, 30, now, mode);
          scheduledCount++;
        }
      }
      // 취침시간 정각
      await _scheduleDaily(id++, endHour, 0, now, mode);
      scheduledCount++;
    } else {
      for (int h = startHour; h < endHour; h++) {
        await _scheduleDaily(id++, h, 0, now, mode);
        scheduledCount++;
        if (intervalMinutes == 30) {
          await _scheduleDaily(id++, h, 30, now, mode);
          scheduledCount++;
        }
      }
      // endHour 정각 알람 (24시 이상은 스킵)
      if (endHour < 24) {
        await _scheduleDaily(id++, endHour, 0, now, mode);
        scheduledCount++;
      }
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
