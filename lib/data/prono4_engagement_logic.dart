import '../models/models.dart';

/// Aperçu pendant le direct : jamais utilisé pour attribuer les points.
/// Le score doit provenir du flux live, pas de l'horloge du match.
int previewPotentialPoints(
    String? prediction, MatchScore? currentScore, MatchScore? exactPick) {
  if (currentScore == null || prediction == null) return 0;
  if (!const {'HOME', 'DRAW', 'AWAY'}.contains(prediction)) return 0;
  final matchResult = currentScore.outcome.key;
  final goodResult = prediction == matchResult;
  final exact = exactPick != null &&
      exactPick.homeScore == currentScore.homeScore &&
      exactPick.awayScore == currentScore.awayScore;
  return (goodResult ? 3 : 0) + (exact ? 2 : 0);
}

class CompletedChallengeVote {
  final String uid;
  final DateTime kickoff;
  final bool correct;
  final bool exact;
  const CompletedChallengeVote({
    required this.uid,
    required this.kickoff,
    required this.correct,
    required this.exact,
  });
}

/// Du lundi 00:00 local au lundi suivant (fin exclusive).
DateTime challengeWeekStart(DateTime now) {
  final localDay = DateTime(now.year, now.month, now.day);
  return localDay.subtract(Duration(days: now.weekday - 1));
}

bool isInChallengeWeek(DateTime kickoff, DateTime now) {
  final start = challengeWeekStart(now);
  return !kickoff.isBefore(start) &&
      kickoff.isBefore(start.add(const Duration(days: 7)));
}

/// Mission collective : dix BONS résultats confirmés parmi les votes
/// d'équipe déjà chargés. Zéro récompense de points supplémentaire.
int teamMissionProgress(
    Iterable<CompletedChallengeVote> completed, Set<String> members,
    DateTime now) {
  return completed.where((e) =>
      members.contains(e.uid) && e.correct && isInChallengeWeek(e.kickoff, now))
      .length;
}

/// Défi surprise : deux SCORES EXACTS le samedi/dimanche de cette semaine.
int weekendExactProgress(
    Iterable<CompletedChallengeVote> completed, String userId, DateTime now) {
  final saturday = challengeWeekStart(now).add(const Duration(days: 5));
  final monday = saturday.add(const Duration(days: 2));
  return completed.where((e) =>
      e.uid == userId && e.exact &&
      !e.kickoff.isBefore(saturday) && e.kickoff.isBefore(monday)).length;
}
