import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
import '../screens/game_center_screen.dart';
import '../theme/app_theme.dart';

class GameLoopCard extends StatelessWidget {
  const GameLoopCard({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final user = prov.currentUser;
    if (user == null) return const SizedBox.shrink();

    final streak = prov.getUserDailyActivityStreak(user.id);
    final xp = prov.getUserGameXp(user.id);
    final level = prov.getUserGameLevel(user.id);
    final xpInLevel = prov.getUserGameXpInLevel(user.id);
    final xpProgress = prov.getUserGameLevelProgress(user.id);
    final season = prov.currentGameSeason;
    final rank = prov.getUserGameSeasonRank(user.id, season);

    final picks = prov.getUserTodayPredictionCount(user.id);
    final pickTarget = prov.getUserTodayPredictionTarget(user.id);
    final exactDone = prov.getUserHasTodayExactPick(user.id);
    final duels = prov.todayGameDuels;
    final duelDone = prov.getUserHasTodayDuelPick(user.id);

    var completed = 0;
    var available = 0;
    if (pickTarget > 0) {
      available += 1;
      if (picks >= pickTarget) completed += 1;
    }
    if (prov.hasPlayableTodayMatch || exactDone) {
      available += 1;
      if (exactDone) completed += 1;
    }
    if (duels.isNotEmpty || duelDone) {
      available += 1;
      if (duelDone) completed += 1;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lime.withOpacity(.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('🎮 TON JEU DU JOUR', '🎮 YOUR DAILY GAME'),
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      available == 0
                          ? context.tr(
                              'Journée calme : aucun objectif impossible.',
                              'Quiet day: no impossible mission.',
                            )
                          : context.tr(
                              '$completed/$available missions terminées aujourd’hui',
                              '$completed/$available missions completed today',
                            ),
                      style: GoogleFonts.inter(
                        color: AppColors.text2,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _streakPill(
                context,
                streak,
                prov.getUserHasPlayedToday(user.id),
                prov.hasPlayableTodayMatch,
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _miniStat(
                    context,
                    icon: '⭐',
                    value: context.tr('Niv. $level', 'Lv. $level'),
                    label: '$xp XP',
                    width: compact ? (constraints.maxWidth - 8) / 2 : 112,
                  ),
                  _miniStat(
                    context,
                    icon: '🏆',
                    value: rank == null ? '—' : '#$rank',
                    label: context.tr('Saison ${season.number}', 'Season ${season.number}'),
                    width: compact ? (constraints.maxWidth - 8) / 2 : 112,
                  ),
                  _miniStat(
                    context,
                    icon: '🎯',
                    value: pickTarget == 0 ? '—' : '${picks.clamp(0, pickTarget)}/$pickTarget',
                    label: context.tr('Pronos du jour', 'Today picks'),
                    width: compact ? constraints.maxWidth : 126,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: xpProgress.clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    backgroundColor: AppColors.bg3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.lime),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$xpInLevel/${AppProvider.gameXpPerLevel} XP',
                style: GoogleFonts.inter(
                  color: AppColors.text2,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GameCenterScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: const Color(0xFF101510),
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.sports_esports_rounded, size: 20),
              label: Text(
                context.tr('OUVRIR LE CENTRE DE JEU', 'OPEN GAME CENTER'),
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _streakPill(
    BuildContext context,
    int streak,
    bool playedToday,
    bool canPlayToday,
  ) {
    final label = streak <= 0
        ? (canPlayToday
            ? context.tr('🔥 Lance ta série', '🔥 Start your streak')
            : context.tr('🔥 Au prochain match', '🔥 Next match'))
        : playedToday
            ? context.tr('🔥 $streak jours', '🔥 $streak days')
            : !canPlayToday
                ? context.tr('🔥 $streak · protégée', '🔥 $streak · protected')
                : context.tr('🔥 $streak · à sauver', '🔥 $streak · save it');
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withOpacity(.28)),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: AppColors.gold,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _miniStat(
    BuildContext context, {
    required String icon,
    required String value,
    required String label,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.06)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.text2,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
