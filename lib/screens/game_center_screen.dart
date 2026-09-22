import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_display.dart';
import '../widgets/wc26_background.dart';
import 'match_detail_screen.dart';

class GameCenterScreen extends StatelessWidget {
  const GameCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final user = prov.currentUser;
    if (user == null) return const SizedBox.shrink();

    final streak = prov.getUserDailyActivityStreak(user.id);
    final playedToday = prov.getUserHasPlayedToday(user.id);
    final xp = prov.getUserGameXp(user.id);
    final level = prov.getUserGameLevel(user.id);
    final xpInLevel = prov.getUserGameXpInLevel(user.id);
    final xpProgress = prov.getUserGameLevelProgress(user.id);
    final season = prov.currentGameSeason;
    final rank = prov.getUserGameSeasonRank(user.id, season);
    final seasonPoints = prov.getUserPointsInGameSeason(user.id, season);
    final recap = prov.getUserLatestGameRecap(user.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(context.tr('Centre de jeu', 'Game Center')),
        backgroundColor: AppColors.bg1,
        foregroundColor: AppColors.text,
      ),
      body: WC2026Background(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _progressCard(
              context,
              level: level,
              xp: xp,
              xpInLevel: xpInLevel,
              progress: xpProgress,
              streak: streak,
              playedToday: playedToday,
              canPlayToday: prov.hasPlayableTodayMatch,
            ),
            const SizedBox(height: 14),
            _sectionTitle(context, '🎯', context.tr('Missions du jour', 'Daily missions')),
            const SizedBox(height: 8),
            _missionsCard(context, prov, user.id),
            const SizedBox(height: 18),
            _sectionTitle(context, '🏆', context.tr('Saison PRONO4', 'PRONO4 season')),
            const SizedBox(height: 8),
            _seasonCard(
              context,
              season: season,
              rank: rank,
              points: seasonPoints,
              ranking: prov.getGameSeasonRanking(season),
            ),
            if (recap != null) ...[
              const SizedBox(height: 18),
              _sectionTitle(context, '📊', context.tr('Ton dernier bilan', 'Your latest recap')),
              const SizedBox(height: 8),
              _recapCard(context, recap),
            ],
            const SizedBox(height: 18),
            _sectionTitle(context, '⚔️', context.tr('Défis entre coéquipiers', 'Teammate challenges')),
            const SizedBox(height: 8),
            const _ChallengesPanel(),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(
    BuildContext context, {
    required int level,
    required int xp,
    required int xpInLevel,
    required double progress,
    required int streak,
    required bool playedToday,
    required bool canPlayToday,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lime.withOpacity(.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('NIVEAU JOUEUR $level', 'PLAYER LEVEL $level'),
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr(
                        '$xp XP gagnés grâce à tes pronostics',
                        '$xp XP earned from your predictions',
                      ),
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(maxWidth: 142),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  streak == 0
                      ? (canPlayToday
                          ? context.tr('🔥 Nouvelle série', '🔥 New streak')
                          : context.tr('🔥 Au prochain match', '🔥 Next match'))
                      : playedToday
                          ? context.tr('🔥 $streak jours', '🔥 $streak days')
                          : !canPlayToday
                              ? context.tr('🔥 $streak · protégée', '🔥 $streak · protected')
                              : context.tr('🔥 $streak · à sauver', '🔥 $streak · save it'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
              backgroundColor: AppColors.bg3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.lime),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Progression vers le niveau ${level + 1}', 'Progress to level ${level + 1}'),
                  style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10),
                ),
              ),
              Text(
                '$xpInLevel/${AppProvider.gameXpPerLevel} XP',
                style: GoogleFonts.inter(
                  color: AppColors.lime,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'XP : +10 par prono, +20 par bon résultat, +30 par score exact, bonus de régularité.',
              'XP: +10 per pick, +20 per correct result, +30 per exact score, plus consistency bonuses.',
            ),
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _missionsCard(BuildContext context, AppProvider prov, String userId) {
    final picks = prov.getUserTodayPredictionCount(userId);
    final target = prov.getUserTodayPredictionTarget(userId);
    final exactDone = prov.getUserHasTodayExactPick(userId);
    final duelDone = prov.getUserHasTodayDuelPick(userId);
    final duels = prov.todayGameDuels;

    final rows = <Widget>[];
    if (target > 0) {
      rows.add(_missionRow(
        context,
        icon: '🗳️',
        title: context.tr('Pronostique $target matchs du jour', 'Pick $target matches today'),
        subtitle: context.tr('Chaque prono fait avancer ton niveau.', 'Every pick moves your level forward.'),
        progress: picks.clamp(0, target).toInt(),
        target: target,
        done: picks >= target,
        onTap: picks >= target ? null : () => Navigator.of(context).pop(),
      ));
    }

    if (prov.hasPlayableTodayMatch || exactDone) {
      rows.add(_missionRow(
        context,
        icon: '🎯',
        title: context.tr('Tente un score exact', 'Try an exact score'),
        subtitle: context.tr('Le score exact rapporte aussi +2 points au classement.', 'An exact score also adds +2 ranking points.'),
        progress: exactDone ? 1 : 0,
        target: 1,
        done: exactDone,
        onTap: exactDone ? null : () => Navigator.of(context).pop(),
      ));
    }

    if (duels.isNotEmpty || duelDone) {
      rows.add(_missionRow(
        context,
        icon: '⚔️',
        title: context.tr('Joue le Duel du jour', 'Play today\'s Duel'),
        subtitle: context.tr('Les grosses affiches comptent dans ta routine gaming.', 'Big fixtures are part of your gaming routine.'),
        progress: duelDone ? 1 : 0,
        target: 1,
        done: duelDone,
        onTap: duelDone || duels.isEmpty
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchDetailScreen(match: duels.first),
                  ),
                ),
      ));
    }

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('😌', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr(
                  'Pas de mission impossible aujourd’hui. Reviens dès qu’un match est disponible : ta progression reste intacte.',
                  'No impossible mission today. Come back when a match is available: your progression stays intact.',
                ),
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Column(children: _withDividers(rows)),
    );
  }

  List<Widget> _withDividers(List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i += 1) {
      if (i > 0) {
        out.add(Divider(height: 18, color: AppColors.overlayBase.withOpacity(.08)));
      }
      out.add(rows[i]);
    }
    return out;
  }

  Widget _missionRow(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required int progress,
    required int target,
    required bool done,
    VoidCallback? onTap,
  }) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 36, child: Text(icon, style: const TextStyle(fontSize: 24))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10, height: 1.3),
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: target <= 0
                      ? 0
                      : (progress / target).clamp(0.0, 1.0).toDouble(),
                  minHeight: 6,
                  backgroundColor: AppColors.bg3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    done ? AppColors.lime : AppColors.usaBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          constraints: const BoxConstraints(minWidth: 46),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: (done ? AppColors.lime : AppColors.bg3).withOpacity(done ? .14 : 1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            done ? '✓' : '$progress/$target',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: done ? AppColors.lime : AppColors.text2,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: row,
        ),
      ),
    );
  }

  Widget _seasonCard(
    BuildContext context, {
    required GameSeasonWindow season,
    required int? rank,
    required int points,
    required List<Map<String, dynamic>> ranking,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withOpacity(.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _seasonChip(context.tr('Saison ${season.number}', 'Season ${season.number}'), AppColors.gold),
              _seasonChip(
                context.tr('${season.daysRemaining} j restants', '${season.daysRemaining} days left'),
                AppColors.usaBlue,
              ),
              _seasonChip(rank == null ? context.tr('Non classé', 'Unranked') : '#$rank', AppColors.lime),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            context.tr(
              '$points points sur cette saison de 4 semaines.',
              '$points points in this 4-week season.',
            ),
            style: GoogleFonts.inter(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.tr(
              'Le classement repart à zéro toutes les 4 semaines : même un nouveau joueur peut viser le podium.',
              'The leaderboard resets every 4 weeks, so even a new player can chase the podium.',
            ),
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10, height: 1.4),
          ),
          if (ranking.isNotEmpty) ...[
            const SizedBox(height: 13),
            Divider(height: 1, color: AppColors.overlayBase.withOpacity(.08)),
            const SizedBox(height: 10),
            Text(
              context.tr('PODIUM ACTUEL', 'CURRENT PODIUM'),
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 7),
            ...ranking.take(3).toList().asMap().entries.map((entry) {
              final row = entry.value;
              final user = row['user'] as AppUser;
              final rowPoints = row['points'] as int;
              const medals = ['🥇', '🥈', '🥉'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(medals[entry.key], style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$rowPoints pts',
                      style: GoogleFonts.inter(
                        color: AppColors.text2,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _seasonChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.11),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.24)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w900),
        ),
      );

  Widget _recapCard(BuildContext context, GameDayRecap recap) {
    final d = recap.date;
    final dateLabel = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Bilan du $dateLabel', 'Recap for $dateLabel'),
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _recapStat('🗳️', '${recap.played}', context.tr('pronos', 'picks')),
              _recapStat('✅', '${recap.correct}', context.tr('bons', 'correct')),
              _recapStat('🎯', '${recap.exact}', context.tr('exacts', 'exact')),
              _recapStat('⭐', '+${recap.points}', context.tr('points', 'points')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recapStat(String icon, String value, String label) => Container(
        constraints: const BoxConstraints(minWidth: 86),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                Text(label, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 9)),
              ],
            ),
          ],
        ),
      );

  Widget _sectionTitle(BuildContext context, String icon, String title) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      );
}

class _ChallengesPanel extends StatelessWidget {
  const _ChallengesPanel();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final me = prov.currentUser;
    final team = prov.myTeam;
    if (me == null) return const SizedBox.shrink();

    if (team == null || team.memberIds.where((id) => id != me.id).isEmpty) {
      return _infoBox(
        context,
        icon: '👥',
        text: context.tr(
          'Rejoins une équipe avec au moins un coéquipier pour lancer des défis 1 contre 1.',
          'Join a team with at least one teammate to start 1v1 challenges.',
        ),
      );
    }

    final authUid = prov.firebaseUid;
    if (authUid == null || authUid != me.id) {
      return _infoBox(
        context,
        icon: '🔄',
        text: context.tr(
          'Connexion du profil en cours. Les défis seront disponibles dans quelques secondes.',
          'Profile connection in progress. Challenges will be available in a few seconds.',
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openCreateChallenge(context, prov),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.lime,
              side: BorderSide(color: AppColors.lime.withOpacity(.40)),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.sports_kabaddi_rounded),
            label: Text(
              context.tr('DÉFIER UN COÉQUIPIER', 'CHALLENGE A TEAMMATE'),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('gameChallenges')
              .where('participants', arrayContains: me.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _infoBox(
                context,
                icon: '⚠️',
                text: context.tr(
                  'Les défis ne sont pas encore disponibles sur ce compte. Vérifie les règles Firestore BUILD74.',
                  'Challenges are not available on this account yet. Check BUILD74 Firestore rules.',
                ),
              );
            }
            final docs = snapshot.data?.docs.toList() ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            docs.sort((a, b) {
              final at = a.data()['createdAt'];
              final bt = b.data()['createdAt'];
              final ad = at is Timestamp ? at.millisecondsSinceEpoch : 0;
              final bd = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
              return bd.compareTo(ad);
            });
            if (docs.isEmpty) {
              return _infoBox(
                context,
                icon: '⚔️',
                text: context.tr(
                  'Aucun défi pour le moment. Choisis un coéquipier et un match : vos pronos habituels décideront du vainqueur.',
                  'No challenge yet. Pick a teammate and a match: your normal predictions decide the winner.',
                ),
              );
            }
            return Column(
              children: docs.take(8).map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _challengeCard(context, prov, doc),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  static Widget _infoBox(BuildContext context, {required String icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _challengeCard(
    BuildContext context,
    AppProvider prov,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final me = prov.currentUser!;
    final challengerId = (data['challengerId'] ?? '').toString();
    final opponentId = (data['opponentId'] ?? '').toString();
    final otherId = challengerId == me.id ? opponentId : challengerId;
    final status = (data['status'] ?? 'pending').toString();
    final matchId = (data['matchId'] ?? '').toString();
    final match = prov.matchById(matchId);
    final other = _findUser(prov, otherId);
    final resultReady = prov.results.containsKey(matchId);
    final expired = status == 'pending' &&
        (resultReady || (match != null && match.hasStarted));
    final incoming = opponentId == me.id && status == 'pending' && !expired;
    final myPoints = resultReady ? prov.getUserMatchPoints(me.id, matchId) : 0;
    final otherPoints = resultReady ? prov.getUserMatchPoints(otherId, matchId) : 0;

    String statusText;
    Color statusColor;
    if (status == 'declined') {
      statusText = context.tr('Refusé', 'Declined');
      statusColor = AppColors.grey;
    } else if (status == 'cancelled') {
      statusText = context.tr('Annulé', 'Cancelled');
      statusColor = AppColors.grey;
    } else if (status == 'pending' && expired) {
      statusText = context.tr('Expiré', 'Expired');
      statusColor = AppColors.grey;
    } else if (status == 'pending') {
      statusText = incoming
          ? context.tr('À toi de répondre', 'Your turn to answer')
          : context.tr('En attente', 'Waiting');
      statusColor = AppColors.gold;
    } else if (resultReady) {
      if (myPoints > otherPoints) {
        statusText = context.tr('🏆 Victoire', '🏆 Win');
        statusColor = AppColors.lime;
      } else if (myPoints < otherPoints) {
        statusText = context.tr('Défaite', 'Loss');
        statusColor = AppColors.canadaRed;
      } else {
        statusText = context.tr('Égalité', 'Draw');
        statusColor = AppColors.usaBlue;
      }
    } else {
      statusText = context.tr('Défi actif', 'Active challenge');
      statusColor = AppColors.lime;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarBubble(avatar: other?.avatar ?? '⚽', size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      other?.name ?? context.tr('Coéquipier', 'Teammate'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      match == null ? context.tr('Match indisponible', 'Match unavailable') : _matchLabel(match),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 104),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (status == 'active' && resultReady) ...[
            const SizedBox(height: 10),
            Text(
              context.tr(
                'Toi $myPoints pt${myPoints > 1 ? 's' : ''} · ${other?.name ?? 'Coéquipier'} $otherPoints pt${otherPoints > 1 ? 's' : ''}',
                'You $myPoints pt${myPoints > 1 ? 's' : ''} · ${other?.name ?? 'Teammate'} $otherPoints pt${otherPoints > 1 ? 's' : ''}',
              ),
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (incoming) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setChallengeStatus(context, doc.reference, 'declined'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text2,
                      side: BorderSide(color: AppColors.overlayBase.withOpacity(.12)),
                    ),
                    child: Text(context.tr('Refuser', 'Decline')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setChallengeStatus(context, doc.reference, 'active'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: const Color(0xFF101510),
                    ),
                    child: Text(context.tr('Accepter', 'Accept')),
                  ),
                ),
              ],
            ),
          ] else if (status == 'pending' && challengerId == me.id) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _setChallengeStatus(context, doc.reference, 'cancelled'),
                child: Text(context.tr('Annuler le défi', 'Cancel challenge')),
              ),
            ),
          ],
          if (status == 'active' && match != null && !match.hasStarted && !resultReady) ...[
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
                ),
                icon: const Icon(Icons.sports_soccer_rounded, size: 18),
                label: Text(context.tr('FAIRE / VOIR MON PRONO', 'MAKE / VIEW MY PICK')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static AppUser? _findUser(AppProvider prov, String uid) {
    for (final user in prov.users) {
      if (user.id == uid) return user;
    }
    return null;
  }

  static String _matchLabel(FootballMatch match) {
    final d = match.dateTime.toLocal();
    final home = match.homeName ?? match.homeCode;
    final away = match.awayName ?? match.awayCode;
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$home – $away · $date $time';
  }

  Future<void> _openCreateChallenge(BuildContext context, AppProvider prov) async {
    final me = prov.currentUser!;
    final team = prov.myTeam!;
    final teammates = team.memberIds
        .where((id) => id != me.id && !prov.isUserBlocked(id))
        .map((id) => _findUser(prov, id))
        .whereType<AppUser>()
        .toList();

    final matches = prov.visibleMatches
        .map(prov.resolveMatch)
        .where((m) => !m.isTBD && !m.hasStarted && !prov.results.containsKey(m.id))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (teammates.isEmpty || matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            teammates.isEmpty
                ? context.tr('Aucun coéquipier disponible.', 'No teammate available.')
                : context.tr('Aucun match à venir disponible.', 'No upcoming match available.'),
          ),
        ),
      );
      return;
    }

    AppUser? selectedUser = teammates.first;
    FootballMatch? selectedMatch = matches.first;
    var saving = false;
    final hostContext = context;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                18,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('⚔️ Nouveau défi', '⚔️ New challenge'),
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr(
                        'Le défi utilise vos pronostics PRONO4 habituels. Aucun double prono à saisir.',
                        'The challenge uses your normal PRONO4 picks. No duplicate pick to enter.',
                      ),
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AppUser>(
                      value: selectedUser,
                      isExpanded: true,
                      dropdownColor: AppColors.bg2,
                      decoration: InputDecoration(
                        labelText: context.tr('Coéquipier', 'Teammate'),
                        filled: true,
                        fillColor: AppColors.bg2,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: teammates.map((u) => DropdownMenuItem<AppUser>(
                        value: u,
                        child: Text(
                          u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.text),
                        ),
                      )).toList(),
                      onChanged: saving ? null : (value) => setModalState(() => selectedUser = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<FootballMatch>(
                      value: selectedMatch,
                      isExpanded: true,
                      dropdownColor: AppColors.bg2,
                      decoration: InputDecoration(
                        labelText: context.tr('Match', 'Match'),
                        filled: true,
                        fillColor: AppColors.bg2,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: matches.take(30).map((m) => DropdownMenuItem<FootballMatch>(
                        value: m,
                        child: Text(
                          _matchLabel(m),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.text),
                        ),
                      )).toList(),
                      onChanged: saving ? null : (value) => setModalState(() => selectedMatch = value),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving || selectedUser == null || selectedMatch == null
                            ? null
                            : () async {
                                setModalState(() => saving = true);
                                final error = await _createChallenge(
                                  prov,
                                  selectedUser!,
                                  selectedMatch!,
                                );
                                if (!context.mounted || !hostContext.mounted) return;
                                if (error == null) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(hostContext).showSnackBar(
                                    SnackBar(content: Text(hostContext.tr('Défi envoyé ⚔️', 'Challenge sent ⚔️'))),
                                  );
                                } else {
                                  setModalState(() => saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: const Color(0xFF101510),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: saving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.overlayBase,
                                ),
                              )
                            : const Icon(Icons.flash_on_rounded),
                        label: Text(
                          saving
                              ? context.tr('ENVOI…', 'SENDING…')
                              : context.tr('LANCER LE DÉFI', 'START CHALLENGE'),
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String?> _createChallenge(
    AppProvider prov,
    AppUser opponent,
    FootballMatch match,
  ) async {
    final me = prov.currentUser;
    if (me == null || prov.firebaseUid != me.id) return 'Profil non synchronisé.';
    if (match.hasStarted || prov.results.containsKey(match.id)) return 'Ce match a déjà commencé.';
    if (prov.myTeam?.memberIds.contains(opponent.id) != true) return 'Ce joueur n’est plus dans ton équipe.';

    final pair = <String>[me.id, opponent.id]..sort();
    final safeMatchId = match.id.replaceAll('/', '_');
    final docId = '${safeMatchId}__${pair[0]}__${pair[1]}';
    try {
      await FirebaseFirestore.instance.collection('gameChallenges').doc(docId).set({
        'challengerId': me.id,
        'opponentId': opponent.id,
        'participants': pair,
        'teamId': prov.myTeam?.id,
        'matchId': match.id,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? 'Défi refusé par Firestore. Déploie les règles BUILD74.'
          : 'Défi impossible : ${e.code}';
    } catch (_) {
      return 'Défi impossible. Vérifie Internet.';
    }
  }

  Future<void> _setChallengeStatus(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    try {
      await ref.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firestore : ${e.code}')),
      );
    }
  }
}
