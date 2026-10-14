/// Affichage du bilan PRONO4 uniquement. Aucune attribution de points.
class NextBadgeGoal {
  final String label;
  final int target;
  final int remaining;
  final int previousThreshold;
  final bool needsMoreResults;
  const NextBadgeGoal(this.label, this.target, this.remaining,
      this.previousThreshold, {this.needsMoreResults = false});

  double get fraction => target <= previousThreshold
      ? 1.0
      : ((target - remaining - previousThreshold) /
              (target - previousThreshold))
          .clamp(0.0, 1.0)
          .toDouble();
}

/// Seuils existants AppProvider.getAutoReputationBadge : 40/55/70/85.
/// Un badge suppose au moins trois pronostics résolus.
NextBadgeGoal nextBadgeGoal(int knowledge, int resolved) {
  final score = knowledge.clamp(0, 100).toInt();
  if (resolved < 3) {
    return NextBadgeGoal('PREMIER NIVEAU', 3, 3 - resolved, 0,
        needsMoreResults: true);
  }
  if (score < 40) return NextBadgeGoal('AMATEUR', 40, 40 - score, 0);
  if (score < 55) return NextBadgeGoal('CONNAISSEUR', 55, 55 - score, 40);
  if (score < 70) return NextBadgeGoal('CONFIRMÉ', 70, 70 - score, 55);
  if (score < 85) return NextBadgeGoal('EXPERT', 85, 85 - score, 70);
  return const NextBadgeGoal('EXPERT', 85, 0, 85);
}

class RivalCandidate {
  final String uid;
  final String name;
  final int points;
  final bool inTeam;
  const RivalCandidate(this.uid, this.name, this.points,
      {this.inTeam = false});
}

/// Ne choisit qu'un VRAI adversaire devant le joueur sur le dernier classement
/// chargé. Préférence aux coéquipiers ; aucun classement imaginé ou requête.
RivalCandidate? rivalToCatch(String uid, List<RivalCandidate> ranking) {
  RivalCandidate? self;
  for (final row in ranking) {
    if (row.uid == uid) {
      self = row;
      break;
    }
  }
  if (self == null) return null;
  final ahead = ranking.where((row) =>
      row.uid != uid && row.name.trim().isNotEmpty && row.points > self!.points);
  if (ahead.isEmpty) return null;
  final teammates = ahead.where((row) => row.inTeam).toList();
  final options = teammates.isNotEmpty ? teammates : ahead.toList();
  options.sort((a, b) {
    final comparison = a.points.compareTo(b.points);
    return comparison != 0 ? comparison : a.uid.compareTo(b.uid);
  });
  return options.first;
}
