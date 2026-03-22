import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

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

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (Platform.isAndroid) {
      // Android 알림 채널 명시적 생성 → 앱 알림 목록에 등록됨
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

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

      // 알림 권한 요청
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    bool granted = true;
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      bool? notifGranted =
          await androidImplementation?.requestNotificationsPermission();
      bool? alarmGranted =
          await androidImplementation?.requestExactAlarmsPermission();
      granted = (notifGranted != false) && (alarmGranted != false);
    } else if (Platform.isIOS) {
      final iosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      bool? iosGranted = await iosImplementation?.requestPermissions(
          alert: true, badge: true, sound: true);
      granted = iosGranted ?? true;
    }
    return granted;
  }

  Future<void> rescheduleAlarms({
    required int startHour,
    required int endHour,
    required int intervalMinutes,
    required bool alarmOn,
  }) async {
    if (kIsWeb) return;

    await flutterLocalNotificationsPlugin.cancelAll();
    if (!alarmOn) return;

    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    int id = 0;

    for (int h = startHour; h <= endHour; h++) {
      await _scheduleDaily(id++, h, 0, now);
      if (intervalMinutes == 30 && h != endHour) {
        await _scheduleDaily(id++, h, 30, now);
      }
    }
  }

  Future<void> _scheduleDaily(
      int id, int h, int m, tz.TZDateTime now) async {
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    int hour12 = h % 12 == 0 ? 12 : h % 12;
    String amPm = h >= 12 ? '오후' : '오전';
    String minStr = m == 0 ? '정각' : '$m분';
    String timeStr = '$amPm $hour12시 $minStr입니다.';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      '중심 유지 App 리마인더',
      '$timeStr 유지 비중을 지금 기록하세요!',
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
