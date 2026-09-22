import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ════════════════════════════════════════════════════════════
//  CALENDAR + LEADERBOARD + TEAM + PROFILE
//  All four screens live here for backward compatibility with
//  team_screen.dart / profile_screen.dart / leaderboard_screen.dart
//  which simply re-export from this file.
// ════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'support_screen.dart';
import 'admin_support_screen.dart';
import 'admin_content_screen.dart';
import 'admin_dynamic_pages_screen.dart';
import 'admin_community_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/anims.dart';
import '../providers/app_provider.dart';
import 'notification_settings_screen.dart';
import 'settings_screen.dart';
import 'team_chat_screen.dart';
import '../models/models.dart';
import '../data/matches_data.dart';
import '../data/teams_data.dart';
import '../data/competitions_data.dart';
import '../widgets/match_card.dart';
import '../widgets/wc26_background.dart';
import '../widgets/avatar_display.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/flag_widget.dart';
import '../widgets/dynamic_content_feed.dart';
import '../widgets/dynamic_pages_feed.dart';
import '../widgets/team_badge.dart';
import '../services/ad_service.dart';
import 'competition_standings_view.dart';
import '../widgets/reputation_badge.dart';
import '../widgets/language_settings_card.dart';
import '../widgets/theme_settings_card.dart';
import '../widgets/competition_settings_card.dart';
import '../l10n/app_locale.dart';

// ════════════════════════════════════════════════════════════
//  CALENDAR SCREEN
// ════════════════════════════════════════════════════════════
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  MatchPhase _phase = MatchPhase.groupe;
  String? _group = 'A';

  static const _phaseLabels = {
    MatchPhase.groupe: '⚽ Groupes',
    MatchPhase.seizieme: '⚔️ 1/16',
    MatchPhase.huitieme: '🎯 1/8',
    MatchPhase.quart: '🔥 1/4',
    MatchPhase.demi: '✨ 1/2',
    MatchPhase.troisieme: '🥉 3e place',
    MatchPhase.finale: '🏆 Finale',
  };

  List<FootballMatch> get _filtered {
    var ms = kMatches.where((m) => m.phase == _phase).toList();
    if (_phase == MatchPhase.groupe && _group != null) {
      ms = ms.where((m) => m.group == _group).toList();
    }
    return ms;
  }

  Map<String, List<FootballMatch>> get _byDate {
    final map = <String, List<FootballMatch>>{};
    for (final m in _filtered) {
      map.putIfAbsent(m.localDate, () => []).add(m);
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              pinned: true,
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withOpacity(0.88),
              expandedHeight: 0,
              title: Text('CALENDRIER DES MATCHS',
                  style: GoogleFonts.bebasNeue(letterSpacing: 2)),
              bottom: PreferredSize(
                preferredSize:
                    Size.fromHeight(_phase == MatchPhase.groupe ? 92 : 50),
                child: Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: MatchPhase.values.map((p) {
                          final sel = p == _phase;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _phase = p;
                                  _group = p == MatchPhase.groupe ? 'A' : null;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppColors.gold.withOpacity(0.15)
                                      : AppColors.overlayBase.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: sel
                                          ? AppColors.gold.withOpacity(0.5)
                                          : AppColors.overlayBase.withOpacity(0.08)),
                                ),
                                child: Text(_phaseLabels[p]!,
                                    style: GoogleFonts.barlowCondensed(
                                        color: sel
                                            ? AppColors.gold
                                            : AppColors.text2,
                                        fontWeight: sel
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        fontSize: 13)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (_phase == MatchPhase.groupe)
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [null, ...kGroups].map((g) {
                            final sel = g == _group;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: 5, bottom: 4),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _group = g);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.usaBlue.withOpacity(0.18)
                                        : AppColors.overlayBase.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: sel
                                            ? AppColors.usaBlue.withOpacity(0.5)
                                            : AppColors.overlayBase.withOpacity(0.08)),
                                  ),
                                  child: Text(g == null ? 'Tous' : 'Gr. $g',
                                      style: GoogleFonts.barlowCondensed(
                                          color: sel
                                              ? AppColors.usaBlue
                                              : AppColors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          body: Consumer<AppProvider>(
            builder: (context, provider, _) {
              final entries = _byDate.entries.toList();
              if (entries.isEmpty) {
                return Center(
                    child: Text('Aucun match',
                        style: GoogleFonts.barlowCondensed(
                          color: AppColors.grey,
                          fontSize: 16,
                        )));
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  if (_phase == MatchPhase.groupe && _group != null) ...[
                    _GroupStandingsCard(
                      group: _group!,
                      standings: provider.getGroupStandings(_group!),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MATCHS ET SCORES DU GROUPE ${_group!}',
                      style: GoogleFonts.bebasNeue(
                        color: AppColors.text,
                        fontSize: 18,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Le score saisi par l’administrateur apparaît directement au centre du match.',
                      style: GoogleFonts.barlowCondensed(
                        color: AppColors.text2,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else if (_phase == MatchPhase.groupe) ...[
                    _GroupSelectionHint(),
                    const SizedBox(height: 12),
                  ],
                  ...entries.map((e) {
                    final dt = DateTime.parse('${e.key}T12:00:00');
                    final label = _fmtDate(dt);
                    return Column(
                      key: ValueKey(
                          'date_${e.key}_${_group ?? 'all'}_${_phase.name}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: Container(
                                  height: 1,
                                  color: AppColors.overlayBase.withOpacity(0.06))),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.gold.withOpacity(0.10),
                                AppColors.usaBlue.withOpacity(0.10),
                              ]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.gold.withOpacity(0.25)),
                            ),
                            child: Text(label,
                                style: GoogleFonts.barlowCondensed(
                                    color: AppColors.gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Container(
                                  height: 1,
                                  color: AppColors.overlayBase.withOpacity(0.06))),
                        ]),
                        const SizedBox(height: 10),
                        ...e.value.map(
                          (m) => MatchCard(
                            key: ValueKey('match_${m.id}'),
                            match: provider.resolveMatch(m),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const months = [
      '',
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return '${days[dt.weekday]} ${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

class _GroupStandingsCard extends StatelessWidget {
  final String group;
  final List<GroupStanding> standings;

  const _GroupStandingsCard({
    required this.group,
    required this.standings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withOpacity(0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.06),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.gold.withOpacity(0.14),
              AppColors.usaBlue.withOpacity(0.08),
            ]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text(
              'CLASSEMENT GROUPE $group',
              style: GoogleFonts.bebasNeue(
                color: AppColors.text,
                fontSize: 20,
                letterSpacing: 1.5,
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(children: [
            _StandingHeader(),
            const SizedBox(height: 4),
            ...standings.asMap().entries.map((entry) {
              return _StandingRow(
                rank: entry.key + 1,
                standing: entry.value,
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

class _StandingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Text header(String value,
        {double? width, TextAlign align = TextAlign.center}) {
      return Text(
        value,
        textAlign: align,
        style: GoogleFonts.barlowCondensed(
          color: AppColors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    Widget fixed(String value, double width) => SizedBox(
          width: width,
          child: header(value),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(children: [
        fixed('#', 22),
        const SizedBox(width: 4),
        Expanded(child: header('ÉQUIPE', align: TextAlign.left)),
        fixed('J', 24),
        fixed('G', 24),
        fixed('N', 24),
        fixed('P', 24),
        fixed('+/-', 34),
        fixed('PTS', 34),
      ]),
    );
  }
}

class _StandingRow extends StatelessWidget {
  final int rank;
  final GroupStanding standing;

  const _StandingRow({
    required this.rank,
    required this.standing,
  });

  @override
  Widget build(BuildContext context) {
    final team = kTeams[standing.teamCode];
    final accent = rank <= 2
        ? AppColors.mexicoGreen
        : rank == 3
            ? AppColors.gold
            : AppColors.grey;

    Widget stat(String value, double width, {bool strong = false}) {
      return SizedBox(
        width: width,
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            color: strong ? AppColors.gold : AppColors.text2,
            fontSize: 12,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      );
    }

    final diff = standing.goalDifference;
    final diffText = diff > 0 ? '+$diff' : '$diff';

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(rank <= 3 ? 0.07 : 0.025),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(rank <= 3 ? 0.22 : 0.08)),
      ),
      child: Row(children: [
        SizedBox(
          width: 22,
          child: Text(
            '$rank',
            textAlign: TextAlign.center,
            style: GoogleFonts.bebasNeue(
              color: accent,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Row(children: [
            FlagWidget(
              flagCode: team?.flagCode ?? '',
              size: 23,
              fallbackEmoji: team?.emoji ?? '🌍',
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                team?.name ?? standing.teamCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.barlowCondensed(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
        ),
        stat('${standing.played}', 24),
        stat('${standing.wins}', 24),
        stat('${standing.draws}', 24),
        stat('${standing.losses}', 24),
        stat(diffText, 34),
        stat('${standing.points}', 34, strong: true),
      ]),
    );
  }
}

class _GroupSelectionHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.usaBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.usaBlue.withOpacity(0.22)),
      ),
      child: Row(children: [
        const Icon(Icons.touch_app_rounded, color: AppColors.usaBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Choisis un groupe en haut pour afficher son classement et ses scores.',
            style: GoogleFonts.barlowCondensed(
              color: AppColors.text2,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  LEADERBOARD SCREEN
// ════════════════════════════════════════════════════════════
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _period = 'general';

  Duration? get _rankingPeriod {
    if (_period == 'week') return const Duration(days: 7);
    if (_period == 'month') return const Duration(days: 30);
    return null;
  }
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final individuals = prov.getIndividualRanking(period: _rankingPeriod);
    final teams = prov.getTeamRanking(period: _rankingPeriod);
    final resultCount = prov.matches
        .where((match) => prov.results.containsKey(match.id))
        .length;

    // Important : on évite NestedScrollView ici.
    // Les onglets Individuel / Équipe ont chacun leur propre scroll.
    // Avec NestedScrollView + TabBarView, Flutter peut garder un drag actif au
    // moment où l'onglet est détruit, ce qui provoque :
    // "Looking up a deactivated widget's ancestor is unsafe" ou
    // "activity!.isScrolling is not true".
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.88),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 52,
                      child: Center(
                        child: Text(
                          context.tr('CLASSEMENT','RANKING'),
                          style: GoogleFonts.bebasNeue(
                            color: AppColors.text,
                            fontSize: 24,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _tab,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.gold,
                      unselectedLabelColor: AppColors.grey,
                      indicatorColor: AppColors.gold,
                      indicatorWeight: 2.5,
                      labelStyle: GoogleFonts.barlowCondensed(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      tabs: [
                        Tab(text: context.tr('🏆 Top équipes (${teams.length})','🏆 Top teams (${teams.length})')),
                        Tab(text: context.tr('👤 Top membres (${individuals.length})','👤 Top members (${individuals.length})')),
                        Tab(text: context.tr('⚽ Championnats','⚽ Leagues')),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
                      child: Row(
                        children: [
                          _periodChip('general', context.tr('Général', 'Overall')),
                          const SizedBox(width: 7),
                          _periodChip('week', context.tr('Semaine', 'Week')),
                          const SizedBox(width: 7),
                          _periodChip('month', context.tr('Mois', 'Month')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const ClampingScrollPhysics(),
                children: [
                  _buildTeams(prov, teams),
                  _buildIndividuals(prov, individuals, resultCount),
                  const CompetitionStandingsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String id, String label) {
    final selected = _period == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _period = id),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.lime : AppColors.overlayBase.withOpacity(.035),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.lime : AppColors.overlayBase.withOpacity(.06)),
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              color: selected ? AppColors.bg0 : AppColors.text2,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndividuals(
      AppProvider prov, List<Map<String, dynamic>> data, int resultCount) {
    if (data.isEmpty) return _empty('👤', context.tr('Aucun joueur inscrit','No players yet'));
    return ListView(
      key: const PageStorageKey<String>('leaderboard_individuals_scroll'),
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (data.length >= 3)
          Appear(
              child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _podiumBlock(data[1], 2, 90, prov),
                const SizedBox(width: 8),
                _podiumBlock(data[0], 1, 120, prov),
                const SizedBox(width: 8),
                _podiumBlock(data[2], 3, 70, prov),
              ],
            ),
          )),
        ...data.asMap().entries.map((e) {
          final rank = e.key + 1;
          final u = e.value['user'] as AppUser;
          final pts = e.value['points'] as int;
          final votes = e.value['votes'] as int;
          final isMe = u.id == prov.currentUser?.id;
          return Appear(
              order: e.key,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      isMe ? AppColors.gold.withOpacity(0.10) : AppColors.bg3,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isMe
                          ? AppColors.gold.withOpacity(0.30)
                          : AppColors.overlayBase.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    _medalWidget(rank),
                    const SizedBox(width: 10),
                    AvatarBubble(
                      avatar: u.avatar,
                      size: 42,
                      ringColor: isMe ? AppColors.gold : AppColors.ringNeutral,
                      ringWidth: isMe ? 2 : 1,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                              child: Text(u.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.barlowCondensed(
                                      color: isMe
                                          ? AppColors.gold
                                          : AppColors.text,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15))),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                  color: AppColors.gold.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(context.tr('MOI','ME'),
                                  style: GoogleFonts.barlowCondensed(
                                      color: AppColors.gold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ]),
                        Text('$votes vote${votes != 1 ? "s" : ""}',
                            style: GoogleFonts.barlowCondensed(
                                color: AppColors.text2, fontSize: 12)),
                        const SizedBox(height: 4),
                        ReputationBadgeChip(badge: prov.getAutoReputationBadge(u.id), compact: true),
                      ],
                    )),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$pts',
                            style: GoogleFonts.bebasNeue(
                                color: rank == 1
                                    ? AppColors.gold
                                    : rank == 2
                                        ? const Color(0xFFC0C0C0)
                                        : rank == 3
                                            ? const Color(0xFFCD7F32)
                                            : AppColors.text,
                                fontSize: 26,
                                height: 1)),
                        Text('pts',
                            style: GoogleFonts.barlowCondensed(
                                color: AppColors.text2, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ));
        }),
      ],
    );
  }

  Widget _podiumBlock(
      Map<String, dynamic> data, int rank, double height, AppProvider prov) {
    final u = data['user'] as AppUser;
    final pts = data['points'] as int;
    final colors = {
      1: AppColors.gold,
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32)
    };
    final c = colors[rank]!;
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    return Expanded(
        child: Column(
      children: [
        Pulse(
          enabled: rank == 1,
          child: AvatarBubble(
            avatar: u.avatar,
            size: rank == 1 ? 56 : 46,
            ringColor: c,
            ringWidth: 2,
            showGlow: rank == 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(u.name,
            style: GoogleFonts.barlowCondensed(
                color: u.id == prov.currentUser?.id
                    ? AppColors.gold
                    : AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        Text('$pts pts', style: GoogleFonts.bebasNeue(color: c, fontSize: 14)),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.withOpacity(0.30), c.withOpacity(0.08)]),
            border: Border.all(color: c.withOpacity(0.40)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Text(medals[rank]!, style: const TextStyle(fontSize: 22)),
        ),
      ],
    ));
  }

  Widget _teamIconWidget(AppTeam team, double size) {
    final raw = team.imageB64.trim();
    if (raw.isNotEmpty) {
      try {
        final bytes = base64Decode(raw);
        return ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => TeamBadge(team: team, size: size),
            ),
          ),
        );
      } catch (_) {
        // Fallback on the generated team badge when no valid team image exists.
      }
    }
    return TeamBadge(team: team, size: size);
  }

  Widget _teamPodiumBlock(
      Map<String, dynamic> data, int rank, double height, AppProvider prov) {
    final team = data['team'] as AppTeam;
    final pts = data['points'] as double;
    final colors = {
      1: AppColors.gold,
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    final c = colors[rank]!;
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final isMine = team.id == prov.currentUser?.teamId;
    return Expanded(
      child: Column(
        children: [
          Text(medals[rank]!, style: TextStyle(fontSize: rank == 1 ? 26 : 20)),
          const SizedBox(height: 4),
          Pulse(
            enabled: rank == 1,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c, width: 2),
              ),
              child: _teamIconWidget(team, rank == 1 ? 52 : 42),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.barlowCondensed(
              color: isMine ? AppColors.mexicoGreen : AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.withOpacity(0.85), c.withOpacity(0.30)],
              ),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pts.toStringAsFixed(1),
                  style: GoogleFonts.bebasNeue(
                    color: const Color(0xFF1A1A1A),
                    fontSize: rank == 1 ? 28 : 22,
                    height: 1,
                  ),
                ),
                Text(
                  context.tr('moy.','avg.'),
                  style: GoogleFonts.barlowCondensed(
                    color: const Color(0xFF1A1A1A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeams(AppProvider prov, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return _empty('🛡️', context.tr('Aucune équipe créée','No teams yet'));
    return ListView.separated(
      key: const PageStorageKey<String>('leaderboard_teams_scroll'),
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: data.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        if (idx == 0) {
          if (data.length < 3) return const SizedBox.shrink();
          return Appear(
              child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _teamPodiumBlock(data[1], 2, 90, prov),
                const SizedBox(width: 8),
                _teamPodiumBlock(data[0], 1, 120, prov),
                const SizedBox(width: 8),
                _teamPodiumBlock(data[2], 3, 70, prov),
              ],
            ),
          ));
        }
        final i = idx - 1;
        final rank = i + 1;
        final team = data[i]['team'] as AppTeam;
        final pts = data[i]['points'] as double;
        final members = data[i]['members'] as List<AppUser>;
        final isMyTeam = team.id == prov.currentUser?.teamId;
        final medals = {1: '🥇', 2: '🥈', 3: '🥉'};

        return Appear(
            order: i,
            child: Container(
              decoration: BoxDecoration(
                color: isMyTeam
                    ? AppColors.mexicoGreen.withOpacity(0.10)
                    : AppColors.bg3,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isMyTeam
                        ? AppColors.mexicoGreen.withOpacity(0.30)
                        : AppColors.overlayBase.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Text(medals[rank] ?? '$rank',
                            style: TextStyle(fontSize: rank <= 3 ? 22 : 16)),
                        const SizedBox(width: 10),
                        _teamIconWidget(team, 40),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                  child: Text(team.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.bebasNeue(
                                          color: isMyTeam
                                              ? AppColors.mexicoGreen
                                              : AppColors.text,
                                          fontSize: 18,
                                          letterSpacing: 0.8))),
                              if (isMyTeam) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: AppColors.mexicoGreen
                                          .withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text(context.tr('MON ÉQUIPE','MY TEAM'),
                                      style: GoogleFonts.barlowCondensed(
                                          color: AppColors.mexicoGreen,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ]),
                            Text(context.isEnglish ? '${team.memberIds.length}/4 members' : '${team.memberIds.length}/4 membres',
                                style: GoogleFonts.barlowCondensed(
                                    color: AppColors.text2, fontSize: 12)),
                          ],
                        )),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(pts.toStringAsFixed(1),
                                style: GoogleFonts.bebasNeue(
                                    color: rank == 1
                                        ? AppColors.gold
                                        : rank == 2
                                            ? const Color(0xFFC0C0C0)
                                            : rank == 3
                                                ? const Color(0xFFCD7F32)
                                                : AppColors.text,
                                    fontSize: 26,
                                    height: 1)),
                            Text(context.tr('moy.','avg.'),
                                style: GoogleFonts.barlowCondensed(
                                    color: AppColors.text2, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x0AFFFFFF))),
                    ),
                    child: Row(
                      children: members.asMap().entries.map((e) {
                        final m = e.value;
                        return Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: e.key < members.length - 1
                                  ? const Border(
                                      right:
                                          BorderSide(color: Color(0x0AFFFFFF)))
                                  : null,
                            ),
                            child: Column(
                              children: [
                                AvatarBubble(avatar: m.avatar, size: 32),
                                const SizedBox(height: 3),
                                Text(m.name,
                                    style: GoogleFonts.barlowCondensed(
                                        color: AppColors.text2, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ));
      },
    );
  }

  Widget _empty(String icon, String text) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(text,
            style: GoogleFonts.barlowCondensed(
                color: AppColors.grey, fontSize: 16)),
      ],
    ));
  }

  Widget _medalWidget(int rank) {
    if (rank == 1) return const Text('🥇', style: TextStyle(fontSize: 22));
    if (rank == 2) return const Text('🥈', style: TextStyle(fontSize: 22));
    if (rank == 3) return const Text('🥉', style: TextStyle(fontSize: 22));
    return SizedBox(
        width: 24,
        child: Text('$rank',
            textAlign: TextAlign.center,
            style: GoogleFonts.bebasNeue(color: AppColors.grey, fontSize: 18)));
  }
}

// ════════════════════════════════════════════════════════════
//  TEAM SCREEN
// ════════════════════════════════════════════════════════════
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String? _mode;
  String _teamSection = 'code';
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _feedback;
  bool _isError = false;
  bool _busy = false;

  Future<void> _showMemberProfileActions(
    BuildContext context,
    AppProvider prov,
    AppUser member,
  ) async {
    if (member.id == prov.currentUser?.id) return;
    final blocked = prov.isUserBlocked(member.id);
    final played = prov.getUserResolvedVoteCount(member.id);
    final correct = prov.getUserCorrectCount(member.id);
    final accuracy = played == 0 ? 0 : ((correct * 100) / played).round();

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                AvatarBubble(avatar: member.avatar, size: 52, showGlow: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name,
                          style: GoogleFonts.spaceGrotesk(
                              color: AppColors.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 5, children: [
                        ReputationBadgeChip(
                            badge: prov.getAutoReputationBadge(member.id), compact: true),
                      ]),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Text(
                context.tr(
                  '$played pronos terminés · $accuracy% de réussite',
                  '$played completed picks · $accuracy% accuracy',
                ),
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.overlayBase.withOpacity(.04),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(blocked ? Icons.visibility_off_rounded : Icons.block_rounded,
                      color: blocked ? AppColors.mexicoGreen : AppColors.canadaRed,
                      size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      blocked
                          ? context.tr(
                              'Ce joueur est bloqué : ses messages sont masqués pour toi. Tu peux le débloquer à tout moment.',
                              'This player is blocked: their messages are hidden for you. You can unblock them anytime.',
                            )
                          : context.tr(
                              'Bloquer masque ses messages pour toi. Le joueur reste dans l’équipe et n’est pas averti.',
                              'Blocking hides their messages for you. The player stays in the team and is not notified.',
                            ),
                      style: GoogleFonts.inter(
                          color: AppColors.text2, fontSize: 10.5, height: 1.35),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, blocked ? 'unblock' : 'block'),
                  icon: Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded),
                  label: Text(blocked
                      ? context.tr('DÉBLOQUER', 'UNBLOCK')
                      : context.tr('BLOQUER CE JOUEUR', 'BLOCK THIS PLAYER')),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        blocked ? AppColors.mexicoGreen : AppColors.canadaRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null || !context.mounted) return;
    if (action == 'block') {
      final error = await prov.blockUser(member.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? context.tr(
          '${member.name} est bloqué. Ses messages seront masqués.',
          '${member.name} is blocked. Their messages will be hidden.',
        )),
      ));
    } else {
      await prov.unblockUser(member.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('${member.name} est débloqué.', '${member.name} is unblocked.')),
      ));
    }
  }

  Widget _teamHeaderBackground(AppTeam team) {
    final raw = team.imageB64.trim();
    Uint8List? bytes;
    if (raw.isNotEmpty) {
      try {
        bytes = base64Decode(raw);
      } catch (_) {
        bytes = null;
      }
    }
    if (bytes == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.lime.withOpacity(0.18),
            AppColors.lime.withOpacity(0.05),
            Theme.of(context).scaffoldBackgroundColor,
          ]),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(.12),
                Colors.black.withOpacity(.72),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final myTeam = prov.myTeam;
    if (myTeam != null) return _buildMyTeam(context, prov, myTeam);
    return _buildNoTeam(context, prov);
  }

  Widget _buildMyTeam(BuildContext context, AppProvider prov, AppTeam team) {
    final members = team.memberIds
        .map((id) => prov.users.firstWhere((u) => u.id == id,
            orElse: () => const AppUser(id: '', name: '?', avatar: '❓')))
        .where((u) => u.id.isNotEmpty)
        .toList();

    int correctFor(AppUser user) => prov.getUserCorrectCount(user.id);
    int playedFor(AppUser user) => prov.getUserResolvedVoteCount(user.id);

    final rankedMembers = [...members]..sort((a, b) {
        final byPoints =
            prov.getUserPoints(b.id).compareTo(prov.getUserPoints(a.id));
        if (byPoints != 0) return byPoints;
        final byCorrect = correctFor(b).compareTo(correctFor(a));
        if (byCorrect != 0) return byCorrect;
        return prov
            .getUserVoteCount(b.id)
            .compareTo(prov.getUserVoteCount(a.id));
      });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor:
                Theme.of(context).colorScheme.surface.withOpacity(0.88),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(team.name,
                  style: GoogleFonts.bebasNeue(letterSpacing: 1.5)),
              background: _teamHeaderBackground(team),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              _teamQuickSections(context, prov, team, members),
              const SizedBox(height: 14),
              _weeklyChallenge(context, prov, rankedMembers),
              const SizedBox(height: 20),
              Text(context.tr('CLASSEMENT INTERNE','TEAM RANKING'),
                  style: GoogleFonts.bebasNeue(
                      color: AppColors.text, fontSize: 20, letterSpacing: 1.6)),
              const SizedBox(height: 10),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.overlayBase.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.usaBlue.withOpacity(0.24),
                          AppColors.mexicoGreen.withOpacity(0.14),
                        ],
                      ),
                    ),
                    child: Row(children: [
                      SizedBox(
                          width: 34,
                          child: Text('#',
                              style: GoogleFonts.barlowCondensed(
                                  color: AppColors.text2,
                                  fontWeight: FontWeight.w800))),
                      Expanded(
                          child: Text(context.tr('JOUEUR','PLAYER'),
                              style: GoogleFonts.barlowCondensed(
                                  color: AppColors.text2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8))),
                      SizedBox(
                          width: 34,
                          child: Text('J',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.barlowCondensed(
                                  color: AppColors.text2,
                                  fontWeight: FontWeight.w800))),
                      SizedBox(
                          width: 34,
                          child: Text('B',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.barlowCondensed(
                                  color: AppColors.text2,
                                  fontWeight: FontWeight.w800))),
                      SizedBox(
                          width: 46,
                          child: Text('PTS',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.barlowCondensed(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w900))),
                    ]),
                  ),
                  ...rankedMembers.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final member = entry.value;
                    final isMe = member.id == prov.currentUser?.id;
                    final points = prov.getUserPoints(member.id);
                    final played = playedFor(member);
                    final correct = correctFor(member);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.gold.withOpacity(0.10)
                            : (rank.isEven
                                ? AppColors.overlayBase.withOpacity(0.025)
                                : Colors.transparent),
                        border: Border(
                          top:
                              BorderSide(color: AppColors.overlayBase.withOpacity(0.06)),
                        ),
                      ),
                      child: Row(children: [
                        SizedBox(
                          width: 34,
                          child: rank <= 3
                              ? Text(['🥇', '🥈', '🥉'][rank - 1],
                                  style: const TextStyle(fontSize: 19))
                              : Text('$rank',
                                  style: GoogleFonts.bebasNeue(
                                      color: AppColors.text2, fontSize: 18)),
                        ),
                        AvatarBubble(
                          avatar: member.avatar,
                          size: 34,
                          ringColor: isMe ? AppColors.gold : AppColors.ringNeutral,
                          ringWidth: isMe ? 1.8 : 1,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: InkWell(
                            onTap: isMe
                                ? null
                                : () => _showMemberProfileActions(
                                    context, prov, member),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                    member.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.barlowCondensed(
                                      color: isMe ? AppColors.gold : AppColors.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (!isMe)
                                  Icon(Icons.more_horiz_rounded,
                                      size: 15, color: AppColors.grey),
                              ]),
                            ),
                          ),
                        ),
                        SizedBox(
                            width: 34,
                            child: Text('$played',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.barlowCondensed(
                                    color: AppColors.text2, fontSize: 13))),
                        SizedBox(
                            width: 34,
                            child: Text('$correct',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.barlowCondensed(
                                    color: AppColors.mexicoGreen,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800))),
                        SizedBox(
                            width: 46,
                            child: Text('$points',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.bebasNeue(
                                    color: AppColors.gold, fontSize: 20))),
                      ]),
                    );
                  }),
                ]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('J = pronostics terminés · B = bons pronostics',
                    style: GoogleFonts.barlowCondensed(
                        color: AppColors.grey, fontSize: 11)),
              ),
              const SizedBox(height: 22),
              Text(context.tr('EFFECTIF','SQUAD'),
                  style: GoogleFonts.bebasNeue(
                      color: AppColors.text, fontSize: 18, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              ...rankedMembers.map((m) {
                final pts = prov.getUserPoints(m.id);
                final isMe = m.id == prov.currentUser?.id;
                final isCreator = m.id == team.createdBy;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        isMe ? AppColors.gold.withOpacity(0.10) : AppColors.bg3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isMe
                            ? AppColors.gold.withOpacity(0.30)
                            : AppColors.overlayBase.withOpacity(0.06)),
                  ),
                  child: Row(children: [
                    AvatarBubble(
                      avatar: m.avatar,
                      size: 46,
                      ringColor: isMe ? AppColors.gold : AppColors.ringNeutral,
                      ringWidth: isMe ? 2 : 1,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                              child: Text(m.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.barlowCondensed(
                                      color: isMe
                                          ? AppColors.gold
                                          : AppColors.text,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15))),
                          if (isMe) _chip('MOI', AppColors.gold),
                          if (isCreator) _chip('CAP.', AppColors.usaBlue),
                        ]),
                        Text(context.isEnglish ? '${prov.getUserVoteCount(m.id)} picks' : '${prov.getUserVoteCount(m.id)} votes',
                            style: GoogleFonts.barlowCondensed(
                                color: AppColors.text2, fontSize: 12)),
                        const SizedBox(height: 5),
                        Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          ReputationBadgeChip(badge: prov.getAutoReputationBadge(m.id), compact: true),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.lime.withOpacity(.07),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.lime.withOpacity(.18)),
                            ),
                            child: Text('${prov.getUserKnowledgeScore(m.id)}/100', style: GoogleFonts.inter(color: AppColors.lime,fontSize:8.5,fontWeight:FontWeight.w900)),
                          ),
                        ]),
                      ],
                    )),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$pts',
                            style: GoogleFonts.bebasNeue(
                                color: AppColors.gold,
                                fontSize: 24,
                                height: 1)),
                        Text('pts',
                            style: GoogleFonts.barlowCondensed(
                                color: AppColors.text2, fontSize: 10)),
                      ],
                    ),
                  ]),
                );
              }),
              ...List.generate(
                  4 - members.length,
                  (i) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.overlayBase.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: AppColors.overlayBase.withOpacity(0.08)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.overlayBase.withOpacity(0.15)),
                            ),
                            alignment: Alignment.center,
                            child:  Icon(Icons.add_rounded,
                                color: AppColors.grey, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                context.tr('Place disponible — code : ${team.code}', 'Open spot — code: ${team.code}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.barlowCondensed(
                                    color: AppColors.grey, fontSize: 13)),
                          ),
                        ]),
                      )),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.bg2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text(context.tr("Quitter l'équipe ?",'Leave the team?'),
                          style: GoogleFonts.bebasNeue(
                              color: AppColors.text, letterSpacing: 1)),
                      content: Text(
                          context.tr('Vous perdrez votre place dans "${team.name}".', 'You will lose your spot in "${team.name}".'),
                          style: GoogleFonts.barlow(color: AppColors.text2)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.tr('Annuler','Cancel'))),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.canadaRed),
                            child: Text(context.tr('Quitter','Leave'))),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  bool success = false;
                  try {
                    success = await context.read<AppProvider>().leaveTeam();
                  } catch (_) {
                    success = false;
                  }
                  if (!context.mounted) return;
                  if (!success) {
                    messenger.showSnackBar(SnackBar(
                      content: Text(
                          "Impossible de quitter l'équipe. Vérifiez votre connexion.",
                          style: GoogleFonts.barlowCondensed()),
                      backgroundColor: AppColors.canadaRed,
                    ));
                  }
                },
                icon: const Icon(Icons.exit_to_app_rounded,
                    color: AppColors.canadaRed),
                label: Text(context.tr("Quitter l'équipe",'Leave team'),
                    style: GoogleFonts.barlowCondensed(
                        color: AppColors.canadaRed, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.canadaRed.withOpacity(0.3))),
              ),
            ])),
          ),
        ]),
      ),
    );
  }


  Widget _teamQuickSections(
    BuildContext context,
    AppProvider prov,
    AppTeam team,
    List<AppUser> members,
  ) {
    const canEditTeamImage = true; // Any current team member can update the team photo.

    ChoiceChip tab({
      required String keyName,
      required String label,
      required IconData icon,
      required Color color,
    }) {
      final selected = _teamSection == keyName;
      return ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _teamSection = keyName),
        avatar: Icon(icon, size: 17, color: selected ? AppColors.bg0 : color),
        label: Text(label),
        selectedColor: color,
        backgroundColor: AppColors.bg2,
        side: BorderSide(
          color: selected ? color : AppColors.overlayBase.withOpacity(.10),
        ),
        labelStyle: GoogleFonts.barlowCondensed(
          color: selected ? AppColors.bg0 : AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('MON ÉQUIPE', 'MY TEAM'),
          style: GoogleFonts.bebasNeue(
            color: AppColors.text,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: _TeamImagePicker(team: team, canEdit: canEditTeamImage),
        ),
        if (canEditTeamImage) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              context.tr(
                'Appuie sur la photo pour modifier l’image de l’équipe',
                'Tap the photo to change the team image',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.text2,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            tab(
              keyName: 'code',
              label: context.tr("Code d'invitation", 'Invite code'),
              icon: Icons.key_rounded,
              color: AppColors.gold,
            ),
            StreamBuilder<CommunitySettings>(
              stream: prov.communitySettingsStream(),
              builder: (context, snap) {
                final settings = snap.data ?? const CommunitySettings();
                if (!settings.teamChatEnabled) return const SizedBox.shrink();
                return ActionChip(
                  avatar: const Icon(Icons.forum_rounded, size: 17, color: AppColors.lime),
                  label: Text(context.tr('Chat équipe', 'Team chat')),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TeamChatScreen()),
                  ),
                  backgroundColor: AppColors.bg2,
                  side: BorderSide(color: AppColors.lime.withOpacity(.28)),
                  labelStyle: GoogleFonts.barlowCondensed(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _teamSection == 'code'
              ? _inviteCodeCard(context, team, members)
              : const SizedBox.shrink(),
        ),
        if (team.createdBy == prov.currentUser?.id) ...[
          const SizedBox(height: 12),
          _CaptainIconPicker(team: team),
        ],
      ],
    );
  }

  Widget _inviteCodeCard(
    BuildContext context,
    AppTeam team,
    List<AppUser> members,
  ) {
    return Container(
      key: const ValueKey('team-invite-section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.key_rounded, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text(
              context.tr("CODE D'INVITATION", 'INVITE CODE'),
              style: GoogleFonts.barlowCondensed(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'À partager uniquement avec les personnes que tu veux ajouter à ton équipe.',
              'Share only with the people you want to add to your team.',
            ),
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10.5, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    team.code,
                    style: GoogleFonts.bebasNeue(
                      color: AppColors.gold,
                      fontSize: 32,
                      letterSpacing: 8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Clipboard.setData(ClipboardData(text: team.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr('Code copié !', 'Code copied!'),
                      style: GoogleFonts.barlowCondensed(),
                    ),
                    backgroundColor: AppColors.mexicoGreen,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(context.tr('Copier', 'Copy')),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            context.isEnglish
                ? 'Up to ${4 - members.length} more teammate${4 - members.length == 1 ? '' : 's'} can join.'
                : "Encore ${4 - members.length} coéquipier${4 - members.length > 1 ? 's' : ''} maximum.",
            style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _weeklyChallenge(BuildContext context, AppProvider prov, List<AppUser> members) {
    final sorted = [...members]..sort((a, b) => prov.getUserCurrentStreak(b.id).compareTo(prov.getUserCurrentStreak(a.id)));
    final leader = sorted.isEmpty ? null : sorted.first;
    final streak = leader == null ? 0 : prov.getUserCurrentStreak(leader.id);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.lime.withOpacity(.13), AppColors.bg2.withOpacity(.96)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lime.withOpacity(.24)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: AppColors.lime.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.local_fire_department_rounded, color: AppColors.lime),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('DÉFI DE L’ÉQUIPE','TEAM CHALLENGE'), style: GoogleFonts.inter(color:AppColors.lime,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),
          const SizedBox(height: 3),
          Text(context.tr('Qui atteindra 3 bons pronos d’affilée ?', 'Who will hit 3 correct picks in a row?'), style: GoogleFonts.spaceGrotesk(color:AppColors.text,fontWeight:FontWeight.w800,fontSize:13)),
          const SizedBox(height: 3),
          Text(
            leader == null || streak == 0
              ? context.tr('À vous de lancer la série 🔥','Start the streak 🔥')
              : context.tr('${leader.name} mène avec $streak bon${streak > 1 ? 's' : ''} prono${streak > 1 ? 's' : ''}.', '${leader.name} leads with a $streak-pick streak.'),
            style: GoogleFonts.inter(color:AppColors.text2,fontSize:9.5),
          ),
        ])),
      ]),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: GoogleFonts.barlowCondensed(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildNoTeam(BuildContext context, AppProvider prov) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(context.tr('MON ÉQUIPE','MY TEAM'),
                    style: GoogleFonts.bebasNeue(
                        color: AppColors.text, fontSize: 26, letterSpacing: 2)),
              ),
              Center(
                  child: Column(children: [
                const Text('🏟️', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback: (r) =>
                      AppColors.trophyGradient.createShader(r),
                  child: Text(context.tr('FORMEZ VOTRE ÉQUIPE !','BUILD YOUR TEAM!'),
                      style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 24,
                          letterSpacing: 1.5)),
                ),
                const SizedBox(height: 8),
                Text(
                    context.tr("Jusqu'à 4 amis. Le score d'équipe est la moyenne des points.", 'Up to 4 friends. Team score is the members’ average.'),
                    style: GoogleFonts.barlow(
                        color: AppColors.text2, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center),
              ])),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => setState(
                          () => _mode = _mode == 'create' ? null : 'create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _mode == 'create' ? AppColors.gold : AppColors.bg3,
                    foregroundColor:
                        _mode == 'create' ? AppColors.bg0 : AppColors.text,
                  ),
                  child: Text(context.tr('🛡️ CRÉER','🛡️ CREATE'),
                      style: GoogleFonts.bebasNeue(
                          fontSize: 16, letterSpacing: 1)),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => setState(
                          () => _mode = _mode == 'join' ? null : 'join'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _mode == 'join' ? AppColors.gold : AppColors.bg3,
                    foregroundColor:
                        _mode == 'join' ? AppColors.bg0 : AppColors.text,
                  ),
                  child: Text(context.tr('🔑 REJOINDRE','🔑 JOIN'),
                      style: GoogleFonts.bebasNeue(
                          fontSize: 16, letterSpacing: 1)),
                )),
              ]),
              if (_mode == 'create') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.overlayBase.withOpacity(0.08))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr("NOM DE L'ÉQUIPE",'TEAM NAME'),
                          style: GoogleFonts.barlowCondensed(
                              color: AppColors.text2,
                              fontSize: 11,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        maxLength: 24,
                        autofocus: true,
                        enabled: !_busy,
                        style: GoogleFonts.barlow(color: AppColors.text),
                        decoration: InputDecoration(
                            hintText: context.tr('Ex : Les Invincibles','Ex: The Invincibles'), counterText: ''),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _createTeam(prov),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_busy || _nameCtrl.text.trim().isEmpty)
                                ? null
                                : () => _createTeam(prov),
                            child: _busy
                                ?  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: AppColors.bg0, strokeWidth: 2.4))
                                : Text(context.tr('CRÉER','CREATE'),
                                    style: GoogleFonts.bebasNeue(
                                        fontSize: 18, letterSpacing: 1)),
                          )),
                    ],
                  ),
                ),
              ],
              if (_mode == 'join') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.overlayBase.withOpacity(0.08))),
                  child: Column(children: [
                    Text(context.tr('ENTREZ LE CODE','ENTER THE CODE'),
                        style: GoogleFonts.barlowCondensed(
                            color: AppColors.text2,
                            fontSize: 11,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeCtrl,
                      maxLength: 6,
                      autofocus: true,
                      enabled: !_busy,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.bebasNeue(
                          color: AppColors.gold,
                          fontSize: 28,
                          letterSpacing: 8),
                      decoration: const InputDecoration(
                          hintText: 'ABC123', counterText: ''),
                      onChanged: (v) {
                        final upper = v.toUpperCase();
                        _codeCtrl.value = TextEditingValue(
                          text: upper,
                          selection:
                              TextSelection.collapsed(offset: upper.length),
                        );
                        setState(() {});
                      },
                      onSubmitted: (_) => _joinTeam(prov),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_busy || _codeCtrl.text.length < 6)
                              ? null
                              : () => _joinTeam(prov),
                          child: _busy
                              ?  SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: AppColors.bg0, strokeWidth: 2.4))
                              : Text(context.tr('REJOINDRE','JOIN'),
                                  style: GoogleFonts.bebasNeue(
                                      fontSize: 18, letterSpacing: 1)),
                        )),
                  ]),
                ),
              ],
              if (_feedback != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: (_isError
                              ? AppColors.canadaRed
                              : AppColors.mexicoGreen)
                          .withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: (_isError
                                  ? AppColors.canadaRed
                                  : AppColors.mexicoGreen)
                              .withOpacity(0.35))),
                  child: Text(_feedback!,
                      style: GoogleFonts.barlowCondensed(
                          color: _isError
                              ? AppColors.canadaRed
                              : AppColors.mexicoGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ],
              if (prov.teams.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(context.tr('ÉQUIPES EXISTANTES','EXISTING TEAMS'),
                    style: GoogleFonts.bebasNeue(
                        color: AppColors.text2,
                        fontSize: 16,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                ...prov.teams.map((t) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.bg2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.overlayBase.withOpacity(0.06))),
                      child: Row(children: [
                        const Icon(Icons.shield_rounded,
                            color: AppColors.mexicoGreen, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.barlowCondensed(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.text)),
                            Text(context.isEnglish ? '${t.memberIds.length}/4 members' : '${t.memberIds.length}/4 membres',
                                style: GoogleFonts.barlowCondensed(
                                    color: AppColors.text2, fontSize: 11)),
                          ],
                        )),
                        if (t.memberIds.length < 4)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      _mode = 'join';
                                      _codeCtrl.text = t.code;
                                    });
                                  },
                            child: Text(context.tr('Rejoindre','Join')),
                          ),
                      ]),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createTeam(AppProvider prov) async {
    if (_busy) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _busy = true;
      _feedback = null;
    });

    try {
      final team = await prov.createTeam(name);
      if (!mounted) return;
      if (team != null) {
        _nameCtrl.clear();
        setState(() {
          _feedback = context.tr('✅ Équipe créée ! Code : ${team.code}', '✅ Team created! Code: ${team.code}');
          _isError = false;
          _mode = null;
        });
      } else {
        setState(() {
          _feedback = context.tr("Impossible de créer l'équipe. Vérifiez votre connexion et réessayez.", 'Unable to create the team. Check your connection and try again.');
          _isError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedback = context.tr('Erreur réseau. Réessayez dans un instant.', 'Network error. Try again shortly.');
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinTeam(AppProvider prov) async {
    if (_busy) return;
    final code = _codeCtrl.text.trim();
    if (code.length < 6) return;

    setState(() {
      _busy = true;
      _feedback = null;
    });

    try {
      final err = await prov.joinTeam(code);
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _feedback = '❌ $err';
          _isError = true;
        });
      } else {
        _codeCtrl.clear();
        setState(() {
          _feedback = context.tr('✅ Équipe rejointe !', '✅ Team joined!');
          _isError = false;
          _mode = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedback = context.tr('Erreur réseau. Réessayez dans un instant.', 'Network error. Try again shortly.');
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ════════════════════════════════════════════════════════════
//  PROFILE SCREEN
// ════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  String _editName = '';
  String _editAvatar = '⚽';
  final _nameCtrl = TextEditingController();
  String _adminMsg = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAvatarPicker() async {
    final result = await AvatarPicker2026.show(context, _editAvatar);
    if (result != null && mounted) {
      setState(() => _editAvatar = result);
    }
  }

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mundial.app';
  static const String _appStoreId = String.fromEnvironment(
    'APP_STORE_ID',
    defaultValue: '',
  ); // ID numérique Apple, injectable au build sans modifier le code
  static const String _appStoreSearchUrl =
      'https://apps.apple.com/fr/search?term=PRONO4';

  String get _storeShareUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return _appStoreId.isNotEmpty
          ? 'https://apps.apple.com/app/id$_appStoreId'
          : _appStoreSearchUrl;
    }
    return _playStoreUrl;
  }

  Future<void> _shareApp() async {
    await Share.share(
      context.tr('⚽ Rejoins PRONO4 et prouve à tes amis que tu connais vraiment le foot !', '⚽ Join PRONO4 and prove to your friends you really know football!') + '\n' + _storeShareUrl,
      subject: context.tr('PRONO4 – Le foot se pronostique en équipe','PRONO4 – Football predictions are better as a team'),
    );
  }

  Future<void> _rateApp() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      if (_appStoreId.isEmpty) {
        await launchUrl(Uri.parse(_appStoreSearchUrl), mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(Uri.parse('itms-apps://itunes.apple.com/app/id$_appStoreId?action=write-review'), mode: LaunchMode.externalApplication);
      return;
    }
    final marketUri = Uri.parse('market://details?id=com.mundial.app');
    final webUri = Uri.parse(_playStoreUrl);
    if (!kIsWeb && await canLaunchUrl(marketUri)) { await launchUrl(marketUri, mode: LaunchMode.externalApplication); return; }
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _recoverOldProfile(AppProvider prov) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(
          context.tr('RÉCUPÉRER MON ANCIEN PROFIL','RECOVER MY OLD PROFILE'),
          style: GoogleFonts.bebasNeue(letterSpacing: 1.2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Entrez votre code personnel de 8 caractères. Votre équipe, vos pronostics et votre classement seront transférés sur ce téléphone.', 'Enter your 8-character personal code. Your team, predictions and ranking will be restored on this device.'),
              style: GoogleFonts.barlow(color: AppColors.text2, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 8,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
              ],
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              style: GoogleFonts.bebasNeue(
                color: AppColors.gold,
                fontSize: 24,
                letterSpacing: 3,
              ),
              decoration: InputDecoration(
                labelText: context.tr('Code personnel','Personal code'),
                hintText: 'XXXXXXXX',
                counterText: '',
                prefixIcon: Icon(Icons.key_rounded, color: AppColors.gold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Annuler','Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.tr('Récupérer','Recover')),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (code == null || code.trim().isEmpty || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final error = await prov.recoverProfileWithCode(code);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? context.tr('Ancien profil récupéré avec succès.', 'Old profile recovered successfully.')),
        backgroundColor:
            error == null ? AppColors.mexicoGreen : AppColors.canadaRed,
      ),
    );
  }

  Future<void> _manageBlockedUsers(AppProvider prov) async {
    final blocked = prov.blockedUserIds.toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('JOUEURS BLOQUÉS', 'BLOCKED PLAYERS'),
                style: GoogleFonts.bebasNeue(
                    color: AppColors.text, fontSize: 22, letterSpacing: 1.1),
              ),
              const SizedBox(height: 5),
              Text(
                context.tr(
                  'Leurs messages sont masqués pour toi uniquement. Ils restent dans les équipes et ne sont pas avertis.',
                  'Their messages are hidden only for you. They stay in teams and are not notified.',
                ),
                style: GoogleFonts.inter(
                    color: AppColors.text2, fontSize: 10.5, height: 1.35),
              ),
              const SizedBox(height: 14),
              if (blocked.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      context.tr('Aucun joueur bloqué.', 'No blocked players.'),
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
                    ),
                  ),
                )
              else
                ...blocked.map((id) {
                  AppUser? user;
                  for (final candidate in prov.users) {
                    if (candidate.id == id) {
                      user = candidate;
                      break;
                    }
                  }
                  final name = user?.name ?? context.tr('Joueur', 'Player');
                  final avatar = user?.avatar ?? '⚽';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarBubble(avatar: avatar, size: 38),
                    title: Text(name,
                        style: GoogleFonts.inter(
                            color: AppColors.text, fontWeight: FontWeight.w800)),
                    trailing: TextButton(
                      onPressed: () async {
                        await prov.unblockUser(id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(context.tr('Débloquer', 'Unblock')),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProfile(AppProvider prov) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.tr('SUPPRIMER LE PROFIL ?', 'DELETE PROFILE?'),
          style: GoogleFonts.bebasNeue(letterSpacing: 1.1),
        ),
        content: Text(
          context.tr(
            'Cette action supprime ton profil PRONO4, tes pronostics, ton classement et ton code de récupération. Elle fonctionne aussi si tu utilises l’app sans compte inscrit. Cette action est définitive.',
            'This deletes your PRONO4 profile, predictions, ranking and recovery code. It also works when you use the app without a registered account. This action is permanent.',
          ),
          style: GoogleFonts.inter(color: AppColors.text2, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.canadaRed),
            child: Text(context.tr('Supprimer définitivement', 'Delete permanently')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final error = await prov.deleteCurrentProfile();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error),
      backgroundColor: AppColors.canadaRed,
    ));
  }

  String _levelLabel(String level) {
    switch (level) {
      case 'À PROUVER':
        return context.tr('À PROUVER', 'TO PROVE');
      case 'AMATEUR':
        return context.tr('AMATEUR', 'ROOKIE');
      case 'CONNAISSEUR':
        return context.tr('CONNAISSEUR', 'KNOWLEDGEABLE');
      default:
        return level;
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'FOOTIX':
        return AppColors.canadaRed;
      case 'AMATEUR':
        return AppColors.usaBlue;
      case 'CONNAISSEUR':
        return AppColors.gold;
      case 'EXPERT':
      case 'ORACLE':
        return AppColors.lime;
      default:
        return AppColors.grey;
    }
  }

  Widget _preferencesCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.usaBlue.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune_rounded,
                color: AppColors.usaBlue, size: 20),
          ),
          title: Text(
            context.tr('Préférences', 'Preferences'),
            style: GoogleFonts.inter(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            context.tr('Thème, langue et championnats', 'Theme, language and leagues'),
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 9.5),
          ),
          children: const [
            ThemeSettingsCard(),
            SizedBox(height: 8),
            LanguageSettingsCard(),
            SizedBox(height: 8),
            CompetitionSettingsCard(),
          ],
        ),
      ),
    );
  }

  Widget _specialtiesCard(AppProvider prov, AppUser user) {
    final generalPlayed = prov.getUserResolvedVoteCount(user.id);
    final generalCorrect = prov.getUserCorrectCount(user.id);
    final generalScore = prov.getUserKnowledgeScore(user.id);
    final generalLevel = prov.getUserKnowledgeLevel(user.id);
    final specialties = prov.getUserCompetitionSpecialties(user.id);
    final proven = specialties.where((s) => s.played >= 3).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final best = proven.isEmpty ? null : proven.first;
    final bestCompetition = best == null ? null : competitionById(best.competitionId);

    final summary = best == null || bestCompetition == null
        ? context.tr(
            '${_levelLabel(generalLevel)} au général · révèle tes spécialités avec 3 pronos par championnat',
            '${_levelLabel(generalLevel)} overall · reveal specialties with 3 picks per league',
          )
        : context.tr(
            '${_levelLabel(generalLevel)} au général · ${_levelLabel(best.level)} ${bestCompetition.name}',
            '${_levelLabel(generalLevel)} overall · ${_levelLabel(best.level)} ${competitionDisplayName(context, bestCompetition)}',
          );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lime.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lime.withOpacity(.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.lime, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('MES SPÉCIALITÉS', 'MY SPECIALTIES'),
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: GoogleFonts.inter(
                      color: AppColors.text2,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          _specialtyRow(
            icon: '⚽',
            title: context.tr('Général', 'Overall'),
            level: generalLevel,
            score: generalScore,
            played: generalPlayed,
            correct: generalCorrect,
            color: AppColors.lime,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Divider(height: 1),
          ),
          ...specialties.map((specialty) {
            final competition = competitionById(specialty.competitionId);
            if (competition == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _specialtyRow(
                icon: competition.emoji,
                title: competitionDisplayName(context, competition),
                level: specialty.level,
                score: specialty.score,
                played: specialty.played,
                correct: specialty.correct,
                color: competition.color,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _specialtyRow({
    required String icon,
    required String title,
    required String level,
    required int score,
    required int played,
    required int correct,
    required Color color,
  }) {
    final accuracy = played == 0 ? 0 : ((correct * 100) / played).round();
    final isProven = played >= 3;
    final progress = isProven
        ? score / 100.0
        : (played / 3.0).clamp(0.0, 1.0).toDouble();
    final levelColor = _levelColor(level);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 30, child: Text(icon, style: const TextStyle(fontSize: 20))),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: levelColor.withOpacity(.28)),
                  ),
                  child: Text(
                    _levelLabel(level),
                    style: GoogleFonts.inter(
                      color: levelColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: progress,
                  color: color,
                  backgroundColor: AppColors.overlayBase.withOpacity(.07),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isProven
                    ? context.tr('$played pronos · $accuracy% de réussite · $score/100', '$played picks · $accuracy% accuracy · $score/100')
                    : context.tr('$played/3 pronos pour révéler ton niveau', '$played/3 picks to reveal your level'),
                style: GoogleFonts.inter(
                  color: AppColors.text2,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final user = prov.currentUser!;
    final pts = prov.getUserPoints(user.id);
    final votes = prov.getUserVoteCount(user.id);
    final total = prov.getUserResolvedVoteCount(user.id);
    final correct = prov.getUserCorrectCount(user.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 205,
              pinned: true,
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withOpacity(.92),
              title: Text(
                context.tr('PROFIL', 'PROFILE'),
                style: GoogleFonts.bebasNeue(
                  fontSize: 20,
                  letterSpacing: 1.4,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: context.tr('Paramètres', 'Settings'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_rounded),
                ),
                const SizedBox(width: 6),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.gold.withOpacity(.14),
                        AppColors.canadaRed.withOpacity(.05),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        AvatarBubble(
                          avatar: user.avatar,
                          size: 82,
                          ringColor: AppColors.gold,
                          ringWidth: 2.5,
                          showGlow: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.bebasNeue(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 24,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.gold.withOpacity(.35),
                            ),
                          ),
                          child: Text(
                            '⭐ $pts points',
                            style: GoogleFonts.barlowCondensed(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                100 + MediaQuery.of(context).viewInsets.bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _profileGroupTitle(
                    context.tr('MA PERFORMANCE', 'MY PERFORMANCE'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _stat(
                        '⭐',
                        '$pts',
                        context.tr('Points', 'Points'),
                        AppColors.gold,
                      ),
                      const SizedBox(width: 10),
                      _stat(
                        '🗳️',
                        '$votes',
                        context.tr('Pronos', 'Picks'),
                        AppColors.usaBlue,
                      ),
                      const SizedBox(width: 10),
                      _stat(
                        '🎯',
                        total > 0 ? '${(correct * 100 ~/ total)}%' : '—',
                        context.tr('Réussite', 'Accuracy'),
                        AppColors.mexicoGreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _specialtiesCard(prov, user),
                  const SizedBox(height: 22),

                  _profileGroupTitle(context.tr('MON PROFIL', 'MY PROFILE')),
                  const SizedBox(height: 10),
                  _section(
                    icon: Icons.edit_rounded,
                    title: context.tr(
                      'Modifier mon profil',
                      'Edit my profile',
                    ),
                    subtitle: context.tr(
                      'Pseudo et avatar',
                      'Nickname and avatar',
                    ),
                    trailing: Icon(
                      _editing ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.text2,
                    ),
                    onTap: () {
                      setState(() {
                        _editing = !_editing;
                        _editName = user.name;
                        _editAvatar = user.avatar;
                        _nameCtrl.text = user.name;
                      });
                    },
                  ),
                  if (_editing)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(14),
                        ),
                        border: Border.all(
                          color: AppColors.overlayBase.withOpacity(.07),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              AvatarBubble(
                                avatar: _editAvatar,
                                size: 64,
                                showGlow: true,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _openAvatarPicker,
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    context.tr('CHANGER L’AVATAR', 'CHANGE AVATAR'),
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 14,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  maxLength: 20,
                                  style: GoogleFonts.barlow(
                                    color: AppColors.text,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.tr(
                                      'Votre pseudo',
                                      'Your nickname',
                                    ),
                                    counterText: '',
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: AppColors.text2,
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _editName = v),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _editName.trim().isEmpty
                                    ? null
                                    : () async {
                                        await prov.updateUser(
                                          name: _editName.trim(),
                                          avatar: _editAvatar,
                                        );
                                        if (!mounted) return;
                                        setState(() => _editing = false);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              context.tr(
                                                'Profil mis à jour ✓',
                                                'Profile updated ✓',
                                              ),
                                            ),
                                            backgroundColor:
                                                AppColors.mexicoGreen,
                                          ),
                                        );
                                      },
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      context.tr(
                        'Profil = identité + performance',
                        'Profile = identity + performance',
                      ),
                      style: GoogleFonts.inter(
                        color: AppColors.text2.withOpacity(.7),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.20))),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  GoogleFonts.bebasNeue(color: color, fontSize: 24, height: 1)),
          Text(label,
              style: GoogleFonts.barlowCondensed(
                  color: AppColors.text2, fontSize: 10, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  Widget _profileGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppColors.trophyGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.bebasNeue(
            color: AppColors.text2,
            fontSize: 15,
            letterSpacing: 1.4,
          ),
        ),
      ]),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.24)),
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: color.withOpacity(0.32)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.barlowCondensed(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    )),
                Text(subtitle,
                    style: GoogleFonts.barlow(
                      color: AppColors.text2,
                      fontSize: 12,
                    )),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: color),
          ]),
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: AppColors.overlayBase.withOpacity(0.07))),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (color ?? AppColors.gold).withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: (color ?? AppColors.gold).withOpacity(0.32)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color ?? AppColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.barlowCondensed(
                      color: color ?? AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              if (subtitle != null)
                Text(subtitle,
                    style: GoogleFonts.barlow(
                        color: AppColors.text2, fontSize: 12)),
            ],
          )),
          if (trailing != null) trailing,
        ]),
      ),
    );
  }
}

class _TeamImagePicker extends StatefulWidget {
  final AppTeam team;
  final bool canEdit;
  const _TeamImagePicker({required this.team, required this.canEdit});

  @override
  State<_TeamImagePicker> createState() => _TeamImagePickerState();
}

class _TeamImagePickerState extends State<_TeamImagePicker> {
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy || !widget.canEdit) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2200,
        maxHeight: 2200,
        imageQuality: 92,
      );
      if (picked == null) return;
      final input = await picked.readAsBytes();
      final decoded = img.decodeImage(input);
      if (decoded == null) throw Exception('image');

      final side = decoded.width < decoded.height ? decoded.width : decoded.height;
      final crop = img.copyCrop(
        decoded,
        x: ((decoded.width - side) / 2).round(),
        y: ((decoded.height - side) / 2).round(),
        width: side,
        height: side,
      );

      var resized = img.copyResize(crop, width: 512, height: 512);
      var quality = 82;
      var bytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      while (bytes.lengthInBytes > 420000 && quality > 50) {
        quality -= 8;
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      }
      if (bytes.lengthInBytes > 520000) {
        resized = img.copyResize(crop, width: 384, height: 384);
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 66));
      }

      if (!mounted) return;
      final error = await context
          .read<AppProvider>()
          .setTeamImageBase64(base64Encode(bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Image de l’équipe mise à jour ✅')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de traiter cette image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    final raw = widget.team.imageB64.trim();
    if (raw.isNotEmpty) {
      try {
        bytes = base64Decode(raw);
      } catch (_) {
        bytes = null;
      }
    }

    final avatar = Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lime, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withOpacity(.12),
            blurRadius: 18,
          ),
        ],
      ),
      child: ClipOval(
        child: bytes == null
            ? Container(
                color: AppColors.bg3,
                alignment: Alignment.center,
                child: TeamBadge(team: widget.team, size: 84),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
      ),
    );

    return GestureDetector(
      onTap: widget.canEdit && !_busy ? _pick : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(opacity: _busy ? .55 : 1, child: avatar),
          if (widget.canEdit)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 31,
                height: 31,
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
                child: _busy
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bg0,
                        ),
                      )
                    : Icon(
                        Icons.edit_rounded,
                        color: AppColors.bg0,
                        size: 17,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CaptainIconPicker extends StatelessWidget {
  final AppTeam team;
  const _CaptainIconPicker({required this.team});

  static const List<String> _choices = [
    '🛡️',
    '⚽',
    '🔥',
    '⭐',
    '🦁',
    '🦅',
    '🐉',
    '⚡',
    '👑',
    '🏆',
    '🐺',
    '🦊',
    '🐻',
    '🦈',
    '🚀',
    '🌟',
  ];

  @override
  Widget build(BuildContext context) {
    final current = team.icon;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mexicoGreen.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _teamPreview(current),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ICÔNE DE L'ÉQUIPE",
                    style: GoogleFonts.barlowCondensed(
                      color: AppColors.text2,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'Capitaine : choisis ton emblème',
                    style: GoogleFonts.barlowCondensed(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _choices.map((emoji) {
              final selected = emoji == current;
              return GestureDetector(
                onTap: () async {
                  final err =
                      await context.read<AppProvider>().setTeamIcon(emoji);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? 'Icône mise à jour ✅')),
                  );
                },
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.mexicoGreen.withOpacity(0.18)
                        : AppColors.overlayBase.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.mexicoGreen
                          : AppColors.overlayBase.withOpacity(0.08),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _teamPreview(String current) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: current.isEmpty
            ? const LinearGradient(
                colors: [AppColors.mexicoGreen, AppColors.usaBlue])
            : null,
        color: current.isEmpty ? null : AppColors.overlayBase.withOpacity(0.06),
        border: Border.all(color: AppColors.overlayBase.withOpacity(0.12)),
      ),
      child: current.isEmpty
          ? const Icon(Icons.shield_rounded, color: Colors.white, size: 24)
          : Text(current, style: const TextStyle(fontSize: 22)),
    );
  }
}
