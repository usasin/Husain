// ════════════════════════════════════════════════════════════
//  CALENDAR + LEADERBOARD + TEAM + PROFILE
//  All four screens live here for backward compatibility with
//  team_screen.dart / profile_screen.dart / leaderboard_screen.dart
//  which simply re-export from this file.
// ════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
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
import 'team_chat_screen.dart';
import '../models/models.dart';
import '../data/matches_data.dart';
import '../data/teams_data.dart';
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
                                      : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: sel
                                          ? AppColors.gold.withOpacity(0.5)
                                          : Colors.white.withOpacity(0.08)),
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
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: sel
                                            ? AppColors.usaBlue.withOpacity(0.5)
                                            : Colors.white.withOpacity(0.08)),
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
                                  color: Colors.white.withOpacity(0.06))),
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
                                  color: Colors.white.withOpacity(0.06))),
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
    final individuals = prov.getIndividualRanking();
    final teams = prov.getTeamRanking();
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
                          : Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    _medalWidget(rank),
                    const SizedBox(width: 10),
                    AvatarBubble(
                      avatar: u.avatar,
                      size: 42,
                      ringColor: isMe ? AppColors.gold : Colors.white24,
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
                        ReputationBadgeChip(badge: prov.reputationBadgeFor(u.id), compact: true),
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
                  'moy.',
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
    if (data.isEmpty) return _empty('🛡️', 'Aucune équipe créée');
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
                        : Colors.white.withOpacity(0.06)),
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
                            Text('${team.memberIds.length}/4 membres',
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
                            Text('moy.',
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
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _feedback;
  bool _isError = false;
  bool _busy = false;

  Future<void> _voteReputation(BuildContext context, AppProvider prov, AppUser member) async {
    final badge = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Quel badge pour ${member.name} ?', 'Which badge for ${member.name}?'), style: GoogleFonts.spaceGrotesk(color: AppColors.text,fontSize:20,fontWeight:FontWeight.w900)),
          const SizedBox(height: 5),
          Text(context.tr('Ton vote peut changer sa réputation dans le classement interne.', 'Your vote can change their reputation in the team ranking.'), style: GoogleFonts.inter(color:AppColors.text2,fontSize:11)),
          const SizedBox(height: 14),
          Wrap(spacing:8,runSpacing:8,children:kReputationBadges.map((b)=>ActionChip(label:ReputationBadgeChip(badge:b),onPressed:()=>Navigator.pop(ctx,b))).toList()),
        ]),
      )),
    );
    if (badge==null || !context.mounted) return;
    final err=await prov.castReputationVote(member.id,badge);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(err ?? context.tr('Vote badge enregistré ✅','Badge vote saved ✅'))));
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
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.lime.withOpacity(0.18),
                    AppColors.lime.withOpacity(0.05),
                    Theme.of(context).scaffoldBackgroundColor,
                  ]),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              if (team.createdBy == prov.currentUser?.id) ...[
                _CaptainIconPicker(team: team),
                const SizedBox(height: 12),
              ],
              // Share code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr("CODE D'INVITATION",'INVITE CODE'),
                        style: GoogleFonts.barlowCondensed(
                            color: AppColors.text2,
                            fontSize: 11,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                              color: AppColors.bg3,
                              borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Text(team.code,
                              style: GoogleFonts.bebasNeue(
                                  color: AppColors.gold,
                                  fontSize: 32,
                                  letterSpacing: 8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: team.code));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(context.tr('Code copié !','Code copied!'),
                                  style: GoogleFonts.barlowCondensed()),
                              backgroundColor: AppColors.mexicoGreen,
                              duration: const Duration(seconds: 2)));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(context.tr('Copier','Copy')),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        context.isEnglish
                            ? 'Share this code with up to ${4 - members.length} teammate${4 - members.length == 1 ? '' : 's'}.'
                            : 'Partagez ce code avec ${4 - members.length} coéquipier${4 - members.length > 1 ? "s" : ""} max.',
                        style: GoogleFonts.barlow(
                            color: AppColors.text2, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TeamChatScreen()),
                  ),
                  icon: const Icon(Icons.forum_rounded, color: AppColors.lime),
                  label: Text(context.tr('CHAT ÉQUIPE · CHAMBRE TES AMIS','TEAM CHAT · TEASE YOUR FRIENDS')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    backgroundColor: AppColors.lime.withOpacity(.06),
                    side: BorderSide(color: AppColors.lime.withOpacity(.28)),
                  ),
                ),
              ),
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
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
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
                                ? Colors.white.withOpacity(0.025)
                                : Colors.transparent),
                        border: Border(
                          top:
                              BorderSide(color: Colors.white.withOpacity(0.06)),
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
                          ringColor: isMe ? AppColors.gold : Colors.white24,
                          ringWidth: isMe ? 1.8 : 1,
                        ),
                        const SizedBox(width: 9),
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
                            : Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(children: [
                    AvatarBubble(
                      avatar: m.avatar,
                      size: 46,
                      ringColor: isMe ? AppColors.gold : Colors.white24,
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
                          ReputationBadgeChip(badge: prov.reputationBadgeFor(m.id), compact: true),
                          if (!isMe) InkWell(
                            onTap: () => _voteReputation(context, prov, m),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              child: Text(context.tr('VOTER','VOTE'), style: GoogleFonts.inter(color: AppColors.lime,fontSize:9,fontWeight:FontWeight.w900)),
                            ),
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
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.add_rounded,
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
                          Border.all(color: Colors.white.withOpacity(0.08))),
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
                                ? const SizedBox(
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
                          Border.all(color: Colors.white.withOpacity(0.08))),
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
                              ? const SizedBox(
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
                              color: Colors.white.withOpacity(0.06))),
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
  static const String _appStoreId = ''; // à renseigner après création de la fiche Apple

  Future<void> _shareApp() async {
    await Share.share(
      context.tr('⚽ Rejoins PRONO4 et prouve à tes amis que tu connais vraiment le foot !', '⚽ Join PRONO4 and prove to your friends you really know football!') + '\n' + ((!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && _appStoreId.isNotEmpty) ? 'https://apps.apple.com/app/id$_appStoreId' : _playStoreUrl),
      subject: context.tr('PRONO4 – Le foot se pronostique en équipe','PRONO4 – Football predictions are better as a team'),
    );
  }

  Future<void> _rateApp() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      if (_appStoreId.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('La note App Store sera activée dès la publication iOS.', 'App Store rating will be enabled after the iOS release.'))));
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
        child: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor:
                Theme.of(context).colorScheme.surface.withOpacity(0.88),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.gold.withOpacity(0.14),
                    AppColors.canadaRed.withOpacity(0.06),
                    Theme.of(context).scaffoldBackgroundColor,
                  ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      AvatarBubble(
                        avatar: user.avatar,
                        size: 84,
                        ringColor: AppColors.gold,
                        ringWidth: 2.5,
                        showGlow: true,
                      ),
                      const SizedBox(height: 8),
                      Text(user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.bebasNeue(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 24,
                              letterSpacing: 1.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.gold.withOpacity(0.35))),
                        child: Text('⭐ $pts points',
                            style: GoogleFonts.barlowCondensed(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 100 + MediaQuery.of(context).viewInsets.bottom),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              _profileGroupTitle(context.tr('TABLEAU DE BORD','DASHBOARD')),
              const SizedBox(height: 10),

              const LanguageSettingsCard(),

              // Stats
              Row(children: [
                _stat('⭐', '$pts', context.tr('Points','Points'), AppColors.gold),
                const SizedBox(width: 10),
                _stat('🗳️', '$votes', context.tr('Pronos','Picks'), AppColors.usaBlue),
                const SizedBox(width: 10),
                _stat('🎯', total > 0 ? '${(correct * 100 ~/ total)}%' : '—',
                    context.tr('Réussite','Accuracy'), AppColors.mexicoGreen),
              ]),
              const SizedBox(height: 14),
              const DynamicContentFeed(placement: 'profile'),
              const DynamicPagesFeed(placement: 'profile', limit: 3),
              const SizedBox(height: 20),

              _profileGroupTitle(context.tr('MON PROFIL','MY PROFILE')),
              const SizedBox(height: 10),

              // ── EDIT PROFILE ──
              _section(
                icon: Icons.edit_rounded,
                title: context.tr('Modifier mon profil','Edit my profile'),
                subtitle: context.tr('Pseudo, avatar (emoji · icône · photo)','Nickname, avatar (emoji · icon · photo)'),
                trailing: Icon(_editing ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.text2),
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
                        bottom: Radius.circular(14)),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Column(children: [
                    // Big avatar preview + open picker
                    Row(children: [
                      AvatarBubble(
                          avatar: _editAvatar, size: 64, showGlow: true),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('Votre avatar','Your avatar'),
                                style: GoogleFonts.barlowCondensed(
                                    color: AppColors.text2,
                                    fontSize: 12,
                                    letterSpacing: 0.6)),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
                              onPressed: _openAvatarPicker,
                              icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 18),
                              label: Text('CHANGER',
                                  style: GoogleFonts.bebasNeue(
                                      fontSize: 14, letterSpacing: 1.2)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: TextField(
                        controller: _nameCtrl,
                        maxLength: 20,
                        style: GoogleFonts.barlow(color: AppColors.text),
                        decoration: const InputDecoration(
                          hintText: 'Votre pseudo',
                          counterText: '',
                          prefixIcon: Icon(Icons.person_outline,
                              color: AppColors.text2),
                        ),
                        onChanged: (v) => setState(() => _editName = v),
                      )),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _editName.trim().isEmpty
                            ? null
                            : () async {
                                await prov.updateUser(
                                    name: _editName.trim(),
                                    avatar: _editAvatar);
                                if (mounted) {
                                  setState(() => _editing = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          const Text('Profil mis à jour ✓'),
                                      backgroundColor: AppColors.mexicoGreen,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 14),
                        ),
                        child: const Text('OK'),
                      ),
                    ]),
                  ]),
                ),

              _profileGroupTitle(context.tr('CONFIDENTIALITÉ','PRIVACY')),
              const SizedBox(height: 10),

              // ── CONFIDENTIALITÉ PUBLICITAIRE ──
              _section(
                icon: Icons.privacy_tip_outlined,
                title: context.tr('Confidentialité des publicités','Ad privacy'),
                subtitle: context.tr('Consulter ou modifier vos choix','Review or change your choices'),
                color: AppColors.mexicoGreen,
                onTap: () async {
                  final error = await AdService.instance.showPrivacyOptions();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(error ?? 'Options de confidentialité ouvertes.'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _profileGroupTitle(context.tr('PARTAGE & AIDE','SHARE & HELP')),
              const SizedBox(height: 10),

              // ── PARTAGER ET NOTER L'APPLICATION ──
              _actionCard(
                icon: Icons.share_rounded,
                title: context.tr('Partager l’application','Share the app'),
                subtitle: context.tr('Inviter vos collègues à participer','Invite your friends to join'),
                color: AppColors.usaBlue,
                onTap: _shareApp,
              ),
              const SizedBox(height: 8),
              _actionCard(
                icon: Icons.star_rounded,
                title: context.tr('Noter l’application','Rate the app'),
                subtitle: context.tr('Donner une note sur Google Play','Leave a store rating'),
                color: AppColors.gold,
                onTap: _rateApp,
              ),
              const SizedBox(height: 18),

              _profileGroupTitle(context.tr('SÉCURITÉ DU COMPTE','ACCOUNT SECURITY')),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final code = prov.currentUser?.recoveryCode ?? '';
                return Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.gold.withOpacity(0.40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.vpn_key_rounded,
                            color: AppColors.gold, size: 18),
                        const SizedBox(width: 8),
                        Text('MON CODE DE RÉCUPÉRATION',
                            style: GoogleFonts.barlow(
                                color: AppColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        'Note bien ce code ! Il te permet de retrouver ton équipe, '
                        'tes pronostics et ton classement si tu changes de téléphone '
                        'ou réinstalles l\'application.',
                        style: GoogleFonts.barlow(
                            color: AppColors.text2, fontSize: 12, height: 1.35),
                      ),
                      const SizedBox(height: 12),
                      if (code.isEmpty)
                        Text(
                          'Code en cours de génération… reviens dans quelques minutes.',
                          style: GoogleFonts.barlow(
                              color: AppColors.text2,
                              fontSize: 12,
                              fontStyle: FontStyle.italic),
                        )
                      else
                        Row(children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.bg1,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.gold.withOpacity(0.30)),
                              ),
                              child: Text(
                                code,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Code copié — garde-le en lieu sûr ✅')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: const Color(0xFF1A1A1A),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: Text(context.tr('Copier','Copy')),
                          ),
                        ]),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              _actionCard(
                icon: Icons.manage_accounts_rounded,
                title: context.tr('Récupérer mon ancien profil','Recover my old profile'),
                subtitle: context.tr('Retrouver mon équipe, mes pronostics et mon classement','Recover my team, predictions and ranking'),
                color: AppColors.mexicoGreen,
                onTap: () => _recoverOldProfile(prov),
              ),
              const SizedBox(height: 12),
              _actionCard(
                icon: Icons.help_outline_rounded,
                title: context.tr('Aide & Contact','Help & Contact'),
                subtitle: context.tr('Une question ou un souci ? Écris-nous','A question or issue? Contact us'),
                color: AppColors.cyan,
                onTap: () async {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  );
                },
              ),
              const SizedBox(height: 18),

              _profileGroupTitle(context.tr('NOTIFICATIONS','NOTIFICATIONS')),
              const SizedBox(height: 10),

              _actionCard(
                icon: Icons.tune_rounded,
                title: context.tr('Gérer mes notifications push','Manage push notifications'),
                subtitle: context.tr('Choisir scores, salon équipe, tribune ou tout désactiver','Choose scores, team chat, match lounge or disable all'),
                color: AppColors.gold,
                onTap: () async {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // ── RAPPELS DE PRONOSTICS ──
              _section(
                icon: prov.voteRemindersEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                title: context.tr('Rappels de pronostics','Prediction reminders'),
                subtitle: prov.voteRemindersSupported
                    ? (prov.voteRemindersEnabled
                        ? context.tr('Actifs · 15 min avant un match sans vote','Active · 15 min before an unpicked match')
                        : context.tr('Recevoir un rappel avant les matchs','Get a reminder before matches'))
                    : context.tr('Disponible sur l’application Android/iPhone','Available on Android/iPhone'),
                color: AppColors.usaBlue,
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(14)),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Me prévenir 15 minutes avant','Notify me 15 minutes before'),
                            style: GoogleFonts.barlow(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            prov.voteRemindersEnabled
                                ? context.tr('${prov.scheduledReminderCount} rappels programmés. Un rappel est annulé dès que vous votez.', '${prov.scheduledReminderCount} reminders scheduled. A reminder is cancelled as soon as you pick.')
                                : context.tr('Aucune notification si votre pronostic est déjà enregistré.', 'No notification when your prediction is already saved.'),
                            style: GoogleFonts.barlow(
                              color: AppColors.text2,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: prov.voteRemindersEnabled,
                      onChanged: prov.voteRemindersSupported
                          ? (value) async {
                              final ok =
                                  await prov.setVoteRemindersEnabled(value);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? (value
                                            ? context.tr('Rappels de pronostics activés.','Prediction reminders enabled.')
                                            : context.tr('Rappels désactivés.','Reminders disabled.'))
                                        : context.tr('Autorisation de notification refusée.','Notification permission denied.'),
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ]),
                  if (prov.voteRemindersEnabled) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await prov.sendTestVoteReminder();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.tr('Notification de test envoyée.','Test notification sent.'))),
                            );
                          }
                        },
                        icon: const Icon(Icons.notification_add_outlined,
                            size: 18),
                        label: Text(context.tr('Tester la notification','Test notification')),
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 10),

              // ── ALERTES MI-TEMPS ──
              _section(
                icon: prov.halftimeAlertsEnabled
                    ? Icons.sports_soccer_rounded
                    : Icons.notifications_none_rounded,
                title: context.tr('Alertes mi-temps','Half-time alerts'),
                subtitle: prov.voteRemindersSupported
                    ? (prov.halftimeAlertsEnabled
                        ? 'Actives \u00b7 notif a la mi-temps de chaque match'
                        : 'Etre prevenu a la mi-temps pour changer son prono')
                    : 'Disponible sur l\u2019application Android/iPhone',
                color: AppColors.mexicoGreen,
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(14)),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Me prevenir a la mi-temps',
                          style: GoogleFonts.barlow(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          prov.halftimeAlertsEnabled
                              ? 'Tu recois une notification des qu\u2019un match est a la mi-temps.'
                              : 'Aucune alerte de mi-temps pour l\u2019instant.',
                          style: GoogleFonts.barlow(
                            color: AppColors.text2,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: prov.halftimeAlertsEnabled,
                    onChanged: prov.voteRemindersSupported
                        ? (value) async {
                            final ok =
                                await prov.setHalftimeAlertsEnabled(value);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? (value
                                          ? 'Alertes mi-temps activees.'
                                          : 'Alertes mi-temps desactivees.')
                                      : 'Autorisation de notification refusee.',
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              // ── ADMIN ──
              if (prov.adminMode) ...[
                _profileGroupTitle('ADMINISTRATION'),
                const SizedBox(height: 10),
                _actionCard(
                  icon: Icons.dashboard_customize_rounded,
                  title: 'Contenu dynamique',
                  subtitle: 'Ajouter images, textes et cartes d’accueil',
                  color: AppColors.cyan,
                  onTap: () async {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AdminContentScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _actionCard(
                  icon: Icons.article_rounded,
                  title: 'Pages dynamiques',
                  subtitle: 'Créer des pages complètes sans mise à jour',
                  color: AppColors.violet,
                  onTap: () async {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AdminDynamicPagesScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _actionCard(
                  icon: Icons.forum_rounded,
                  title: 'Messagerie (admin)',
                  subtitle: 'Répondre aux joueurs · publier une annonce',
                  color: AppColors.gold,
                  onTap: () async {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AdminSupportScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _actionCard(
                  icon: Icons.stadium_rounded,
                  title: 'Animation salons',
                  subtitle: 'Activer/désactiver salons · message épinglé',
                  color: AppColors.mexicoGreen,
                  onTap: () async {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AdminCommunityScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _section(
                  icon: Icons.build_rounded,
                  title: 'Mode Administrateur (ACTIF)',
                  subtitle: 'Saisir les résultats des matchs',
                  color: AppColors.gold,
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.05),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                    border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            "✅ Accès admin autorisé. Allez dans l'onglet Matchs pour saisir les résultats officiels.",
                            style: GoogleFonts.barlow(
                                color: AppColors.text2,
                                fontSize: 13,
                                height: 1.4)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final ok = await prov.refreshAdminAccess();
                                setState(() {
                                  _adminMsg = ok
                                      ? '✅ Accès admin confirmé.'
                                      : 'Accès admin non autorisé.';
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Rafraîchir'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final count =
                                    await prov.syncMatchesToFirestore();
                                if (!mounted) return;
                                setState(() {
                                  _adminMsg = count > 0
                                      ? '✅ $count horaires synchronisés dans Firebase.'
                                      : 'Synchronisation impossible. Vérifiez les règles Firebase.';
                                });
                              },
                              icon: const Icon(Icons.cloud_sync_rounded),
                              label: const Text('Synchroniser les horaires'),
                            ),
                          ],
                        ),
                      ]),
                ),
              ],
              if (_adminMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_adminMsg,
                      style: GoogleFonts.barlowCondensed(
                          color: AppColors.text2, fontSize: 13)),
                ),

              const SizedBox(height: 24),
              const Divider(color: Color(0x10FFFFFF)),
              const SizedBox(height: 16),
              Center(
                  child: Column(children: [
                const WC2026Wordmark(fontSize: 13),
                const SizedBox(height: 6),
                ShaderMask(
                  shaderCallback: (r) =>
                      AppColors.trophyGradient.createShader(r),
                  child: Text('PRONO4\nEn équipe',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 22,
                          height: 0.95,
                          letterSpacing: 4)),
                ),
                const SizedBox(height: 4),
                Text(context.tr('Le foot se pronostique en équipe.','Football predictions are better as a team.'),
                    style: GoogleFonts.barlowCondensed(
                        color: AppColors.grey, fontSize: 12)),
                Text('Saison 2026–2027',
                    style: GoogleFonts.barlowCondensed(
                        color: AppColors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Text(context.tr('Fait avec ❤️ pour vos équipes','Made with ❤️ for your teams'),
                    style: GoogleFonts.barlow(
                        color: AppColors.grey.withOpacity(0.5), fontSize: 11)),
              ])),
            ])),
          ),
        ]),
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
            border: Border.all(color: Colors.white.withOpacity(0.07))),
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
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.mexicoGreen
                          : Colors.white.withOpacity(0.08),
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
        color: current.isEmpty ? null : Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: current.isEmpty
          ? const Icon(Icons.shield_rounded, color: Colors.white, size: 24)
          : Text(current, style: const TextStyle(fontSize: 22)),
    );
  }
}
