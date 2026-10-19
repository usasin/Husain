import 'points_reward_logic.dart';

/// Ordre officiel des badges PRONO4. Ce fichier n'attribue aucun badge.
const _badgeOrder = <String>[
  'FOOTIX', 'AMATEUR', 'CONNAISSEUR', 'CONFIRMÉ', 'EXPERT',
];

String normalizedRewardBadge(String badge) {
  final normalized = badge.trim().toUpperCase();
  if (normalized == 'CONFIRME') return 'CONFIRMÉ';
  return normalized;
}

/// Une récompense n'est célébrée que lors d'une VRAIE montée de badge,
/// jamais lors d'un premier chargement ou d'une rétrogradation.
bool isBadgePromotion(String? previous, String current) {
  if (previous == null) return false;
  final from = _badgeOrder.indexOf(normalizedRewardBadge(previous));
  final to = _badgeOrder.indexOf(normalizedRewardBadge(current));
  return from >= 0 && to > from;
}

class RewardMoment {
  final String matchLabel;
  final String kind;
  final int points;
  final bool confetti;
  const RewardMoment({
    required this.matchLabel,
    required this.kind,
    required this.points,
    required this.confetti,
  });
}

/// +3 bon résultat, puis +2 score exact, selon les points DÉJÀ crédités.
/// Chaque gain partiel reste visible, sans attribuer de nouveaux points.
List<RewardMoment> buildRewardMoments(List<RecentPointsGain> gains) {
  final moments = <RewardMoment>[];
  for (final gain in gains) {
    if (gain.goodResultPoints > 0) {
      moments.add(RewardMoment(
        matchLabel: gain.matchLabel,
        kind: 'result',
        points: gain.goodResultPoints,
        confetti: false,
      ));
    }
    if (gain.exactBonus > 0) {
      moments.add(RewardMoment(
        matchLabel: gain.matchLabel,
        kind: 'exact',
        points: gain.exactBonus,
        confetti: true,
      ));
    }
  }
  return moments;
}
