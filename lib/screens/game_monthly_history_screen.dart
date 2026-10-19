import 'package:flutter/material.dart';
import '../data/game_month.dart';
import '../l10n/app_locale.dart';
import '../services/game_monthly_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/game_center_dashboard.dart';

class GameMonthlyHistoryScreen extends StatefulWidget {
  final GameMonthlySource source;
  final GameMonth current;
  final String userId;
  const GameMonthlyHistoryScreen(
      {super.key,
      required this.source,
      required this.current,
      required this.userId});
  @override
  State<GameMonthlyHistoryScreen> createState() =>
      _GameMonthlyHistoryScreenState();
}

class _GameMonthlyHistoryScreenState extends State<GameMonthlyHistoryScreen> {
  late Future<List<GameMonthlySnapshot>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.source.history(widget.current);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
          title: Text(context.tr('Historique des podiums', 'Podium history')),
          backgroundColor: AppColors.bg1,
          foregroundColor: AppColors.text),
      body: FutureBuilder<List<GameMonthlySnapshot>>(
          future: _future,
          builder: (context, state) {
            if (state.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.hasError)
              return Center(
                  child: TextButton.icon(
                      onPressed: () => setState(() {
                            _future = widget.source
                                .history(widget.current, refresh: true);
                          }),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.tr('Réessayer', 'Try again'))));
            final months = state.data ?? const [];
            if (months.isEmpty)
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                          context.tr('Les mois terminés apparaîtront ici.',
                              'Completed months will appear here.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.text2))));
            return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: months.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final month = months[index];
                  final rank = month.rankOf(widget.userId);
                  return GameDashboardCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                  month.month.label(
                                      Localizations.localeOf(context)
                                              .languageCode ==
                                          'fr'),
                                  style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900))),
                          if (rank != null)
                            Text(
                                '#$rank · ${month.player(widget.userId)!.points} pts',
                                style: const TextStyle(
                                    color: AppColors.lime,
                                    fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 12),
                        if (month.players.isEmpty)
                          Text(
                              context.tr('Aucun participant ce mois-ci.',
                                  'No participants this month.'),
                              style: TextStyle(color: AppColors.text2)),
                        for (var i = 0; i < month.players.length && i < 3; i++)
                          GameMonthlyPlayerRow(
                              player: month.players[i],
                              rank: i + 1,
                              highlight: month.players[i].id == widget.userId),
                        TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => GameMonthlyStandingsScreen(
                                        snapshot: month,
                                        userId: widget.userId))),
                            child:
                                Text(context.tr('Voir ce mois', 'View month'))),
                      ]));
                });
          }));
}

class GameMonthlyStandingsScreen extends StatelessWidget {
  final GameMonthlySnapshot snapshot;
  final String userId;
  const GameMonthlyStandingsScreen(
      {super.key, required this.snapshot, required this.userId});
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
          title: Text(snapshot.month
              .label(Localizations.localeOf(context).languageCode == 'fr')),
          backgroundColor: AppColors.bg1,
          foregroundColor: AppColors.text),
      body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.players.length + (snapshot.truncated ? 1 : 0),
          itemBuilder: (context, index) => index == snapshot.players.length
              ? Text(
                  context.tr('Les 500 premiers joueurs sont affichés.',
                      'Showing the top 500 players.'),
                  style: TextStyle(color: AppColors.text2))
              : GameMonthlyPlayerRow(
                  player: snapshot.players[index],
                  rank: index + 1,
                  highlight: snapshot.players[index].id == userId)));
}
