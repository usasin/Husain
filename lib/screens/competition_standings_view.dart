import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/competitions_data.dart';
import '../theme/app_theme.dart';
import '../widgets/club_crest.dart';
import '../l10n/app_locale.dart';

class CompetitionStandingsView extends StatefulWidget {
  const CompetitionStandingsView({super.key});

  @override
  State<CompetitionStandingsView> createState() =>
      _CompetitionStandingsViewState();
}

class _CompetitionStandingsViewState extends State<CompetitionStandingsView> {
  String _selectedId = kCompetitions.first.id;

  CompetitionInfo get _selected => competitionById(_selectedId)!;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 43,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: kCompetitions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, index) {
              final comp = kCompetitions[index];
              final active = comp.id == _selectedId;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => _selectedId = comp.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.lime.withOpacity(.14)
                        : AppColors.bg2.withOpacity(.95),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? AppColors.lime.withOpacity(.55)
                          : Colors.white.withOpacity(.07),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(comp.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        comp.shortName,
                        style: GoogleFonts.inter(
                          color: active ? AppColors.lime : AppColors.text2,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('competitionStandings')
                .doc(_selectedId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.lime),
                );
              }

              final data = snapshot.data?.data();
              final rawRows = data?['rows'];
              final rows = rawRows is List
                  ? rawRows
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList()
                  : <Map<String, dynamic>>[];

              if (rows.isEmpty) {
                return _emptyState();
              }

              return _standingsList(data ?? const {}, rows);
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.lime.withOpacity(.10),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.lime.withOpacity(.26)),
              ),
              child: const Icon(Icons.table_rows_rounded,
                  size: 30, color: AppColors.lime),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('Classement ${_selected.name}','${competitionDisplayName(context, _selected)} standings'),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              context.tr('Le classement sera affiché après la première synchronisation.', 'Standings will appear after the first synchronization.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.text2,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _standingsList(
      Map<String, dynamic> data, List<Map<String, dynamic>> rows) {
    final season = data['season'];
    final seasonText = season == null ? '' : '$season/${(season as num).toInt() + 1}';
    final updatedAt = data['updatedAt'];
    String updated = '';
    if (updatedAt is Timestamp) {
      final dt = updatedAt.toDate().toLocal();
      updated =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 410;
        return ListView.builder(
          key: PageStorageKey<String>('standings_$_selectedId'),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 105),
          itemCount: rows.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.bg2.withOpacity(.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.07)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selected.color.withOpacity(.12),
                        borderRadius: BorderRadius.circular(13),
                        border:
                            Border.all(color: _selected.color.withOpacity(.25)),
                      ),
                      child: Text(_selected.emoji,
                          style: const TextStyle(fontSize: 21)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            competitionDisplayName(context, _selected),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (seasonText.isNotEmpty) context.tr('Saison $seasonText','Season $seasonText'),
                              if (updated.isNotEmpty) context.tr('MAJ $updated','Updated $updated'),
                            ].join(' · '),
                            style: GoogleFonts.inter(
                              color: AppColors.text2,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.sync_rounded,
                        color: AppColors.lime, size: 18),
                  ],
                ),
              );
            }

            if (index == 1) return _header(wide);
            return _row(rows[index - 2], wide);
          },
        );
      },
    );
  }

  Widget _header(bool wide) {
    final style = GoogleFonts.inter(
      color: AppColors.grey,
      fontSize: 9,
      fontWeight: FontWeight.w800,
    );
    return Container(
      height: 29,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(width: 25, child: Text('#', style: style)),
          Expanded(child: Text('CLUB', style: style)),
          _statHeader('J', style),
          if (wide) ...[
            _statHeader('G', style),
            _statHeader('N', style),
            _statHeader('P', style),
          ],
          _statHeader('DIFF', style, width: 42),
          _statHeader('PTS', style, width: 38),
        ],
      ),
    );
  }

  Widget _statHeader(String text, TextStyle style, {double width = 29}) =>
      SizedBox(
        width: width,
        child: Text(text, textAlign: TextAlign.center, style: style),
      );

  Widget _row(Map<String, dynamic> row, bool wide) {
    int n(String key) => (row[key] as num?)?.toInt() ?? 0;
    final position = n('position');
    final name = (row['shortName'] ?? row['teamName'] ?? 'Club').toString();
    final fullName = (row['teamName'] ?? name).toString();
    final diff = n('goalDifference');
    final points = n('points');
    final topZone = position > 0 && position <= 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: topZone
            ? AppColors.lime.withOpacity(.055)
            : AppColors.bg2.withOpacity(.92),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: topZone
              ? AppColors.lime.withOpacity(.16)
              : Colors.white.withOpacity(.055),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 25,
            child: Text(
              '$position',
              style: GoogleFonts.spaceGrotesk(
                color: topZone ? AppColors.lime : AppColors.text2,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                ClubCrest(
                  url: (row['crestUrl'] ?? '').toString(),
                  clubName: fullName,
                  size: 27,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _stat('${n('played')}'),
          if (wide) ...[
            _stat('${n('won')}'),
            _stat('${n('draw')}'),
            _stat('${n('lost')}'),
          ],
          _stat(diff > 0 ? '+$diff' : '$diff', width: 42),
          _stat('$points', width: 38, strong: true),
        ],
      ),
    );
  }

  Widget _stat(String value, {double width = 29, bool strong = false}) =>
      SizedBox(
        width: width,
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            color: strong ? AppColors.lime : AppColors.text2,
            fontSize: strong ? 12 : 10.5,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      );
}
