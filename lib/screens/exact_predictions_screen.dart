import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'match_detail_screen.dart';

class ExactPredictionsScreen extends StatelessWidget {
  const ExactPredictionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final uid = provider.currentUser?.id;
    final rows = uid == null
        ? <Map<String, dynamic>>[]
        : provider.getUserExactHistory(uid);
    return Scaffold(
        backgroundColor: AppColors.bg0,
        appBar: AppBar(
            title: Text(context.tr('Mes scores exacts', 'My exact scores'))),
        body: rows.isEmpty
            ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        context.tr(
                            'Tes pronostics de score exact apparaîtront ici.',
                            'Your exact score predictions will appear here.'),
                        textAlign: TextAlign.center)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final match = row['match'] as FootballMatch?;
                  final pick = row['prediction'] as MatchScore;
                  final score = row['score'] as MatchScore?;
                  final resolved = row['finished'] == true && score != null;
                  final correct = resolved &&
                      pick.homeScore == score.homeScore &&
                      pick.awayScore == score.awayScore;
                  final status = !resolved
                      ? context.tr('En attente', 'Pending')
                      : correct
                          ? context.tr('Réussi', 'Correct')
                          : context.tr('Manqué', 'Missed');
                  final color = !resolved
                      ? AppColors.text2
                      : correct
                          ? AppColors.lime
                          : AppColors.canadaRed;
                  return Card(
                      color: AppColors.bg2,
                      child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: match == null
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          MatchDetailScreen(match: match))),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        match == null
                                            ? context.tr('Match indisponible',
                                                'Match unavailable')
                                            : '${match.homeName ?? match.homeCode} – ${match.awayName ?? match.awayCode}',
                                        style: TextStyle(
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w800)),
                                    if (match != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                          DateFormat.yMMMd(context.isEnglish
                                                  ? 'en'
                                                  : 'fr')
                                              .add_Hm()
                                              .format(match.dateTime),
                                          style: TextStyle(
                                              color: AppColors.text2,
                                              fontSize: 12))
                                    ],
                                    const SizedBox(height: 12),
                                    Wrap(spacing: 20, runSpacing: 6, children: [
                                      Text(
                                          '${context.tr('Mon prono', 'My pick')} : ${pick.display}',
                                          style: TextStyle(
                                              color: AppColors.text,
                                              fontWeight: FontWeight.w700)),
                                      if (resolved)
                                        Text(
                                            '${context.tr('Score final', 'Final score')} : ${score.display}',
                                            style: TextStyle(
                                                color: AppColors.text2)),
                                    ]),
                                    const SizedBox(height: 8),
                                    Text(status,
                                        style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w700)),
                                  ]))));
                }));
  }
}
