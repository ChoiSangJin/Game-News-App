import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/story.dart';

class Reminders {
  static final plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _ready;
  static Future<void> _init() async {
    tzdata.initializeTimeZones();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification')));
  }
  // Stable across processes, unlike String.hashCode.
  static int idFor(String id) => id.codeUnits.fold(0, (v, c) => (v * 31 + c) & 0x7fffffff);
  static Future<void> schedule(Story story) async {
    await (_ready ??= _init());
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (await android?.requestNotificationsPermission() != true) {
      throw StateError('알림 권한을 허용해 주세요.');
    }
    final when = DateTime(story.date.year, story.date.month, story.date.day - 1, 9);
    if (!when.isAfter(DateTime.now())) throw StateError('전날 오전 9시가 지난 일정은 알림을 예약할 수 없습니다.');
    await plugin.zonedSchedule(idFor(story.id), '내일의 게임 일정', story.titleKo ?? story.title,
      tz.TZDateTime.from(when.toUtc(), tz.UTC), const NotificationDetails(android: AndroidNotificationDetails(
        'game_schedule', '게임 일정', channelDescription: '선택한 일정의 전날 알림',
        importance: Importance.defaultImportance)), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
  }
  static Future<void> cancel(Story story) async {
    await (_ready ??= _init());
    await plugin.cancel(idFor(story.id));
  }
}
