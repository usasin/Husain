import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/teams_data.dart';
import '../models/models.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _payloadPrefix = 'vote-reminder:';
  static const int _maxPendingReminders = 60;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;

    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      debugPrint('Notification timezone fallback to UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: settings);

    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        'mundial_push',
        'Notifications Mundial',
        description: 'Scores, salons et annonces importantes Mundial 2026',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return false;
  }

  Future<int> scheduleVoteReminders({
    required List<FootballMatch> matches,
    required Set<String> votedMatchIds,
    Duration reminderBefore = const Duration(minutes: 15),
  }) async {
    if (!isSupported) return 0;
    await initialize();

    await cancelAllVoteReminders();

    final now = DateTime.now();
    final upcoming = matches
        .where((m) => !m.isTBD && !m.hasStarted && !votedMatchIds.contains(m.id))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    var scheduled = 0;
    for (final match in upcoming.take(_maxPendingReminders)) {
      var reminderAt = match.dateTime.subtract(reminderBefore);

      // Si les rappels sont activés après l'heure normale du rappel,
      // on programme une alerte rapide tant que le match n'a pas commencé.
      if (!reminderAt.isAfter(now.add(const Duration(seconds: 10)))) {
        if (!match.dateTime.isAfter(now.add(const Duration(minutes: 2)))) {
          continue;
        }
        reminderAt = now.add(const Duration(seconds: 15));
      }

      final home = kTeams[match.homeCode]?.name ?? match.homeCode;
      final away = kTeams[match.awayCode]?.name ?? match.awayCode;
      final local = match.dateTime;
      final time =
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

      await _plugin.zonedSchedule(
        id: _notificationId(match.id),
        title: '⚽ Plus que 15 minutes pour voter',
        body: '$home – $away commence à $time. Votre pronostic n’est pas encore enregistré.',
        scheduledDate: tz.TZDateTime.from(reminderAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'vote_reminders',
            'Rappels de pronostics',
            channelDescription:
                'Rappel avant les matchs pour ne pas oublier de voter',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$_payloadPrefix${match.id}',
      );
      scheduled++;
    }

    return scheduled;
  }

  Future<void> cancelReminderForMatch(String matchId) async {
    if (!isSupported) return;
    await initialize();
    await _plugin.cancel(id: _notificationId(matchId));
  }

  Future<void> cancelAllVoteReminders() async {
    if (!isSupported) return;
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final item in pending) {
      if (item.payload?.startsWith(_payloadPrefix) == true) {
        await _plugin.cancel(id: item.id);
      }
    }
  }

  Future<void> showTestNotification() async {
    if (!isSupported) return;
    await initialize();
    await _plugin.show(
      id: 99001,
      title: '✅ Rappels activés',
      body: 'Vous serez prévenu 15 minutes avant un match si vous n’avez pas voté.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'vote_reminders',
          'Rappels de pronostics',
          channelDescription:
              'Rappel avant les matchs pour ne pas oublier de voter',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }


  Future<void> showPushNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!isSupported) return;
    await initialize();
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'mundial_push',
          'Notifications Mundial',
          channelDescription:
              'Scores, salons et annonces importantes Mundial 2026',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> showHalftimeAlert({
    required String title,
    required String body,
  }) async {
    if (!isSupported) return;
    await initialize();
    await _plugin.show(
      id: 91000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'halftime_alerts',
          'Alertes mi-temps',
          channelDescription:
              'Alerte a la mi-temps pour changer son pronostic',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  int _notificationId(String matchId) {
    final digits = int.tryParse(matchId.replaceAll(RegExp(r'\D'), '')) ??
        matchId.hashCode.abs() % 9000;
    return 10000 + digits;
  }
}
