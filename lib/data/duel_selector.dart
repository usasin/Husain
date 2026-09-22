import '../models/models.dart';

/// football-data.org fournit les matchs, horaires et scores.
/// Il ne fournit pas un champ officiel "Duel".
/// PRONO4 sélectionne donc les grosses affiches parmi les matchs du jour,
/// puis l'admin peut corriger la sélection.
List<FootballMatch> selectAutomaticDuels(
  List<FootballMatch> matches,
  Iterable<String> enabledCompetitionIds, {
  bool Function(String code)? isFavoriteClub,
}) {
  final enabled = enabledCompetitionIds.toSet();
  final grouped = <String, List<FootballMatch>>{};

  for (final match in matches) {
    if (!enabled.contains(match.competitionId) || match.hasStarted) continue;
    grouped.putIfAbsent(match.competitionId, () => <FootballMatch>[]).add(match);
  }

  final selected = <FootballMatch>[];
  grouped.forEach((competitionId, candidates) {
    FootballMatch? best;
    var bestScore = -999;

    for (final match in candidates) {
      final score = _duelScore(match, favorite: isFavoriteClub);
      if (score > bestScore ||
          (score == bestScore &&
              best != null &&
              match.dateTime.isBefore(best!.dateTime))) {
        bestScore = score;
        best = match;
      }
    }

    if (best != null && bestScore >= 8) selected.add(best!);
  });

  selected.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return selected;
}

int _duelScore(
  FootballMatch match, {
  bool Function(String code)? favorite,
}) {
  final home = _clubKey(match.homeName ?? match.homeCode);
  final away = _clubKey(match.awayName ?? match.awayCode);
  var score = 0;

  if (_isMajorClub(home, match.competitionId)) score += 4;
  if (_isMajorClub(away, match.competitionId)) score += 4;
  if (_isClassicRivalry(home, away)) score += 8;

  if (match.competitionId == 'champions-league') score += 3;
  if (match.competitionId == 'euro') score += 2;
  if (match.phase != MatchPhase.groupe) score += 5;
  if (match.phase == MatchPhase.demi || match.phase == MatchPhase.finale) {
    score += 5;
  }

  if (favorite != null) {
    if (favorite(match.homeCode)) score += 1;
    if (favorite(match.awayCode)) score += 1;
  }

  return score;
}

String _clubKey(String raw) {
  return raw
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

bool _containsAny(String value, List<String> aliases) =>
    aliases.any((alias) => value.contains(alias));

bool _isMajorClub(String club, String competitionId) {
  switch (competitionId) {
    case 'ligue-1':
      return _containsAny(club, const [
        'parissaintgermain', 'psg', 'marseille', 'olympiquedemarseille',
        'lyon', 'olympiquelyonnais', 'monaco', 'lille', 'losc',
      ]);
    case 'premier-league':
      return _containsAny(club, const [
        'arsenal', 'liverpool', 'manchesterunited', 'manchestercity',
        'chelsea', 'tottenham',
      ]);
    case 'serie-a':
      return _containsAny(club, const [
        'inter', 'internazionale', 'acmilan', 'milan', 'juventus',
        'napoli', 'roma', 'lazio',
      ]);
    case 'bundesliga':
      return _containsAny(club, const [
        'bayern', 'bayernmunich', 'borussiadortmund', 'dortmund',
        'leverkusen', 'rbleipzig', 'leipzig',
      ]);
    case 'champions-league':
      return _containsAny(club, const [
        'realmadrid', 'barcelona', 'atleticomadrid', 'arsenal', 'liverpool',
        'manchesterunited', 'manchestercity', 'chelsea', 'tottenham',
        'bayern', 'dortmund', 'inter', 'milan', 'juventus', 'napoli',
        'parissaintgermain', 'psg', 'marseille', 'benfica', 'porto',
        'ajax', 'psv',
      ]);
    case 'euro':
      return _containsAny(club, const [
        'france', 'spain', 'espagne', 'england', 'angleterre', 'germany',
        'allemagne', 'italy', 'italie', 'portugal', 'netherlands', 'paysbas',
        'belgium', 'belgique', 'croatia', 'croatie',
      ]);
    default:
      return false;
  }
}

bool _isClassicRivalry(String a, String b) {
  bool pair(List<String> left, List<String> right) =>
      (_containsAny(a, left) && _containsAny(b, right)) ||
      (_containsAny(a, right) && _containsAny(b, left));

  return pair(const ['marseille'], const ['parissaintgermain', 'psg']) ||
      pair(const ['realmadrid'], const ['barcelona']) ||
      pair(const ['manchesterunited'], const ['manchestercity']) ||
      pair(const ['liverpool'], const ['manchesterunited']) ||
      pair(const ['arsenal'], const ['tottenham']) ||
      pair(const ['inter', 'internazionale'], const ['acmilan', 'milan']) ||
      pair(const ['juventus'], const ['inter', 'internazionale']) ||
      pair(const ['bayern'], const ['dortmund']);
}
