import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Notifications PUSH FCM intelligentes + préférences utilisateur.
///
/// Topics utilisés :
/// - general : alertes matchs/scores/fin de match/tribune ouverte ;
/// - team_XXX : salon de l'équipe de l'utilisateur ;
/// - match_XXX : tribune d'un match ouverte par l'utilisateur.
///
/// Si l'utilisateur désactive les notifications, l'app se désabonne des topics.
class MessagingService {
  MessagingService._();
  static final MessagingService instance = MessagingService._();

  static const String halftimeTopic = 'halftime';
  static const String generalTopic = 'general';

  static const String _lastTeamTopicKey = 'mundial_last_team_topic_v1';
  static const String _matchTopicsKey = 'mundial_match_topics_v1';

  static const String _pushEnabledKey = 'mundial_push_enabled_v1';
  static const String _generalAlertsKey = 'mundial_push_general_alerts_v1';
  static const String _teamChatAlertsKey = 'mundial_push_team_chat_alerts_v1';
  static const String _matchRoomAlertsKey = 'mundial_push_match_room_alerts_v1';

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<fb_auth.User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// À appeler une fois au démarrage depuis main().
  Future<void> initialize() async {
    if (_initialized || !isSupported) return;
    _initialized = true;

    _foregroundSub ??= FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleForegroundMessage(message));
    });

    _openedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification ouverte: ${message.data}');
      // Navigation ciblée possible plus tard : salon équipe / tribune / match.
    });

    try {
      if (await arePushNotificationsEnabled()) {
        await requestPermission();
      }
      _wireAuthAndTeamSync();
      await _applyTopicPreferences();
      await _saveTokenForCurrentUser();
    } catch (e) {
      debugPrint('Messaging init non bloquant: $e');
    }
  }

  /// Demande l'autorisation d'envoyer des notifications.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;

    final localOk = await NotificationService.instance.requestPermission();
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus;
    final fcmOk = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    return localOk || fcmOk;
  }

  Future<NotificationPrefs> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(
      pushEnabled: prefs.getBool(_pushEnabledKey) ?? true,
      generalAlerts: prefs.getBool(_generalAlertsKey) ?? true,
      teamChatAlerts: prefs.getBool(_teamChatAlertsKey) ?? true,
      matchRoomAlerts: prefs.getBool(_matchRoomAlertsKey) ?? true,
    );
  }

  Future<bool> arePushNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushEnabledKey) ?? true;
  }

  Future<void> setPushEnabled(bool enabled) async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushEnabledKey, enabled);

    if (enabled) {
      await requestPermission();
      await _applyTopicPreferences();
      await _saveTokenForCurrentUser();
    } else {
      await _unsubscribeAllManagedTopics();
      await _saveNotificationPrefsToFirestore();
    }
  }

  Future<void> setGeneralAlertsEnabled(bool enabled) async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_generalAlertsKey, enabled);
    await _applyTopicPreferences();
  }

  Future<void> setTeamChatAlertsEnabled(bool enabled) async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_teamChatAlertsKey, enabled);
    await _applyTopicPreferences();
  }

  Future<void> setMatchRoomAlertsEnabled(bool enabled) async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_matchRoomAlertsKey, enabled);
    await _applyTopicPreferences();
  }

  Future<void> subscribeHalftime() async {
    if (!isSupported) return;
    await initialize();
    await FirebaseMessaging.instance.subscribeToTopic(halftimeTopic);
  }

  Future<void> unsubscribeHalftime() async {
    if (!isSupported) return;
    await FirebaseMessaging.instance.unsubscribeFromTopic(halftimeTopic);
  }

  Future<void> subscribeMatch(String matchId) async {
    if (!isSupported || matchId.trim().isEmpty) return;
    await initialize();
    final prefs = await getPreferences();
    if (!prefs.pushEnabled || !prefs.matchRoomAlerts) return;

    final topic = matchTopic(matchId);
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    await _rememberMatchTopic(topic);
  }

  Future<void> unsubscribeMatch(String matchId) async {
    if (!isSupported || matchId.trim().isEmpty) return;
    final topic = matchTopic(matchId);
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    await _forgetMatchTopic(topic);
  }

  static String teamTopic(String teamId) => 'team_${_safeTopicPart(teamId)}';
  static String matchTopic(String matchId) => 'match_${_safeTopicPart(matchId)}';

  static String _safeTopicPart(String value) {
    final clean = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_.~%-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (clean.isEmpty) return 'unknown';
    return clean.length > 120 ? clean.substring(0, 120) : clean;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!isSupported) return;
    final n = message.notification;
    if (n == null) return;

    final prefs = await getPreferences();
    if (!prefs.pushEnabled) return;

    final type = message.data['type']?.toString() ?? '';
    if ((type == 'team_chat' && !prefs.teamChatAlerts) ||
        (type == 'match_room' && !prefs.matchRoomAlerts) ||
        ((type == 'score_changed' ||
                type == 'match_finished' ||
                type == 'match_soon' ||
                type == 'match_lounge_open') &&
            !prefs.generalAlerts)) {
      return;
    }

    await NotificationService.instance.showPushNotification(
      title: n.title ?? 'Mundial 2026',
      body: n.body ?? '',
      payload: type,
    );
  }

  void _wireAuthAndTeamSync() {
    _authSub ??= fb_auth.FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _userSub?.cancel();
      _userSub = null;

      if (user == null) {
        await _syncTeamTopic(null);
        return;
      }

      await _saveTokenForUser(user.uid);
      await _saveNotificationPrefsToFirestore();

      _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) unawaited(_saveToken(uid, token));
      });

      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snap) {
        final teamId = snap.data()?['teamId']?.toString().trim();
        unawaited(_syncTeamTopic(teamId));
      }, onError: (e) {
        debugPrint('Sync topic équipe impossible: $e');
      });
    });
  }

  Future<void> _applyTopicPreferences() async {
    if (!isSupported) return;
    final prefs = await getPreferences();

    if (!prefs.pushEnabled) {
      await _unsubscribeAllManagedTopics();
      await _saveNotificationPrefsToFirestore();
      return;
    }

    if (prefs.generalAlerts) {
      await FirebaseMessaging.instance.subscribeToTopic(generalTopic);
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic(generalTopic);
    }

    if (!prefs.matchRoomAlerts) {
      await _unsubscribeAllMatchTopics();
    }

    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final teamId = snap.data()?['teamId']?.toString().trim();
        await _syncTeamTopic(teamId);
      } catch (e) {
        debugPrint('Application prefs topic équipe impossible: $e');
      }
    }

    await _saveNotificationPrefsToFirestore();
  }

  Future<void> _unsubscribeAllManagedTopics() async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(generalTopic);
    await _syncTeamTopic(null);
    await _unsubscribeAllMatchTopics();
  }

  Future<void> _rememberMatchTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final topics = prefs.getStringList(_matchTopicsKey) ?? <String>[];
    if (!topics.contains(topic)) {
      topics.add(topic);
      await prefs.setStringList(_matchTopicsKey, topics);
    }
  }

  Future<void> _forgetMatchTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final topics = prefs.getStringList(_matchTopicsKey) ?? <String>[];
    topics.remove(topic);
    await prefs.setStringList(_matchTopicsKey, topics);
  }

  Future<void> _unsubscribeAllMatchTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final topics = prefs.getStringList(_matchTopicsKey) ?? <String>[];
    for (final topic in topics) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      } catch (e) {
        debugPrint('Unsubscribe topic match impossible: $e');
      }
    }
    await prefs.remove(_matchTopicsKey);
  }

  Future<void> _saveTokenForCurrentUser() async {
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await _saveTokenForUser(uid);
  }

  Future<void> _saveTokenForUser(String uid) async {
    if (!await arePushNotificationsEnabled()) {
      await _saveNotificationPrefsToFirestore();
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _saveToken(uid, token);
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      final prefs = await getPreferences();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
        'notificationPrefs': prefs.toMap(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Sauvegarde token FCM impossible: $e');
    }
  }

  Future<void> _saveNotificationPrefsToFirestore() async {
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final prefs = await getPreferences();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'notificationPrefs': prefs.toMap(),
        'notificationPrefsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Sauvegarde préférences notification impossible: $e');
    }
  }

  Future<void> _syncTeamTopic(String? teamId) async {
    if (!isSupported) return;

    final shared = await SharedPreferences.getInstance();
    final previous = shared.getString(_lastTeamTopicKey);
    final prefs = await getPreferences();
    final next = teamId == null || teamId.trim().isEmpty
        ? null
        : teamTopic(teamId);

    if (previous != null && previous != next) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(previous);
      } catch (e) {
        debugPrint('Unsubscribe ancien topic équipe impossible: $e');
      }
      await shared.remove(_lastTeamTopicKey);
    }

    if (!prefs.pushEnabled || !prefs.teamChatAlerts || next == null) {
      if (next == null) await shared.remove(_lastTeamTopicKey);
      return;
    }

    if (previous != next) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(next);
        await shared.setString(_lastTeamTopicKey, next);
      } catch (e) {
        debugPrint('Subscribe topic équipe impossible: $e');
      }
    }
  }
}

class NotificationPrefs {
  final bool pushEnabled;
  final bool generalAlerts;
  final bool teamChatAlerts;
  final bool matchRoomAlerts;

  const NotificationPrefs({
    required this.pushEnabled,
    required this.generalAlerts,
    required this.teamChatAlerts,
    required this.matchRoomAlerts,
  });

  Map<String, dynamic> toMap() => {
        'pushEnabled': pushEnabled,
        'generalAlerts': generalAlerts,
        'teamChatAlerts': teamChatAlerts,
        'matchRoomAlerts': matchRoomAlerts,
      };

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? generalAlerts,
    bool? teamChatAlerts,
    bool? matchRoomAlerts,
  }) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      generalAlerts: generalAlerts ?? this.generalAlerts,
      teamChatAlerts: teamChatAlerts ?? this.teamChatAlerts,
      matchRoomAlerts: matchRoomAlerts ?? this.matchRoomAlerts,
    );
  }
}
