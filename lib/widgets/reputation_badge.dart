import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';

/// Statut football automatique de PRONO4.
/// Il dépend uniquement des résultats du joueur, jamais du vote des autres.
const List<String> kReputationBadges = [
  'À PROUVER',
  'FOOTIX',
  'AMATEUR',
  'CONNAISSEUR',
  'CONFIRMÉ',
  'EXPERT',
];

String reputationEmoji(String badge) {
  switch (badge.toUpperCase()) {
    case 'À PROUVER':
    case 'A PROUVER':
      return '⏳';
    case 'FOOTIX': return '🥴';
    case 'AMATEUR': return '⚽';
    case 'CONNAISSEUR': return '🧠';
    case 'CONFIRMÉ':
    case 'CONFIRME':
      return '🔥';
    case 'EXPERT': return '👑';
    default: return '⚽';
  }
}

String reputationLabel(BuildContext context, String badge) {
  final normalized = badge.toUpperCase();
  if (!context.isEnglish) return normalized;
  switch (normalized) {
    case 'À PROUVER':
    case 'A PROUVER': return 'TO PROVE';
    case 'CONNAISSEUR': return 'CONNOISSEUR';
    case 'CONFIRMÉ':
    case 'CONFIRME': return 'CONFIRMED';
    default: return normalized;
  }
}

String? reputationBadgeAsset(BuildContext context, String badge) {
  final normalized = badge.toUpperCase();
  if (normalized == 'À PROUVER' || normalized == 'A PROUVER') return null;
  final lang = context.isEnglish ? 'en' : 'fr';
  String key;
  switch (normalized) {
    case 'FOOTIX': key = 'footix'; break;
    case 'AMATEUR': key = 'amateur'; break;
    case 'CONNAISSEUR': key = lang == 'en' ? 'connoisseur' : 'connaisseur'; break;
    case 'CONFIRMÉ':
    case 'CONFIRME': key = lang == 'en' ? 'confirmed' : 'confirme'; break;
    case 'EXPERT': key = 'expert'; break;
    default: return null;
  }
  return 'assets/badges/$lang/$key.webp';
}

class ReputationBadgeChip extends StatelessWidget {
  final String badge;
  final bool compact;
  const ReputationBadgeChip({super.key, required this.badge, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final normalized = badge.toUpperCase();
    final asset = reputationBadgeAsset(context, normalized);
    Color color;
    if (normalized == 'FOOTIX') {
      color = Colors.orangeAccent;
    } else if (normalized == 'AMATEUR') {
      color = AppColors.text2;
    } else if (normalized == 'CONNAISSEUR') {
      color = AppColors.cyan;
    } else if (normalized == 'CONFIRMÉ' || normalized == 'CONFIRME') {
      color = AppColors.lime;
    } else if (normalized == 'EXPERT') {
      color = AppColors.lime;
    } else {
      color = AppColors.grey;
    }
    final imageSize = compact ? 24.0 : 34.0;
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 4 : 5, compact ? 3 : 4, compact ? 7 : 9, compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (asset != null)
          Container(
            width: imageSize,
            height: imageSize,
            margin: const EdgeInsets.only(right: 5),
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: AppColors.logoPlate,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.logoPlateBorder),
            ),
            child: ClipOval(
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(reputationEmoji(normalized), style: TextStyle(fontSize: compact ? 13 : 17)),
                ),
              ),
            ),
          )
        else ...[
          Text(reputationEmoji(normalized), style: TextStyle(fontSize: compact ? 12 : 15)),
          const SizedBox(width: 4),
        ],
        Text(
          reputationLabel(context, normalized),
          style: TextStyle(
            color: color,
            fontSize: compact ? 9 : 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ]),
    );
  }
}
