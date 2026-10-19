import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/competitions_data.dart';
import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'club_crest.dart';

class MatchStandingsCard extends StatefulWidget {
  final FootballMatch match;
  const MatchStandingsCard({super.key, required this.match});
  @override
  State<MatchStandingsCard> createState() => _MatchStandingsCardState();
}

class _MatchStandingsCardState extends State<MatchStandingsCard> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;
  bool _expanded = false;
  void _loadStream() => _stream = FirebaseFirestore.instance
      .collection('competitionStandings')
      .doc(widget.match.competitionId)
      .snapshots();
  @override
  void initState() {
    super.initState();
    _loadStream();
  }

  @override
  void didUpdateWidget(covariant MatchStandingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.competitionId != widget.match.competitionId) {
      _loadStream();
      _expanded = false;
    }
  }

  bool _isMatchClub(Map<String, dynamic> row) {
    String norm(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final codes = {norm(widget.match.homeCode), norm(widget.match.awayCode)}
      ..remove('');
    final names = {
      norm(widget.match.homeName ?? widget.match.homeCode),
      norm(widget.match.awayName ?? widget.match.awayCode),
    }..remove('');
    return codes.contains(norm((row['tla'] ?? '').toString())) ||
        names.contains(norm((row['teamName'] ?? '').toString())) ||
        names.contains(norm((row['shortName'] ?? '').toString()));
  }

  @override
  Widget build(BuildContext context) {
    final comp = competitionById(widget.match.competitionId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final data = snap.data?.data();
        final raw = data?['rows'];
        final rows = raw is List
            ? raw
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList()
            : <Map<String, dynamic>>[];
        rows.removeWhere(
          (r) => r['position'] is! num || (r['position'] as num) <= 0,
        );
        rows.sort(
          (a, b) => (a['position'] as num).compareTo(b['position'] as num),
        );
        final involved = rows.where(_isMatchClub).toList();
        final visible = _expanded
            ? rows
            : involved.isNotEmpty
                ? involved
                : rows.take(5).toList();
        final updatedAt = data?['updatedAt'];
        final updated =
            updatedAt is Timestamp ? updatedAt.toDate().toLocal() : null;
        final title = comp == null
            ? context.tr('Classement du championnat', 'League standings')
            : context.tr(
                'Classement ${competitionDisplayName(context, comp)}',
                '${competitionDisplayName(context, comp)} standings',
              );
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg1,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (updated != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.tr(
                      'Mis à jour le ${updated.day}/${updated.month}/${updated.year}',
                      'Updated ${updated.day}/${updated.month}/${updated.year}',
                    ),
                    style: TextStyle(color: AppColors.text2, fontSize: 10),
                  ),
                ),
              const SizedBox(height: 10),
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (rows.isEmpty)
                Text(
                  context.tr(
                    'Classement indisponible pour le moment.',
                    'Standings are currently unavailable.',
                  ),
                  style: TextStyle(color: AppColors.text2, fontSize: 12),
                )
              else ...[
                Row(
                  children: [
                    const SizedBox(width: 25, child: Text('#')),
                    Expanded(child: Text(context.tr('Club', 'Club'))),
                    SizedBox(
                      width: 32,
                      child: Text(
                        context.tr('J', 'P'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(context.tr('DIFF', 'GD'),
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(
                      width: 32,
                      child: Text('PTS', textAlign: TextAlign.center),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final row in visible) _row(row),
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded
                        ? context.tr('Voir les deux clubs', 'Show match clubs')
                        : context.tr(
                            'Voir le classement complet',
                            'View full standings',
                          ),
                  ),
                ),
              ],
              if (snap.hasError)
                Text(
                  context.tr(
                    'Vérifie la connexion pour actualiser le classement.',
                    'Check your connection to refresh standings.',
                  ),
                  style: TextStyle(color: AppColors.text2, fontSize: 11),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(Map<String, dynamic> row) {
    String stat(String key) =>
        row[key] is num ? (row[key] as num).toInt().toString() : '—';
    final selected = _isMatchClub(row);
    final name = (row['shortName'] ?? row['teamName'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.lime.withValues(alpha: .10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 25,
            child: Text(
              stat('position'),
              style: TextStyle(
                color: selected ? AppColors.lime : AppColors.text2,
              ),
            ),
          ),
          ClubCrest(
            url: (row['crestUrl'] ?? '').toString(),
            clubName: name,
            size: 22,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(stat('played'), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 36,
            child: Text(stat('goalDifference'), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 32,
            child: Text(
              stat('points'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
