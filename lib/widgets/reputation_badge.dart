import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';

const List<String> kReputationBadges = [
  'FOOTIX', 'AMATEUR', 'CONNAISSEUR', 'EXPERT', 'ORACLE', 'VISIONNAIRE', 'SNIPER', 'CHAT NOIR'
];

String reputationEmoji(String badge) {
  switch (badge) {
    case 'FOOTIX': return '🥴';
    case 'AMATEUR': return '⚽';
    case 'CONNAISSEUR': return '🧠';
    case 'EXPERT': return '👑';
    case 'ORACLE': return '🔮';
    case 'VISIONNAIRE': return '👁️';
    case 'SNIPER': return '🎯';
    case 'CHAT NOIR': return '🐈‍⬛';
    default: return '⚽';
  }
}


String reputationLabel(BuildContext context, String badge) {
  if (!context.isEnglish) return badge;
  switch (badge) {
    case 'FOOTIX': return 'FOOTIX';
    case 'AMATEUR': return 'ROOKIE';
    case 'CONNAISSEUR': return 'KNOWLEDGEABLE';
    case 'EXPERT': return 'EXPERT';
    case 'ORACLE': return 'ORACLE';
    case 'VISIONNAIRE': return 'VISIONARY';
    case 'SNIPER': return 'SNIPER';
    case 'CHAT NOIR': return 'BAD LUCK';
    default: return badge;
  }
}

class ReputationBadgeChip extends StatelessWidget {
  final String badge;
  final bool compact;
  const ReputationBadgeChip({super.key, required this.badge, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final good = badge == 'EXPERT' || badge == 'ORACLE' || badge == 'CONNAISSEUR' || badge == 'VISIONNAIRE' || badge == 'SNIPER';
    final color = good ? AppColors.lime : (badge == 'FOOTIX' || badge == 'CHAT NOIR' ? Colors.orangeAccent : AppColors.text2);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.30))),
      child: Text('${reputationEmoji(badge)} ${reputationLabel(context, badge)}', style: TextStyle(color: color, fontSize: compact ? 9 : 10, fontWeight: FontWeight.w900)),
    );
  }
}
