import 'package:flutter/material.dart';
import '../data/game_month.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import 'avatar_display.dart';

class GameProgressHeader extends StatelessWidget {
  final int level, xp, xpInLevel, streak;
  final bool playedToday, canPlayToday;
  const GameProgressHeader(
      {super.key,
      required this.level,
      required this.xp,
      required this.xpInLevel,
      required this.streak,
      required this.playedToday,
      required this.canPlayToday});

  @override
  Widget build(BuildContext context) => GameDashboardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
              width: 66,
              height: 66,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                    child: CircularProgressIndicator(
                        value: (xpInLevel / 500).clamp(0.0, 1.0),
                        strokeWidth: 5,
                        backgroundColor: AppColors.bg3,
                        color: AppColors.lime)),
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('$level',
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 29,
                                color: AppColors.text,
                                fontWeight: FontWeight.w900)))),
              ])),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(context.tr('TON NIVEAU', 'YOUR LEVEL'),
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: AppColors.text2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(context.tr('Niveau $level', 'Level $level'),
                    style: TextStyle(
                        fontSize: 22,
                        color: AppColors.text,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('$xp XP',
                    style: TextStyle(color: AppColors.text2, fontSize: 12)),
              ])),
          IconButton(
              tooltip: context.tr('Comment gagner des XP', 'How to earn XP'),
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                          title: Text(
                              context.tr('Ta progression', 'Your progress')),
                          content: SingleChildScrollView(
                              child: Text(context.tr(
                                  'Prono : +10 XP\nBon résultat : +20 XP\nScore exact : +30 XP\n\nLe niveau progresse tous les 500 XP. La série compte tes jours de participation et reste protégée les jours sans match jouable. Ton niveau ne repart pas à zéro chaque mois.',
                                  'Pick: +10 XP\nCorrect result: +20 XP\nExact score: +30 XP\n\nLevel up every 500 XP. Your streak counts participating days and is protected when there is no playable match. Your level does not reset each month.'))),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(dialog),
                                child: Text(context.tr('Fermer', 'Close')))
                          ])),
              icon: Icon(Icons.info_outline_rounded,
                  color: AppColors.text2, size: 21)),
        ]),
        const SizedBox(height: 17),
        Row(children: [
          Expanded(
              child: Text(
                  context.tr('Vers le niveau ${level + 1}',
                      'Next: level ${level + 1}'),
                  style: TextStyle(fontSize: 11, color: AppColors.text2))),
          Text('$xpInLevel / 500 XP',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.lime,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: (xpInLevel / 500).clamp(0.0, 1.0),
                minHeight: 7,
                color: AppColors.lime,
                backgroundColor: AppColors.bg3)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _DashboardPill(
              icon: Icons.local_fire_department_rounded,
              text: streak > 0
                  ? context.tr('Série · $streak jours joués',
                      '$streak-day playing streak')
                  : context.tr('Nouvelle série', 'New streak'),
              color: const Color(0xFFD97425)),
          if (streak > 0 && !playedToday)
            _DashboardPill(
                icon: canPlayToday ? Icons.bolt_rounded : Icons.shield_outlined,
                text: canPlayToday
                    ? context.tr('À prolonger', 'Keep it going')
                    : context.tr('Série protégée', 'Streak protected'),
                color: AppColors.lime),
        ]),
      ]));
}

class GameMonthlyCard extends StatelessWidget {
  final GameMonth month;
  final GameMonthlySnapshot? snapshot;
  final String userId;
  final bool loading, hasError;
  final DateTime now;
  final VoidCallback onHistory, onStandings;
  const GameMonthlyCard(
      {super.key,
      required this.month,
      required this.snapshot,
      required this.userId,
      required this.loading,
      required this.hasError,
      required this.now,
      required this.onHistory,
      required this.onStandings});

  @override
  Widget build(BuildContext context) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final rank = snapshot?.rankOf(userId);
    final me = snapshot?.player(userId);
    return GameDashboardCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('CLASSEMENT DU MOIS', 'MONTHLY LEADERBOARD'),
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: AppColors.text2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(month.label(french),
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
        ])),
        Tooltip(
            message: context.tr('Historique des mois', 'Monthly history'),
            child: TextButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text(context.tr('Historique', 'History'),
                    style: const TextStyle(fontSize: 11)))),
      ]),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 7,
                children: [
              Text(snapshot == null ? '—' : '${me?.points ?? 0}',
                  style: TextStyle(
                      fontSize: 39,
                      height: 1.1,
                      color: AppColors.text,
                      fontWeight: FontWeight.w900)),
              Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(context.tr('points', 'points'),
                      style: TextStyle(color: AppColors.text2))),
            ])),
        _DashboardPill(
            icon: Icons.emoji_events_outlined,
            text: rank == null ? context.tr('Rang —', 'Rank —') : '#$rank',
            color: AppColors.lime),
      ]),
      const SizedBox(height: 14),
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
              value: month.progressAt(now),
              minHeight: 4,
              color: AppColors.usaBlue.withValues(alpha: .65),
              backgroundColor: AppColors.bg3)),
      const SizedBox(height: 7),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 5,
          children: [
            Text(
                context.tr(
                    'Du 1er au ${month.days}', 'From 1 to ${month.days}'),
                style: TextStyle(color: AppColors.text2, fontSize: 10)),
            Text(
                context.tr(
                    'Nouveau podium chaque mois', 'A new podium each month'),
                style: TextStyle(color: AppColors.text2, fontSize: 10)),
          ]),
      const SizedBox(height: 15),
      Divider(height: 1, color: AppColors.text2.withValues(alpha: .13)),
      const SizedBox(height: 12),
      if (snapshot == null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              if (loading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.cloud_sync_outlined,
                    color: AppColors.text2, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      hasError
                          ? context.tr(
                              'Classement indisponible. Réessaie avec Internet.',
                              'Ranking unavailable. Try again online.')
                          : loading
                              ? context.tr('Chargement du podium…',
                                  'Loading the podium…')
                              : context.tr(
                                  'Le classement du mois est en préparation.',
                                  'This month’s ranking is being prepared.'),
                      style: TextStyle(fontSize: 12, color: AppColors.text2))),
            ]))
      else if (snapshot!.players.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
                context.tr('Le mois commence. À toi de jouer !',
                    'A new month. Make your first pick!'),
                style: TextStyle(fontSize: 12, color: AppColors.text2)))
      else ...[
        for (var i = 0; i < snapshot!.players.length && i < 3; i++)
          GameMonthlyPlayerRow(
              player: snapshot!.players[i],
              rank: i + 1,
              highlight: snapshot!.players[i].id == userId),
        const SizedBox(height: 4),
        SizedBox(
            width: double.infinity,
            child: TextButton.icon(
                onPressed: onStandings,
                icon: const Icon(Icons.leaderboard_outlined, size: 17),
                label: Text(
                    context.tr('Voir le classement', 'View leaderboard')))),
      ],
    ]));
  }
}

class GameMonthlyPlayerRow extends StatelessWidget {
  final GameMonthlyPlayer player;
  final int rank;
  final bool highlight;
  const GameMonthlyPlayerRow(
      {super.key,
      required this.player,
      required this.rank,
      this.highlight = false});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
          color: highlight ? AppColors.lime.withValues(alpha: .08) : null,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        SizedBox(
            width: 23,
            child: Text(rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                style: TextStyle(
                    fontSize: rank <= 3 ? 18 : 12, color: AppColors.text2))),
        const SizedBox(width: 8),
        AvatarBubble(avatar: player.avatar, size: 29),
        const SizedBox(width: 9),
        Expanded(
            child: Text(player.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Text('${player.points}',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900)),
        const SizedBox(width: 3),
        Text('pts', style: TextStyle(color: AppColors.text2, fontSize: 10)),
      ]));
}

class GameDashboardCard extends StatelessWidget {
  final Widget child;
  const GameDashboardCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: AppColors.text2.withValues(alpha: .12))),
      child: child);
}

class GameMissionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final int progress, target;
  final bool done;
  final VoidCallback? onTap;
  const GameMissionTile(
      {super.key,
      required this.title,
      required this.icon,
      required this.progress,
      required this.target,
      required this.done,
      this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.usaBlue.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.usaBlue, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                          value: target == 0
                              ? 0
                              : (progress / target).clamp(0.0, 1.0),
                          minHeight: 5,
                          color: done ? AppColors.lime : AppColors.usaBlue,
                          backgroundColor: AppColors.bg3)),
                ])),
            const SizedBox(width: 12),
            if (done)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.lime, size: 25)
            else
              Text('$progress/$target',
                  style: TextStyle(
                      color: AppColors.text2,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
          ])));
}

class _DashboardPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _DashboardPill(
      {required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w800))),
      ]));
}
