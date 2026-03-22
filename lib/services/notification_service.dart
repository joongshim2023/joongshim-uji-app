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
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // 알림 채널 생성 (중요도 MAX)
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );

      // 알림 권한 및 정밀 알람 권한 요청
      final notifGranted = await androidPlugin?.requestNotificationsPermission();
      final alarmGranted = await androidPlugin?.requestExactAlarmsPermission();
      debugPrint('[알림] 알림 권한=$notifGranted, 정밀 알람 권한=$alarmGranted');
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    bool granted = true;
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final notifGranted =
          await androidImplementation?.requestNotificationsPermission();
      final alarmGranted =
          await androidImplementation?.requestExactAlarmsPermission();
      debugPrint('[알림] requestPermissions → 알림=$notifGranted, 정밀알람=$alarmGranted');
      granted = (notifGranted != false) && (alarmGranted != false);
    } else if (Platform.isIOS) {
      final iosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await iosImplementation?.requestPermissions(
          alert: true, badge: true, sound: true);
      granted = iosGranted ?? true;
    }
    return granted;
  }

  /// 알람 전체 재등록
  /// startHour ~ endHour 사이를 intervalMinutes 간격으로 알람 예약
  Future<void> rescheduleAlarms({
    required int startHour,
    required int endHour,
    required int intervalMinutes,
    required bool alarmOn,
  }) async {
    if (kIsWeb) return;

    // 기존 알람 전체 취소
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('[알림] 기존 알람 전체 취소 완료');

    if (!alarmOn) {
      debugPrint('[알림] alarmOn=false → 알람 예약 건너뜀');
      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    int id = 0;
    int scheduledCount = 0;

    for (int h = startHour; h < endHour; h++) {
      // 정각 알람
      await _scheduleDaily(id++, h, 0, now);
      scheduledCount++;

      // 30분 간격이면 30분 알람 추가 (마지막 시간 직전까지만)
      if (intervalMinutes == 30) {
        await _scheduleDaily(id++, h, 30, now);
        scheduledCount++;
      }
    }

    // endHour 정각 알람 (예: 24시 → 자정 알람)
    if (endHour < 24) {
      await _scheduleDaily(id++, endHour, 0, now);
      scheduledCount++;
    }

    debugPrint('[알림] 총 $scheduledCount개 알람 예약 완료 ($startHour시~$endHour시, $intervalMinutes분 간격)');
  }

  Future<void> _scheduleDaily(
      int id, int h, int m, tz.TZDateTime now) async {
    // 오늘 기준으로 예약 시각 계산
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);

    // 이미 지난 시간이면 내일로 설정
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
      // 잠금 화면에도 전체 내용 표시
      visibility: NotificationVisibility.public,
      // 헤드업 알림 강제
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
        // exactAllowWhileIdle: 도즈 모드(절전)에서도 정확히 울림
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // time: 매일 같은 시간에 반복
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[알림] 예약 성공 id=$id → $scheduledDate ($timeStr)');
    } catch (e) {
      // 정밀 알람 권한이 없을 경우 inexact로 fallback
      debugPrint('[알림] exactAllowWhileIdle 실패, inexact로 fallback: $e');
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          '중심 유지 App 리마인더',
          '$timeStr입니다. 유지 비중을 지금 기록하세요!',
          scheduledDate,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('[알림] inexact 예약 성공 id=$id → $scheduledDate ($timeStr)');
      } catch (e2) {
        debugPrint('[알림] 알람 예약 완전 실패 id=$id: $e2');
      }
    }
  }
}
