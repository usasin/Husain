import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Répartition réelle des pronostics PRONO4.
/// Les pourcentages sont calculés uniquement depuis les votes Firestore ;
/// aucun faux volume d'utilisateurs n'est affiché.
class CommunityPredictionStats extends StatelessWidget {
  final String matchId;
  final bool reveal;
  final bool compact;

  const CommunityPredictionStats({
    super.key,
    required this.matchId,
    required this.reveal,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!reveal) {
      return Container(
        margin: EdgeInsets.only(top: compact ? 8 : 10),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: compact ? 7 : 9,
        ),
        decoration: BoxDecoration(
          color: AppColors.overlayBase.withOpacity(.025),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.055)),
        ),
        child: Row(
          children: [
             Icon(Icons.lock_outline_rounded,
                color: AppColors.grey, size: 14),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                context.tr(
                  'Pronostique pour découvrir l’avis de la communauté',
                  'Make your pick to reveal the community view',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.grey,
                  fontSize: compact ? 8.5 : 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final dist = context.select<AppProvider, Map<String, double>>(
      (p) => p.communityVotePercentages(matchId),
    );
    final home = dist['HOME'] ?? 0;
    final draw = dist['DRAW'] ?? 0;
    final away = dist['AWAY'] ?? 0;
    final hasVotes = home + draw + away > 0;

    return Container(
      margin: EdgeInsets.only(top: compact ? 8 : 10),
      padding: EdgeInsets.fromLTRB(
        compact ? 9 : 12,
        compact ? 7 : 10,
        compact ? 9 : 12,
        compact ? 8 : 11,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg1.withOpacity(.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.lime.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_2_rounded,
                  color: AppColors.lime, size: compact ? 12 : 15),
              const SizedBox(width: 6),
              Text(
                context.tr('COMMUNAUTÉ', 'COMMUNITY'),
                style: GoogleFonts.inter(
                  color: AppColors.text2,
                  fontSize: compact ? 8 : 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const Spacer(),
              if (!hasVotes)
                Text(
                  context.tr('Sois le premier', 'Be the first'),
                  style: GoogleFonts.inter(
                    color: AppColors.grey,
                    fontSize: compact ? 7.5 : 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              _pct('1', home, AppColors.lime, compact),
              _pct(context.isEnglish ? 'X' : 'N', draw, AppColors.gold, compact),
              _pct('2', away, AppColors.usaBlue, compact),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: compact ? 5 : 7,
              child: Row(
                children: hasVotes
                    ? [
                        if (home > 0)
                          Expanded(
                            flex: (home * 1000).round().clamp(1, 1000).toInt(),
                            child: const ColoredBox(color: AppColors.lime),
                          ),
                        if (draw > 0)
                          Expanded(
                            flex: (draw * 1000).round().clamp(1, 1000).toInt(),
                            child: const ColoredBox(color: AppColors.gold),
                          ),
                        if (away > 0)
                          Expanded(
                            flex: (away * 1000).round().clamp(1, 1000).toInt(),
                            child: const ColoredBox(color: AppColors.usaBlue),
                          ),
                      ]
                    : [
                        const Expanded(
                          child: ColoredBox(color: Color(0x18FFFFFF)),
                        ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pct(String label, double ratio, Color color, bool compact) {
    return Expanded(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(color: color),
            ),
            TextSpan(text: '${(ratio * 100).round()}%'),
          ],
        ),
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.text,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
