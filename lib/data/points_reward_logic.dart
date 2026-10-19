/// PRONO4 — présentation uniquement des points déjà acquis.
/// Aucune écriture Firestore, aucun calcul de classement ou attribution.
class RecentPointsGain {
  final String matchId;
  final String matchLabel;
  final int previousPoints;
  final int currentPoints;

  const RecentPointsGain({
    required this.matchId,
    required this.matchLabel,
    required this.previousPoints,
    required this.currentPoints,
  });

  int get gained => currentPoints - previousPoints;
  int get exactBonus => currentPoints >= 5 && previousPoints < 5 ? 2 : 0;
  int get goodResultPoints => gained - exactBonus;
}

/// Ne signale que les augmentations positives, match par match.
/// Une correction de résultat ne provoque jamais une animation négative.
List<RecentPointsGain> newPointsSinceLastVisit({
  required Map<String, int> seen,
  required Map<String, int> awarded,
  required Map<String, String> matchLabels,
}) {
  final gains = <RecentPointsGain>[];
  for (final entry in awarded.entries) {
    final previous = seen[entry.key] ?? 0;
    if (entry.value <= previous || entry.value <= 0) continue;
    gains.add(RecentPointsGain(
      matchId: entry.key,
      matchLabel: matchLabels[entry.key] ?? 'Match',
      previousPoints: previous,
      currentPoints: entry.value,
    ));
  }
  gains.sort((a, b) => a.matchId.compareTo(b.matchId));
  return gains;
}
