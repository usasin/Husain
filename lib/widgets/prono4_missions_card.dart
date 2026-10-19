import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/prono4_engagement_logic.dart';
import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Objectifs ludiques calculés à partir des votes déjà chargés dans l'app.
/// Aucune écriture et aucune lecture Firestore supplémentaire.
class Prono4MissionsCard extends StatelessWidget {
  final DateTime now;
  final VoidCallback onSeeMatches;
  final VoidCallback onTeamTap;

  const Prono4MissionsCard({
    super.key,
    required this.now,
    required this.onSeeMatches,
    required this.onTeamTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return const SizedBox.shrink();
    final team = provider.myTeam;
    final members = team?.memberIds.toSet() ?? <String>{};
    final knownUsers = {...members, user.id};
    final completed = <CompletedChallengeVote>[];
    if (provider.loaded) {
      for (final entry in provider.votes.entries) {
        // Un même utilisateur peut avoir plusieurs matchs ; aucune écriture.
        final separator = entry.key.indexOf('__');
        if (separator < 1) continue;
        final uid = entry.key.substring(0, separator);
        if (!knownUsers.contains(uid)) continue;
        final matchId = entry.key.substring(separator + 2);
        final status = (provider.liveStatusFor(matchId) ?? '').toUpperCase();
        if (!const {'FINISHED', 'AWARDED', 'FT', 'FULL_TIME'}
            .contains(status)) continue;
        final match = provider.matchById(matchId);
        if (match == null || !isInChallengeWeek(match.dateTime, now)) continue;
        final actual = provider.results[matchId];
        final score = provider.scores[matchId];
        final exact = provider.getExactPrediction(matchId, userId: uid);
        completed.add(CompletedChallengeVote(
          uid: uid,
          kickoff: match.dateTime,
          correct: actual != null && actual == entry.value,
          exact: score != null && exact != null &&
              score.homeScore == exact.homeScore &&
              score.awayScore == exact.awayScore,
        ));
      }
    }
    final teamWins = team == null ? 0 :
        teamMissionProgress(completed, members, now);
    final weekendExact = weekendExactProgress(completed, user.id, now);
    final isWeekend = now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
    final teamCompleted = team != null && teamWins >= 10;
    final soloCompleted = weekendExact >= 2;
    const golden = Color(0xFFE4AC37);
    return Material(
      color: AppColors.bg2,
      borderRadius: BorderRadius.circular(18),
      child: ExpansionTile(
        shape: const Border(), collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 1),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
        leading: const Icon(Icons.flag_rounded, color: golden, size: 22),
        title: Text(context.tr('MES DÉFIS DE LA SEMAINE', 'MY WEEKLY MISSIONS'),
          style: GoogleFonts.spaceGrotesk(
              color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w900)),
        subtitle: Text(
          team == null
              ? context.tr('Objectif week-end : $weekendExact/2 scores exacts',
                  'Weekend goal: $weekendExact/2 exact scores')
              : context.tr('Équipe : $teamWins/10 · Week-end : $weekendExact/2',
                  'Team: $teamWins/10 · Weekend: $weekendExact/2'),
          style: TextStyle(color: AppColors.text2, fontSize: 10.5),
        ),
        children: [
          if (team == null)
            _mission(
              context: context, icon: Icons.groups_rounded, title: context.tr(
                  'Mission d’équipe', 'Team mission'),
              description: context.tr(
                'Rejoins une équipe pour réussir 10 bons pronostics ensemble.',
                'Join a team to get 10 correct predictions together.'),
              progress: 0, goal: 10, color: golden,
              onTap: onTeamTap, action: context.tr('Voir les équipes', 'View teams'),
            )
          else
            _mission(
              context: context, icon: Icons.groups_rounded,
              title: context.tr('Mission collective', 'Team mission'),
              description: teamCompleted
                  ? context.tr('🏆 Défi réussi ! Trophée visuel débloqué.',
                      '🏆 Mission complete! Visual trophy unlocked.')
                  : context.tr('10 bons résultats confirmés cette semaine.',
                      '10 confirmed correct results this week.'),
              progress: teamWins, goal: 10, color: golden,
              onTap: onTeamTap, action: context.tr('Mon équipe', 'My team'),
            ),
          const SizedBox(height: 10),
          _mission(
            context: context, icon: Icons.stars_rounded,
            title: context.tr('Défi surprise du week-end',
                'Weekend surprise challenge'),
            description: soloCompleted
                ? context.tr('🏆 Bravo ! 2 scores exacts ce week-end.',
                    '🏆 Well done! 2 exact scores this weekend.')
                : isWeekend
                    ? context.tr('Réussis 2 scores exacts avant lundi.',
                        'Get 2 exact scores before Monday.')
                    : context.tr('Samedi et dimanche : vise 2 scores exacts.',
                        'Saturday and Sunday: aim for 2 exact scores.'),
            progress: weekendExact, goal: 2,
            color: const Color(0xFF22C55E),
            onTap: onSeeMatches,
            action: context.tr('Voir les matchs', 'View matches'),
          ),
          const SizedBox(height: 7),
          Text(
            context.tr('Défis visuels, sans points de classement supplémentaires. Progression basée sur les résultats chargés.',
                'Visual missions with no extra ranking points. Progress uses loaded results.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _mission({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required int progress,
    required int goal,
    required Color color,
    required VoidCallback onTap,
    required String action,
  }) {
    final complete = progress >= goal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg1, borderRadius: BorderRadius.circular(13),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(complete ? Icons.emoji_events_rounded : icon,
              color: color, size: 19),
          const SizedBox(width: 7),
          Expanded(child: Text(title, style: GoogleFonts.inter(
              color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w800))),
          Text('$progress/$goal', style: GoogleFonts.spaceGrotesk(
              color: color, fontSize: 15, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (progress / goal).clamp(0.0, 1.0).toDouble(),
            backgroundColor: AppColors.bg2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 7,
          ),
        ),
        const SizedBox(height: 7),
        Text(description,
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10.5)),
        Align(alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.chevron_right_rounded, size: 15),
            label: Text(action, style: const TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(foregroundColor: AppColors.lime),
          ),
        ),
      ]),
    );
  }
}
