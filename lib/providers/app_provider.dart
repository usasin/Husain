import '../data/user_identity.dart';
import '../services/social_auth_service.dart';
import '../data/team_identity.dart';
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
import '../data/duel_selector.dart';
import '../data/teams_data.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/messaging_service.dart';

part 'app_provider_accounts.dart';

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

class AdminSyncResult {
  final bool ok;
  final int syncedMatches;
  final bool skipped;
  final String message;

  const AdminSyncResult({
    required this.ok,
    this.syncedMatches = 0,
    this.skipped = false,
    required this.message,
  });
}

class CompetitionSpecialty {
  final String competitionId;
  final int played;
  final int correct;
  final int score;
  final String level;

  const CompetitionSpecialty({
    required this.competitionId,
    required this.played,
    required this.correct,
    required this.score,
    required this.level,
  });

  int get accuracy => played == 0 ? 0 : ((correct * 100) / played).round();
  double get progress => (score.clamp(0, 100)) / 100.0;
}

class GameSeasonWindow {
  final int number;
  final DateTime start;
  final DateTime end;

  const GameSeasonWindow({
    required this.number,
    required this.start,
    required this.end,
  });

  int get daysRemaining {
    final now = DateTime.now();
    final endOfDay = DateTime(end.year, end.month, end.day);
    final today = DateTime(now.year, now.month, now.day);
    return endOfDay.difference(today).inDays.clamp(0, 9999).toInt();
  }
}

class GameDayRecap {
  final DateTime date;
  final int played;
  final int correct;
  final int exact;
  final int points;

  const GameDayRecap({
    required this.date,
    required this.played,
    required this.correct,
    required this.exact,
    required this.points,
  });
}

class AppProvider extends ChangeNotifier {
  // Compétitions librement sélectionnables + alertes personnalisables.
  AppProvider({FirebaseFirestore? firestore, fb_auth.FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db;
  final fb_auth.FirebaseAuth _auth;
  Future<void>? _signInFuture;

  // Stable stream instances: StreamBuilder must not receive a brand-new
  // snapshots() object on every provider rebuild, otherwise Firestore may
  // unsubscribe/re-subscribe and bill a fresh query snapshot.
  Stream<CommunitySettings>? _communitySettingsStreamCache;
  String? _teamChatStreamTeamId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _teamChatStreamCache;
  String? _teamPresenceStreamTeamId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _teamPresenceStreamCache;
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>
      _matchRoomStreamCache = {};
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>
      _matchRoomPresenceStreamCache = {};
  String? _supportStreamUid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _supportThreadStreamCache;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _adminSupportStreamCache;

  final _AccountState _account = _AccountState();
  void _notifyAccountChange() => notifyListeners();
  AppUser? _currentUser;
  List<AppUser> _users = [];
  List<AppTeam> _teams = [];
  Map<String, String> _votes = {};
  Map<String, Map<String, int>> _voteCountsByMatch = {};
  final Map<String, Map<String, int>> _communityAggregateCounts = {};
  Map<String, String> _results = {};
  Map<String, Map<String, String>> _reputationVotes = {};
  Map<String, MatchScore> _scores = {};
  Map<String, MatchScore> _exactPredictions = {};
  Map<String, DateTime> _voteUpdatedAt = {};
  Set<String> _scoringMatchIds = {};
  Map<String, DateTime> _scoringKickoffAt = {};
  Map<String, String> _scoringCompetitionIds = {};
  Map<String, String> _liveStatus = {};
  Map<String, List<String>> _resolvedTeams = {};
  List<FootballMatch> _clubMatches = [];
  Set<String> _halftimeChangedMatchIds = {};
  Set<String> _favoriteClubCodes = {};
  Set<String> _enabledCompetitionIds = kCompetitions.map((c) => c.id).toSet();
  Set<String> _blockedUserIds = {};
  Set<String>? _manualTodayDuelIds;
  String? _manualDuelDateKey;

  // BUILD75 cost hotfix: the app no longer keeps every season vote live on
  // every device. Normal sessions subscribe only to the current team (max 4
  // players). Global ranking/community data is loaded only when the user opens
  // the corresponding feature, then cached for the rest of the session.
  bool _rankingDataLoaded = false;
  bool _rankingDataLoading = false;
  String? _rankingLoadError;
  bool _goldenBootDataLoaded = false;
  bool _goldenBootDataLoading = false;
  bool _teamDirectoryLoaded = false;
  bool _teamDirectoryLoading = false;
  String _identityScopeSignature = '';
  String _liveVoteScopeSignature = '';
  Set<String> _scopedVoteKeys = <String>{};
  final Set<String> _communityLoadedMatchIds = <String>{};
  final Set<String> _communityLoadingMatchIds = <String>{};

  // BUILD76 scalable data layer: compact fixture manifests + local cache.
  static const String _fixtureCachePrefix = 'prono4_fixture_manifest_v1_';
  static const String _fixtureVersionPrefix = 'prono4_fixture_version_v1_';
  static const String _rankingCacheKey = 'prono4_public_ranking_v1';
  final Map<String, List<Map<String, dynamic>>> _fixtureRowsByCompetition = {};
  final Map<String, String> _fixtureVersions = {};
  bool _fixtureCacheRestored = false;
  bool _fixtureRefreshRunning = false;

  // BUILD78: self-healing bootstrap. The first device that discovers missing
  // shared data asks the backend to repair it once. A server-side lease makes
  // this safe even if several devices start at the same time.
  Future<bool>? _publicDataBootstrapFuture;
  DateTime? _lastPublicDataBootstrapAttempt;

  // Server-precomputed ranking snapshots.
  final Map<String, List<Map<String, dynamic>>> _precomputedIndividuals = {};
  final Map<String, List<Map<String, dynamic>>> _precomputedTeams = {};
  final Map<String, String> _precomputedBadgeByUser = {};
  int? _precomputedGameSeasonNumber;
  bool _usingPrecomputedRanking = false;
  bool _competitionRankingsReady = false;

  /// Le palmarès par championnat n'est affiché que si les agrégats du
  /// serveur sont disponibles (pas de classement partiel depuis le téléphone).
  bool get competitionRankingAvailable =>
      _usingPrecomputedRanking && _competitionRankingsReady;
  String _reputationScopeSignature = '';

  bool _adminMode = false; // true uniquement si users/{uid}.isAdmin == true
  bool _loaded = false;
  bool _loadingStarted = false;
  bool _voteRemindersEnabled = false;
  String _voteReminderScope = 'duels'; // duels | favorites | all
  bool _halftimeAlertsEnabled = false;
  int _scheduledReminderCount = 0;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _teamsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _votesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _goldenBootSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _fixtureManifestMetaSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reputationVotesSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _duelSelectionSub;
  Timer? _liveNotifyTimer;
  final Map<String, Map<String, String>> _goldenBoot = {};
  final Map<String, int> _goldenBootAggregateCounts = {};
  int _goldenBootAggregateTotal = 0;
  bool _goldenBootAggregateAvailable = false;

  AppUser? get currentUser => _currentUser;
  List<AppUser> get users => _users;
  List<AppTeam> get teams => _teams;
  Map<String, String> get votes => _votes;
  Map<String, String> get results => _results;
  Map<String, Map<String, String>> get reputationVotes => _reputationVotes;
  Map<String, MatchScore> get scores => _scores;
  MatchScore? getExactPrediction(String matchId, {String? userId}) {
    final uid = userId ?? _currentUser?.id;
    if (uid == null) return null;
    return _exactPredictions['${uid}__$matchId'];
  }

  List<FootballMatch> get matches => List.unmodifiable(_clubMatches);
  String? liveStatusFor(String matchId) => _liveStatus[matchId];
  bool isHalftime(String matchId) => _liveStatus[matchId] == 'PAUSED';

  Set<String> get favoriteClubCodes => Set.unmodifiable(_favoriteClubCodes);
  bool isFavoriteClub(String code) =>
      _favoriteClubCodes.contains(code.trim().toUpperCase());

  Set<String> get enabledCompetitionIds =>
      Set.unmodifiable(_enabledCompetitionIds);
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);
  bool isUserBlocked(String userId) => _blockedUserIds.contains(userId);
  bool isCompetitionEnabled(String competitionId) =>
      _enabledCompetitionIds.contains(competitionId.trim());

  List<CompetitionInfo> get enabledCompetitions => kCompetitions
      .where((competition) => _enabledCompetitionIds.contains(competition.id))
      .toList(growable: false);

  List<FootballMatch> get visibleMatches => _clubMatches
      .where((match) => _enabledCompetitionIds.contains(match.competitionId))
      .toList(growable: false);

  bool hasCurrentUserVoted(String matchId) {
    final uid = _currentUser?.id;
    return uid != null && _votes.containsKey('${uid}__$matchId');
  }

  void _rebuildVoteCounts() {
    final next = <String, Map<String, int>>{};
    for (final entry in _votes.entries) {
      final split = entry.key.indexOf('__');
      if (split < 0 || split + 2 >= entry.key.length) continue;
      final matchId = entry.key.substring(split + 2);
      // Before the global ranking data is explicitly requested, only expose
      // community percentages for matches that were loaded in full. This
      // avoids presenting the current team's partial sample as "community".
      if (!_rankingDataLoaded && !_communityLoadedMatchIds.contains(matchId)) {
        continue;
      }
      final row = next.putIfAbsent(
        matchId,
        () => {'HOME': 0, 'DRAW': 0, 'AWAY': 0},
      );
      if (row.containsKey(entry.value)) {
        row[entry.value] = row[entry.value]! + 1;
      }
    }
    _voteCountsByMatch = next;
  }

  Map<String, int> communityVoteCounts(String matchId) {
    final row = _communityAggregateCounts[matchId];
    if (row == null) return const {'HOME': 0, 'DRAW': 0, 'AWAY': 0};
    return Map<String, int>.from(row);
  }

  Map<String, double> communityVotePercentages(String matchId) {
    final counts = communityVoteCounts(matchId);
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const {'HOME': 0.0, 'DRAW': 0.0, 'AWAY': 0.0};
    return {
      'HOME': (counts['HOME'] ?? 0) / total,
      'DRAW': (counts['DRAW'] ?? 0) / total,
      'AWAY': (counts['AWAY'] ?? 0) / total,
    };
  }

  Future<void> toggleFavoriteClub(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;
    final next = Set<String>.from(_favoriteClubCodes);
    if (!next.add(clean)) next.remove(clean);
    _favoriteClubCodes = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'prono4_favorite_clubs_v1', next.toList()..sort());
    unawaited(MessagingService.instance.syncFavoriteClubTopics(next));
    if (_voteRemindersEnabled && _voteReminderScope == 'favorites') {
      unawaited(_refreshVoteReminders());
    }
    notifyListeners();
    unawaited(_saveCloudPreferences());
  }

  Future<bool> toggleCompetitionEnabled(String competitionId) async {
    final id = competitionId.trim();
    if (competitionById(id) == null) return false;

    final next = Set<String>.from(_enabledCompetitionIds);
    if (next.contains(id)) {
      // Toujours conserver au moins une compétition active.
      if (next.length <= 1) return false;
      next.remove(id);
    } else {
      next.add(id);
    }

    _enabledCompetitionIds = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'prono4_enabled_competitions_v1',
      next.toList(growable: false),
    );
    if (_voteRemindersEnabled) unawaited(_refreshVoteReminders());
    notifyListeners();
    return true;
  }

  Future<void> enableAllCompetitions() async {
    _enabledCompetitionIds =
        kCompetitions.map((competition) => competition.id).toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'prono4_enabled_competitions_v1',
      _enabledCompetitionIds.toList(growable: false),
    );
    if (_voteRemindersEnabled) unawaited(_refreshVoteReminders());
    notifyListeners();
  }

  Future<void> setEnabledCompetitions(Iterable<String> ids) async {
    final valid = ids
        .map((id) => id.trim())
        .where((id) => competitionById(id) != null)
        .toSet();
    if (valid.isEmpty) return;
    _enabledCompetitionIds = valid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'prono4_enabled_competitions_v1',
      valid.toList(growable: false),
    );
    if (_voteRemindersEnabled) unawaited(_refreshVoteReminders());
    notifyListeners();
    unawaited(_saveCloudPreferences());
  }

  List<Map<String, dynamic>> teamMatchPicks(String matchId) {
    final team = myTeam;
    if (team == null) return const [];
    final rows = <Map<String, dynamic>>[];
    for (final uid in team.memberIds) {
      AppUser? user;
      for (final u in _users) {
        if (u.id == uid) {
          user = u;
          break;
        }
      }
      if (user == null) continue;
      final key = '${uid}__$matchId';
      rows.add({
        'user': user,
        'prediction': _votes[key],
        'exact': _exactPredictions[key],
      });
    }
    return rows;
  }

  int getUserMatchPoints(String userId, String matchId) {
    final result = _results[matchId];
    if (result == null || result.isEmpty) return 0;
    final key = '${userId}__$matchId';
    var points = _votes[key] == result ? 3 : 0;
    final exact = _exactPredictions[key];
    final score = _scores[matchId];
    if (exact != null &&
        score != null &&
        exact.homeScore == score.homeScore &&
        exact.awayScore == score.awayScore) {
      points += 2;
    }
    return points;
  }

  List<Map<String, dynamic>> getUserExactHistory(String userId) {
    final prefix = '${userId}__';
    final rows = <Map<String, dynamic>>[];
    for (final entry in _exactPredictions.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final matchId = entry.key.substring(prefix.length);
      final match = matchById(matchId);
      rows.add({
        'match': match,
        'prediction': entry.value,
        'score': _scores[matchId],
        'finished': _results.containsKey(matchId)
      });
    }
    rows.sort((a, b) {
      final first = a['match'] as FootballMatch?;
      final second = b['match'] as FootballMatch?;
      if (first == null) return second == null ? 0 : 1;
      if (second == null) return -1;
      return second.dateTime.compareTo(first.dateTime);
    });
    return rows;
  }

  List<Map<String, dynamic>> getUserRecentExactWins(
    String userId, {
    int limit = 3,
    Duration maxAge = const Duration(days: 7),
  }) {
    final now = DateTime.now();
    final rows = <Map<String, dynamic>>[];
    for (final matchId in _recentResolvedMatchIds(userId)) {
      if (!_isExactCorrect(userId, matchId)) continue;
      final match = matchById(matchId);
      final score = _scores[matchId];
      if (match == null || score == null) continue;
      final age = now.difference(match.dateTime);
      if (!age.isNegative && age > maxAge) continue;
      rows.add({
        'match': match,
        'score': score,
        'points': getUserMatchPoints(userId, matchId),
      });
      if (rows.length >= limit) break;
    }
    return rows;
  }

  List<Map<String, dynamic>> teamMatchRanking(String matchId) {
    final team = myTeam;
    if (team == null || !_results.containsKey(matchId)) return const [];
    final rows = <Map<String, dynamic>>[];
    for (final uid in team.memberIds) {
      AppUser? user;
      for (final u in _users) {
        if (u.id == uid) {
          user = u;
          break;
        }
      }
      if (user == null) continue;
      rows.add({'user': user, 'points': getUserMatchPoints(uid, matchId)});
    }
    rows.sort((a, b) {
      final byPoints = (b['points'] as int).compareTo(a['points'] as int);
      if (byPoints != 0) return byPoints;
      return (a['user'] as AppUser).name.compareTo((b['user'] as AppUser).name);
    });
    return rows;
  }

  FootballMatch? matchById(String matchId) {
    for (final m in _clubMatches) if (m.id == matchId) return m;
    return null;
  }

  List<String> recentClubForm(String clubCode,
      {String? excludeMatchId, int take = 5}) {
    final code = clubCode.trim().toUpperCase();
    final played = _clubMatches.where((m) {
      if (m.id == excludeMatchId) return false;
      if (!_scores.containsKey(m.id)) return false;
      return m.homeCode == code || m.awayCode == code;
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final out = <String>[];
    for (final m in played) {
      final score = _scores[m.id]!;
      final isHome = m.homeCode == code;
      final gf = isHome ? score.homeScore : score.awayScore;
      final ga = isHome ? score.awayScore : score.homeScore;
      out.add(gf > ga
          ? 'W'
          : gf == ga
              ? 'D'
              : 'L');
      if (out.length >= take) break;
    }
    return out;
  }

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
      homeCrestUrl:
          (data['homeCrestUrl'] ?? data['homeCrest'] ?? '').toString().trim(),
      awayCrestUrl:
          (data['awayCrestUrl'] ?? data['awayCrest'] ?? '').toString().trim(),
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

  FootballMatch? _clubMatchFromManifestRow(Map<String, dynamic> data) {
    if ((data['status'] ?? '').toString().toUpperCase() == 'CANCELLED') {
      return null;
    }
    final competitionId = (data['competitionId'] ?? '').toString().trim();
    if (competitionId.isEmpty || competitionById(competitionId) == null) {
      return null;
    }
    final kickoffMs = data['kickoffAtMs'];
    if (kickoffMs is! num) return null;
    final utc = DateTime.fromMillisecondsSinceEpoch(
      kickoffMs.toInt(),
      isUtc: true,
    );
    final local = utc.toLocal();
    final homeCode = (data['homeCode'] ?? '').toString().trim().toUpperCase();
    final awayCode = (data['awayCode'] ?? '').toString().trim().toUpperCase();
    final id = (data['id'] ?? '').toString().trim();
    if (id.isEmpty || homeCode.isEmpty || awayCode.isEmpty) return null;
    final date = '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return FootballMatch(
      id: id,
      homeCode: homeCode,
      awayCode: awayCode,
      competitionId: competitionId,
      homeName: (data['homeName'] ?? homeCode).toString().trim(),
      awayName: (data['awayName'] ?? awayCode).toString().trim(),
      homeCrestUrl: (data['homeCrestUrl'] ?? '').toString().trim(),
      awayCrestUrl: (data['awayCrestUrl'] ?? '').toString().trim(),
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

  void _applyFixtureManifestCache() {
    final allRows = _fixtureRowsByCompetition.values
        .expand((rows) => rows)
        .toList(growable: false);
    final matches = allRows
        .map(_clubMatchFromManifestRow)
        .whereType<FootballMatch>()
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    _clubMatches = matches;
    _scoringMatchIds = matches.map((m) => m.id).toSet();
    _scoringKickoffAt = {for (final m in matches) m.id: m.dateTime};
    _scoringCompetitionIds = {
      for (final m in matches) m.id: m.competitionId,
    };

    final nextResults = <String, String>{};
    final nextScores = <String, MatchScore>{};
    final nextLiveStatus = <String, String>{};
    for (final row in allRows) {
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final result = (row['result'] ?? '').toString().toUpperCase();
      if (result == 'HOME' || result == 'DRAW' || result == 'AWAY') {
        nextResults[id] = result;
      }
      final home = row['homeScore'];
      final away = row['awayScore'];
      if (home is num && away is num) {
        nextScores[id] = MatchScore(
          homeScore: home.toInt(),
          awayScore: away.toInt(),
        );
      }
      final status = (row['status'] ?? '').toString().trim();
      if (status.isNotEmpty) nextLiveStatus[id] = status;
    }
    _results = nextResults;
    _scores = nextScores;
    _liveStatus = nextLiveStatus;
  }

  Future<void> _restoreFixtureManifestCache() async {
    if (_fixtureCacheRestored) return;
    _fixtureCacheRestored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final competition in kCompetitions) {
        final raw = prefs.getString('$_fixtureCachePrefix${competition.id}');
        final version =
            prefs.getString('$_fixtureVersionPrefix${competition.id}');
        if (version != null && version.isNotEmpty) {
          _fixtureVersions[competition.id] = version;
        }
        if (raw == null || raw.isEmpty) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;
        _fixtureRowsByCompetition[competition.id] = decoded
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }
      if (_fixtureRowsByCompetition.isNotEmpty) {
        _applyFixtureManifestCache();
      }
    } catch (e) {
      debugPrint('fixture cache restore error: $e');
    }
  }

  Future<void> _refreshFixtureManifestsFromMeta(
    Map<String, dynamic>? meta, {
    bool force = false,
  }) async {
    if (_fixtureRefreshRunning) return;
    final rawVersions = meta?['versions'];
    if (rawVersions is! Map) return;
    final remoteVersions = <String, String>{
      for (final entry in rawVersions.entries)
        entry.key.toString(): entry.value.toString(),
    };
    final wanted = kCompetitions.where((competition) {
      final remote = remoteVersions[competition.id];
      if (remote == null || remote.isEmpty) return false;
      return force ||
          _fixtureVersions[competition.id] != remote ||
          !_fixtureRowsByCompetition.containsKey(competition.id);
    }).toList(growable: false);
    if (wanted.isEmpty) return;

    _fixtureRefreshRunning = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final docs = await Future.wait(
        wanted.map((competition) =>
            _db.collection('fixtureManifests').doc(competition.id).get()),
      ).timeout(const Duration(seconds: 12));
      for (var i = 0; i < docs.length; i++) {
        final snapshot = docs[i];
        final competition = wanted[i];
        final data = snapshot.data();
        if (data == null || data['rows'] is! List) continue;
        final rows = (data['rows'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
        final version =
            (data['version'] ?? remoteVersions[competition.id] ?? '')
                .toString();
        _fixtureRowsByCompetition[competition.id] = rows;
        _fixtureVersions[competition.id] = version;
        await prefs.setString(
          '$_fixtureCachePrefix${competition.id}',
          jsonEncode(rows),
        );
        await prefs.setString(
          '$_fixtureVersionPrefix${competition.id}',
          version,
        );
      }
      _applyFixtureManifestCache();
      if (_voteRemindersEnabled) unawaited(_refreshVoteReminders());
      _notifyLiveData();
    } catch (e) {
      debugPrint('fixture manifest refresh error: $e');
    } finally {
      _fixtureRefreshRunning = false;
    }
  }

  void _listenFixtureManifest() {
    _fixtureManifestMetaSub?.cancel();
    _fixtureManifestMetaSub =
        _db.collection('system').doc('fixtureManifestMeta').snapshots().listen(
      (snapshot) {
        final data = snapshot.data();
        if (data != null) {
          unawaited(_refreshFixtureManifestsFromMeta(data));
        } else {
          // BUILD83: clients never trigger a server rebuild. The scheduled
          // backend owns bootstrap/repair; the app only uses the bounded
          // legacy window as a temporary display fallback.
          if (_fixtureRowsByCompetition.isEmpty) {
            unawaited(_loadLegacyFixturesOnce());
          }
        }
      },
      onError: (e) => debugPrint('fixture manifest listener error: $e'),
    );
  }

  Future<void> _loadLegacyFixturesOnce() async {
    if (_fixtureRowsByCompetition.isNotEmpty) return;
    try {
      // Migration safety net only: never scan the full season/results
      // collection. Keep the window small until BUILD76 manifests are seeded.
      final matchesSnap = await _activeMatchesQuery()
          .get()
          .timeout(const Duration(seconds: 10));
      _setClubMatches(matchesSnap.docs);
      _scoringMatchIds = matchesSnap.docs.map((d) => d.id).toSet();
      _scoringKickoffAt = {
        for (final d in matchesSnap.docs)
          if (d.data()['kickoffAt'] is Timestamp)
            d.id: (d.data()['kickoffAt'] as Timestamp).toDate().toLocal(),
      };
      _scoringCompetitionIds = {
        for (final d in matchesSnap.docs)
          if ((d.data()['competitionId'] ?? '').toString().isNotEmpty)
            d.id: (d.data()['competitionId'] ?? '').toString(),
      };

      final resultDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final ids = matchesSnap.docs.map((d) => d.id).toList(growable: false);
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, min(i + 30, ids.length));
        if (chunk.isEmpty) continue;
        final snap = await _db
            .collection('results')
            .where(FieldPath.documentId, whereIn: chunk)
            .get()
            .timeout(const Duration(seconds: 8));
        resultDocs.addAll(snap.docs);
      }
      _results = {
        for (final doc in resultDocs)
          if ((doc.data()['result'] ?? '').toString().isNotEmpty)
            doc.id: (doc.data()['result'] ?? '').toString(),
      };
      _liveStatus = {
        for (final doc in resultDocs)
          if ((doc.data()['liveStatus'] ?? '').toString().isNotEmpty)
            doc.id: (doc.data()['liveStatus'] ?? '').toString(),
      };
      _scores = {
        for (final doc in resultDocs)
          if (doc.data()['homeScore'] is num && doc.data()['awayScore'] is num)
            doc.id: MatchScore(
              homeScore: (doc.data()['homeScore'] as num).toInt(),
              awayScore: (doc.data()['awayScore'] as num).toInt(),
            ),
      };
      _resolvedTeams = _readResolvedTeams(resultDocs);
      _notifyLiveData();
    } catch (e) {
      debugPrint('legacy fixture bootstrap error: $e');
    }
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
    return _communitySettingsStreamCache ??= _db
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
    return null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> teamChatStream() {
    final teamId = _currentUser?.teamId ?? '_';
    if (_teamChatStreamCache == null || _teamChatStreamTeamId != teamId) {
      _teamChatStreamTeamId = teamId;
      _teamChatStreamCache = _db
          .collection('teamChats')
          .doc(teamId)
          .collection('messages')
          .orderBy('createdAt')
          .limitToLast(50)
          .snapshots();
    }
    return _teamChatStreamCache!;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> teamChatPresenceStream() {
    final teamId = _currentUser?.teamId ?? '_';
    if (_teamPresenceStreamCache == null ||
        _teamPresenceStreamTeamId != teamId) {
      _teamPresenceStreamTeamId = teamId;
      _teamPresenceStreamCache = _db
          .collection('teamChats')
          .doc(teamId)
          .collection('presence')
          .orderBy('activeUntil', descending: true)
          .limit(30)
          .snapshots();
    }
    return _teamPresenceStreamCache!;
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
    final candidates = visibleMatches
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
    final upcoming = visibleMatches
        .map(resolveMatch)
        .where((m) => !m.isTBD && !results.containsKey(m.id))
        .where((m) => m.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> matchRoomStream(String matchId) {
    return _matchRoomStreamCache.putIfAbsent(
      matchId,
      () => _db
          .collection('matchRooms')
          .doc(matchId)
          .collection('messages')
          .orderBy('createdAt')
          .limitToLast(80)
          .snapshots(),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> matchRoomPresenceStream(
      String matchId) {
    return _matchRoomPresenceStreamCache.putIfAbsent(
      matchId,
      () => _db
          .collection('matchRooms')
          .doc(matchId)
          .collection('presence')
          .orderBy('activeUntil', descending: true)
          .limit(50)
          .snapshots(),
    );
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
    if (_supportThreadStreamCache == null || _supportStreamUid != uid) {
      _supportStreamUid = uid;
      _supportThreadStreamCache = _db
          .collection('support')
          .where('userId', isEqualTo: uid)
          .limit(200)
          .snapshots();
    }
    return _supportThreadStreamCache!;
  }

  /// Flux de tous les messages (page admin), les plus récents d'abord.
  Stream<QuerySnapshot<Map<String, dynamic>>> adminSupportStream() {
    return _adminSupportStreamCache ??= _db
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
  String get voteReminderScope => _voteReminderScope;
  bool get halftimeAlertsEnabled => _halftimeAlertsEnabled;
  bool get voteRemindersSupported => NotificationService.instance.isSupported;
  int get scheduledReminderCount => _scheduledReminderCount;
  bool get rankingDataLoaded => _rankingDataLoaded;
  bool get rankingDataLoading => _rankingDataLoading;
  String? get rankingLoadError => _rankingLoadError;
  bool get goldenBootDataLoaded => _goldenBootDataLoaded;
  bool get teamDirectoryLoaded => _teamDirectoryLoaded;

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
  static const String _kVoteReminderScopeKey = 'prono4_vote_reminder_scope_v1';
  static const String _kHalftimeAlertsKey = 'mundial_halftime_alerts_v1';
  static const String _kBlockedUsersKey = 'prono4_blocked_users_v1';

  Future<void> _restoreCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _voteRemindersEnabled = prefs.getBool(_kVoteRemindersKey) ?? false;
      final savedReminderScope = prefs.getString(_kVoteReminderScopeKey);
      _voteReminderScope =
          const {'duels', 'favorites', 'all'}.contains(savedReminderScope)
              ? savedReminderScope!
              : 'duels';
      _halftimeAlertsEnabled = prefs.getBool(_kHalftimeAlertsKey) ?? false;
      _favoriteClubCodes =
          (prefs.getStringList('prono4_favorite_clubs_v1') ?? const <String>[])
              .map((e) => e.toUpperCase())
              .toSet();
      _blockedUserIds =
          (prefs.getStringList(_kBlockedUsersKey) ?? const <String>[]).toSet();
      final savedCompetitions =
          prefs.getStringList('prono4_enabled_competitions_v1');
      if (savedCompetitions != null) {
        final valid = savedCompetitions
            .where((id) => competitionById(id) != null)
            .toSet();
        if (valid.isNotEmpty) _enabledCompetitionIds = valid;
      }
      final pending = prefs.getString(_AccountState.pendingKey);
      if (pending != null)
        _account.pending =
            Map<String, dynamic>.from(jsonDecode(pending) as Map);
      final raw = prefs.getString(_kCachedUserKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _currentUser = AppUser(
        id: (data['id'] ?? '').toString(),
        name: (data['name'] ?? 'Joueur').toString(),
        avatar: (data['avatar'] ?? '⚽').toString(),
        teamId: data['teamId'] as String?,
        isAdmin: data['isAdmin'] == true,
        recoveryCode: (data['recoveryCode'] ?? '').toString(),
        acceptChallenges: data['acceptChallenges'] != false,
      );
      _account.avatars[_currentUser!.id] = _currentUser!.avatar;
      _adminMode = _currentUser!.isAdmin;
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
            'recoveryCode': u.recoveryCode,
            'acceptChallenges': u.acceptChallenges,
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
    await _restoreFixtureManifestCache();
    // Réapplique les abonnements aux équipes favorites dès le démarrage.
    unawaited(
        MessagingService.instance.syncFavoriteClubTopics(_favoriteClubCodes));
    if (_currentUser != null) {
      // L'UI peut déjà sortir de l'onboarding.
      _loaded = true;
      notifyListeners();
    }

    // 2) Firebase Auth en best-effort
    try {
      await _ensureSignedIn().timeout(const Duration(seconds: 6));
      if (hasConnectedAccount) await _loadConnectedProfile();
      await _repairCachedProfileIdentityAndRecoveryCode();
      // Récupère immédiatement users/{uid}.isAdmin == true. On ne dépend plus
      // du chargement complet de toute la collection users pour réafficher
      // les outils d'administration.
      await refreshAdminAccess().timeout(const Duration(seconds: 5));
      await _loadBlockedUsersFromCloud();
    } catch (e) {
      debugPrint('Mundial load auth error: $e');
    }

    // 3) BUILD76 : calendriers et résultats viennent du cache local puis du
    // manifeste compact. Aucun scan global matches/results au démarrage.
    await _repairCachedProfileIdentityAndRecoveryCode();

    // BUILD75: aucune synchronisation serveur automatique au démarrage.
    // Le bouton de synchronisation admin reste disponible dans Réglages.

    // 4) Reprogrammer les rappels locaux déjà activés.
    if (_voteRemindersEnabled) {
      unawaited(_refreshVoteReminders());
    }

    // 5) Listeners live (best-effort)
    try {
      _listenFirestore();
    } catch (e) {
      debugPrint('Mundial listeners error: $e');
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _ensureSignedIn() {
    if (_auth.currentUser != null) return Future.value();
    return _signInFuture ??= _auth
        .signInAnonymously()
        .timeout(const Duration(seconds: 8))
        .then<void>((_) {})
        .whenComplete(() => _signInFuture = null);
  }

  Future<void> _repairCachedProfileIdentityAndRecoveryCode() =>
      _restoreAndSyncProfile();

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

  Query<Map<String, dynamic>> _activeReputationVotesQuery() {
    final teamId = _currentUser?.teamId;
    return _db.collection('reputationVotes').where(
          'teamId',
          isEqualTo:
              (teamId != null && teamId.isNotEmpty) ? teamId : '__none__',
        );
  }

  void _listenReputationVotes({bool force = false}) {
    final signature = _currentUser?.teamId ?? '';
    if (!force &&
        signature == _reputationScopeSignature &&
        _reputationVotesSub != null) {
      return;
    }
    _reputationScopeSignature = signature;
    _reputationVotesSub?.cancel();
    _reputationVotesSub = _activeReputationVotesQuery().snapshots().listen(
      (snapshot) {
        _reputationVotes = {
          for (final d in snapshot.docs)
            d.id: {
              'teamId': (d.data()['teamId'] ?? '').toString(),
              'voterId': (d.data()['voterId'] ?? '').toString(),
              'targetUserId': (d.data()['targetUserId'] ?? '').toString(),
              'badge': (d.data()['badge'] ?? '').toString(),
              'updatedAtMs': d.data()['updatedAt'] is Timestamp
                  ? (d.data()['updatedAt'] as Timestamp)
                      .millisecondsSinceEpoch
                      .toString()
                  : '0',
            },
        };
        _notifyLiveData();
      },
      onError: (e) => debugPrint('reputationVotes listener error: $e'),
    );
  }

  Query<Map<String, dynamic>> _scopedUsersQuery() {
    final uid = _currentUser?.id;
    final teamId = _currentUser?.teamId;
    if (teamId != null && teamId.isNotEmpty) {
      return _db.collection('users').where('teamId', isEqualTo: teamId);
    }
    return _db.collection('users').where(
          FieldPath.documentId,
          isEqualTo: (uid != null && uid.isNotEmpty) ? uid : '__none__',
        );
  }

  Query<Map<String, dynamic>> _scopedTeamsQuery() {
    final teamId = _currentUser?.teamId;
    return _db.collection('teams').where(
          FieldPath.documentId,
          isEqualTo:
              (teamId != null && teamId.isNotEmpty) ? teamId : '__none__',
        );
  }

  String _currentIdentityScopeSignature() =>
      '${_currentUser?.id ?? ''}|${_currentUser?.teamId ?? ''}';

  void _patchPrecomputedIdentity(List<AppUser> scoped) {
    if (scoped.isEmpty || !_usingPrecomputedRanking) return;
    final byId = <String, AppUser>{for (final user in scoped) user.id: user};
    for (final rows in _precomputedIndividuals.values) {
      for (final row in rows) {
        final existing = row['user'];
        if (existing is! AppUser) continue;
        final live = byId[existing.id];
        if (live == null) continue;
        row['user'] = existing.copyWith(
          name: live.name.trim().isNotEmpty ? live.name : existing.name,
          avatar: live.avatar,
          teamId: live.teamId ?? existing.teamId,
          isAdmin: live.isAdmin,
          recoveryCode: live.recoveryCode,
          acceptChallenges: live.acceptChallenges,
        );
      }
    }
    for (final rows in _precomputedTeams.values) {
      for (final row in rows) {
        final members = row['members'];
        if (members is! List<AppUser>) continue;
        row['members'] = members.map((existing) {
          final live = byId[existing.id];
          if (live == null) return existing;
          return existing.copyWith(
            name: live.name.trim().isNotEmpty ? live.name : existing.name,
            avatar: live.avatar,
            teamId: live.teamId ?? existing.teamId,
            isAdmin: live.isAdmin,
            recoveryCode: live.recoveryCode,
            acceptChallenges: live.acceptChallenges,
          );
        }).toList(growable: false);
      }
    }
  }

  void _mergeScopedUsers(List<AppUser> scoped) {
    if (!_rankingDataLoaded) {
      _users = scoped;
      return;
    }
    final byId = <String, AppUser>{for (final user in _users) user.id: user};
    for (final user in scoped) {
      byId[user.id] = user;
    }
    _users = byId.values.toList(growable: false);
    _patchPrecomputedIdentity(scoped);
  }

  void _patchPrecomputedTeamIdentity(List<AppTeam> scoped) {
    if (scoped.isEmpty || !_usingPrecomputedRanking) return;
    final byId = {for (final team in scoped) team.id: team};
    for (final rows in _precomputedTeams.values) {
      for (final row in rows) {
        final existing = row['team'];
        if (existing is AppTeam && byId.containsKey(existing.id)) {
          row['team'] = byId[existing.id];
        }
      }
    }
  }

  void _mergeScopedTeams(List<AppTeam> scoped) {
    if (!_rankingDataLoaded && !_teamDirectoryLoaded) {
      _teams = scoped;
      _patchPrecomputedTeamIdentity(scoped);
      return;
    }
    final byId = <String, AppTeam>{for (final team in _teams) team.id: team};
    for (final team in scoped) {
      byId[team.id] = team;
    }
    _teams = byId.values.toList(growable: false);
    _patchPrecomputedTeamIdentity(scoped);
  }

  void _listenScopedIdentity({bool force = false}) {
    final signature = _currentIdentityScopeSignature();
    if (!force &&
        signature == _identityScopeSignature &&
        _usersSub != null &&
        _teamsSub != null) {
      return;
    }
    _identityScopeSignature = signature;
    _usersSub?.cancel();
    _teamsSub?.cancel();

    _usersSub = _scopedUsersQuery().snapshots().listen(
      (snapshot) {
        final beforeTeamId = _currentUser?.teamId;
        final scoped = snapshot.docs
            .where((doc) => doc.data()['isArchived'] != true)
            .map(_userFromDoc)
            .toList(growable: false);
        _mergeScopedUsers(scoped);
        _refreshCurrentUserFromUsers();
        _notifyLiveData();

        if (beforeTeamId != _currentUser?.teamId) {
          scheduleMicrotask(() {
            _listenScopedIdentity(force: true);
            _listenScopedVotes(force: true);
            _listenReputationVotes(force: true);
          });
        }
      },
      onError: (e) => debugPrint('scoped users listener error: $e'),
    );

    _teamsSub = _scopedTeamsQuery().snapshots().listen(
      (snapshot) {
        _mergeScopedTeams(
          snapshot.docs.map(_teamFromDoc).toList(growable: false),
        );
        _listenScopedVotes();
        _notifyLiveData();
      },
      onError: (e) => debugPrint('scoped teams listener error: $e'),
    );
  }

  Query<Map<String, dynamic>> _scopedVotesQuery() {
    final uid = _currentUser?.id;
    final team = myTeam;
    final ids = <String>{
      if (uid != null && uid.isNotEmpty) uid,
      if (team != null) ...team.memberIds.where((id) => id.isNotEmpty),
    }.take(10).toList(growable: false);

    if (ids.isEmpty) {
      // Auth/profile is still being restored. This query intentionally returns
      // nothing instead of falling back to the full votes collection.
      return _db.collection('votes').where('userId', isEqualTo: '__none__');
    }
    if (ids.length == 1) {
      return _db.collection('votes').where('userId', isEqualTo: ids.first);
    }
    return _db.collection('votes').where('userId', whereIn: ids);
  }

  String _currentVoteScopeSignature() {
    final uid = _currentUser?.id;
    final team = myTeam;
    final ids = <String>{
      if (uid != null && uid.isNotEmpty) uid,
      if (team != null) ...team.memberIds.where((id) => id.isNotEmpty),
    }.toList()
      ..sort();
    return ids.join('|');
  }

  void _applyVoteDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool replaceScoped,
  }) {
    final nextVotes = Map<String, String>.from(_votes);
    final nextExact = Map<String, MatchScore>.from(_exactPredictions);
    final nextUpdatedAt = Map<String, DateTime>.from(_voteUpdatedAt);

    if (replaceScoped) {
      for (final key in _scopedVoteKeys) {
        nextVotes.remove(key);
        nextExact.remove(key);
        nextUpdatedAt.remove(key);
      }
      _scopedVoteKeys = docs.map((doc) => doc.id).toSet();
    }

    for (final doc in docs) {
      final data = doc.data();
      final prediction = (data['prediction'] ?? '').toString();
      if (prediction.isNotEmpty) {
        nextVotes[doc.id] = prediction;
      } else {
        nextVotes.remove(doc.id);
      }

      final h = data['exactHome'];
      final a = data['exactAway'];
      if (h is num && a is num) {
        nextExact[doc.id] = MatchScore(
          homeScore: h.toInt(),
          awayScore: a.toInt(),
        );
      } else {
        nextExact.remove(doc.id);
      }

      final updatedAt = data['updatedAt'];
      if (updatedAt is Timestamp) {
        nextUpdatedAt[doc.id] = updatedAt.toDate();
      }
    }

    _votes = nextVotes;
    _exactPredictions = nextExact;
    _voteUpdatedAt = nextUpdatedAt;
    _rebuildVoteCounts();
  }

  void _listenScopedVotes({bool force = false}) {
    final signature = _currentVoteScopeSignature();
    if (!force && signature == _liveVoteScopeSignature && _votesSub != null) {
      return;
    }
    _liveVoteScopeSignature = signature;
    _votesSub?.cancel();
    _votesSub = _scopedVotesQuery().snapshots().listen(
      (snapshot) {
        final uid = _currentUser?.id;
        final beforeOwn = uid == null
            ? <String>{}
            : _votes.keys.where((k) => k.startsWith('${uid}__')).toSet();

        _applyVoteDocs(snapshot.docs, replaceScoped: true);

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
        _notifyLiveData();
      },
      onError: (e) => debugPrint('scoped votes listener error: $e'),
    );
  }

  Future<void> ensureCommunityVotesForMatch(String matchId) async {
    if (matchId.isEmpty ||
        _communityLoadedMatchIds.contains(matchId) ||
        _communityLoadingMatchIds.contains(matchId)) {
      return;
    }
    _communityLoadingMatchIds.add(matchId);
    try {
      final aggregate = await _db
          .collection('matchAggregates')
          .doc(matchId)
          .get()
          .timeout(const Duration(seconds: 6));
      final data = aggregate.data();
      if (data != null) {
        _communityAggregateCounts[matchId] = {
          'HOME': data['HOME'] is num ? (data['HOME'] as num).toInt() : 0,
          'DRAW': data['DRAW'] is num ? (data['DRAW'] as num).toInt() : 0,
          'AWAY': data['AWAY'] is num ? (data['AWAY'] as num).toInt() : 0,
        };
        _communityLoadedMatchIds.add(matchId);
        notifyListeners();
        return;
      }

      // Cost-safe migration behavior: never fall back to downloading every
      // vote for the match. BUILD78 auto-bootstrap backfills historical aggregates.
      _communityAggregateCounts[matchId] = const {
        'HOME': 0,
        'DRAW': 0,
        'AWAY': 0,
      };
      _communityLoadedMatchIds.add(matchId);
      notifyListeners();
    } catch (e) {
      debugPrint('community aggregate load error for $matchId: $e');
    } finally {
      _communityLoadingMatchIds.remove(matchId);
    }
  }

  String _rankingPeriodKey(Duration? period) {
    if (period == null) return 'general';
    if (period.inDays <= 7) return 'week';
    if (period.inDays <= 30) return 'month';
    return 'general';
  }

  Future<bool> _loadPrecomputedRankingSnapshots() async {
    const ids = ['general', 'week', 'month', 'gameSeason'];
    Map<String, Map<String, dynamic>> payloads = {};

    try {
      final snapshots = await Future.wait(
        ids.map((id) => _db.collection('rankingSnapshots').doc(id).get()),
      ).timeout(const Duration(seconds: 10));

      for (var i = 0; i < snapshots.length; i++) {
        final data = snapshots[i].data();
        if (data == null) continue;
        payloads[ids[i]] = <String, dynamic>{
          'schemaVersion': data['schemaVersion'] is num
              ? (data['schemaVersion'] as num).toInt()
              : 0,
          'competitionRankingsVersion': data['competitionRankingsVersion'] is num
              ? (data['competitionRankingsVersion'] as num).toInt()
              : 0,
          'individuals':
              data['individuals'] is List ? data['individuals'] : const [],
          'teams': data['teams'] is List ? data['teams'] : const [],
          'gameSeasonNumber': data['gameSeasonNumber'],
        };
      }

      // A public ranking is valid as soon as the general snapshot exists.
      // Week/month/gameSeason may legitimately be empty but their tabs must
      // never disappear.
      if (!payloads.containsKey('general') ||
          (payloads['general']?['schemaVersion'] as int? ?? 0) < 90) {
        // BUILD82: snapshots 76-81 could exist but contain a stale directory
        // (for example only one old team). Invalidate them once so the
        // automatic backend rebuilds the complete ranking.
        payloads = {};
      } else {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_rankingCacheKey, jsonEncode(payloads));
        } catch (e) {
          debugPrint('ranking cache write skipped: $e');
        }
      }
    } catch (e) {
      debugPrint('precomputed ranking network load error: $e');
    }

    // BUILD81: keep the last known public ranking usable across temporary
    // backend/network failures. This is a tiny local cache, not a Firestore
    // fallback scan, so it cannot recreate the old read-cost problem.
    if (!payloads.containsKey('general')) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_rankingCacheKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final cached = <String, Map<String, dynamic>>{};
            for (final entry in decoded.entries) {
              if (entry.value is Map) {
                cached[entry.key.toString()] =
                    Map<String, dynamic>.from(entry.value as Map);
              }
            }
            if (cached.containsKey('general') &&
                (cached['general']?['schemaVersion'] as int? ?? 0) >= 90) {
              payloads = cached;
            }
          }
        }
      } catch (e) {
        debugPrint('ranking cache restore skipped: $e');
      }
    }

    if (!payloads.containsKey('general')) return false;

    try {
      final individuals = <String, List<Map<String, dynamic>>>{};
      final teams = <String, List<Map<String, dynamic>>>{};
      final mergedUsers = <String, AppUser>{for (final u in _users) u.id: u};
      if (_currentUser != null) mergedUsers[_currentUser!.id] = _currentUser!;
      final mergedTeams = <String, AppTeam>{for (final t in _teams) t.id: t};
      _precomputedBadgeByUser.clear();

      for (final id in ids) {
        final data = payloads[id];
        if (data == null) {
          individuals[id] = const <Map<String, dynamic>>[];
          teams[id] = const <Map<String, dynamic>>[];
          continue;
        }
        if (id == 'gameSeason' && data['gameSeasonNumber'] is num) {
          _precomputedGameSeasonNumber =
              (data['gameSeasonNumber'] as num).toInt();
        }

        final personRows = <Map<String, dynamic>>[];
        final rawPeople = data['individuals'];
        if (rawPeople is List) {
          for (final raw in rawPeople.whereType<Map>()) {
            final row = Map<String, dynamic>.from(raw);
            final uid = (row['id'] ?? '').toString();
            if (uid.isEmpty) continue;
            final snapshotUser = AppUser(
              id: uid,
              name: (row['name'] ?? 'Joueur').toString(),
              avatar: (row['avatar'] ?? '⚽').toString(),
              teamId: row['teamId']?.toString(),
            );
            final liveUser = mergedUsers[uid];
            final user = liveUser == null
                ? snapshotUser
                : snapshotUser.copyWith(
                    name: liveUser.name.trim().isNotEmpty
                        ? liveUser.name
                        : snapshotUser.name,
                    avatar: liveUser.avatar.startsWith('img:')
                        ? liveUser.avatar
                        : snapshotUser.avatar,
                    teamId: liveUser.teamId ?? snapshotUser.teamId,
                    isAdmin: liveUser.isAdmin,
                    recoveryCode: liveUser.recoveryCode,
                    acceptChallenges: liveUser.acceptChallenges,
                  );
            final resolved = userWithKnownAvatar(user, _account.avatars[uid]);
            mergedUsers[uid] = resolved;
            final badge = (row['badge'] ?? '').toString();
            if (badge.isNotEmpty) _precomputedBadgeByUser[uid] = badge;
            personRows.add({
              'user': resolved,
              'points':
                  row['points'] is num ? (row['points'] as num).toInt() : 0,
              'votes': row['votes'] is num ? (row['votes'] as num).toInt() : 0,
              'resolvedVotes': row['resolvedVotes'] is num
                  ? (row['resolvedVotes'] as num).toInt()
                  : 0,
              'knowledgeScore': row['knowledgeScore'],
              'correct':
                  row['correct'] is num ? (row['correct'] as num).toInt() : 0,
              'byCompetition': row['byCompetition'] is Map
                  ? Map<String, dynamic>.from(row['byCompetition'] as Map)
                  : <String, dynamic>{},
            });
          }
        }
        individuals[id] = personRows;

        final teamRows = <Map<String, dynamic>>[];
        final rawTeams = data['teams'];
        if (rawTeams is List) {
          for (final raw in rawTeams.whereType<Map>()) {
            final row = Map<String, dynamic>.from(raw);
            final teamId = (row['id'] ?? '').toString();
            if (teamId.isEmpty) continue;
            final memberIds = row['memberIds'] is List
                ? (row['memberIds'] as List).map((e) => e.toString()).toList()
                : <String>[];
            final team = teamWithLiveImage(
                AppTeam(
                  id: teamId,
                  name: (row['name'] ?? 'Équipe').toString(),
                  code: (row['code'] ?? '').toString(),
                  memberIds: memberIds,
                  createdBy: (row['createdBy'] ?? '').toString(),
                  icon: (row['icon'] ?? '').toString(),
                ),
                mergedTeams[teamId]);
            mergedTeams[teamId] = team;
            final memberRows = <AppUser>[];
            if (row['members'] is List) {
              for (final rawMember
                  in (row['members'] as List).whereType<Map>()) {
                final member = Map<String, dynamic>.from(rawMember);
                final uid = (member['id'] ?? '').toString();
                if (uid.isEmpty) continue;
                final user = mergedUsers[uid] ??
                    AppUser(
                      id: uid,
                      name: (member['name'] ?? '?').toString(),
                      avatar: (member['avatar'] ?? '❓').toString(),
                      teamId: member['teamId']?.toString() ?? teamId,
                    );
                mergedUsers[uid] = user;
                memberRows.add(user);
              }
            }
            teamRows.add({
              'team': team,
              'points': row['points'] is num
                  ? (row['points'] as num).toDouble()
                  : 0.0,
              'periodVotes': row['periodVotes'] is num
                  ? (row['periodVotes'] as num).toInt()
                  : 0,
              'members': memberRows,
            });
          }
        }
        teams[id] = teamRows;
      }

      _competitionRankingsReady =
          ((payloads['general']?['competitionRankingsVersion'] as int?) ?? 0) >= 1;
      _precomputedIndividuals
        ..clear()
        ..addAll(individuals);
      _precomputedTeams
        ..clear()
        ..addAll(teams);
      _users = mergedUsers.values.toList(growable: false);
      _teams = mergedTeams.values.toList(growable: false);
      _usingPrecomputedRanking = true;
      return true;
    } catch (e) {
      debugPrint('precomputed ranking parse error: $e');
      return false;
    }
  }

  Future<void> ensureRankingDataLoaded({bool force = false}) async {
    if (_rankingDataLoading || (_rankingDataLoaded && !force)) return;
    _rankingDataLoading = true;
    _rankingLoadError = null;
    notifyListeners();
    try {
      await _ensureSignedIn();
      final loaded = await _loadPrecomputedRankingSnapshots();

      // BUILD83: opening the ranking NEVER launches server work. Public
      // snapshots are maintained automatically by scheduled/incremental
      // backend functions, independent of the number of app users.

      if (!loaded) {
        _rankingLoadError =
            'Classement temporairement indisponible. Réessaie dans quelques instants.';
        if (!_usingPrecomputedRanking) _rankingDataLoaded = false;

        // BUILD80: IMPORTANT — no timer/retry loop here. A missing backend or
        // an initialization error must never make the UI alternate between
        // loading/error states every few seconds. A new attempt happens only
        // when the user reopens the screen or presses Retry.
        return;
      }
      _rankingDataLoaded = true;
    } catch (e) {
      _rankingLoadError = 'Classement indisponible. Vérifie la connexion.';
      debugPrint('ranking load error: $e');
    } finally {
      _rankingDataLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureTeamDirectoryLoaded({bool force = false}) async {
    if (_teamDirectoryLoading || (_teamDirectoryLoaded && !force)) return;
    _teamDirectoryLoading = true;
    try {
      final snapshot = await _db
          .collection('teams')
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 8));
      final directory = snapshot.docs.map(_teamFromDoc).toList(growable: false);
      final byId = <String, AppTeam>{for (final team in _teams) team.id: team};
      for (final team in directory) {
        byId[team.id] = team;
      }
      _teams = byId.values.toList(growable: false);
      _patchPrecomputedTeamIdentity(directory);
      _teamDirectoryLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('team directory load error: $e');
    } finally {
      _teamDirectoryLoading = false;
    }
  }

  Future<void> ensureGoldenBootDataLoaded({bool force = false}) async {
    if (_goldenBootDataLoading || (_goldenBootDataLoaded && !force)) return;
    _goldenBootDataLoading = true;
    try {
      final uid = _currentUser?.id;
      final reads = await Future.wait([
        if (uid != null && uid.isNotEmpty)
          _db.collection('goldenBootVotes').doc(uid).get()
        else
          _db.collection('goldenBootVotes').doc('__none__').get(),
        _db.collection('system').doc('goldenBootAggregate').get(),
      ]).timeout(const Duration(seconds: 8));
      final own = reads[0] as DocumentSnapshot<Map<String, dynamic>>;
      var aggregate = reads[1] as DocumentSnapshot<Map<String, dynamic>>;

      _goldenBoot.clear();
      if (uid != null && own.exists) {
        final data = own.data() ?? const <String, dynamic>{};
        _goldenBoot[uid] = {
          'name': (data['name'] ?? '').toString(),
          'code': (data['code'] ?? '').toString(),
        };
      }

      // BUILD83: no user action can trigger a costly backend rebuild.
      // Missing shared aggregates are repaired by the server scheduler.

      final aggregateData = aggregate.data();
      if (aggregateData != null && aggregateData['counts'] is Map) {
        _goldenBootAggregateCounts
          ..clear()
          ..addEntries(
            (aggregateData['counts'] as Map).entries.map(
                  (entry) => MapEntry(
                    entry.key.toString(),
                    entry.value is num ? (entry.value as num).toInt() : 0,
                  ),
                ),
          );
        _goldenBootAggregateTotal = aggregateData['total'] is num
            ? (aggregateData['total'] as num).toInt()
            : _goldenBootAggregateCounts.values.fold<int>(0, (a, b) => a + b);
        _goldenBootAggregateAvailable = true;
      } else {
        // Safe degraded mode: keep only the current user's own vote. Never
        // download the entire goldenBootVotes collection on a phone.
        _goldenBootAggregateCounts.clear();
        _goldenBootAggregateTotal = _goldenBoot.isEmpty ? 0 : 1;
        _goldenBootAggregateAvailable = true;
      }
      _goldenBootDataLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('goldenBoot load error: $e');
    } finally {
      _goldenBootDataLoading = false;
    }
  }

  void _notifyLiveData() {
    // A server sync can update dozens of documents almost simultaneously.
    // Coalescing those callbacks avoids rebuilding the whole app once per
    // document while preserving a very responsive UI.
    if (_liveNotifyTimer?.isActive == true) return;
    _liveNotifyTimer = Timer(const Duration(milliseconds: 80), notifyListeners);
  }

  void _listenFirestore() {
    _usersSub?.cancel();
    _teamsSub?.cancel();
    _votesSub?.cancel();
    _goldenBootSub?.cancel();
    _fixtureManifestMetaSub?.cancel();
    _reputationVotesSub?.cancel();
    _duelSelectionSub?.cancel();

    final duelDateKey = _localDateKey(DateTime.now());
    _manualDuelDateKey = duelDateKey;
    final duelSelectionRef =
        _db.collection('dynamicContents').doc('duel_selection_$duelDateKey');
    _duelSelectionSub = duelSelectionRef.snapshots().listen(
      (snapshot) {
        final data = snapshot.data();
        final hasOverride = data != null &&
            data['enabled'] != false &&
            data['selectedMatchIds'] is List;
        _manualTodayDuelIds = hasOverride
            ? (data!['selectedMatchIds'] as List)
                .map((e) => e.toString())
                .toSet()
            : null;
        _notifyLiveData();
      },
      onError: (e) => debugPrint('duel selection listener error: $e'),
    );

    // BUILD76: one metadata listener replaces hundreds of match/result docs.
    _listenFixtureManifest();
    _listenScopedIdentity(force: true);
    _listenReputationVotes(force: true);

    // Golden Boot is loaded on demand through one aggregate + the user's vote.
    _listenScopedVotes(force: true);
  }

  // ─────────────────────────────────────────────
  // CONVERSIONS FIRESTORE
  // ─────────────────────────────────────────────

  AppUser _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final user = userFromProfileData(doc.id, doc.data() ?? {},
        cached: _currentUser, pending: _account.pending);
    _account.avatars[user.id] = user.avatar;
    return user;
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

  Future<String?> setTeamImageBase64(String imageB64) async {
    final t = myTeam;
    if (t == null) return 'Aucune équipe.';
    try {
      await _db.collection('teams').doc(t.id).set(
        {
          'imageB64': imageB64,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 10));

      // Keep the local team model in sync immediately. Ranking uses _teams,
      // so without this it could temporarily fall back to the 2-letter badge
      // until the Firestore snapshot arrived.
      final index = _teams.indexWhere((team) => team.id == t.id);
      if (index >= 0) {
        final updated = _teams[index].copyWith(imageB64: imageB64);
        final next = List<AppTeam>.from(_teams);
        next[index] = updated;
        _teams = next;
        _patchPrecomputedTeamIdentity([updated]);
        notifyListeners();
      }
      return null;
    } catch (e) {
      debugPrint('setTeamImageBase64 error: $e');
      return 'Modification impossible. Vérifie ta connexion.';
    }
  }

  Map<String, String>? get myGoldenBootPick {
    final uid = _currentUser?.id;
    if (uid == null) return null;
    final pick = _goldenBoot[uid];
    if (pick == null || (pick['name'] ?? '').isEmpty) return null;
    return pick;
  }

  int get goldenBootVoteCount => _goldenBootAggregateAvailable
      ? _goldenBootAggregateTotal
      : _goldenBoot.length;

  Map<String, int> goldenBootCounts() {
    if (_goldenBootAggregateAvailable) {
      return Map<String, int>.from(_goldenBootAggregateCounts);
    }
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
      final previousName = _goldenBoot[uid]?['name'] ?? '';
      await _db.collection('goldenBootVotes').doc(uid).set({
        'uid': uid,
        'name': name,
        'code': code,
        'votedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
      _goldenBoot[uid] = {'name': name, 'code': code};
      if (_goldenBootAggregateAvailable && previousName != name) {
        if (previousName.isNotEmpty) {
          final left = (_goldenBootAggregateCounts[previousName] ?? 1) - 1;
          if (left <= 0) {
            _goldenBootAggregateCounts.remove(previousName);
          } else {
            _goldenBootAggregateCounts[previousName] = left;
          }
        } else {
          _goldenBootAggregateTotal += 1;
        }
        _goldenBootAggregateCounts[name] =
            (_goldenBootAggregateCounts[name] ?? 0) + 1;
      }
      _goldenBootDataLoaded = true;
      notifyListeners();
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
      imageB64: (data['imageB64'] ?? '').toString(),
      isLocked: data['isLocked'] == true,
    );
  }

  void _refreshCurrentUserFromUsers() {
    final authUid = firebaseUid;
    final profileUid = _currentUser?.id;

    // Un profil récupéré peut avoir un id différent de l'UID anonyme courant.
    // On privilégie donc d'abord l'id du profil, puis l'UID Firebase.
    final candidateIds = <String>[
      if (profileUid != null && profileUid.isNotEmpty) profileUid,
      if (authUid != null && authUid.isNotEmpty && authUid != profileUid)
        authUid,
    ];
    if (candidateIds.isEmpty) return;

    for (final id in candidateIds) {
      for (final user in _users) {
        if (user.id == id) {
          _currentUser = user;
          _adminMode = user.isAdmin;
          _cacheCurrentUser();
          return;
        }
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
    unawaited(_saveCloudPreferences());
    return true;
  }

  Future<void> setVoteReminderScope(String scope) async {
    if (!const {'duels', 'favorites', 'all'}.contains(scope)) return;
    _voteReminderScope = scope;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVoteReminderScopeKey, scope);
    if (_voteRemindersEnabled) await _refreshVoteReminders();
    notifyListeners();
    unawaited(_saveCloudPreferences());
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
    unawaited(_saveCloudPreferences());
    return true;
  }

  Future<void> sendTestVoteReminder() async {
    if (!_voteRemindersEnabled) return;
    await NotificationService.instance.showTestNotification();
  }

  String _localDateKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Future<List<FootballMatch>> _matchesForReminderScope() async {
    final upcoming = visibleMatches
        .where((match) => !match.isTBD && !match.hasStarted)
        .toList(growable: false);

    if (_voteReminderScope == 'all') return upcoming;

    if (_voteReminderScope == 'favorites') {
      if (_favoriteClubCodes.isEmpty) return const <FootballMatch>[];
      return upcoming
          .where((match) =>
              _favoriteClubCodes.contains(match.homeCode.toUpperCase()) ||
              _favoriteClubCodes.contains(match.awayCode.toUpperCase()))
          .toList(growable: false);
    }

    // Mode recommandé : uniquement les Duels. On reprend exactement la logique
    // de l'accueil, avec la sélection admin du jour si elle existe.
    final grouped = <String, List<FootballMatch>>{};
    for (final match in upcoming) {
      grouped
          .putIfAbsent(_localDateKey(match.dateTime), () => <FootballMatch>[])
          .add(match);
    }

    final selected = <FootballMatch>[];
    final todayKey = _localDateKey(DateTime.now());
    for (final entry in grouped.entries) {
      if (entry.key == todayKey) {
        try {
          final snap = await _db
              .collection('dynamicContents')
              .doc('duel_selection_${entry.key}')
              .get();
          final data = snap.data();
          final newSelection = data != null &&
              data['enabled'] != false &&
              data['selectedMatchIds'] is List;
          final legacySelection =
              data?['manual'] == true && data?['matchIds'] is List;
          final ids = newSelection
              ? (data!['selectedMatchIds'] as List)
                  .map((e) => e.toString())
                  .toSet()
              : legacySelection
                  ? (data!['matchIds'] as List).map((e) => e.toString()).toSet()
                  : <String>{};
          if (newSelection || legacySelection) {
            selected.addAll(entry.value.where((m) => ids.contains(m.id)));
            continue;
          }
        } catch (e) {
          debugPrint('Lecture duels pour rappels impossible: $e');
        }
      }
      selected.addAll(selectAutomaticDuels(
        entry.value,
        _enabledCompetitionIds,
        isFavoriteClub: isFavoriteClub,
      ));
    }
    return selected;
  }

  Future<void> _refreshVoteReminders() async {
    if (!_voteRemindersEnabled || _currentUser == null) return;
    try {
      final uid = _currentUser!.id;
      final votedMatchIds = _votes.keys
          .where((key) => key.startsWith('${uid}__'))
          .map((key) => key.substring('${uid}__'.length))
          .toSet();
      final reminderMatches = await _matchesForReminderScope();
      _scheduledReminderCount =
          await NotificationService.instance.scheduleVoteReminders(
        matches: reminderMatches,
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

    if (hasConnectedAccount) {
      final existing = await _db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      if (existing.exists) {
        _currentUser = _userFromDoc(existing);
        await _cacheCurrentUser();
        _listenScopedIdentity(force: true);
        _listenScopedVotes(force: true);
        notifyListeners();
        return;
      }
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
        'acceptChallenges': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Mundial: user $uid synced to Firestore.');
    } catch (e) {
      debugPrint('Mundial: user $uid Firestore sync deferred: $e');
    }
  }

  Future<void> setAcceptChallenges(bool enabled) async {
    final user = _currentUser;
    if (user == null) return;

    final next = user.copyWith(acceptChallenges: enabled);
    _currentUser = next;
    _users = _users.map((x) => x.id == next.id ? next : x).toList();
    await _cacheCurrentUser();
    notifyListeners();

    try {
      await _db.collection('users').doc(next.id).set({
        'acceptChallenges': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Mundial: acceptChallenges sync deferred: $e');
    }
  }

  Future<String?> updateUser({String? name, String? avatar}) =>
      _updateProfile(name: name, avatar: avatar);

  Future<String?> blockUser(String userId) async {
    final clean = userId.trim();
    if (clean.isEmpty) return 'Profil invalide.';
    if (clean == _currentUser?.id) return 'Tu ne peux pas te bloquer toi-même.';

    _blockedUserIds = {..._blockedUserIds, clean};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kBlockedUsersKey, _blockedUserIds.toList()..sort());
    notifyListeners();
    unawaited(_syncBlockedUsers());
    return null;
  }

  Future<void> unblockUser(String userId) async {
    final next = Set<String>.from(_blockedUserIds)..remove(userId.trim());
    _blockedUserIds = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kBlockedUsersKey, next.toList()..sort());
    notifyListeners();
    unawaited(_syncBlockedUsers());
  }

  Future<void> _syncBlockedUsers() async {
    final uid = firebaseUid;
    final me = _currentUser;
    if (uid == null || me == null || me.id != uid) return;
    try {
      await _db.collection('userSettings').doc(uid).set({
        'blockedUserIds': _blockedUserIds.toList()..sort(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('Mundial: blocked users sync deferred: $e');
    }
  }

  Future<void> _loadBlockedUsersFromCloud() async {
    final uid = firebaseUid;
    if (uid == null || (_currentUser != null && _currentUser!.id != uid))
      return;
    try {
      final snap = await _db
          .collection('userSettings')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      await _restoreCloudPreferences(snap.data());
      final raw = snap.data()?['blockedUserIds'];
      if (raw is! List) return;
      _blockedUserIds = {
        ..._blockedUserIds,
        ...raw.map((e) => e.toString()).where((e) => e.isNotEmpty),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _kBlockedUsersKey, _blockedUserIds.toList()..sort());
      notifyListeners();
    } catch (e) {
      debugPrint('Mundial: blocked users cloud load deferred: $e');
    }
  }

  Future<String?> deleteCurrentProfile() async {
    final me = _currentUser;
    if (me == null) return null;

    final authUser = _auth.currentUser;
    final isServerProfile = authUser != null && authUser.uid == me.id;

    if (isServerProfile) {
      try {
        final token = await authUser.getIdToken(true);
        if (token == null || token.isEmpty) {
          return 'Connexion impossible. Réessaie avant de supprimer le profil.';
        }
        final response = await http
            .post(
              Uri.parse(
                'https://europe-west1-mundial2026-ibab-01.cloudfunctions.net/deleteMyProfile',
              ),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(<String, dynamic>{'data': <String, dynamic>{}}),
            )
            .timeout(const Duration(seconds: 120));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          String? message;
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded['error'] is Map) {
              message = (decoded['error']['message'] ?? '').toString();
            }
          } catch (_) {}
          return message?.isNotEmpty == true
              ? message
              : 'Suppression impossible pour le moment. Réessaie avec Internet.';
        }
      } on TimeoutException {
        return 'La suppression prend trop de temps. Réessaie avec une connexion stable.';
      } catch (e) {
        debugPrint('deleteCurrentProfile error: $e');
        return 'Suppression impossible pour le moment. Réessaie avec Internet.';
      }
    }

    // Profil purement local (créé sans Auth) : il n'existe aucune donnée
    // distante à supprimer. Pour un profil synchronisé, le serveur a déjà
    // confirmé la suppression avant d'arriver ici.
    try {
      await _auth.signOut();
    } catch (_) {}

    final oldId = me.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCachedUserKey);
    await prefs.remove(_AccountState.pendingKey);
    _account.pending = null;

    _currentUser = null;
    _adminMode = false;
    _users = _users.where((u) => u.id != oldId).toList();
    _votes.removeWhere((key, _) => key.startsWith('${oldId}__'));
    _exactPredictions.removeWhere((key, _) => key.startsWith('${oldId}__'));
    _voteUpdatedAt.removeWhere((key, _) => key.startsWith('${oldId}__'));
    _rebuildVoteCounts();
    notifyListeners();
    return null;
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
        'isLocked': false,
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
      _listenScopedIdentity(force: true);
      _listenScopedVotes(force: true);

      notifyListeners();

      return team;
    } catch (e) {
      debugPrint('createTeam error: $e');
      return null;
    }
  }

  /// A request never grants membership. A current member must review it.
  final Map<String, Stream<List<Map<String, dynamic>>>> _pendingTeamJoinRequestStreams = {};

  Stream<List<Map<String, dynamic>>> pendingTeamJoinRequests(String teamId) {
    if (myTeam?.id != teamId) return Stream.value(const []);
    return _pendingTeamJoinRequestStreams.putIfAbsent(teamId, () =>
      _db.collection('teams').doc(teamId).collection('joinRequests')
        .where('status', isEqualTo: 'pending')
        .limit(30).snapshots().map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'userId': doc.id})
            .toList(growable: false)));
  }

  Future<String?> requestTeamMembershipById(String teamId) async {
    final user = _currentUser;
    if (user == null || firebaseUid == null) return 'Connectez-vous pour envoyer une demande.';
    if (user.teamId != null && user.teamId!.isNotEmpty) return 'Vous appartenez déjà à une équipe.';
    if (teamId.isEmpty) return 'Équipe introuvable.';
    try {
      final teamRef = _db.collection('teams').doc(teamId);
      final requestRef = teamRef.collection('joinRequests').doc(user.id);
      String? error;
      await _db.runTransaction((tx) async {
        final teamDoc = await tx.get(teamRef);
        final requestDoc = await tx.get(requestRef);
        if (!teamDoc.exists) { error = 'Équipe introuvable.'; return; }
        final data = teamDoc.data() ?? <String, dynamic>{};
        final members = List<String>.from(data['memberIds'] ?? const []);
        if (data['isLocked'] == true) { error = 'Cette équipe est verrouillée.'; return; }
        if (members.length >= 4) { error = 'Cette équipe est complète (4 joueurs).'; return; }
        if (members.contains(user.id)) { error = 'Vous êtes déjà membre.'; return; }
        if (requestDoc.data()?['status'] == 'pending') {
          error = 'Votre demande est déjà en attente.'; return;
        }
        tx.set(requestRef, {
          'userId': user.id,
          'authUid': firebaseUid,
          'name': user.name,
          'avatar': user.avatar,
          'status': 'pending',
          'requestedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }).timeout(const Duration(seconds: 8));
      return error;
    } catch (e) {
      debugPrint('requestTeamMembershipById error: $e');
      return 'Demande impossible. Vérifiez votre connexion.';
    }
  }

  Future<String?> reviewTeamJoinRequest(String teamId, String userId, {required bool approve}) async {
    final actor = _currentUser;
    if (actor == null || myTeam?.id != teamId) return 'Vous ne faites pas partie de cette équipe.';
    try {
      final teamRef = _db.collection('teams').doc(teamId);
      final userRef = _db.collection('users').doc(userId);
      final requestRef = teamRef.collection('joinRequests').doc(userId);
      String? error;
      await _db.runTransaction((tx) async {
        // Firestore requires all reads before the first write.
        final teamDoc = await tx.get(teamRef);
        final requestDoc = await tx.get(requestRef);
        final userDoc = approve ? await tx.get(userRef) : null;
        final team = teamDoc.data() ?? <String, dynamic>{};
        final members = List<String>.from(team['memberIds'] ?? const []);
        if (!members.contains(actor.id)) { error = 'Vous ne faites plus partie de cette équipe.'; return; }
        if (!requestDoc.exists || requestDoc.data()?['status'] != 'pending') {
          error = 'Cette demande a déjà été traitée.'; return;
        }
        if (approve) {
          if (members.length >= 4) { error = 'Équipe complète (4 joueurs).'; return; }
          if (!userDoc!.exists) { error = 'Profil du demandeur introuvable.'; return; }
          final userData = userDoc.data() ?? <String, dynamic>{};
          final currentTeam = (userData['teamId'] ?? '').toString();
          if (currentTeam.isNotEmpty) { error = 'Ce joueur appartient déjà à une équipe.'; return; }
          tx.update(teamRef, {
            'memberIds': FieldValue.arrayUnion([userId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(userRef, {
            'teamId': teamId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        tx.update(requestRef, {
          'status': approve ? 'accepted' : 'rejected',
          'reviewedBy': actor.id,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
      }).timeout(const Duration(seconds: 8));
      return error;
    } catch (e) {
      debugPrint('reviewTeamJoinRequest error: $e');
      return 'Décision non enregistrée. Vérifiez votre connexion.';
    }
  }

  Future<String?> renameMyTeam(String value) async {
    final team = myTeam;
    final user = _currentUser;
    final name = value.trim();
    if (team == null || user == null || !team.memberIds.contains(user.id)) {
      return 'Réservé aux membres de cette équipe.';
    }
    if (name.length < 3 || name.length > 28) return 'Nom : entre 3 et 28 caractères.';
    try {
      await _db.collection('teams').doc(team.id).update({
        'name': name, 'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('renameMyTeam error: $e');
      return 'Impossible de renommer cette équipe.';
    }
  }

  Future<String?> setMyTeamLocked(bool locked) async {
    final team = myTeam;
    if (team == null || team.createdBy != _currentUser?.id) {
      return 'Seul le créateur peut verrouiller cette équipe.';
    }
    try {
      await _db.collection('teams').doc(team.id).update({
        'isLocked': locked, 'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('setMyTeamLocked error: $e');
      return 'Impossible de modifier le verrouillage.';
    }
  }

  /// Compatibility with the existing invitation-code screen: request only.
  Future<String?> joinTeam(String code) async {
    if (_currentUser == null) return 'Vous devez d’abord créer votre profil.';
    if (_currentUser!.teamId != null) return 'Vous êtes déjà dans une équipe.';
    final upper = code.trim().toUpperCase();
    if (upper.length < 4) return 'Code invalide.';
    try {
      final found = await _db.collection('teams')
          .where('code', isEqualTo: upper).limit(1).get()
          .timeout(const Duration(seconds: 8));
      if (found.docs.isEmpty) return 'Code invalide — équipe introuvable.';
      return requestTeamMembershipById(found.docs.first.id);
    } catch (e) {
      debugPrint('joinTeam request error: $e');
      return 'Demande impossible. Vérifiez votre connexion.';
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
      _listenScopedIdentity(force: true);
      _listenScopedVotes(force: true);
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
    _rebuildVoteCounts();
    final exactNow = Map<String, MatchScore>.from(_exactPredictions)
      ..remove(key);
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
      _rebuildVoteCounts();
      if (previousExact != null) {
        _exactPredictions = {..._exactPredictions, key: previousExact};
      }
      notifyListeners();
      return 'Vote impossible. Vérifiez la connexion ou demandez à l’administrateur de synchroniser les horaires.';
    }
  }

  Future<String?> castExactScore(String matchId, int home, int away) async {
    if (_currentUser == null) return 'Profil utilisateur indisponible.';
    if (home < 0 || away < 0 || home > 20 || away > 20)
      return 'Score invalide.';
    FootballMatch? match;
    for (final item in _clubMatches) {
      if (item.id == matchId) {
        match = resolveMatch(item);
        break;
      }
    }
    if (match == null || match.isTBD) return 'Ce match n’est pas disponible.';
    if (match.hasStarted) return 'Pronostic fermé : le match a déjà commencé.';
    final prediction = home > away
        ? Prediction.home
        : (away > home ? Prediction.away : Prediction.draw);
    if (prediction == Prediction.draw && !match.allowsDraw)
      return 'Le nul n’est pas proposé pour ce match.';
    final key = '${_currentUser!.id}__$matchId';
    final previous = _votes[key];
    final previousExact = _exactPredictions[key];
    _votes = {..._votes, key: prediction.key};
    _rebuildVoteCounts();
    _exactPredictions = {
      ..._exactPredictions,
      key: MatchScore(homeScore: home, awayScore: away)
    };
    notifyListeners();
    try {
      await _db.collection('votes').doc(key).set({
        'userId': _currentUser!.id,
        'matchId': matchId,
        'teamId': _currentUser!.teamId,
        'prediction': prediction.key,
        'exactHome': home,
        'exactAway': away,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
      if (_voteRemindersEnabled) {
        await NotificationService.instance.cancelReminderForMatch(matchId);
        unawaited(_refreshVoteReminders());
      }
      return null;
    } catch (e) {
      final v = Map<String, String>.from(_votes);
      if (previous == null) {
        v.remove(key);
      } else {
        v[key] = previous;
      }
      _votes = v;
      _rebuildVoteCounts();
      final ex = Map<String, MatchScore>.from(_exactPredictions);
      if (previousExact == null) {
        ex.remove(key);
      } else {
        ex[key] = previousExact;
      }
      _exactPredictions = ex;
      notifyListeners();
      return 'Score exact impossible. Vérifie la connexion.';
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

  String _callableErrorMessage(Map<String, dynamic>? payload, String fallback) {
    final rawError = payload?['error'];
    if (rawError is Map) {
      final error = Map<String, dynamic>.from(rawError);
      final message = error['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return fallback;
  }

  Future<bool> _ensurePublicDataReady() async {
    final running = _publicDataBootstrapFuture;
    if (running != null) return running;

    final now = DateTime.now();
    final last = _lastPublicDataBootstrapAttempt;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return false;
    }
    _lastPublicDataBootstrapAttempt = now;

    final future = _runPublicDataBootstrapRequest();
    _publicDataBootstrapFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_publicDataBootstrapFuture, future)) {
        _publicDataBootstrapFuture = null;
      }
    }
  }

  Future<bool> _runPublicDataBootstrapRequest() async {
    try {
      await _ensureSignedIn().timeout(const Duration(seconds: 10));
      final authUser = _auth.currentUser;
      final token = await authUser?.getIdToken(true);
      if (authUser == null || token == null || token.isEmpty) return false;

      final response = await http
          .post(
            Uri.parse(
              'https://europe-west1-mundial2026-ibab-01.cloudfunctions.net/ensurePublicDataReady',
            ),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, dynamic>{'data': <String, dynamic>{}}),
          )
          .timeout(const Duration(seconds: 300));

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        payload = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'ensurePublicDataReady HTTP ${response.statusCode}: ${response.body}',
        );
        return false;
      }

      final raw = payload?['result'] ?? payload?['data'];
      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      var ready = data['ready'] == true;

      // Another phone may already own the server-side bootstrap lease. In
      // that rare migration case, wait on the tiny status document instead
      // of launching another expensive sync.
      if (!ready && data['initializing'] == true) {
        for (final delay in const <Duration>[
          Duration(seconds: 3),
          Duration(seconds: 7),
          Duration(seconds: 12),
        ]) {
          await Future<void>.delayed(delay);
          final status = await _db
              .collection('system')
              .doc('publicDataBootstrap')
              .get()
              .timeout(const Duration(seconds: 6));
          if (status.data()?['state'] == 'ready') {
            ready = true;
            break;
          }
          if (status.data()?['state'] == 'error') break;
        }
      }

      if (!ready) return false;

      // Pull the freshly-created manifest immediately; the listener remains
      // the normal update path afterwards.
      try {
        final meta = await _db
            .collection('system')
            .doc('fixtureManifestMeta')
            .get()
            .timeout(const Duration(seconds: 8));
        if (meta.exists) {
          await _refreshFixtureManifestsFromMeta(
            meta.data() ?? const <String, dynamic>{},
            force: true,
          );
        }
      } catch (e) {
        debugPrint('BUILD78 manifest refresh deferred: $e');
      }
      return true;
    } on TimeoutException {
      debugPrint('BUILD78 public data bootstrap timeout');
      return false;
    } catch (e) {
      debugPrint('BUILD78 public data bootstrap error: $e');
      return false;
    }
  }

  Future<AdminSyncResult> syncMatchesToFirestore() async {
    if (!_adminMode) {
      return const AdminSyncResult(
        ok: false,
        message: 'Accès administrateur non actif sur ce profil.',
      );
    }

    try {
      await _ensureSignedIn().timeout(const Duration(seconds: 10));
      final authUser = _auth.currentUser;
      final token = await authUser?.getIdToken(true);
      if (authUser == null || token == null || token.isEmpty) {
        return const AdminSyncResult(
          ok: false,
          message: 'Connexion Firebase impossible.',
        );
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

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        payload = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _callableErrorMessage(
          payload,
          'Synchronisation impossible (HTTP ${response.statusCode}).',
        );
        debugPrint(
            'syncMatchesToFirestore HTTP ${response.statusCode}: ${response.body}');
        return AdminSyncResult(ok: false, message: message);
      }

      final raw = payload?['result'] ?? payload?['data'];
      if (raw is! Map) {
        return const AdminSyncResult(
          ok: false,
          message: 'Réponse serveur invalide.',
        );
      }

      final data = Map<String, dynamic>.from(raw);
      final synced = data['syncedMatches'] is num
          ? (data['syncedMatches'] as num).toInt()
          : 0;
      final skipped = data['skipped'] == true;
      final competitions = data['syncedCompetitions'] is List
          ? (data['syncedCompetitions'] as List).length
          : 0;
      final manifestsChanged = data['fixtureManifestChanged'] is num
          ? (data['fixtureManifestChanged'] as num).toInt()
          : 0;

      // BUILD77: rafraîchir explicitement les manifests après la synchro au
      // lieu d'attendre uniquement le listener Firestore.
      try {
        final meta =
            await _db.collection('system').doc('fixtureManifestMeta').get();
        if (meta.exists) {
          await _refreshFixtureManifestsFromMeta(
              meta.data() ?? const <String, dynamic>{});
        }
      } catch (e) {
        debugPrint('fixture manifest immediate refresh deferred: $e');
      }

      _rankingLoadError = null;
      _rankingDataLoaded = false;
      await ensureRankingDataLoaded(force: true);

      final message = skipped
          ? 'Calendriers déjà synchronisés récemment. Classement recalculé et données rechargées.'
          : 'Synchronisation terminée : $competitions compétition(s), $synced match(s) modifié(s), $manifestsChanged calendrier(s) actualisé(s).';
      return AdminSyncResult(
        ok: true,
        syncedMatches: synced,
        skipped: skipped,
        message: message,
      );
    } on TimeoutException {
      return const AdminSyncResult(
        ok: false,
        message:
            'La synchronisation dépasse 5 minutes. Vérifie les logs Firebase.',
      );
    } catch (e) {
      debugPrint('syncMatchesToFirestore error: $e');
      return AdminSyncResult(
        ok: false,
        message: 'Synchronisation impossible : $e',
      );
    }
  }

  Future<AdminSyncResult> refreshRankingSnapshotsNow() async {
    if (!_adminMode) {
      return const AdminSyncResult(
        ok: false,
        message: 'Accès administrateur non actif sur ce profil.',
      );
    }

    try {
      await _ensureSignedIn().timeout(const Duration(seconds: 10));
      final authUser = _auth.currentUser;
      final token = await authUser?.getIdToken(true);
      if (authUser == null || token == null || token.isEmpty) {
        return const AdminSyncResult(
            ok: false, message: 'Connexion Firebase impossible.');
      }

      final response = await http
          .post(
            Uri.parse(
              'https://europe-west1-mundial2026-ibab-01.cloudfunctions.net/refreshRankingSnapshotsNow',
            ),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, dynamic>{'data': <String, dynamic>{}}),
          )
          .timeout(const Duration(seconds: 300));

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        payload = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AdminSyncResult(
          ok: false,
          message: _callableErrorMessage(
            payload,
            'Recalcul du classement impossible (HTTP ${response.statusCode}).',
          ),
        );
      }

      final raw = payload?['result'] ?? payload?['data'];
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      _rankingLoadError = null;
      _rankingDataLoaded = false;
      await ensureRankingDataLoaded(force: true);

      final votes = data['votes'];
      final users = data['users'];
      return AdminSyncResult(
        ok: true,
        message: votes is num && users is num
            ? 'Classement recalculé : ${votes.toInt()} pronostic(s), ${users.toInt()} joueur(s).'
            : 'Classement recalculé et rechargé.',
      );
    } on TimeoutException {
      return const AdminSyncResult(
        ok: false,
        message: 'Le recalcul du classement dépasse 5 minutes.',
      );
    } catch (e) {
      debugPrint('refreshRankingSnapshotsNow error: $e');
      return AdminSyncResult(
          ok: false, message: 'Recalcul du classement impossible : $e');
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
    final authUid = firebaseUid;
    final profileUid = _currentUser?.id;
    final candidateIds = <String>{
      if (authUid != null && authUid.isNotEmpty) authUid,
      if (profileUid != null && profileUid.isNotEmpty) profileUid,
    };

    // Ne masque pas un accès admin déjà présent dans le profil local pendant
    // une coupure réseau / avant que Firebase Auth soit prêt.
    if (candidateIds.isEmpty) {
      _adminMode = _currentUser?.isAdmin == true;
      notifyListeners();
      return _adminMode;
    }

    try {
      bool isAdmin = false;
      for (final uid in candidateIds) {
        final snap = await _db.collection('users').doc(uid).get().timeout(
              const Duration(seconds: 8),
            );
        if (snap.data()?['isAdmin'] == true) {
          isAdmin = true;
          break;
        }
      }

      _adminMode = isAdmin;
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(isAdmin: isAdmin);
        final currentId = _currentUser!.id;
        _users =
            _users.map((u) => u.id == currentId ? _currentUser! : u).toList();
        await _cacheCurrentUser();
      }
      notifyListeners();
      // BUILD75: admin access must never trigger a server sync implicitly.
      // Manual sync remains available from Settings.
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

  Map<String, dynamic>? _precomputedUserRow(String userId,
      {String period = 'general'}) {
    if (!_usingPrecomputedRanking) return null;
    final rows = _precomputedIndividuals[period];
    if (rows == null) return null;
    for (final row in rows) {
      final user = row['user'];
      if (user is AppUser && user.id == userId) return row;
    }
    return null;
  }

  int getLeaderboardUserPoints(String userId) {
    final row = _precomputedUserRow(userId);
    return row != null && row['points'] is num
        ? (row['points'] as num).toInt()
        : getUserPointsForPeriod(userId, null);
  }

  int getLeaderboardUserVoteCount(String userId) {
    final row = _precomputedUserRow(userId);
    return row != null && row['votes'] is num
        ? (row['votes'] as num).toInt()
        : getUserVoteCountForPeriod(userId, null);
  }

  int getLeaderboardUserResolvedVoteCount(String userId) {
    final row = _precomputedUserRow(userId);
    return row != null && row['resolvedVotes'] is num
        ? (row['resolvedVotes'] as num).toInt()
        : getUserResolvedVoteCount(userId);
  }

  int getLeaderboardUserCorrectCount(String userId) {
    final row = _precomputedUserRow(userId);
    return row != null && row['correct'] is num
        ? (row['correct'] as num).toInt()
        : getUserCorrectCount(userId);
  }

  int getUserPoints(String userId) => getUserPointsForPeriod(userId, null);

  bool _matchInPeriod(String matchId, Duration? period) {
    if (period == null) return true;
    final date = _scoringKickoffAt[matchId] ?? matchById(matchId)?.dateTime;
    if (date == null) return false;
    return date.isAfter(DateTime.now().subtract(period));
  }

  bool hasUserRecordedStats(String userId) =>
      _precomputedUserRow(userId) != null;

  Map<String, dynamic>? _precomputedTeamRow(String teamId,
      {String period = 'general'}) {
    if (!_usingPrecomputedRanking) return null;
    for (final row in _precomputedTeams[period] ?? <Map<String, dynamic>>[]) {
      final team = row['team'];
      if (team is AppTeam && team.id == teamId) return row;
    }
    return null;
  }

  bool hasTeamRecordedStats(String teamId) =>
      _precomputedTeamRow(teamId) != null;

  int getUserPointsForPeriod(String userId, Duration? period) {
    final recorded =
        _precomputedUserRow(userId, period: _rankingPeriodKey(period));
    if (recorded?['points'] is num) return (recorded!['points'] as num).toInt();
    final ids = _scoringMatchIds.isEmpty
        ? _clubMatches.map((m) => m.id).toSet()
        : _scoringMatchIds;
    return _results.entries
        .where((entry) =>
            ids.contains(entry.key) && _matchInPeriod(entry.key, period))
        .fold(0,
            (points, entry) => points + getUserMatchPoints(userId, entry.key));
  }

  int getUserVoteCountForPeriod(String userId, Duration? period) {
    final recorded =
        _precomputedUserRow(userId, period: _rankingPeriodKey(period));
    if (recorded?['votes'] is num) return (recorded!['votes'] as num).toInt();
    final ids = _scoringMatchIds.isEmpty
        ? _clubMatches.map((m) => m.id).toSet()
        : _scoringMatchIds;
    return _votes.keys.where((key) {
      if (!key.startsWith('${userId}__')) return false;
      final matchId = key.substring('${userId}__'.length);
      return ids.contains(matchId) && _matchInPeriod(matchId, period);
    }).length;
  }

  int getUserVoteCount(String userId) =>
      getUserVoteCountForPeriod(userId, null);

  double getTeamPoints(String teamId) => getTeamPointsForPeriod(teamId, null);

  double getTeamPointsForPeriod(String teamId, Duration? period) {
    final recorded =
        _precomputedTeamRow(teamId, period: _rankingPeriodKey(period));
    if (recorded?['points'] is num)
      return (recorded!['points'] as num).toDouble();
    final team = _teams.firstWhere(
      (t) => t.id == teamId,
      orElse: () => const AppTeam(
          id: '', name: '', code: '', memberIds: [], createdBy: ''),
    );
    if (team.memberIds.isEmpty) return 0;
    final total = team.memberIds.fold<int>(
      0,
      (sum, uid) => sum + getUserPointsForPeriod(uid, period),
    );
    return total / team.memberIds.length;
  }

  List<Map<String, dynamic>> getIndividualRanking({
    Duration? period,
    String? competitionId,
  }) {
    // Aucune lecture des votes d'autres joueurs sur le téléphone : les
    // chiffres par championnat viennent uniquement des snapshots serveur.
    if (competitionId != null) {
      if (!competitionRankingAvailable) return const [];
      final rows = _precomputedIndividuals[_rankingPeriodKey(period)] ?? const [];
      final filtered = <Map<String, dynamic>>[];
      for (final original in rows) {
        final byCompetition = original['byCompetition'];
        if (byCompetition is! Map) continue;
        final stats = byCompetition[competitionId];
        if (stats is! Map) continue;
        final votes = stats['votes'] is num ? (stats['votes'] as num).toInt() : 0;
        if (votes <= 0) continue;
        filtered.add({
          ...original,
          'points': stats['points'] is num ? (stats['points'] as num).toInt() : 0,
          'votes': votes,
        });
      }
      filtered.sort((a, b) {
        final cmp = (b['points'] as int).compareTo(a['points'] as int);
        if (cmp != 0) return cmp;
        final voted = (b['votes'] as int).compareTo(a['votes'] as int);
        if (voted != 0) return voted;
        return (a['user'] as AppUser).name.compareTo((b['user'] as AppUser).name);
      });
      return filtered;
    }
    if (_usingPrecomputedRanking) {
      return List<Map<String, dynamic>>.from(
        _precomputedIndividuals[_rankingPeriodKey(period)] ?? const [],
      );
    }
    final ranking = _users
        .map((user) => {
              'user': user,
              'points': getUserPointsForPeriod(user.id, period),
              'votes': getUserVoteCountForPeriod(user.id, period),
            })
        .where((row) => period == null || (row['votes'] as int) > 0)
        .toList();
    ranking.sort((a, b) {
      final pointsCompare = (b['points'] as int).compareTo(a['points'] as int);
      if (pointsCompare != 0) return pointsCompare;
      return (b['votes'] as int).compareTo(a['votes'] as int);
    });
    return ranking;
  }

  List<Map<String, dynamic>> getTeamRanking({
    Duration? period,
    String? competitionId,
  }) {
    // BUILD94 : meme regle de classement que le general (moyenne des
    // membres), appliquee aux points d'un seul championnat. Toutes les
    // donnees viennent des 4 documents rankingSnapshots deja telecharges.
    // Aucun scan de votes et aucune lecture Firestore supplementaire.
    if (competitionId != null) {
      if (!competitionRankingAvailable) return const [];
      final key = _rankingPeriodKey(period);
      final people = _precomputedIndividuals[key] ?? const [];
      final teams = _precomputedTeams[key] ?? const [];
      final membersById = <String, Map<String, dynamic>>{
        for (final p in people) (p['user'] as AppUser).id: p,
      };
      final filtered = <Map<String, dynamic>>[];
      for (final teamRow in teams) {
        final team = teamRow['team'] as AppTeam;
        if (team.memberIds.isEmpty) continue;
        var totalPoints = 0;
        var totalVotes = 0;
        for (final memberId in team.memberIds) {
          final stats = membersById[memberId]?['byCompetition'];
          if (stats is! Map) continue;
          final league = stats[competitionId];
          if (league is! Map) continue;
          totalPoints += league['points'] is num
              ? (league['points'] as num).toInt() : 0;
          totalVotes += league['votes'] is num
              ? (league['votes'] as num).toInt() : 0;
        }
        if (totalVotes == 0) continue;
        filtered.add({
          ...teamRow,
          'points': totalPoints / team.memberIds.length,
          'periodVotes': totalVotes,
        });
      }
      filtered.sort((a, b) {
        final score = (b['points'] as double).compareTo(a['points'] as double);
        if (score != 0) return score;
        final votes = (b['periodVotes'] as int).compareTo(a['periodVotes'] as int);
        if (votes != 0) return votes;
        return (a['team'] as AppTeam).name.compareTo((b['team'] as AppTeam).name);
      });
      return filtered;
    }
    if (_usingPrecomputedRanking) {
      return List<Map<String, dynamic>>.from(
        _precomputedTeams[_rankingPeriodKey(period)] ?? const [],
      );
    }
    final ranking = _teams
        .map((team) => {
              'team': team,
              'points': getTeamPointsForPeriod(team.id, period),
              'periodVotes': team.memberIds.fold<int>(0,
                  (sum, uid) => sum + getUserVoteCountForPeriod(uid, period)),
              'members': team.memberIds
                  .map((id) => _users.firstWhere(
                        (user) => user.id == id,
                        orElse: () =>
                            const AppUser(id: '', name: '?', avatar: '❓'),
                      ))
                  .toList(),
            })
        .where((row) => period == null || (row['periodVotes'] as int) > 0)
        .toList();
    ranking.sort(
        (a, b) => (b['points'] as double).compareTo(a['points'] as double));
    return ranking;
  }

  // ─────────────────────────────────────────────
  // NIVEAU FOOT + BADGES SOCIAUX
  // ─────────────────────────────────────────────
  int getUserResolvedVoteCount(String userId) {
    final recorded = _precomputedUserRow(userId);
    if (recorded?['resolvedVotes'] is num)
      return (recorded!['resolvedVotes'] as num).toInt();
    final ids =
        _scoringMatchIds.isEmpty ? _results.keys.toSet() : _scoringMatchIds;
    return _results.keys
        .where((id) => ids.contains(id) && _votes.containsKey('${userId}__$id'))
        .length;
  }

  int getUserCorrectCount(String userId) {
    final recorded = _precomputedUserRow(userId);
    if (recorded?['correct'] is num)
      return (recorded!['correct'] as num).toInt();
    final ids =
        _scoringMatchIds.isEmpty ? _results.keys.toSet() : _scoringMatchIds;
    return _results.entries
        .where((e) =>
            ids.contains(e.key) && _votes['${userId}__${e.key}'] == e.value)
        .length;
  }

  List<String> _recentResolvedMatchIds(String userId) {
    final ids =
        _scoringMatchIds.isEmpty ? _results.keys.toSet() : _scoringMatchIds;
    final out = _results.keys
        .where((id) => ids.contains(id) && _votes.containsKey('${userId}__$id'))
        .toList();
    out.sort((a, b) {
      final da = _scoringKickoffAt[a] ??
          _voteUpdatedAt['${userId}__$a'] ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = _scoringKickoffAt[b] ??
          _voteUpdatedAt['${userId}__$b'] ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return out.take(30).toList();
  }

  bool _isExactCorrect(String userId, String matchId) {
    final exact = _exactPredictions['${userId}__$matchId'];
    final score = _scores[matchId];
    return exact != null &&
        score != null &&
        exact.homeScore == score.homeScore &&
        exact.awayScore == score.awayScore;
  }

  int getUserKnowledgeScore(String userId) {
    final recorded = _precomputedUserRow(userId);
    if (recorded?['knowledgeScore'] is num)
      return (recorded!['knowledgeScore'] as num).round().clamp(0, 100);
    final recent = _recentResolvedMatchIds(userId);
    if (recent.isEmpty) return 50;
    final correct =
        recent.where((id) => _votes['${userId}__$id'] == _results[id]).length;
    final exact = recent.where((id) => _isExactCorrect(userId, id)).length;
    // Le score exact compte davantage sans permettre de monter juste en votant beaucoup.
    final weighted = correct + (exact * .45);
    return (((weighted + 2) / (recent.length + 4)) * 100)
        .round()
        .clamp(0, 100)
        .toInt();
  }

  String _knowledgeLevel(int score, int played) {
    if (played < 3) return 'À PROUVER';
    if (score < 40) return 'FOOTIX';
    if (score < 55) return 'AMATEUR';
    if (score < 70) return 'CONNAISSEUR';
    if (score < 85) return 'CONFIRMÉ';
    return 'EXPERT';
  }

  String getUserKnowledgeLevel(String userId) => _knowledgeLevel(
        getUserKnowledgeScore(userId),
        getUserResolvedVoteCount(userId),
      );

  List<String> _recentResolvedMatchIdsForCompetition(
    String userId,
    String competitionId,
  ) {
    final ids =
        _scoringMatchIds.isEmpty ? _results.keys.toSet() : _scoringMatchIds;
    final out = _results.keys.where((id) {
      if (!ids.contains(id) || !_votes.containsKey('${userId}__$id'))
        return false;
      var comp = _scoringCompetitionIds[id];
      if (comp == null || comp.isEmpty) {
        for (final match in _clubMatches) {
          if (match.id == id) {
            comp = match.competitionId;
            break;
          }
        }
      }
      return comp == competitionId;
    }).toList();
    out.sort((a, b) {
      final da = _scoringKickoffAt[a] ??
          _voteUpdatedAt['${userId}__$a'] ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = _scoringKickoffAt[b] ??
          _voteUpdatedAt['${userId}__$b'] ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return out.take(30).toList();
  }

  CompetitionSpecialty getUserCompetitionSpecialty(
    String userId,
    String competitionId,
  ) {
    final recent = _recentResolvedMatchIdsForCompetition(userId, competitionId);
    final played = recent.length;
    final correct =
        recent.where((id) => _votes['${userId}__$id'] == _results[id]).length;
    final exact = recent.where((id) => _isExactCorrect(userId, id)).length;
    final score = played == 0
        ? 50
        : ((((correct + (exact * .45)) + 2) / (played + 4)) * 100)
            .round()
            .clamp(0, 100)
            .toInt();
    return CompetitionSpecialty(
      competitionId: competitionId,
      played: played,
      correct: correct,
      score: score,
      level: _knowledgeLevel(score, played),
    );
  }

  List<CompetitionSpecialty> getUserCompetitionSpecialties(String userId) {
    final rows = kCompetitions
        .map((competition) =>
            getUserCompetitionSpecialty(userId, competition.id))
        .toList();
    rows.sort((a, b) {
      final byPlayed = b.played.compareTo(a.played);
      if (byPlayed != 0) return byPlayed;
      return b.score.compareTo(a.score);
    });
    return rows;
  }

  int getUserCurrentStreak(String userId) {
    var streak = 0;
    for (final id in _recentResolvedMatchIds(userId)) {
      if (_votes['${userId}__$id'] == _results[id]) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  bool getUserGoodForm(String userId) {
    final recent = _recentResolvedMatchIds(userId);
    if (getUserCurrentStreak(userId) >= 2) return true;
    final sample = recent.take(5).toList();
    if (sample.length < 4) return false;
    final ok =
        sample.where((id) => _votes['${userId}__$id'] == _results[id]).length;
    return ok / sample.length >= .60;
  }

  String getAutoReputationBadge(String userId) {
    final precomputed = _precomputedBadgeByUser[userId];
    if (_usingPrecomputedRanking &&
        precomputed != null &&
        precomputed.isNotEmpty) {
      return precomputed;
    }
    final played = getUserResolvedVoteCount(userId);
    final score = getUserKnowledgeScore(userId);
    // Le joueur possède un vrai badge dès son arrivée dans PRONO4.
    if (played < 3) return 'FOOTIX';
    if (score < 40) return 'FOOTIX';
    if (score < 55) return 'AMATEUR';
    if (score < 70) return 'CONNAISSEUR';
    if (score < 85) return 'CONFIRMÉ';
    return 'EXPERT';
  }

  int getUserExactCorrectCount(String userId, {Duration? period}) {
    var count = 0;
    for (final matchId in _results.keys) {
      if (!_matchInPeriod(matchId, period)) continue;
      if (_isExactCorrect(userId, matchId)) count++;
    }
    return count;
  }

  String formMessage(String userId, {bool english = false}) {
    final streak = getUserCurrentStreak(userId);
    final exactWeek =
        getUserExactCorrectCount(userId, period: const Duration(days: 7));
    if (streak >= 3)
      return english
          ? '🔥 $streak correct picks in a row'
          : '🔥 $streak bons pronos de suite';
    if (exactWeek >= 2)
      return english
          ? '🎯 $exactWeek exact scores this week'
          : '🎯 $exactWeek scores exacts cette semaine';
    if (getUserGoodForm(userId))
      return english
          ? '⚡ Great form right now'
          : '⚡ Très bonne forme en ce moment';
    return english
        ? 'Prove what you know on the next matches.'
        : 'Prouve ce que tu sais sur les prochains matchs.';
  }

  // ─────────────────────────────────────────────
  // GAME LOOP — BUILD74
  // Progression dérivée des pronostics existants : aucune migration et aucun
  // compteur fragile à maintenir côté serveur.
  // ─────────────────────────────────────────────

  DateTime _gameLocalDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _gameSameDay(DateTime a, DateTime b) =>
      _gameLocalDay(a) == _gameLocalDay(b);

  Map<DateTime, int> _userVoteDays(String userId) {
    final counts = <DateTime, int>{};
    final prefix = '${userId}__';
    for (final entry in _voteUpdatedAt.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final day = _gameLocalDay(entry.value);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  /// Série de journées de matchs avec au moins un pronostic. Les jours sans
  /// match ne cassent jamais la série et la journée en cours bénéficie d'une
  /// grâce jusqu'à minuit : elle est affichée comme "à sauver".
  int getUserDailyActivityStreak(String userId) {
    final playedDays = _userVoteDays(userId).keys.toSet();
    if (playedDays.isEmpty) return 0;
    final today = _gameLocalDay(DateTime.now());

    final matchDays = <DateTime>{};
    for (final entry in _scoringKickoffAt.entries) {
      final competitionId = _scoringCompetitionIds[entry.key];
      if (competitionId != null &&
          competitionId.isNotEmpty &&
          !_enabledCompetitionIds.contains(competitionId)) {
        continue;
      }
      final day = _gameLocalDay(entry.value);
      if (!day.isAfter(today)) matchDays.add(day);
    }
    // Fallback utile pendant le tout premier chargement Firestore.
    if (matchDays.isEmpty) {
      matchDays.addAll(playedDays.where((day) => !day.isAfter(today)));
    }

    final ordered = matchDays.toList()..sort((a, b) => b.compareTo(a));
    if (ordered.isEmpty) return 0;

    var index = 0;
    // Aujourd'hui n'est pas encore perdu : si aucun prono n'a été fait, on
    // calcule la série à partir de la précédente journée de matchs.
    if (ordered.first == today && !playedDays.contains(today)) index = 1;
    if (index >= ordered.length || !playedDays.contains(ordered[index]))
      return 0;

    var streak = 0;
    for (var i = index; i < ordered.length; i += 1) {
      if (!playedDays.contains(ordered[i])) break;
      streak += 1;
    }
    return streak;
  }

  bool getUserHasPlayedToday(String userId) {
    final today = _gameLocalDay(DateTime.now());
    return _userVoteDays(userId).containsKey(today);
  }

  int getUserActiveDaysCount(String userId) => _userVoteDays(userId).length;

  int getUserThreePickDaysCount(String userId) =>
      _userVoteDays(userId).values.where((count) => count >= 3).length;

  int getUserTotalExactCorrectCount(String userId) {
    var count = 0;
    for (final matchId in _results.keys) {
      if (_isExactCorrect(userId, matchId)) count += 1;
    }
    return count;
  }

  /// XP de jeu : récompense l'activité ET la qualité sans modifier les points
  /// officiels PRONO4 utilisés dans les classements.
  int getUserGameXp(String userId) {
    final votes = getUserVoteCount(userId);
    final correct = getUserCorrectCount(userId);
    final exact = getUserTotalExactCorrectCount(userId);
    final activeDays = getUserActiveDaysCount(userId);
    final threePickDays = getUserThreePickDaysCount(userId);
    return (votes * 10) +
        (correct * 20) +
        (exact * 30) +
        (activeDays * 15) +
        (threePickDays * 20);
  }

  static const int gameXpPerLevel = 500;

  int getUserGameLevel(String userId) =>
      1 + (getUserGameXp(userId) ~/ gameXpPerLevel);

  int getUserGameXpInLevel(String userId) =>
      getUserGameXp(userId) % gameXpPerLevel;

  double getUserGameLevelProgress(String userId) =>
      getUserGameXpInLevel(userId) / gameXpPerLevel;

  List<FootballMatch> get todayGameDuels {
    final candidates = todayMatches
        .where((match) => !match.hasStarted && !_results.containsKey(match.id))
        .toList(growable: false);
    final manualIds = _manualDuelDateKey == _localDateKey(DateTime.now())
        ? _manualTodayDuelIds
        : null;
    if (manualIds != null) {
      final selected = candidates
          .where((m) => manualIds.contains(m.id))
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return selected;
    }
    return selectAutomaticDuels(
      candidates,
      _enabledCompetitionIds,
      isFavoriteClub: isFavoriteClub,
    );
  }

  int getUserTodayPredictionCount(String userId) {
    final ids = todayMatches.map((match) => match.id).toSet();
    return ids.where((id) => _votes.containsKey('${userId}__$id')).length;
  }

  int getUserTodayPredictionTarget(String userId) {
    final matches = todayMatches;
    if (matches.isEmpty) return 0;
    final votedIds = matches
        .where((m) => _votes.containsKey('${userId}__${m.id}'))
        .map((m) => m.id)
        .toSet();
    final stillPlayable = matches
        .where((m) => !m.hasStarted && !_results.containsKey(m.id))
        .where((m) => !votedIds.contains(m.id))
        .length;
    final possible = votedIds.length + stillPlayable;
    if (possible <= 0) return 0;
    return min(3, possible);
  }

  bool getUserHasTodayExactPick(String userId) {
    for (final match in todayMatches) {
      if (_exactPredictions.containsKey('${userId}__${match.id}')) return true;
    }
    return false;
  }

  bool get hasPlayableTodayMatch => todayMatches.any(
        (match) => !match.hasStarted && !_results.containsKey(match.id),
      );

  bool getUserHasTodayDuelPick(String userId) => todayGameDuels.any(
        (match) => _votes.containsKey('${userId}__${match.id}'),
      );

  /// Saisons gaming de 4 semaines, lancées avec BUILD74. Elles n'altèrent pas
  /// la saison football ni les classements historiques existants.
  GameSeasonWindow get currentGameSeason {
    final now = _gameLocalDay(DateTime.now());
    final anchor = DateTime(2026, 9, 21);
    if (now.isBefore(anchor)) {
      return GameSeasonWindow(
        number: 1,
        start: anchor,
        end: anchor.add(const Duration(days: 28)),
      );
    }
    final offset = now.difference(anchor).inDays ~/ 28;
    final start = anchor.add(Duration(days: offset * 28));
    return GameSeasonWindow(
      number: offset + 1,
      start: start,
      end: start.add(const Duration(days: 28)),
    );
  }

  bool _matchInGameRange(String matchId, DateTime start, DateTime end) {
    final date = _scoringKickoffAt[matchId] ?? matchById(matchId)?.dateTime;
    if (date == null) return false;
    final local = date.toLocal();
    return !local.isBefore(start) && local.isBefore(end);
  }

  int getUserPointsInGameSeason(String userId, GameSeasonWindow season) {
    return _results.keys
        .where(
            (matchId) => _matchInGameRange(matchId, season.start, season.end))
        .fold<int>(
            0, (sum, matchId) => sum + getUserMatchPoints(userId, matchId));
  }

  int getUserVotesInGameSeason(String userId, GameSeasonWindow season) {
    final prefix = '${userId}__';
    var count = 0;
    for (final key in _votes.keys) {
      if (!key.startsWith(prefix)) continue;
      final matchId = key.substring(prefix.length);
      if (_matchInGameRange(matchId, season.start, season.end)) count += 1;
    }
    return count;
  }

  List<Map<String, dynamic>> getGameSeasonRanking(GameSeasonWindow season) {
    if (_usingPrecomputedRanking &&
        _precomputedGameSeasonNumber == season.number) {
      return List<Map<String, dynamic>>.from(
        _precomputedIndividuals['gameSeason'] ?? const [],
      );
    }
    final ranking = _users
        .map((user) {
          final votes = getUserVotesInGameSeason(user.id, season);
          return <String, dynamic>{
            'user': user,
            'points': getUserPointsInGameSeason(user.id, season),
            'votes': votes,
          };
        })
        .where((row) => (row['votes'] as int) > 0)
        .toList();
    ranking.sort((a, b) {
      final byPoints = (b['points'] as int).compareTo(a['points'] as int);
      if (byPoints != 0) return byPoints;
      return (b['votes'] as int).compareTo(a['votes'] as int);
    });
    return ranking;
  }

  int? getUserGameSeasonRank(String userId, GameSeasonWindow season) {
    final ranking = getGameSeasonRanking(season);
    final index =
        ranking.indexWhere((row) => (row['user'] as AppUser).id == userId);
    return index < 0 ? null : index + 1;
  }

  GameDayRecap? getUserLatestGameRecap(String userId) {
    final today = _gameLocalDay(DateTime.now());
    DateTime? latestDay;
    for (final matchId in _results.keys) {
      if (!_votes.containsKey('${userId}__$matchId')) continue;
      final kickoff =
          _scoringKickoffAt[matchId] ?? matchById(matchId)?.dateTime;
      if (kickoff == null) continue;
      final day = _gameLocalDay(kickoff);
      if (!day.isBefore(today)) continue;
      if (latestDay == null || day.isAfter(latestDay)) latestDay = day;
    }
    if (latestDay == null) return null;

    var played = 0;
    var correct = 0;
    var exact = 0;
    var points = 0;
    for (final matchId in _results.keys) {
      if (!_votes.containsKey('${userId}__$matchId')) continue;
      final kickoff =
          _scoringKickoffAt[matchId] ?? matchById(matchId)?.dateTime;
      if (kickoff == null || !_gameSameDay(kickoff, latestDay)) continue;
      played += 1;
      if (_votes['${userId}__$matchId'] == _results[matchId]) correct += 1;
      if (_isExactCorrect(userId, matchId)) exact += 1;
      points += getUserMatchPoints(userId, matchId);
    }
    if (played == 0) return null;
    return GameDayRecap(
      date: latestDay,
      played: played,
      correct: correct,
      exact: exact,
      points: points,
    );
  }

  Map<String, int> reputationCountsFor(String targetUserId) {
    String? teamId;
    for (final u in _users) {
      if (u.id == targetUserId) {
        teamId = u.teamId;
        break;
      }
    }
    final counts = <String, int>{};
    final cutoff =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    for (final v in _reputationVotes.values) {
      final updated = int.tryParse(v['updatedAtMs'] ?? '0') ?? 0;
      if (updated > 0 && updated < cutoff) continue;
      if (v['targetUserId'] == targetUserId &&
          (teamId == null || v['teamId'] == teamId)) {
        final b = v['badge'] ?? '';
        if (b.isNotEmpty) counts[b] = (counts[b] ?? 0) + 1;
      }
    }
    return counts;
  }

  String reputationBadgeFor(String targetUserId) {
    // BUILD52 : le statut est un résultat sportif automatique. Les anciens
    // votes de réputation sont volontairement ignorés.
    return getAutoReputationBadge(targetUserId);
  }

  Future<String?> castReputationVote(String targetUserId, String badge) async {
    final me = _currentUser, team = myTeam;
    const allowed = {
      'FOOTIX',
      'AMATEUR',
      'CONNAISSEUR',
      'EXPERT',
      'ORACLE',
      'VISIONNAIRE',
      'SNIPER',
      'CHAT NOIR'
    };
    if (me == null || team == null) return 'Équipe indisponible.';
    if (targetUserId == me.id) return 'Tu ne peux pas voter pour toi-même.';
    if (!team.memberIds.contains(targetUserId))
      return 'Ce joueur ne fait pas partie de ton équipe.';
    if (!allowed.contains(badge)) return 'Badge invalide.';
    final id = '${team.id}__${me.id}__$targetUserId';
    try {
      await _db.collection('reputationVotes').doc(id).set({
        'teamId': team.id,
        'voterId': me.id,
        'targetUserId': targetUserId,
        'badge': badge,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('castReputationVote error: $e');
      return 'Vote badge impossible. Vérifie la connexion.';
    }
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

    return visibleMatches
        .map(resolveMatch)
        .where((match) => match.localDate == todayStr && !match.isTBD)
        .toList();
  }

  List<FootballMatch> get upcomingMatches {
    final today = DateTime.now();

    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return visibleMatches
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
    _goldenBootSub?.cancel();
    _fixtureManifestMetaSub?.cancel();
    _reputationVotesSub?.cancel();
    _duelSelectionSub?.cancel();
    _liveNotifyTimer?.cancel();

    super.dispose();
  }
}
