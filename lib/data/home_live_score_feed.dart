import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Scores d'affichage uniquement. N'alimente JAMAIS les points et pronostics.
class HomeLiveScore {
  final String status;
  final MatchScore? score;

  const HomeLiveScore({required this.status, required this.score});

  bool get isLive => const {
        'IN_PLAY', 'PAUSED', 'LIVE', 'EXTRA_TIME', 'PENALTY_SHOOTOUT',
      }.contains(status);

  bool get isFinished => const {'FINISHED', 'AWARDED'}.contains(status);

  static HomeLiveScore? fromMap(Object? value) {
    if (value is! Map) return null;
    final status = (value['status'] ?? '').toString().toUpperCase();
    if (status.isEmpty) return null;
    final home = value['homeScore'];
    final away = value['awayScore'];
    return HomeLiveScore(
      status: status,
      score: home is int && away is int && home >= 0 && away >= 0
          ? MatchScore(homeScore: home, awayScore: away)
          : null,
    );
  }
}

/// Si la synchro s'est arrêtée, ne pas afficher un score LIVE périmé.
Map<String, HomeLiveScore> parseHomeLiveScores(
  Map<String, dynamic>? data,
  DateTime now,
) {
  if (data == null) return {};
  final checked = data['checkedAt'];
  if (checked is! Timestamp) return {};
  final age = now.difference(checked.toDate());
  if (age > const Duration(minutes: 45) || age < const Duration(minutes: -5)) {
    return {};
  }
  final rows = data['matches'];
  if (rows is! Map) return {};
  final scores = <String, HomeLiveScore>{};
  for (final entry in rows.entries) {
    final value = HomeLiveScore.fromMap(entry.value);
    if (value != null) scores[entry.key.toString()] = value;
  }
  return scores;
}
