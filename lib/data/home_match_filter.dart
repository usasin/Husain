import '../models/models.dart';

enum HomeMatchStatus { all, upcoming, live, finished }

// Accueil uniquement : le flux peut fournir un résultat PROVISOIRE pendant
// IN_PLAY et la synchronisation serveur n'est pas instantanée.
const _homeInProgressStatuses = <String>{
  'IN_PLAY', 'PAUSED', 'LIVE', 'EXTRA_TIME', 'PENALTY_SHOOTOUT',
};
const _homeFinishedStatuses = <String>{'FINISHED', 'AWARDED'};
const _homeInterruptedStatuses = <String>{
  'CANCELLED', 'POSTPONED', 'SUSPENDED',
};

bool isHomeLiveMatch({
  required FootballMatch match,
  required DateTime now,
  required String? liveStatus,
  required bool hasRecordedResult,
}) {
  final status = (liveStatus ?? '').trim().toUpperCase();
  if (_homeInProgressStatuses.contains(status)) return true;
  if (_homeFinishedStatuses.contains(status) ||
      _homeInterruptedStatuses.contains(status) || hasRecordedResult) {
    return false;
  }

  // Repli d'affichage lorsque l'API n'a pas encore confirmé le coup d'envoi :
  // après le début prévu, le match figure dans « En direct » pendant 3 heures
  // max. Aucun résultat/point n'est calculé à partir de cette estimation.
  final sinceKickoff = now.difference(match.dateTime);
  return !sinceKickoff.isNegative && sinceKickoff < const Duration(hours: 3);
}

bool isHomeFinishedMatch({
  required String? liveStatus,
  required bool hasRecordedResult,
}) {
  final status = (liveStatus ?? '').trim().toUpperCase();
  if (_homeInProgressStatuses.contains(status)) return false;
  return _homeFinishedStatuses.contains(status) || hasRecordedResult;
}

List<FootballMatch> filterHomeMatches({
  required Iterable<FootballMatch> matches,
  required DateTime now,
  String competitionId = 'all',
  DateTime? day,
  HomeMatchStatus status = HomeMatchStatus.all,
  required bool Function(String) isLive,
  required bool Function(String) isFinished,
}) {
  final localNow = now.toLocal();
  final selectedDay = (day ?? now).toLocal();
  final result = matches.where((match) {
    final date = match.dateTime.toLocal();
    if (date.year != selectedDay.year ||
        date.month != selectedDay.month ||
        date.day != selectedDay.day) {
      return false;
    }
    if (competitionId != 'all' && match.competitionId != competitionId) {
      return false;
    }
    final finished = isFinished(match.id);
    final live = !finished && isLive(match.id);
    return switch (status) {
      HomeMatchStatus.all => true,
      HomeMatchStatus.upcoming => !finished && !live && date.isAfter(localNow),
      HomeMatchStatus.live => live,
      HomeMatchStatus.finished => finished,
    };
  }).toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return result;
}
