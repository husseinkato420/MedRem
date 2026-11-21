import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/medication.dart';

class Notifier {
  static final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  static bool _localReady = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails('meds', 'Medicine reminders',
        importance: Importance.max, priority: Priority.high),
    iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
  );

  static Future<void> init() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Kampala'));
    _localReady = await _p.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    )) ?? false;

    final android = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    final ios = _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

  }

  static Future<void> schedule(Medication m) async {
    if (!_localReady || !m.active || !m.localRemindersEnabled || m.times.isEmpty || m.daysOfWeek.isEmpty) return;
    await cancel(m);
    final now = tz.TZDateTime.now(tz.local);
    final start = m.startDate == null ? now : tz.TZDateTime.parse(tz.local, '${m.startDate} 00:00:00');
    final end = m.endDate == null ? null : DateTime.tryParse(m.endDate!);
    var notificationId = ((m.id.abs() % 100000) * 1000) % 2147483647;
    var scheduled = 0;

    for (var offset = 0; offset < 14 && scheduled < 60; offset++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      if (date.isBefore(DateTime(start.year, start.month, start.day))) continue;
      if (end != null && date.isAfter(DateTime(end.year, end.month, end.day))) continue;
      if (!m.daysOfWeek.contains(date.weekday % 7)) continue;
      for (final time in m.times) {
        final hour = int.tryParse(time.split(':').first);
        final minute = int.tryParse(time.split(':').last);
        if (hour == null || minute == null) continue;
        final when = tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute);
        if (!when.isAfter(now)) continue;
        await _p.zonedSchedule(
        notificationId,
          'Time for your medicine',
          '${m.name}${m.dose.isEmpty ? '' : ' · ${m.dose}'}',
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'med:${m.id}|$time',
        );
        scheduled++;
        notificationId = (notificationId + 1) % 2147483647;
        if (scheduled >= 60) break;
      }
    }
  }

  static Future<void> cancel(Medication m) async {
    if (!_localReady) return;
    final pending = await _p.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith('med:${m.id}|') == true) await _p.cancel(request.id);
    }
  }

  static Future<void> test() async {
    if (!_localReady) return;
    await _p.show(0, 'Test reminder', 'Reminders are working', _details);
  }
}
