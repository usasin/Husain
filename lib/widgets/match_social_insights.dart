import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'avatar_display.dart';
import 'knowledge_meter.dart';
import 'reputation_badge.dart';

class MatchSocialInsights extends StatelessWidget {
  final FootballMatch match;
  const MatchSocialInsights({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final me = prov.currentUser;
    final reveal = me != null &&
            prov.votes.containsKey('${me.id}__${match.id}') ||
        match.hasStarted ||
        prov.results.containsKey(match.id);
    final teamPicks = prov.teamMatchPicks(match.id);
    final finished = prov.results.containsKey(match.id);
    final myPoints = me == null ? 0 : prov.getUserMatchPoints(me.id, match.id);

    return Column(
      children: [
        if (prov.myTeam != null) ...[
          _TeamPicksCard(match: match, picks: teamPicks, reveal: reveal),
        ],
        if (finished && me != null) ...[
          const SizedBox(height: 12),
          _ResultImpactCard(match: match, points: myPoints, user: me),
        ],
      ],
    );
  }
}

class _TeamPicksCard extends StatelessWidget {
  final FootballMatch match;
  final List<Map<String, dynamic>> picks;
  final bool reveal;
  const _TeamPicksCard({
    required this.match,
    required this.picks,
    required this.reveal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_2_rounded,
                  color: AppColors.lime, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.tr('PRONOS DE TON ÉQUIPE', 'YOUR TEAM PICKS'),
                  style: GoogleFonts.inter(
                    color: AppColors.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (picks.isEmpty)
            Text(
              context.tr('Crée une équipe pour comparer vos pronos.',
                  'Create a team to compare your picks.'),
              style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: picks.map((row) {
                final user = row['user'] as AppUser;
                final prediction = row['prediction'] as String?;
                final exact = row['exact'] as MatchScore?;
                final hasPick = prediction != null && prediction.isNotEmpty;
                final label = !reveal && hasPick
                    ? '✓'
                    : exact != null
                        ? exact.display
                        : prediction == 'HOME'
                            ? '1'
                            : prediction == 'DRAW'
                                ? (context.isEnglish ? 'X' : 'N')
                                : prediction == 'AWAY'
                                    ? '2'
                                    : '—';
                return Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                  decoration: BoxDecoration(
                    color: hasPick
                        ? AppColors.lime.withOpacity(.07)
                        : AppColors.overlayBase.withOpacity(.025),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasPick
                          ? AppColors.lime.withOpacity(.18)
                          : AppColors.overlayBase.withOpacity(.05),
                    ),
                  ),
                  child: Column(
                    children: [
                      AvatarBubble(avatar: user.avatar, size: 30),
                      const SizedBox(height: 5),
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.text2,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: GoogleFonts.spaceGrotesk(
                          color: hasPick ? AppColors.lime : AppColors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (!reveal && picks.any((e) => e['prediction'] != null)) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Les choix se dévoilent après ton pronostic.',
                'Picks are revealed after you make yours.',
              ),
              style: GoogleFonts.inter(
                  color: AppColors.grey, fontSize: 8.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultImpactCard extends StatelessWidget {
  final FootballMatch match;
  final int points;
  final AppUser user;
  const _ResultImpactCard({
    required this.match,
    required this.points,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final score = prov.getUserKnowledgeScore(user.id);
    final good = points > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: good
              ? [AppColors.lime.withOpacity(.12), AppColors.bg2]
              : [Colors.orange.withOpacity(.09), AppColors.bg2],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (good ? AppColors.lime : Colors.orange).withOpacity(.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(good ? '🔥' : '🧊', style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  points == 5
                      ? context.tr('SCORE EXACT : +5 PTS', 'EXACT SCORE: +5 PTS')
                      : points == 3
                          ? context.tr('BON RÉSULTAT : +3 PTS', 'RIGHT RESULT: +3 PTS')
                          : context.tr('PAS DE POINT SUR CE MATCH', 'NO POINTS ON THIS MATCH'),
                  style: GoogleFonts.spaceGrotesk(
                    color: good ? AppColors.lime : AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ReputationBadgeChip(
                badge: prov.reputationBadgeFor(user.id),
                compact: true,
              ),
            ],
          ),
          FootballKnowledgeMeter(
            score: score,
            played: prov.getUserResolvedVoteCount(user.id),
            correct: prov.getUserCorrectCount(user.id),
            currentStreak: prov.getUserCurrentStreak(user.id),
            goodForm: prov.getUserGoodForm(user.id),
          ),
          const SizedBox(height: 8),
          _MiniMatchRanking(matchId: match.id),
        ],
      ),
    );
  }
}

class _MiniMatchRanking extends StatelessWidget {
  final String matchId;
  const _MiniMatchRanking({required this.matchId});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final rows = prov.teamMatchRanking(matchId);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('CLASSEMENT DU MATCH', 'MATCH RANKING'),
          style: GoogleFonts.inter(
            color: AppColors.text2,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 7),
        ...rows.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final row = entry.value;
          final user = row['user'] as AppUser;
          final pts = row['points'] as int;
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '$rank.',
                    style: GoogleFonts.spaceGrotesk(
                        color: AppColors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                AvatarBubble(avatar: user.avatar, size: 22),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppColors.text2,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700)),
                ),
                Text(
                  '+$pts',
                  style: GoogleFonts.spaceGrotesk(
                      color: pts > 0 ? AppColors.lime : AppColors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w900),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
