import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/matches_data.dart';
import '../data/competitions_data.dart';
import '../data/teams_data.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/messaging_service.dart';

class CommunitySettings {
  final bool teamChatEnabled;
  final bool matchLoungeEnabled;
  final int slowModeSeconds;
  final String pinnedMessage;

  const CommunitySettings({
    this.teamChatEnabled = true,
    this.matchLoungeEnabled = true,
    this.slowModeSeconds = 0,
    this.pinnedMessage = '',
  });

  factory CommunitySettings.fromMap(Map<String, dynamic>? data) {
    final rawSlowMode = data?['slowModeSeconds'];
    final slow = rawSlowMode is num ? rawSlowMode.toInt() : 0;
    return CommunitySettings(
      teamChatEnabled: data?['teamChatEnabled'] != false,
      matchLoungeEnabled: data?['matchLoungeEnabled'] != false,
      slowModeSeconds: slow.clamp(0, 300).toInt(),
      pinnedMessage: (data?['pinnedMessage'] ?? '').toString().trim(),
    );
  }
}

class AppProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;

  AppUser? _currentUser;
  List<AppUser> _users = [];
  List<AppTeam> _teams = [];
  Map<String, String> _votes = {};
  Map<String, String> _results = {};
  Map<String, Map<String, String>> _reputationVotes = {};
  Map<String, MatchScore> _scores = {};
  Map<String, MatchScore> _exactPredictions = {};
  Map<String, DateTime> _voteUpdatedAt = {};
  Set<String> _scoringMatchIds = {};
  Map<String, String> _liveStatus = {};
  Map<String, List<String>> _resolvedTeams = {};
  List<FootballMatch> _clubMatches = [];
  Set<String> _halftimeChangedMatchIds = {};

  bool _adminMode = false; // true uniquement si users/{uid}.isAdmin == true
  bool _loaded = false;
  bool _loadingStarted = false;
  bool _voteRemindersEnabled = false;
  bool _halftimeAlertsEnabled = false;
  int _scheduledReminderCount = 0;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _teamsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _votesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _resultsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _goldenBootSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _matchesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reputationVotesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockedUsersSub;
  final Map<String, Map<String, String>> _goldenBoot = {};
  Set<String> _blockedUserIds = <String>{};

  AppUser? get currentUser => _currentUser;
  List<AppUser> get users => _users;
  List<AppTeam> get teams => _teams;
  Map<String, String> get votes => _votes;
  Map<String, String> get results => _results;
  Map<String, Map<String, String>> get reputationVotes => _reputationVotes;
  Map<String, MatchScore> get scores => _scores;
  MatchScore? getExactPrediction(String matchId, {String? userId}) {
    final uid=userId ?? _currentUser?.id; if(uid==null) return null;
    return _exactPredictions['${uid}__$matchId'];
  }
  List<FootballMatch> get matches => List.unmodifiable(_clubMatches);
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);
  bool isUserBlocked(String userId) => _blockedUserIds.contains(userId);
  String? liveStatusFor(String matchId) => _liveStatus[matchId];
  bool isHalftime(String matchId) => _liveStatus[matchId] == 'PAUSED';

  // --- Phases finales : équipes résolues depuis l'API (champs *Resolved) ---
  Map<String, List<String>> _readResolvedTeams(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final out = <String, List<String>>{};
    for (final doc in docs) {
      final data = doc.data();
      final h = (data['homeCodeResolved'] ?? '').toString();
      final a = (data['awayCodeResolved'] ?? '').toString();
      if (h.isNotEmpty && a.isNotEmpty) out[doc.id] = [h, a];
    }
    return out;
  }

  /// Remplace les équipes "TBD" d'un match à élimination par les vraies
  /// équipes qualifiées si le serveur les a déjà résolues.
  FootballMatch resolveMatch(FootballMatch m) {
    if (!m.isTBD) return m;
    final r = _resolvedTeams[m.id];
    if (r == null || r.length < 2) return m;
    return m.copyWith(homeCode: r[0], awayCode: r[1]);
  }

  FootballMatch? _clubMatchFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if ((data['status'] ?? '').toString().toUpperCase() == 'CANCELLED') {
      return null;
    }
    final competitionId = (data['competitionId'] ?? '').toString().trim();
    final kickoff = data['kickoffAt'];
    if (competitionId.isEmpty || kickoff is! Timestamp) return null;
    // PRONO4 n'affiche que les compétitions actuellement supportées.
    // Les anciens documents (Mondial / coupes payantes) restent conservés
    // côté historique mais ne chargent plus l'interface.
    if (competitionById(competitionId) == null) return null;

    final utc = kickoff.toDate().toUtc();
    final local = utc.toLocal();
    final date = '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final homeCode = (data['homeCode'] ?? '').toString().trim().toUpperCase();
    final awayCode = (data['awayCode'] ?? '').toString().trim().toUpperCase();
    if (homeCode.isEmpty || awayCode.isEmpty) return null;

    return FootballMatch(
      id: doc.id,
      homeCode: homeCode,
      awayCode: awayCode,
      competitionId: competitionId,
      homeName: (data['homeName'] ?? homeCode).toString().trim(),
      awayName: (data['awayName'] ?? awayCode).toString().trim(),
      homeCrestUrl: (data['homeCrestUrl'] ?? data['homeCrest'] ?? '').toString().trim(),
      awayCrestUrl: (data['awayCrestUrl'] ?? data['awayCrest'] ?? '').toString().trim(),
      date: date,
      time: time,
      kickoffUtcIso: utc.toIso8601String(),
      venue: (data['venue'] ?? '').toString().trim(),
      phase: MatchPhase.groupe,
      matchday: data['matchday'] is num
          ? (data['matchday'] as num).toInt()
          : int.tryParse((data['matchday'] ?? '').toString()),
      stage: (data['stage'] ?? '').toString().trim(),
      label: (data['label'] ?? '').toString().trim(),
      allowsDraw: data['allowsDraw'] != false,
    );
  }

  void _setClubMatches(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    _clubMatches = docs
        .map(_clubMatchFromDoc)
        .whereType<FootballMatch>()
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  bool isLiveMatch(String matchId) {
    final s = _liveStatus[matchId];
    return s == 'IN_PLAY' || s == 'PAUSED' || s == 'LIVE';
  }

  bool canChangeAtHalftime(String matchId) {
    final uid = _currentUser?.id;
    if (uid == null) return false;
    if (!isHalftime(matchId)) return false;
    if (_halftimeChangedMatchIds.contains(matchId)) return false;
    return _votes.containsKey('${uid}__$matchId');
  }

  // ── SALONS COMMUNAUTAIRES INTELLIGENTS ─────────────────────────────
  static const String _communityConfigDoc = 'communityConfig';

  Stream<CommunitySettings> communitySettingsStream() {
    return _db
        .collection('system')
        .doc(_communityConfigDoc)
        .snapshots()
        .map((snap) => CommunitySettings.fromMap(snap.data()));
  }

  Future<CommunitySettings> _communitySettingsOnce() async {
    try {
      final snap = await _db
          .collection('system')
          .doc(_communityConfigDoc)
          .get()
          .timeout(const Duration(seconds: 5));
      return CommunitySettings.fromMap(snap.data());
    } catch (e) {
      debugPrint('community settings read error: $e');
      return const CommunitySettings();
    }
  }

  Future<String?> adminUpdateCommunitySettings({
    bool? teamChatEnabled,
    bool? matchLoungeEnabled,
    int? slowModeSeconds,
    String? pinnedMessage,
  }) async {
    if (!_adminMode) return 'Accès administrateur requis.';
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (teamChatEnabled != null) data['teamChatEnabled'] = teamChatEnabled;
    if (matchLoungeEnabled != null)
      data['matchLoungeEnabled'] = matchLoungeEnabled;
    if (slowModeSeconds != null)
      data['slowModeSeconds'] = slowModeSeconds.clamp(0, 300);
    if (pinnedMessage != null) data['pinnedMessage'] = pinnedMessage.trim();

    try {
      await _db
          .collection('system')
          .doc(_communityConfigDoc)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('adminUpdateCommunitySettings error: $e');
      return 'Modification impossible pour le moment.';
    }
  }

  String? _validateChatText(String raw, {int max = 600}) {
    final text = raw.trim();
    if (text.isEmpty) return 'Écris ton message avant d’envoyer.';
    if (text.length > max) return 'Message trop long ($max caractères max).';
    final link = RegExp(r'(https?://|www\.)', caseSensitive: false);
    if (link.hasMatch(text)) {
      return 'Les liens sont désactivés dans les salons pour éviter le spam.';
    }
    final objectionable = RegExp(
      r'\b(pute|salope|connard|connasse|encul[eé]|nique|merde|fuck|fucking|shit|bitch|asshole|whore)\b',
      caseSensitive: false,
      unicode: true,
    );
    if (objectionable.hasMatch(text)) {
      return 'Ce message contient des termes interdits. Merci de rester respectueux.';
    }
    return null;
  }

  void _listenBlockedUsers([String? userId]) {
    _blockedUsersSub?.cancel();
    final uid = userId ?? _currentUser?.id;
    if (uid == null || uid.isEmpty) {
      _blockedUserIds = <String>{};
      return;
    }
    _blockedUsersSub = _db
        .collection('userBlocks')
        .doc(uid)
        .collection('blocked')
        .snapshots()
        .listen(
      (snapshot) {
        _blockedUserIds = snapshot.docs.map((doc) => doc.id).toSet();
        notifyListeners();
      },
      onError: (e) => debugPrint('blocked users listener error: $e'),
    );
  }

  Future<String?> blockUser(String targetUserId, String targetName) async {
    final uid = _currentUser?.id;
    if (uid == null) return 'Profil indisponible.';
    if (targetUserId.isEmpty || targetUserId == uid) {
      return 'Ce joueur ne peut pas être bloqué.';
    }
    try {
      await _db
          .collection('userBlocks')
          .doc(uid)
          .collection('blocked')
          .doc(targetUserId)
          .set({
        'targetUserId': targetUserId,
        'targetName': targetName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      _blockedUserIds.add(targetUserId);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('blockUser error: $e');
      return 'Blocage impossible pour le moment.';
    }
  }

  Future<String?> unblockUser(String targetUserId) async {
    final uid = _currentUser?.id;
    if (uid == null) return 'Profil indisponible.';
    try {
      await _db
          .collection('userBlocks')
          .doc(uid)
          .collection('blocked')
          .doc(targetUserId)
          .delete()
          .timeout(const Duration(seconds: 8));
      _blockedUserIds.remove(targetUserId);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('unblockUser error: $e');
      return 'Déblocage impossible pour le moment.';
    }
  }

  Future<String?> reportMessage({
    required String messageId,
    required String reportedUserId,
    required String reportedUserName,
    required String message,
    required String chatType,
    String? teamId,
    String? matchId,
  }) async {
    final uid = _currentUser?.id;
    if (uid == null) return 'Profil indisponible.';
    if (messageId.isEmpty || reportedUserId.isEmpty || reportedUserId == uid) {
      return 'Ce message ne peut pas être signalé.';
    }
    try {
      await _db.collection('contentReports').add({
        'reporterId': uid,
        'reportedUserId': reportedUserId,
        'reportedUserName': reportedUserName.trim(),
        'messageId': messageId,
        'message': message.trim(),
        'chatType': chatType,
        'teamId': teamId,
        'matchId': matchId,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('reportMessage error: $e');
      return 'Signalement impossible pour le moment.';
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> contentReportsStream() {
    return _db
        .collection('contentReports')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<String?> adminResolveContentReport(
    String reportId, {
    bool removeMessage = false,
  }) async {
    if (!_adminMode) return 'Accès administrateur requis.';
    try {
      final reportRef = _db.collection('contentReports').doc(reportId);
      final snapshot = await reportRef.get();
      final data = snapshot.data();
      if (data == null) return 'Signalement introuvable.';

      if (removeMessage) {
        final messageId = (data['messageId'] ?? '').toString();
        final chatType = (data['chatType'] ?? '').toString();
        if (chatType == 'team') {
          final teamId = (data['teamId'] ?? '').toString();
          if (teamId.isNotEmpty && messageId.isNotEmpty) {
            await _db
                .collection('teamChats')
                .doc(teamId)
                .collection('messages')
                .doc(messageId)
                .delete();
          }
        } else if (chatType == 'match') {
          final matchId = (data['matchId'] ?? '').toString();
          if (matchId.isNotEmpty && messageId.isNotEmpty) {
            await _db
                .collection('matchRooms')
                .doc(matchId)
                .collection('messages')
                .doc(messageId)
                .delete();
          }
        }
      }

      await reportRef.set({
        'status': 'resolved',
        'messageRemoved': removeMessage,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': firebaseUid,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('adminResolveContentReport error: $e');
      return 'Traitement du signalement impossible.';
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> teamChatStream() {
    final teamId = _currentUser?.teamId ?? '_';
    return _db
        .collection('teamChats')
        .doc(teamId)
        .collection('messages')
        .orderBy('createdAt')
        .limitToLast(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> teamChatPresenceStream() {
    final teamId = _currentUser?.teamId ?? '_';
    return _db
        .collection('teamChats')
        .doc(teamId)
        .collection('presence')
        .orderBy('activeUntil', descending: true)
        .limit(30)
        .snapshots();
  }

  Future<void> touchTeamChatPresence() async {
    final user = _currentUser;
    final teamId = user?.teamId;
    if (user == null || teamId == null || teamId.isEmpty) return;
    try {
      await _db
          .collection('teamChats')
          .doc(teamId)
          .collection('presence')
          .doc(user.id)
          .set({
        'userId': user.id,
        'name': user.name,
        'avatar': user.avatar,
        'teamId': teamId,
        'activeUntil':
            Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 3))),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('touchTeamChatPresence error: $e');
    }
  }

  Future<void> leaveTeamChatPresence() async {
    final user = _currentUser;
    final teamId = user?.teamId;
    if (user == null || teamId == null || teamId.isEmpty) return;
    try {
      await _db
          .collection('teamChats')
          .doc(teamId)
          .collection('presence')
          .doc(user.id)
          .set({
        'activeUntil': Timestamp.fromDate(DateTime.now()),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<String?> sendTeamMessage(String message) async {
    final user = _currentUser;
    final teamId = user?.teamId;
    if (user == null) return 'Profil indisponible.';
    if (teamId == null || teamId.isEmpty) {
      return 'Rejoins une équipe avant d’écrire dans le salon.';
    }

    final validation = _validateChatText(message);
    if (validation != null) return validation;

    final settings = await _communitySettingsOnce();
    if (!settings.teamChatEnabled) {
      return 'Le salon équipe est momentanément désactivé par l’admin.';
    }

    final text = message.trim();
    try {
      await touchTeamChatPresence();
      await _db.collection('teamChats').doc(teamId).collection('messages').add({
        'teamId': teamId,
        'userId': user.id,
        'name': user.name,
        'avatar': user.avatar,
        'message': text,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('sendTeamMessage error: $e');
      return 'Envoi impossible pour le moment. Réessaie plus tard.';
    }
  }

  FootballMatch? activeMatchLoungeMatch() {
    final now = DateTime.now();
    final candidates = kMatches
        .map(resolveMatch)
        .where((m) => !m.isTBD && !results.containsKey(m.id))
        .where((m) {
      final start = m.dateTime.subtract(const Duration(minutes: 45));
      final end = m.dateTime.add(const Duration(hours: 5));
      return !now.isBefore(start) && now.isBefore(end);
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return candidates.isEmpty ? null : candidates.first;
  }

  FootballMatch? nextLoungeMatch() {
    final now = DateTime.now();
    final upcoming = kMatches
        .map(resolveMatch)
        .where((m) => !m.isTBD && !results.containsKey(m.id))
        .where((m) => m.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> matchRoomStream(String matchId) {
    return _db
        .collection('matchRooms')
        .doc(matchId)
        .collection('messages')
        .orderBy('createdAt')
        .limitToLast(80)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> matchRoomPresenceStream(
      String matchId) {
    return _db
        .collection('matchRooms')
        .doc(matchId)
        .collection('presence')
        .orderBy('activeUntil', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> touchMatchRoomPresence(String matchId) async {
    final user = _currentUser;
    if (user == null) return;
    try {
      await _db
          .collection('matchRooms')
          .doc(matchId)
          .collection('presence')
          .doc(user.id)
          .set({
        'userId': user.id,
        'name': user.name,
        'avatar': user.avatar,
        'matchId': matchId,
        'activeUntil':
            Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 3))),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('touchMatchRoomPresence error: $e');
    }
  }

  Future<void> leaveMatchRoomPresence(String matchId) async {
    final user = _currentUser;
    if (user == null) return;
    try {
      await _db
          .collection('matchRooms')
          .doc(matchId)
          .collection('presence')
          .doc(user.id)
          .set({
        'activeUntil': Timestamp.fromDate(DateTime.now()),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<String?> sendMatchRoomMessage(
      FootballMatch match, String message) async {
    final user = _currentUser;
    if (user == null) return 'Profil indisponible.';

    final validation = _validateChatText(message);
    if (validation != null) return validation;

    final settings = await _communitySettingsOnce();
    if (!settings.matchLoungeEnabled) {
      return 'La tribune du match est momentanément désactivée par l’admin.';
    }

    final active = activeMatchLoungeMatch();
    if (active?.id != match.id) {
      return 'La tribune ouvre 45 minutes avant le match et ferme après la rencontre.';
    }

    final text = message.trim();
    try {
      await touchMatchRoomPresence(match.id);
      await _db
          .collection('matchRooms')
          .doc(match.id)
          .collection('messages')
          .add({
        'matchId': match.id,
        'userId': user.id,
        'teamId': user.teamId,
        'name': user.name,
        'avatar': user.avatar,
        'message': text,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('sendMatchRoomMessage error: $e');
      return 'Envoi impossible pour le moment. Réessaie plus tard.';
    }
  }

  // ── MESSAGERIE D'AIDE (style WhatsApp) ──────────────────────────────
  // Chaque message : userId (le joueur concerné), sender ('user'/'admin'),
  // message, createdAt, readByAdmin, readByUser.

  Future<String?> sendSupportMessage(String message) async {
    final uid = _currentUser?.id;
    if (uid == null) return 'Profil indisponible.';
    final text = message.trim();
    if (text.isEmpty) return 'Écris ton message avant d\'envoyer.';
    if (text.length > 2000) return 'Message trop long (2000 caractères max).';
    try {
      await _db.collection('support').add({
        'userId': uid,
        'name': _currentUser?.name ?? 'Joueur',
        'sender': 'user',
        'message': text,
        'createdAt': FieldValue.serverTimestamp(),
        'readByAdmin': false,
        'readByUser': true,
      }).timeout(const Duration(seconds: 8));
      return null;
    } catch (_) {
      return 'Envoi impossible pour le moment. Réessaie plus tard.';
    }
  }

  /// Réponse de l'admin dans la conversation d'un joueur.
  Future<String?> adminSendSupportReply(
      String targetUserId, String targetName, String message) async {
    if (!_adminMode) return 'Accès administrateur requis.';
    final text = message.trim();
    if (text.isEmpty) return 'Écris ta réponse avant d\'envoyer.';
    try {
      await _db.collection('support').add({
        'userId': targetUserId,
        'name': targetName,
        'sender': 'admin',
        'message': text,
        'createdAt': FieldValue.serverTimestamp(),
        'readByAdmin': true,
        'readByUser': false,
      }).timeout(const Duration(seconds: 8));
      return null;
    } catch (_) {
      return 'Envoi impossible pour le moment.';
    }
  }

  /// Flux de la conversation du joueur connecté (tri côté client).
  Stream<QuerySnapshot<Map<String, dynamic>>> supportThreadStream() {
    final uid = _currentUser?.id ?? '_';
    return _db
        .collection('support')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  /// Flux de tous les messages (page admin), les plus récents d'abord.
  Stream<QuerySnapshot<Map<String, dynamic>>> adminSupportStream() {
    return _db
        .collection('support')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots();
  }

  /// Marque comme lus (côté joueur) les messages admin de sa conversation.
  Future<void> markSupportReadByUser(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final batch = _db.batch();
    var n = 0;
    for (final d in docs) {
      final data = d.data();
      if (data['sender'] == 'admin' && data['readByUser'] != true) {
        batch.update(d.reference, {'readByUser': true});
        n++;
      }
    }
    if (n > 0) {
      try {
        await batch.commit();
      } catch (_) {}
    }
  }

  /// Marque comme lus (côté admin) les messages d'un joueur.
  Future<void> markSupportReadByAdmin(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (!_adminMode) return;
    final batch = _db.batch();
    var n = 0;
    for (final d in docs) {
      final data = d.data();
      if (data['sender'] == 'user' && data['readByAdmin'] != true) {
        batch.update(d.reference, {'readByAdmin': true});
        n++;
      }
    }
    if (n > 0) {
      try {
        await batch.commit();
      } catch (_) {}
    }
  }

  /// Publie / met à jour l'annonce affichée à tous les joueurs (bandeau accueil).
  ///
  /// L'annonce accepte maintenant :
  /// - titre
  /// - message
  /// - image optionnelle via URL
  /// - bouton/lien cliquable
  /// - couleur de fond et couleur du texte en HEX
  Future<String?> adminSetAnnouncement({
    required bool enabled,
    String title = '',
    String message = '',
    String buttonText = '',
    String url = '',
    String imageUrl = '',
    String textColor = '#F8FBFF',
    String backgroundColor = '#172B43',
    String animation = 'none',
  }) async {
    try {
      // Sécurise le cas où l'app affiche encore l'ancien cache admin.
      await _ensureSignedIn().timeout(const Duration(seconds: 8));

      final isAdminNow = await refreshAdminAccess();
      if (!isAdminNow) {
        return 'Accès administrateur refusé. Vérifie dans Firestore que ton utilisateur a bien isAdmin = true.';
      }

      String clean(String value, int maxLength) {
        final trimmed = value.trim();
        if (trimmed.length <= maxLength) return trimmed;
        return trimmed.substring(0, maxLength);
      }

      final cleanTitle = clean(title, 90);
      final cleanMessage = clean(message, 700);
      final cleanButtonText = clean(buttonText, 40);
      final cleanUrl = clean(url, 500);
      final cleanImageUrl = clean(imageUrl, 500);
      final cleanTextColor =
          clean(textColor, 9).isEmpty ? '#F8FBFF' : clean(textColor, 9);
      final cleanBackgroundColor = clean(backgroundColor, 9).isEmpty
          ? '#172B43'
          : clean(backgroundColor, 9);
      final requestedAnimation = animation.trim().toLowerCase();
      const allowedAnimations = {'none', 'glow', 'marquee', 'pulse'};
      final cleanAnimation = allowedAnimations.contains(requestedAnimation)
          ? requestedAnimation
          : 'none';

      final hasContent = cleanTitle.isNotEmpty ||
          cleanMessage.isNotEmpty ||
          cleanImageUrl.isNotEmpty ||
          cleanUrl.isNotEmpty;

      await _db.collection('system').doc('appConfig').set({
        // Nouveau format évolué
        'announcementEnabled': enabled && hasContent,
        'announcementTitle': cleanTitle,
        'announcementMessage': cleanMessage,
        'announcementButtonText': cleanButtonText,
        'announcementUrl': cleanUrl,
        'announcementImageUrl': cleanImageUrl,
        'announcementTextColor': cleanTextColor,
        'announcementBackgroundColor': cleanBackgroundColor,
        'announcementAnimation': cleanAnimation,

        // Ancien champ gardé pour compatibilité avec les anciennes versions
        'announcement': enabled && hasContent
            ? (cleanMessage.isNotEmpty ? cleanMessage : cleanTitle)
            : '',

        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': firebaseUid,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      return null;
    } on TimeoutException {
      return 'Publication trop longue. Vérifie ta connexion puis réessaie.';
    } on FirebaseException catch (e) {
      debugPrint(
          'adminSetAnnouncement FirebaseException: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        return 'Publication refusée par Firestore. Il faut isAdmin = true sur ton utilisateur et les règles Firestore déployées.';
      }
      if (e.code == 'unavailable') {
        return 'Firestore indisponible pour le moment. Réessaie dans quelques secondes.';
      }
      return 'Publication impossible : ${e.code}';
    } catch (e) {
      debugPrint('adminSetAnnouncement error: $e');
      return 'Publication impossible pour le moment.';
    }
  }

  bool get adminMode => _adminMode;
  bool get loaded => _loaded;
  bool get voteRemindersEnabled => _voteRemindersEnabled;
  bool get halftimeAlertsEnabled => _halftimeAlertsEnabled;
  bool get voteRemindersSupported => NotificationService.instance.isSupported;
  int get scheduledReminderCount => _scheduledReminderCount;

  String? get firebaseUid => _auth.currentUser?.uid;

  AppTeam? get myTeam {
    final teamId = _currentUser?.teamId;
    if (teamId == null) return null;

    for (final team in _teams) {
      if (team.id == teamId) return team;
    }

    return null;
  }

  // ─────────────────────────────────────────────
  // PERSISTANCE LOCALE (offline-first)
  // ─────────────────────────────────────────────
  static const String _kCachedUserKey = 'mundial_cached_user_v1';
  static const String _kVoteRemindersKey = 'mundial_vote_reminders_v1';
  static const String _kHalftimeAlertsKey = 'mundial_halftime_alerts_v1';

  Future<void> _restoreCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _voteRemindersEnabled = prefs.getBool(_kVoteRemindersKey) ?? false;
      _halftimeAlertsEnabled = prefs.getBool(_kHalftimeAlertsKey) ?? false;
      final raw = prefs.getString(_kCachedUserKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _currentUser = AppUser(
        id: (data['id'] ?? '').toString(),
        name: (data['name'] ?? 'Joueur').toString(),
        avatar: (data['avatar'] ?? '⚽').toString(),
        teamId: data['teamId'] as String?,
        isAdmin: data['isAdmin'] == true,
      );
      debugPrint('Mundial: cached user restored (${_currentUser!.id})');
    } catch (e) {
      debugPrint('Mundial: cache restore error: $e');
    }
  }

  Future<void> _cacheCurrentUser() async {
    try {
      final u = _currentUser;
      if (u == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kCachedUserKey,
          jsonEncode({
            'id': u.id,
            'name': u.name,
            'avatar': u.avatar,
            'teamId': u.teamId,
            'isAdmin': u.isAdmin,
          }));
    } catch (e) {
      debugPrint('Mundial: cache write error: $e');
    }
  }

  String _generateLocalUid() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return 'local_${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  // ─────────────────────────────────────────────
  // INIT FIREBASE
  // ─────────────────────────────────────────────

  Future<void> load() async {
    if (_loadingStarted) return;
    _loadingStarted = true;

    // 1) Restaurer le user local AVANT tout réseau → UI réactive même offline.
    await _restoreCachedUser();
    if (_currentUser != null) {
      // L'UI peut déjà sortir de l'onboarding.
      _loaded = true;
      notifyListeners();
    }

    // 2) Firebase Auth en best-effort
    try {
      await _ensureSignedIn().timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('Mundial load auth error: $e');
    }

    // 3) Chargement initial Firestore (best-effort)
    try {
      await _loadInitialFirestoreData().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Mundial load firestore error: $e');
    }

    // 4) Si le compte courant est administrateur, lancer immédiatement une
    // synchronisation. Le listener Firestore ci-dessous affichera les matchs
    // dès que la Cloud Function les aura enregistrés.
    if (_adminMode) {
      unawaited(syncMatchesToFirestore());
    }

    // 5) Reprogrammer les rappels locaux déjà activés.
    if (_voteRemindersEnabled) {
      unawaited(_refreshVoteReminders());
    }

    // 6) Listeners live (best-effort)
    try {
      _listenFirestore();
    } catch (e) {
      debugPrint('Mundial listeners error: $e');
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously().timeout(const Duration(seconds: 8));
    }
  }

  Query<Map<String, dynamic>> _activeMatchesQuery() {
    final now = DateTime.now().toUtc();
    final from = Timestamp.fromDate(now.subtract(const Duration(days: 14)));
    final to = Timestamp.fromDate(now.add(const Duration(days: 120)));
    return _db
        .collection('matches')
        .where('kickoffAt', isGreaterThanOrEqualTo: from)
        .where('kickoffAt', isLessThanOrEqualTo: to)
        .orderBy('kickoffAt');
  }

  Query<Map<String, dynamic>> _seasonMatchesQuery() {
    final now = DateTime.now().toUtc();
    final startYear = now.month >= 7 ? now.year : now.year - 1;
    final from = Timestamp.fromDate(DateTime.utc(startYear, 7, 1));
    final to = Timestamp.fromDate(DateTime.utc(startYear + 1, 7, 1));
    return _db.collection('matches')
        .where('kickoffAt', isGreaterThanOrEqualTo: from)
        .where('kickoffAt', isLessThan: to)
        .orderBy('kickoffAt');
  }

  Future<void> _loadInitialFirestoreData() async {
    // Chargement en parallèle : nettement plus rapide sur mobile/réseau moyen.
    final snaps = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      _db.collection('users').get(),
      _db.collection('teams').get(),
      _db.collection('votes').get(),
      _db.collection('results').get(),
      _activeMatchesQuery().get(),
      _seasonMatchesQuery().get(),
      _db.collection('reputationVotes').get(),
    ]);
    final usersSnap = snaps[0];
    final teamsSnap = snaps[1];
    final votesSnap = snaps[2];
    final resultsSnap = snaps[3];
    final matchesSnap = snaps[4];
    final seasonMatchesSnap = snaps[5];
    final reputationSnap = snaps[6];

    _users = usersSnap.docs
        .where((doc) => doc.data()['isArchived'] != true)
        .map(_userFromDoc)
        .toList();
    _teams = teamsSnap.docs.map(_teamFromDoc).toList();
    _setClubMatches(matchesSnap.docs);
    _scoringMatchIds = seasonMatchesSnap.docs.map((d) => d.id).toSet();

    _votes = Map.fromEntries(
      votesSnap.docs.map((doc) {
        final data = doc.data();
        return MapEntry(doc.id, (data['prediction'] ?? '').toString());
      }).where((entry) => entry.value.isNotEmpty),
    );

    _exactPredictions = Map.fromEntries(votesSnap.docs.map((doc) {
      final data=doc.data(); final h=data['exactHome']; final a=data['exactAway'];
      if(h is num && a is num) return MapEntry(doc.id, MatchScore(homeScore:h.toInt(), awayScore:a.toInt()));
      return null;
    }).whereType<MapEntry<String,MatchScore>>());
    _voteUpdatedAt = {
      for (final doc in votesSnap.docs)
        if (doc.data()['updatedAt'] is Timestamp)
          doc.id: (doc.data()['updatedAt'] as Timestamp).toDate(),
    };

    _results = Map.fromEntries(
      resultsSnap.docs.map((doc) {
        final data = doc.data();
        return MapEntry(doc.id, (data['result'] ?? '').toString());
      }).where((entry) => entry.value.isNotEmpty),
    );

    _liveStatus = {
      for (final doc in resultsSnap.docs)
        if ((doc.data()['liveStatus'] ?? '').toString().isNotEmpty)
          doc.id: (doc.data()['liveStatus']).toString(),
    };

    _resolvedTeams = _readResolvedTeams(resultsSnap.docs);

    _scores = Map.fromEntries(
      resultsSnap.docs.map((doc) {
        final data = doc.data();
        final home = data['homeScore'];
        final away = data['awayScore'];
        if (home is num && away is num) {
          return MapEntry(
            doc.id,
            MatchScore(homeScore: home.toInt(), awayScore: away.toInt()),
          );
        }
        return null;
      }).whereType<MapEntry<String, MatchScore>>(),
    );

    _reputationVotes = {for (final d in reputationSnap.docs) d.id: {
      'teamId': (d.data()['teamId'] ?? '').toString(),
      'voterId': (d.data()['voterId'] ?? '').toString(),
      'targetUserId': (d.data()['targetUserId'] ?? '').toString(),
      'badge': (d.data()['badge'] ?? '').toString(),
    }};

    _refreshCurrentUserFromUsers();
  }

  void _listenFirestore() {
    _usersSub?.cancel();
    _teamsSub?.cancel();
    _votesSub?.cancel();
    _resultsSub?.cancel();
    _goldenBootSub?.cancel();
    _matchesSub?.cancel();
    _reputationVotesSub?.cancel();
    _blockedUsersSub?.cancel();

    _matchesSub = _activeMatchesQuery().snapshots().listen(
      (snapshot) {
        _setClubMatches(snapshot.docs);
        _scoringMatchIds.addAll(snapshot.docs.map((d) => d.id));
        if (_voteRemindersEnabled) unawaited(_refreshVoteReminders());
        notifyListeners();
      },
      onError: (e) {
        debugPrint('matches listener error: $e');
      },
    );

    _usersSub = _db.collection('users').snapshots().listen(
      (snapshot) {
        _users = snapshot.docs
            .where((doc) => doc.data()['isArchived'] != true)
            .map(_userFromDoc)
            .toList();
        _refreshCurrentUserFromUsers();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('users listener error: $e');
      },
    );

    _teamsSub = _db.collection('teams').snapshots().listen(
      (snapshot) {
        _teams = snapshot.docs.map(_teamFromDoc).toList();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('teams listener error: $e');
      },
    );

    _reputationVotesSub = _db.collection('reputationVotes').snapshots().listen(
      (snapshot) {
        _reputationVotes = {for (final d in snapshot.docs) d.id: {
          'teamId': (d.data()['teamId'] ?? '').toString(),
          'voterId': (d.data()['voterId'] ?? '').toString(),
          'targetUserId': (d.data()['targetUserId'] ?? '').toString(),
          'badge': (d.data()['badge'] ?? '').toString(),
        }};
        notifyListeners();
      },
      onError: (e) => debugPrint('reputationVotes listener error: $e'),
    );

    _goldenBootSub = _db.collection('goldenBootVotes').snapshots().listen(
      (snapshot) {
        _goldenBoot
          ..clear()
          ..addEntries(snapshot.docs.map((d) {
            final data = d.data();
            return MapEntry(d.id, {
              'name': (data['name'] ?? '').toString(),
              'code': (data['code'] ?? '').toString(),
            });
          }));
        notifyListeners();
      },
      onError: (e) {
        debugPrint('goldenBoot listener error: $e');
      },
    );

    _votesSub = _db.collection('votes').snapshots().listen(
      (snapshot) {
        final uid = _currentUser?.id;
        final beforeOwn = uid == null
            ? <String>{}
            : _votes.keys.where((k) => k.startsWith('${uid}__')).toSet();

        _votes = Map.fromEntries(
          snapshot.docs.map((doc) {
            final data = doc.data();
            return MapEntry(doc.id, (data['prediction'] ?? '').toString());
          }).where((entry) => entry.value.isNotEmpty),
        );
        _exactPredictions = Map.fromEntries(snapshot.docs.map((doc) {
          final data=doc.data(); final h=data['exactHome']; final a=data['exactAway'];
          if(h is num && a is num) return MapEntry(doc.id, MatchScore(homeScore:h.toInt(), awayScore:a.toInt()));
          return null;
        }).whereType<MapEntry<String,MatchScore>>());
        _voteUpdatedAt = {
          for (final doc in snapshot.docs)
            if (doc.data()['updatedAt'] is Timestamp)
              doc.id: (doc.data()['updatedAt'] as Timestamp).toDate(),
        };

        _halftimeChangedMatchIds = uid == null
            ? <String>{}
            : {
                for (final doc in snapshot.docs)
                  if (doc.id.startsWith('${uid}__') &&
                      doc.data()['changedAtHalftime'] == true)
                    doc.id.substring('${uid}__'.length),
              };

        final afterOwn = uid == null
            ? <String>{}
            : _votes.keys.where((k) => k.startsWith('${uid}__')).toSet();
        if (_voteRemindersEnabled && !setEquals(beforeOwn, afterOwn)) {
          unawaited(_refreshVoteReminders());
        }
        notifyListeners();
      },
      onError: (e) {
        debugPrint('votes listener error: $e');
      },
    );

    _resultsSub = _db.collection('results').snapshots().listen(
      (snapshot) {
        _results = Map.fromEntries(
          snapshot.docs.map((doc) {
            final data = doc.data();
            return MapEntry(doc.id, (data['result'] ?? '').toString());
          }).where((entry) => entry.value.isNotEmpty),
        );

        _liveStatus = {
          for (final doc in snapshot.docs)
            if ((doc.data()['liveStatus'] ?? '').toString().isNotEmpty)
              doc.id: (doc.data()['liveStatus']).toString(),
        };

        _resolvedTeams = _readResolvedTeams(snapshot.docs);

        _scores = Map.fromEntries(
          snapshot.docs.map((doc) {
            final data = doc.data();
            final home = data['homeScore'];
            final away = data['awayScore'];
            if (home is num && away is num) {
              return MapEntry(
                doc.id,
                MatchScore(homeScore: home.toInt(), awayScore: away.toInt()),
              );
            }
            return null;
          }).whereType<MapEntry<String, MatchScore>>(),
        );
        notifyListeners();
      },
      onError: (e) {
        debugPrint('results listener error: $e');
      },
    );

    _listenBlockedUsers();
  }

  // ─────────────────────────────────────────────
  // CONVERSIONS FIRESTORE
  // ─────────────────────────────────────────────

  AppUser _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return AppUser(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      avatar: (data['avatar'] ?? '👤').toString(),
      teamId: data['teamId']?.toString(),
      isAdmin: data['isAdmin'] == true,
      recoveryCode: (data['recoveryCode'] ?? '').toString(),
    );
  }

  bool get isCaptain {
    final t = myTeam;
    return t != null && t.createdBy == _currentUser?.id;
  }

  Future<String?> setTeamIcon(String icon) async {
    final t = myTeam;
    if (t == null) return 'Aucune equipe.';
    if (t.createdBy != _currentUser?.id) {
      return 'Seul le capitaine peut changer l\u2019icone.';
    }
    try {
      await _db.collection('teams').doc(t.id).set(
        {'icon': icon},
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('setTeamIcon error: $e');
      return 'Modification impossible. Verifie ta connexion.';
    }
  }

  Map<String, String>? get myGoldenBootPick {
    final uid = _currentUser?.id;
    if (uid == null) return null;
    final pick = _goldenBoot[uid];
    if (pick == null || (pick['name'] ?? '').isEmpty) return null;
    return pick;
  }

  int get goldenBootVoteCount => _goldenBoot.length;

  Map<String, int> goldenBootCounts() {
    final counts = <String, int>{};
    for (final pick in _goldenBoot.values) {
      final name = pick['name'] ?? '';
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  Future<String?> setGoldenBootPick(String name, String code) async {
    final uid = _currentUser?.id;
    if (uid == null) return 'Connecte-toi pour voter.';
    try {
      await _db.collection('goldenBootVotes').doc(uid).set({
        'uid': uid,
        'name': name,
        'code': code,
        'votedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('setGoldenBootPick error: $e');
      return 'Vote impossible. Verifie ta connexion.';
    }
  }

  AppTeam _teamFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return AppTeam(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      code: (data['code'] ?? '').toString(),
      memberIds: List<String>.from(data['memberIds'] ?? const []),
      createdBy: (data['createdBy'] ?? '').toString(),
      icon: (data['icon'] ?? '').toString(),
    );
  }

  void _refreshCurrentUserFromUsers() {
    final uid = firebaseUid;

    // Si Firebase n'a pas répondu, on garde notre user local (cache).
    if (uid == null) return;

    for (final user in _users) {
      if (user.id == uid) {
        _currentUser = user;
        _adminMode = user.isAdmin;
        _cacheCurrentUser();
        return;
      }
    }
    // User pas (encore) en Firestore → ne touche PAS _currentUser,
    // on garde la version locale sortie de createUser().
  }

  Future<bool> setVoteRemindersEnabled(bool enabled) async {
    if (enabled && !voteRemindersSupported) return false;

    if (enabled) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) return false;
    }

    _voteRemindersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoteRemindersKey, enabled);

    if (enabled) {
      await _refreshVoteReminders();
    } else {
      _scheduledReminderCount = 0;
      await NotificationService.instance.cancelAllVoteReminders();
    }

    notifyListeners();
    return true;
  }

  Future<bool> setHalftimeAlertsEnabled(bool enabled) async {
    if (enabled && !MessagingService.instance.isSupported) return false;
    if (enabled) {
      final granted = await MessagingService.instance.requestPermission();
      if (!granted) return false;
    }
    _halftimeAlertsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHalftimeAlertsKey, enabled);
    if (enabled) {
      await MessagingService.instance.subscribeHalftime();
    } else {
      await MessagingService.instance.unsubscribeHalftime();
    }
    notifyListeners();
    return true;
  }

  Future<void> sendTestVoteReminder() async {
    if (!_voteRemindersEnabled) return;
    await NotificationService.instance.showTestNotification();
  }

  Future<void> _refreshVoteReminders() async {
    if (!_voteRemindersEnabled || _currentUser == null) return;
    try {
      final uid = _currentUser!.id;
      final votedMatchIds = _votes.keys
          .where((key) => key.startsWith('${uid}__'))
          .map((key) => key.substring('${uid}__'.length))
          .toSet();
      _scheduledReminderCount =
          await NotificationService.instance.scheduleVoteReminders(
        matches: _clubMatches,
        votedMatchIds: votedMatchIds,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Mundial reminder scheduling error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // USER
  // ─────────────────────────────────────────────

  String _newRecoveryCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => alphabet[random.nextInt(alphabet.length)])
        .join();
  }

  Future<void> createUser(String name, String avatar) async {
    final cleanName = name.trim().isEmpty ? 'Joueur' : name.trim();

    // 1) Récupérer un UID : Firebase si possible, sinon local.
    //    On timeout vite pour ne JAMAIS bloquer l'UI.
    String uid;
    try {
      await _ensureSignedIn().timeout(const Duration(seconds: 5));
      uid = firebaseUid ?? _generateLocalUid();
    } catch (e) {
      debugPrint(
          'Mundial: anon-auth failed in createUser, using local uid: $e');
      uid = firebaseUid ?? _generateLocalUid();
    }

    final recoveryCode = _newRecoveryCode();

    final user = AppUser(
      id: uid,
      name: cleanName,
      avatar: avatar,
      recoveryCode: recoveryCode,
    );

    // 2) APPLIQUE IMMÉDIATEMENT en local + cache + notify
    //    → L'UI sort de l'onboarding et passe sur MainShell tout de suite.
    _currentUser = user;
    _users = [
      ..._users.where((x) => x.id != uid),
      user,
    ];
    await _cacheCurrentUser();
    notifyListeners();

    // 3) Écriture Firestore en arrière-plan (fire-and-forget).
    //    Si ça rate, pas grave : le user reste en local, on retentera plus tard.
    unawaited(_writeUserDocBackground(uid, cleanName, avatar, recoveryCode));
    _listenFirestore();
  }

  Future<void> _writeUserDocBackground(
      String uid, String name, String avatar, String recoveryCode) async {
    try {
      await _db.collection('users').doc(uid).set({
        'id': uid,
        'name': name,
        'avatar': avatar,
        'recoveryCode': recoveryCode,
        'recoveryCodeCreatedAt': FieldValue.serverTimestamp(),
        'teamId': _currentUser?.teamId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Mundial: user $uid synced to Firestore.');
    } catch (e) {
      debugPrint('Mundial: user $uid Firestore sync deferred: $e');
    }
  }

  Future<void> updateUser({String? name, String? avatar}) async {
    if (_currentUser == null) return;

    final newName =
        name == null || name.trim().isEmpty ? _currentUser!.name : name.trim();
    final newAvatar = avatar ?? _currentUser!.avatar;

    final user = _currentUser!.copyWith(
      name: newName,
      avatar: newAvatar,
    );

    // Apply locally + cache + notify FIRST (UI feels instant)
    _currentUser = user;
    _users = _users.map((x) => x.id == user.id ? user : x).toList();
    await _cacheCurrentUser();
    notifyListeners();

    // Sync to Firestore in background — no exception bubbles to UI
    unawaited(() async {
      try {
        await _db.collection('users').doc(user.id).set({
          'id': user.id,
          'name': user.name,
          'avatar': user.avatar,
          'teamId': user.teamId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Mundial: updateUser sync deferred: $e');
      }
    }());
  }

  /// Efface le compte invité et toutes ses données via Firebase Admin.
  /// Retourne null en cas de succès, sinon un message affichable à l'utilisateur.
  Future<String?> deleteAccount() async {
    try {
      await _ensureSignedIn().timeout(const Duration(seconds: 10));
      final authUser = _auth.currentUser;
      final token = await authUser?.getIdToken(true);
      if (authUser == null || token == null || token.isEmpty) {
        return 'Connexion Firebase impossible.';
      }

      final response = await http
          .post(
            Uri.parse(
              'https://europe-west1-mundial2026-ibab-01.cloudfunctions.net/deleteAccountData',
            ),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, dynamic>{'data': <String, dynamic>{}}),
          )
          .timeout(const Duration(seconds: 120));

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        payload = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final rawError = payload?['error'];
        if (rawError is Map) {
          final message = rawError['message']?.toString().trim();
          if (message != null && message.isNotEmpty) return message;
        }
        return 'Suppression impossible pour le moment.';
      }

      final result = payload?['result'] ?? payload?['data'];
      if (result is! Map || result['deleted'] != true) {
        return 'Confirmation de suppression invalide.';
      }

      await _usersSub?.cancel();
      await _teamsSub?.cancel();
      await _votesSub?.cancel();
      await _resultsSub?.cancel();
      await _goldenBootSub?.cancel();
      await _matchesSub?.cancel();
      await _reputationVotesSub?.cancel();
      await _blockedUsersSub?.cancel();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedUserKey);
      await prefs.remove(_kVoteRemindersKey);
      await prefs.remove(_kHalftimeAlertsKey);
      try {
        await _auth.signOut();
      } catch (_) {}

      _currentUser = null;
      _users = <AppUser>[];
      _teams = <AppTeam>[];
      _votes = <String, String>{};
      _results = <String, String>{};
      _reputationVotes = <String, Map<String, String>>{};
      _scores = <String, MatchScore>{};
      _exactPredictions = <String, MatchScore>{};
      _voteUpdatedAt = <String, DateTime>{};
      _goldenBoot.clear();
      _blockedUserIds = <String>{};
      _adminMode = false;
      _voteRemindersEnabled = false;
      _halftimeAlertsEnabled = false;
      notifyListeners();
      return null;
    } on TimeoutException {
      return 'La suppression prend trop de temps. Réessayez.';
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      return 'Suppression impossible. Vérifiez votre connexion.';
    }
  }

  /// Récupère un ancien profil via la Cloud Function sécurisée.
  /// Le transfert complet est exécuté côté serveur avec Firebase Admin.
  Future<String?> recoverProfileWithCode(String rawCode) async {
    final code =
        rawCode.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (code.length != 8) {
      return 'Le code doit contenir exactement 8 caractères.';
    }

    try {
      await _ensureSignedIn().timeout(const Duration(seconds: 10));
      final authUser = _auth.currentUser;
      final token = await authUser?.getIdToken(true);
      if (authUser == null || token == null || token.isEmpty) {
        return 'Connexion Firebase impossible.';
      }

      final response = await http
          .post(
            Uri.parse(
              'https://europe-west1-mundial2026-ibab-01.cloudfunctions.net/recoverProfile',
            ),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{'code': code},
            }),
          )
          .timeout(const Duration(seconds: 120));

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        payload = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final rawError = payload?['error'];
        if (rawError is Map) {
          final error = Map<String, dynamic>.from(rawError);
          final status = (error['status'] ?? '').toString().toLowerCase();
          final message = error['message']?.toString();
          switch (status) {
            case 'not_found':
              return 'Code introuvable.';
            case 'invalid_argument':
              return message ?? 'Code invalide.';
            case 'unauthenticated':
              return 'Connexion Firebase impossible.';
            case 'failed_precondition':
              return message ?? 'Récupération impossible.';
            default:
              return message ?? 'Récupération impossible.';
          }
        }
        return 'Récupération impossible.';
      }

      final rawData = payload?['result'] ?? payload?['data'];
      if (rawData is! Map) {
        return 'Réponse serveur invalide.';
      }
      final data = Map<String, dynamic>.from(rawData);

      final recovered = AppUser(
        id: (data['id'] ?? authUser.uid).toString(),
        name: (data['name'] ?? 'Joueur').toString(),
        avatar: (data['avatar'] ?? '⚽').toString(),
        teamId: data['teamId']?.toString(),
        isAdmin: data['isAdmin'] == true,
        recoveryCode: (data['recoveryCode'] ?? code).toString(),
      );

      _currentUser = recovered;
      _adminMode = recovered.isAdmin;
      await _cacheCurrentUser();
      await _loadInitialFirestoreData();
      _listenFirestore();
      if (_voteRemindersEnabled) {
        unawaited(_refreshVoteReminders());
      }
      notifyListeners();
      return null;
    } on TimeoutException {
      return 'Le transfert prend trop de temps. Réessayez.';
    } catch (e) {
      debugPrint('recoverProfileWithCode error: $e');
      return 'Récupération impossible. Vérifiez Internet.';
    }
  }

  // ─────────────────────────────────────────────
  // TEAM
  // ─────────────────────────────────────────────

  Future<AppTeam?> createTeam(String teamName) async {
    if (_currentUser == null || _currentUser!.teamId != null) return null;

    final name = teamName.trim();
    if (name.isEmpty) return null;

    try {
      final teamRef = _db.collection('teams').doc();
      final code = await _generateUniqueTeamCode();

      final team = AppTeam(
        id: teamRef.id,
        name: name,
        code: code,
        memberIds: [_currentUser!.id],
        createdBy: _currentUser!.id,
      );

      final batch = _db.batch();

      batch.set(teamRef, {
        'id': team.id,
        'name': team.name,
        'code': team.code,
        'memberIds': team.memberIds,
        'createdBy': team.createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        _db.collection('users').doc(_currentUser!.id),
        {
          'teamId': team.id,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit().timeout(const Duration(seconds: 8));

      final user = _currentUser!.copyWith(teamId: team.id);

      _currentUser = user;
      _users = _users.map((x) => x.id == user.id ? user : x).toList();
      _teams = [..._teams, team];
      _cacheCurrentUser();

      notifyListeners();

      return team;
    } catch (e) {
      debugPrint('createTeam error: $e');
      return null;
    }
  }

  Future<String?> joinTeam(String code) async {
    if (_currentUser == null) {
      return 'Vous devez d’abord créer votre profil.';
    }

    if (_currentUser!.teamId != null) {
      return 'Vous êtes déjà dans une équipe.';
    }

    final upper = code.trim().toUpperCase();

    if (upper.length < 4) {
      return 'Code invalide.';
    }

    try {
      final query = await _db
          .collection('teams')
          .where('code', isEqualTo: upper)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));

      if (query.docs.isEmpty) {
        return 'Code invalide — équipe introuvable.';
      }

      final teamRef = query.docs.first.reference;
      final userRef = _db.collection('users').doc(_currentUser!.id);

      String? error;

      await _db.runTransaction((transaction) async {
        final teamSnap = await transaction.get(teamRef);
        final data = teamSnap.data() ?? <String, dynamic>{};
        final memberIds = List<String>.from(data['memberIds'] ?? const []);

        if (memberIds.contains(_currentUser!.id)) {
          error = 'Vous êtes déjà dans cette équipe.';
          return;
        }

        if (memberIds.length >= 4) {
          error = 'Équipe complète (max 4 joueurs).';
          return;
        }

        transaction.update(teamRef, {
          'memberIds': FieldValue.arrayUnion([_currentUser!.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(
          userRef,
          {
            'teamId': teamRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }).timeout(const Duration(seconds: 8));

      if (error != null) return error;

      final user = _currentUser!.copyWith(teamId: teamRef.id);

      _currentUser = user;
      _users = _users.map((x) => x.id == user.id ? user : x).toList();
      _cacheCurrentUser();

      notifyListeners();

      return null;
    } catch (e) {
      debugPrint('joinTeam error: $e');
      return 'Connexion impossible. Vérifiez votre réseau et réessayez.';
    }
  }

  Future<bool> leaveTeam() async {
    if (_currentUser?.teamId == null) return false;

    final uid = _currentUser!.id;
    final teamId = _currentUser!.teamId!;
    final teamRef = _db.collection('teams').doc(teamId);
    final userRef = _db.collection('users').doc(uid);

    try {
      await _db.runTransaction((transaction) async {
        final teamSnap = await transaction.get(teamRef);

        if (teamSnap.exists) {
          final data = teamSnap.data() ?? <String, dynamic>{};
          final memberIds = List<String>.from(data['memberIds'] ?? const []);
          final newMembers = memberIds.where((id) => id != uid).toList();

          if (newMembers.isEmpty) {
            transaction.delete(teamRef);
          } else {
            transaction.update(teamRef, {
              'memberIds': newMembers,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        transaction.set(
          userRef,
          {
            'teamId': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }).timeout(const Duration(seconds: 8));

      final user = _currentUser!.copyWith(clearTeam: true);

      _currentUser = user;
      _users = _users.map((x) => x.id == user.id ? user : x).toList();

      _teams = _teams
          .map(
            (team) => team.id == teamId
                ? team.copyWith(
                    memberIds: team.memberIds.where((id) => id != uid).toList(),
                  )
                : team,
          )
          .where((team) => team.memberIds.isNotEmpty)
          .toList();

      _cacheCurrentUser();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('leaveTeam error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // VOTES
  // ─────────────────────────────────────────────

  Future<String?> castVote(String matchId, Prediction prediction) async {
    if (_currentUser == null) return 'Profil utilisateur indisponible.';

    FootballMatch? match;
    for (final item in _clubMatches) {
      if (item.id == matchId) {
        match = item;
        break;
      }
    }

    if (match != null) match = resolveMatch(match);

    if (match == null || match.isTBD) {
      return 'Ce match n’est pas encore disponible pour les pronostics.';
    }
    if (match.hasStarted) {
      return 'Pronostic fermé : le match a déjà commencé.';
    }

    final key = '${_currentUser!.id}__$matchId';
    final previous = _votes[key];
    final previousExact = _exactPredictions[key];

    _votes = {
      ..._votes,
      key: prediction.key,
    };
    final exactNow = Map<String, MatchScore>.from(_exactPredictions)..remove(key);
    _exactPredictions = exactNow;
    notifyListeners();

    try {
      await _db.collection('votes').doc(key).set({
        'userId': _currentUser!.id,
        'matchId': matchId,
        'teamId': _currentUser!.teamId,
        'prediction': prediction.key,
        'exactHome': FieldValue.delete(),
        'exactAway': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));

      if (_voteRemindersEnabled) {
        await NotificationService.instance.cancelReminderForMatch(matchId);
        // Reprogramme la liste afin d'ajouter le prochain match au-delà de
        // la limite mobile des notifications en attente.
        unawaited(_refreshVoteReminders());
      }
      return null;
    } catch (e) {
      debugPrint('castVote error (rolling back local state): $e');
      final rolledBack = Map<String, String>.from(_votes);
      if (previous == null) {
        rolledBack.remove(key);
      } else {
        rolledBack[key] = previous;
      }
      _votes = rolledBack;
      if (previousExact != null) { _exactPredictions = {..._exactPredictions, key: previousExact}; }
      notifyListeners();
      return 'Vote impossible. Vérifiez la connexion ou demandez à l’administrateur de synchroniser les horaires.';
    }
  }

  Future<String?> castExactScore(String matchId, int home, int away) async {
    if (_currentUser == null) return 'Profil utilisateur indisponible.';
    if (home < 0 || away < 0 || home > 20 || away > 20) return 'Score invalide.';
    FootballMatch? match;
    for (final item in _clubMatches) { if (item.id == matchId) { match = resolveMatch(item); break; } }
    if (match == null || match.isTBD) return 'Ce match n’est pas disponible.';
    if (match.hasStarted) return 'Pronostic fermé : le match a déjà commencé.';
    final prediction = home > away ? Prediction.home : (away > home ? Prediction.away : Prediction.draw);
    if (prediction == Prediction.draw && !match.allowsDraw) return 'Le nul n’est pas proposé pour ce match.';
    final key='${_currentUser!.id}__$matchId';
    final previous=_votes[key]; final previousExact=_exactPredictions[key];
    _votes={..._votes,key:prediction.key};
    _exactPredictions={..._exactPredictions,key:MatchScore(homeScore:home,awayScore:away)};
    notifyListeners();
    try {
      await _db.collection('votes').doc(key).set({
        'userId':_currentUser!.id,'matchId':matchId,'teamId':_currentUser!.teamId,
        'prediction':prediction.key,'exactHome':home,'exactAway':away,'updatedAt':FieldValue.serverTimestamp(),
      },SetOptions(merge:true)).timeout(const Duration(seconds:8));
      if (_voteRemindersEnabled) {
        await NotificationService.instance.cancelReminderForMatch(matchId);
        unawaited(_refreshVoteReminders());
      }
      return null;
    } catch(e) {
      final v=Map<String,String>.from(_votes); if(previous==null){v.remove(key);}else{v[key]=previous;} _votes=v;
      final ex=Map<String,MatchScore>.from(_exactPredictions); if(previousExact==null){ex.remove(key);}else{ex[key]=previousExact;} _exactPredictions=ex;
      notifyListeners(); return 'Score exact impossible. Vérifie la connexion.';
    }
  }

  Future<String?> castHalftimeVote(
      String matchId, Prediction prediction) async {
    if (_currentUser == null) return 'Profil utilisateur indisponible.';
    if (!isHalftime(matchId)) {
      return 'Le changement n\u2019est possible qu\u2019\u00e0 la mi-temps.';
    }
    if (_halftimeChangedMatchIds.contains(matchId)) {
      return 'Tu as d\u00e9j\u00e0 utilis\u00e9 ton changement pour ce match.';
    }

    final key = '${_currentUser!.id}__$matchId';
    final previous = _votes[key];
    final previousChanged = Set<String>.from(_halftimeChangedMatchIds);

    _votes = {..._votes, key: prediction.key};
    _halftimeChangedMatchIds = {..._halftimeChangedMatchIds, matchId};
    notifyListeners();

    try {
      await _db.collection('votes').doc(key).set({
        'userId': _currentUser!.id,
        'matchId': matchId,
        'teamId': _currentUser!.teamId,
        'prediction': prediction.key,
        'changedAtHalftime': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('castHalftimeVote error (rollback): $e');
      final rolledBack = Map<String, String>.from(_votes);
      if (previous == null) {
        rolledBack.remove(key);
      } else {
        rolledBack[key] = previous;
      }
      _votes = rolledBack;
      _halftimeChangedMatchIds = previousChanged;
      notifyListeners();
      return 'Changement impossible. V\u00e9rifie ta connexion.';
    }
  }

  Prediction? getVote(String matchId, {String? userId}) {
    final uid = userId ?? _currentUser?.id;

    if (uid == null) return null;

    return PredictionLabel.fromKey(_votes['${uid}__$matchId']);
  }

  Future<int> syncMatchesToFirestore() async {
    if (!_adminMode) return 0;

    try {
      await _ensureSignedIn().timeout(const Duration(seconds: 10));
      final authUser = _auth.currentUser;
      final token = await authUser?.getIdToken(true);
      if (authUser == null || token == null || token.isEmpty) {
        return _clubMatches.length;
      }

      final response = await http
          .post(
            Uri.parse(
              'https://europe-west1-mundial2026-ibab-01.cloudfunctions.net/syncClubMatchesNow',
            ),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{},
            }),
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'syncMatchesToFirestore HTTP ${response.statusCode}: ${response.body}',
        );
        return _clubMatches.length;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final payload = Map<String, dynamic>.from(decoded);
        final raw = payload['result'] ?? payload['data'];
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          final synced = data['syncedMatches'];
          if (synced is num) return synced.toInt();
        }
      }
      return _clubMatches.length;
    } catch (e) {
      debugPrint('syncMatchesToFirestore error: $e');
      return _clubMatches.length;
    }
  }

  Future<String?> saveClubMatch({
    String? id,
    required String competitionId,
    required String homeName,
    required String awayName,
    required DateTime kickoff,
    String venue = '',
    String stage = '',
    int? matchday,
    bool allowsDraw = true,
  }) async {
    if (!_adminMode) return 'Accès administrateur requis.';
    final cleanHome = homeName.trim();
    final cleanAway = awayName.trim();
    if (competitionId.trim().isEmpty ||
        cleanHome.isEmpty ||
        cleanAway.isEmpty) {
      return 'Compétition et deux clubs requis.';
    }

    String codeFor(String name) {
      final letters = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      return letters.padRight(3, 'X').substring(0, 3);
    }

    final ref = id == null || id.trim().isEmpty
        ? _db.collection('matches').doc()
        : _db.collection('matches').doc(id.trim());
    try {
      await ref.set({
        'matchId': ref.id,
        'competitionId': competitionId.trim(),
        'homeCode': codeFor(cleanHome),
        'awayCode': codeFor(cleanAway),
        'homeName': cleanHome,
        'awayName': cleanAway,
        'kickoffAt': Timestamp.fromDate(kickoff.toUtc()),
        'venue': venue.trim(),
        'stage': stage.trim(),
        'matchday': matchday,
        'allowsDraw': allowsDraw,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUser?.id,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('saveClubMatch error: $e');
      return 'Impossible d’enregistrer la rencontre.';
    }
  }

  // ─────────────────────────────────────────────
  // RESULTS ADMIN
  // ─────────────────────────────────────────────

  Future<String?> setMatchScore(
    String matchId,
    int homeScore,
    int awayScore,
  ) async {
    if (!_adminMode) {
      return 'Accès administrateur requis.';
    }
    if (homeScore < 0 || awayScore < 0 || homeScore > 99 || awayScore > 99) {
      return 'Saisissez un score valide entre 0 et 99.';
    }

    final score = MatchScore(homeScore: homeScore, awayScore: awayScore);
    final previousResult = _results[matchId];
    final previousScore = _scores[matchId];

    // Mise à jour immédiate dans l'interface.
    _results = {
      ..._results,
      matchId: score.outcome.key,
    };
    _scores = {
      ..._scores,
      matchId: score,
    };
    notifyListeners();

    try {
      await _db.collection('results').doc(matchId).set({
        'matchId': matchId,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'result': score.outcome.key,
        'status': 'FINISHED',
        'updatedBy': _currentUser?.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('setMatchScore error (rolling back): $e');

      final rolledBackResults = Map<String, String>.from(_results);
      if (previousResult == null) {
        rolledBackResults.remove(matchId);
      } else {
        rolledBackResults[matchId] = previousResult;
      }
      _results = rolledBackResults;

      final rolledBackScores = Map<String, MatchScore>.from(_scores);
      if (previousScore == null) {
        rolledBackScores.remove(matchId);
      } else {
        rolledBackScores[matchId] = previousScore;
      }
      _scores = rolledBackScores;
      notifyListeners();
      return 'Impossible d’enregistrer le score. Vérifiez la connexion.';
    }
  }

  Future<bool> refreshAdminAccess() async {
    final uid = firebaseUid;
    if (uid == null || uid.isEmpty) {
      _adminMode = false;
      notifyListeners();
      return false;
    }

    try {
      final snap = await _db.collection('users').doc(uid).get().timeout(
            const Duration(seconds: 8),
          );
      final isAdmin = snap.data()?['isAdmin'] == true;
      _adminMode = isAdmin;
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(isAdmin: isAdmin);
        _users = _users.map((u) => u.id == uid ? _currentUser! : u).toList();
      }
      notifyListeners();
      if (isAdmin) {
        unawaited(syncMatchesToFirestore());
      }
      return isAdmin;
    } catch (e) {
      debugPrint('refresh admin access error: $e');
      return _adminMode;
    }
  }

  Future<bool> toggleAdmin(String password) async {
    // Ancien mot de passe désactivé volontairement :
    // l’accès admin se donne maintenant uniquement depuis Firestore
    // avec users/{uid}.isAdmin = true.
    return refreshAdminAccess();
  }

  // ─────────────────────────────────────────────
  // SCORING
  // ─────────────────────────────────────────────

  List<GroupStanding> getGroupStandings(String group) {
    final rows = <String, GroupStanding>{
      for (final team in kTeams.values.where((team) => team.group == group))
        team.code: GroupStanding(teamCode: team.code),
    };

    for (final match in kMatches.where(
      (match) => match.phase == MatchPhase.groupe && match.group == group,
    )) {
      final score = _scores[match.id];
      if (score == null) continue;

      final home = rows[match.homeCode];
      final away = rows[match.awayCode];
      if (home == null || away == null) continue;

      rows[match.homeCode] = home.addMatch(
        scored: score.homeScore,
        conceded: score.awayScore,
      );
      rows[match.awayCode] = away.addMatch(
        scored: score.awayScore,
        conceded: score.homeScore,
      );
    }

    final standings = rows.values.toList();
    standings.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;

      final byDifference = b.goalDifference.compareTo(a.goalDifference);
      if (byDifference != 0) return byDifference;

      final byGoals = b.goalsFor.compareTo(a.goalsFor);
      if (byGoals != 0) return byGoals;

      final aName = kTeams[a.teamCode]?.name ?? a.teamCode;
      final bName = kTeams[b.teamCode]?.name ?? b.teamCode;
      return aName.compareTo(bName);
    });

    return standings;
  }

  int getUserPoints(String userId) {
    final ids = _scoringMatchIds.isEmpty ? _clubMatches.map((m)=>m.id).toSet() : _scoringMatchIds;
    return _results.entries
        .where((entry) => ids.contains(entry.key))
        .fold(0, (points, entry) {
      final voteKey = '${userId}__${entry.key}';
      final userPrediction = _votes[voteKey];
      final correctResult = entry.value;

      var gained = userPrediction == correctResult ? 3 : 0;
      final exact = _exactPredictions[voteKey];
      final finalScore = _scores[entry.key];
      if (exact != null && finalScore != null &&
          exact.homeScore == finalScore.homeScore && exact.awayScore == finalScore.awayScore) {
        gained += 2;
      }
      return points + gained;
    });
  }

  int getUserVoteCount(String userId) {
    final ids = _scoringMatchIds.isEmpty ? _clubMatches.map((m)=>m.id).toSet() : _scoringMatchIds;
    return _votes.keys.where((key) {
      if (!key.startsWith('${userId}__')) return false;
      return ids.contains(key.substring('${userId}__'.length));
    }).length;
  }

  double getTeamPoints(String teamId) {
    final team = _teams.firstWhere(
      (t) => t.id == teamId,
      orElse: () => const AppTeam(
        id: '',
        name: '',
        code: '',
        memberIds: [],
        createdBy: '',
      ),
    );

    if (team.memberIds.isEmpty) return 0;

    final total = team.memberIds.fold<int>(
      0,
      (sum, uid) => sum + getUserPoints(uid),
    );

    return total / team.memberIds.length;
  }

  List<Map<String, dynamic>> getIndividualRanking() {
    final ranking = _users
        .map(
          (user) => {
            'user': user,
            'points': getUserPoints(user.id),
            'votes': getUserVoteCount(user.id),
          },
        )
        .toList();

    ranking.sort((a, b) {
      final pointsCompare = (b['points'] as int).compareTo(a['points'] as int);

      if (pointsCompare != 0) return pointsCompare;

      return (b['votes'] as int).compareTo(a['votes'] as int);
    });

    return ranking;
  }

  List<Map<String, dynamic>> getTeamRanking() {
    final ranking = _teams
        .map(
          (team) => {
            'team': team,
            'points': getTeamPoints(team.id),
            'members': team.memberIds
                .map(
                  (id) => _users.firstWhere(
                    (user) => user.id == id,
                    orElse: () => const AppUser(
                      id: '',
                      name: '?',
                      avatar: '❓',
                    ),
                  ),
                )
                .toList(),
          },
        )
        .toList();

    ranking.sort(
      (a, b) => (b['points'] as double).compareTo(a['points'] as double),
    );

    return ranking;
  }


  // ─────────────────────────────────────────────
  // NIVEAU FOOT + BADGES SOCIAUX
  // ─────────────────────────────────────────────
  int getUserResolvedVoteCount(String userId) {
    final ids = _scoringMatchIds.isEmpty ? _results.keys.toSet() : _scoringMatchIds;
    return _results.keys.where((id) => ids.contains(id) && _votes.containsKey('${userId}__$id')).length;
  }

  int getUserCorrectCount(String userId) {
    final ids = _scoringMatchIds.isEmpty ? _results.keys.toSet() : _scoringMatchIds;
    return _results.entries.where((e) => ids.contains(e.key) && _votes['${userId}__${e.key}'] == e.value).length;
  }

  List<String> _recentResolvedMatchIds(String userId) {
    final ids = _scoringMatchIds.isEmpty ? _results.keys.toSet() : _scoringMatchIds;
    final out = _results.keys
        .where((id) => ids.contains(id) && _votes.containsKey('${userId}__$id'))
        .toList();
    out.sort((a,b) {
      final da=_voteUpdatedAt['${userId}__$a'] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db=_voteUpdatedAt['${userId}__$b'] ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return out.take(30).toList();
  }

  bool _isExactCorrect(String userId, String matchId) {
    final exact=_exactPredictions['${userId}__$matchId'];
    final score=_scores[matchId];
    return exact!=null && score!=null && exact.homeScore==score.homeScore && exact.awayScore==score.awayScore;
  }

  int getUserKnowledgeScore(String userId) {
    final recent = _recentResolvedMatchIds(userId);
    if (recent.isEmpty) return 50;
    final correct = recent.where((id) => _votes['${userId}__$id'] == _results[id]).length;
    final exact = recent.where((id) => _isExactCorrect(userId,id)).length;
    // Le score exact compte davantage sans permettre de monter juste en votant beaucoup.
    final weighted = correct + (exact * .45);
    return (((weighted + 2) / (recent.length + 4)) * 100).round().clamp(0,100).toInt();
  }

  int getUserCurrentStreak(String userId) {
    var streak=0;
    for (final id in _recentResolvedMatchIds(userId)) {
      if (_votes['${userId}__$id'] == _results[id]) { streak++; } else { break; }
    }
    return streak;
  }

  bool getUserGoodForm(String userId) {
    final recent=_recentResolvedMatchIds(userId);
    if (getUserCurrentStreak(userId)>=2) return true;
    final sample=recent.take(5).toList();
    if (sample.length<4) return false;
    final ok=sample.where((id)=>_votes['${userId}__$id']==_results[id]).length;
    return ok/sample.length>=.60;
  }

  String getAutoReputationBadge(String userId) {
    final played=getUserResolvedVoteCount(userId), score=getUserKnowledgeScore(userId);
    if (played<3) return 'AMATEUR';
    if (score<40) return 'FOOTIX';
    if (score<55) return 'AMATEUR';
    if (score<70) return 'CONNAISSEUR';
    if (score<85) return 'EXPERT';
    return 'ORACLE';
  }

  Map<String,int> reputationCountsFor(String targetUserId) {
    String? teamId;
    for (final u in _users) { if (u.id==targetUserId) { teamId=u.teamId; break; } }
    final counts=<String,int>{};
    for (final v in _reputationVotes.values) {
      if (v['targetUserId']==targetUserId && (teamId==null || v['teamId']==teamId)) {
        final b=v['badge']??''; if (b.isNotEmpty) counts[b]=(counts[b]??0)+1;
      }
    }
    return counts;
  }

  String reputationBadgeFor(String targetUserId) {
    final counts=reputationCountsFor(targetUserId);
    if (counts.isEmpty) return getAutoReputationBadge(targetUserId);
    final entries=counts.entries.toList()..sort((a,b){final c=b.value.compareTo(a.value); return c!=0?c:a.key.compareTo(b.key);});
    return entries.first.key;
  }

  Future<String?> castReputationVote(String targetUserId, String badge) async {
    final me=_currentUser, team=myTeam;
    const allowed={'FOOTIX','AMATEUR','CONNAISSEUR','EXPERT','ORACLE','VISIONNAIRE','SNIPER','CHAT NOIR'};
    if (me==null || team==null) return 'Équipe indisponible.';
    if (targetUserId==me.id) return 'Tu ne peux pas voter pour toi-même.';
    if (!team.memberIds.contains(targetUserId)) return 'Ce joueur ne fait pas partie de ton équipe.';
    if (!allowed.contains(badge)) return 'Badge invalide.';
    final id='${team.id}__${me.id}__$targetUserId';
    try {
      await _db.collection('reputationVotes').doc(id).set({
        'teamId':team.id,'voterId':me.id,'targetUserId':targetUserId,'badge':badge,'updatedAt':FieldValue.serverTimestamp(),
      },SetOptions(merge:true)).timeout(const Duration(seconds:8));
      return null;
    } catch(e) { debugPrint('castReputationVote error: $e'); return 'Vote badge impossible. Vérifie la connexion.'; }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  Future<String> _generateUniqueTeamCode() async {
    // Try once with a short server check. If Firestore is slow or unavailable,
    // we fall back to a locally-random code rather than chaining 20 timeouts
    // (which could keep the CRÉER button busy for 2+ minutes).
    for (int i = 0; i < 5; i++) {
      final code = _rand(6).toUpperCase();

      try {
        final exists = await _db
            .collection('teams')
            .where('code', isEqualTo: code)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 3));

        if (exists.docs.isEmpty) return code;
      } catch (e) {
        debugPrint(
          '_generateUniqueTeamCode: server check failed, using random code: $e',
        );
        return code;
      }
    }

    // Worst case: just use a timestamp-derived code.
    return '${DateTime.now().millisecondsSinceEpoch}'
        .substring(7, 13)
        .toUpperCase();
  }

  String _rand(int len) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();

    return List.generate(
      len,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }

  List<FootballMatch> get todayMatches {
    final today = DateTime.now();

    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _clubMatches
        .map(resolveMatch)
        .where((match) => match.localDate == todayStr && !match.isTBD)
        .toList();
  }

  List<FootballMatch> get upcomingMatches {
    final today = DateTime.now();

    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _clubMatches
        .map(resolveMatch)
        .where(
            (match) => match.localDate.compareTo(todayStr) > 0 && !match.isTBD)
        .take(5)
        .toList();
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _teamsSub?.cancel();
    _votesSub?.cancel();
    _resultsSub?.cancel();
    _goldenBootSub?.cancel();
    _matchesSub?.cancel();
    _reputationVotesSub?.cancel();

    super.dispose();
  }
}
