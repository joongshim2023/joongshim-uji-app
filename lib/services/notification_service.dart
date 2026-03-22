import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

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
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

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

    const InitializationSettings initializationSettings = InitializationSettings(
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
      final notifGranted = await _androidPlugin?.requestNotificationsPermission();
      debugPrint('[알림] 알림 권한=$notifGranted');
    }
  }

  /// POST_NOTIFICATIONS 권한만 요청 (알람 권한은 별도 처리)
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      final granted = await _androidPlugin?.requestNotificationsPermission();
      return granted ?? true;
    } else if (Platform.isIOS) {
      final iosImpl = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
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

  /// 알람 전체 재등록
  Future<void> rescheduleAlarms({
    required int startHour,
    required int endHour,
    required int intervalMinutes,
    required bool alarmOn,
  }) async {
    if (kIsWeb) return;

    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('[알림] 기존 알람 전체 취소 완료');

    if (!alarmOn) {
      debugPrint('[알림] alarmOn=false → 알람 예약 건너뜀');
      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    int id = 0;
    int scheduledCount = 0;

    // 정밀 알람 권한 확인
    final bool canExact = await canScheduleExactAlarms();
    final AndroidScheduleMode mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint('[알림] 스케줄 모드: ${canExact ? "exact" : "inexact (권한 없음)"}');

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

    debugPrint('[알림] 총 $scheduledCount개 알람 예약 완료 ($startHour시~$endHour시, $intervalMinutes분 간격)');
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

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      visibility: NotificationVisibility.public,
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
    } catch (e) {
      debugPrint('[알림] 알람 예약 실패 id=$id: $e');
    }
  }
}
