// ─── TEAM MODEL ───────────────────────────────────────
class TeamInfo {
  final String code;
  final String name;
  final String flagCode;
  final String group;
  final String emoji;

  const TeamInfo({
    required this.code,
    required this.name,
    required this.flagCode,
    required this.group,
    required this.emoji,
  });
}

// ─── MATCH MODEL ──────────────────────────────────────
enum MatchPhase { groupe, seizieme, huitieme, quart, demi, troisieme, finale }

class FootballMatch {
  final String id;
  final String homeCode;
  final String awayCode;
  final String competitionId;
  final String? homeName;
  final String? awayName;
  final String? homeCrestUrl;
  final String? awayCrestUrl;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  final String venue;
  final String? group;
  final MatchPhase phase;
  final int? matchday;
  final String? label;
  final String? stage;
  final bool allowsDraw;
  final String? kickoffUtcIso;

  const FootballMatch({
    required this.id,
    required this.homeCode,
    required this.awayCode,
    this.competitionId = 'world-cup-2026',
    this.homeName,
    this.awayName,
    this.homeCrestUrl,
    this.awayCrestUrl,
    required this.date,
    required this.time,
    required this.venue,
    this.group,
    required this.phase,
    this.matchday,
    this.label,
    this.stage,
    this.allowsDraw = true,
    this.kickoffUtcIso,
  });

  bool get isTBD => homeCode == 'TBD';

  FootballMatch copyWith({String? homeCode, String? awayCode}) {
    return FootballMatch(
      id: id,
      homeCode: homeCode ?? this.homeCode,
      awayCode: awayCode ?? this.awayCode,
      competitionId: competitionId,
      homeName: homeName,
      awayName: awayName,
      homeCrestUrl: homeCrestUrl,
      awayCrestUrl: awayCrestUrl,
      date: date,
      time: time,
      venue: venue,
      group: group,
      phase: phase,
      matchday: matchday,
      label: label,
      stage: stage,
      allowsDraw: allowsDraw,
      kickoffUtcIso: kickoffUtcIso,
    );
  }

  // Les champs `date` et `time` sont stockés en HEURE DE PARIS (CEST = UTC+2),
  // valable sur toute la durée du tournoi (11 juin → 19 juillet 2026, période
  // d'heure d'été en France). On reconstruit l'instant réel puis on le convertit
  // automatiquement dans le fuseau horaire de l'appareil de l'utilisateur.
  static const int _parisOffsetHours = 2;

  /// Instant réel du match, exprimé dans le fuseau horaire de l'appareil.
  DateTime get dateTime {
    if (kickoffUtcIso != null && kickoffUtcIso!.isNotEmpty) {
      return DateTime.parse(kickoffUtcIso!).toLocal();
    }
    final y = int.parse(date.substring(0, 4));
    final mo = int.parse(date.substring(5, 7));
    final d = int.parse(date.substring(8, 10));
    final h = int.parse(time.substring(0, 2));
    final mi = int.parse(time.substring(3, 5));

    // Heure murale de Paris → instant UTC → heure locale de l'appareil.
    final utcInstant = DateTime.utc(y, mo, d, h, mi)
        .subtract(const Duration(hours: _parisOffsetHours));
    return utcInstant.toLocal();
  }

  /// Heure du match « HH:mm » dans le fuseau horaire de l'appareil.
  String get localTime {
    final dt = dateTime;
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Date « yyyy-MM-dd » dans le fuseau horaire de l'appareil
  /// (sert à regrouper les matchs par jour correctement selon le fuseau).
  String get localDate {
    final dt = dateTime;
    return '${dt.year}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  bool get hasStarted => !DateTime.now().isBefore(dateTime);
}

// ─── USER MODEL ──────────────────────────────────────
class AppUser {
  final String id;
  final String name;
  final String avatar;
  final String? teamId;
  final bool isAdmin;
  final String recoveryCode;

  const AppUser({
    required this.id,
    required this.name,
    required this.avatar,
    this.teamId,
    this.isAdmin = false,
    this.recoveryCode = '',
  });

  AppUser copyWith(
      {String? name,
      String? avatar,
      String? teamId,
      bool? isAdmin,
      bool clearTeam = false,
      String? recoveryCode}) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      teamId: clearTeam ? null : (teamId ?? this.teamId),
      isAdmin: isAdmin ?? this.isAdmin,
      recoveryCode: recoveryCode ?? this.recoveryCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'teamId': teamId,
        'isAdmin': isAdmin,
        'recoveryCode': recoveryCode,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        avatar: j['avatar'],
        teamId: j['teamId'],
        isAdmin: j['isAdmin'] == true,
        recoveryCode: (j['recoveryCode'] ?? '').toString(),
      );
}

// ─── APP TEAM MODEL ──────────────────────────────────
class AppTeam {
  final String id;
  final String name;
  final String code;
  final List<String> memberIds;
  final String createdBy;
  final String icon;

  const AppTeam({
    required this.id,
    required this.name,
    required this.code,
    required this.memberIds,
    required this.createdBy,
    this.icon = '',
  });

  AppTeam copyWith({List<String>? memberIds, String? icon}) => AppTeam(
        id: id,
        name: name,
        code: code,
        memberIds: memberIds ?? this.memberIds,
        createdBy: createdBy,
        icon: icon ?? this.icon,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'memberIds': memberIds,
        'createdBy': createdBy,
        'icon': icon,
      };

  factory AppTeam.fromJson(Map<String, dynamic> j) => AppTeam(
        id: j['id'],
        name: j['name'],
        code: j['code'],
        memberIds: List<String>.from(j['memberIds']),
        createdBy: j['createdBy'],
        icon: (j['icon'] ?? '').toString(),
      );
}

// ─── VOTE PREDICTION ─────────────────────────────────
enum Prediction { home, draw, away }

extension PredictionLabel on Prediction {
  String get label {
    switch (this) {
      case Prediction.home:
        return 'Victoire Dom.';
      case Prediction.draw:
        return 'Match Nul';
      case Prediction.away:
        return 'Victoire Ext.';
    }
  }

  String get icon {
    switch (this) {
      case Prediction.home:
        return '🏠';
      case Prediction.draw:
        return '🤝';
      case Prediction.away:
        return '✈️';
    }
  }

  String get key {
    switch (this) {
      case Prediction.home:
        return 'HOME';
      case Prediction.draw:
        return 'DRAW';
      case Prediction.away:
        return 'AWAY';
    }
  }

  static Prediction? fromKey(String? k) {
    if (k == 'HOME') return Prediction.home;
    if (k == 'DRAW') return Prediction.draw;
    if (k == 'AWAY') return Prediction.away;
    return null;
  }
}

// ─── OFFICIAL MATCH SCORE ─────────────────────────────
class MatchScore {
  final int homeScore;
  final int awayScore;

  const MatchScore({
    required this.homeScore,
    required this.awayScore,
  });

  Prediction get outcome {
    if (homeScore > awayScore) return Prediction.home;
    if (awayScore > homeScore) return Prediction.away;
    return Prediction.draw;
  }

  String get display => '$homeScore – $awayScore';
}

// ─── GROUP STANDING ───────────────────────────────────
class GroupStanding {
  final String teamCode;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int points;

  const GroupStanding({
    required this.teamCode,
    this.played = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.points = 0,
  });

  int get goalDifference => goalsFor - goalsAgainst;

  GroupStanding addMatch({
    required int scored,
    required int conceded,
  }) {
    final won = scored > conceded;
    final drew = scored == conceded;
    return GroupStanding(
      teamCode: teamCode,
      played: played + 1,
      wins: wins + (won ? 1 : 0),
      draws: draws + (drew ? 1 : 0),
      losses: losses + (!won && !drew ? 1 : 0),
      goalsFor: goalsFor + scored,
      goalsAgainst: goalsAgainst + conceded,
      points: points +
          (won
              ? 3
              : drew
                  ? 1
                  : 0),
    );
  }
}
