import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/match_card.dart';
import '../widgets/wc26_background.dart';
import '../widgets/avatar_display.dart';
import '../widgets/anims.dart';
import '../widgets/announcement_banner.dart';
import '../widgets/dynamic_content_feed.dart';
import '../widgets/dynamic_pages_feed.dart';
import '../widgets/knowledge_meter.dart';
import '../data/matches_data.dart';
import '../models/models.dart';
import 'bracket_screen.dart';
import 'team_chat_screen.dart';
import 'match_lounge_screen.dart';
import '../data/teams_data.dart';
import 'package:cached_network_image/cached_network_image.dart';


class _KnowledgeStats {
  final int score;
  final int played;
  final int correct;
  final int currentStreak;
  final bool goodForm;

  const _KnowledgeStats({
    required this.score,
    required this.played,
    required this.correct,
    required this.currentStreak,
    required this.goodForm,
  });
}

_KnowledgeStats _knowledgeStats(AppProvider prov, String userId) {
  final matchById = <String, FootballMatch>{
    for (final m in kMatches) m.id: prov.resolveMatch(m),
    for (final m in prov.matches) m.id: m,
  };

  final resolved = prov.results.entries
      .where((e) => prov.votes.containsKey('${userId}__${e.key}'))
      .toList()
    ..sort((a, b) {
      final ad = matchById[a.key]?.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = matchById[b.key]?.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

  final recent = resolved.take(30).toList();
  var correct = 0;
  var streak = 0;
  var streakOpen = true;
  var recentFiveCorrect = 0;

  for (var i = 0; i < recent.length; i++) {
    final e = recent[i];
    final isCorrect = prov.votes['${userId}__${e.key}'] == e.value;
    if (isCorrect) {
      correct++;
      if (i < 5) recentFiveCorrect++;
      if (streakOpen) streak++;
    } else {
      streakOpen = false;
    }
  }

  final played = recent.length;
  // Lissage vers 50% au début : un seul bon résultat ne suffit pas à devenir Expert.
  final smoothed = played == 0 ? 50.0 : ((correct + 2) / (played + 4)) * 100;
  final score = smoothed.round().clamp(0, 100).toInt();
  final sample = played < 5 ? played : 5;
  final goodForm = streak >= 2 || (sample >= 4 && recentFiveCorrect / sample >= .60);

  return _KnowledgeStats(
    score: score,
    played: played,
    correct: correct,
    currentStreak: streak,
    goodForm: goodForm,
  );
}

class HomeScreen extends StatelessWidget {
  final VoidCallback? onJoinTeamTap;
  const HomeScreen({super.key, this.onJoinTeamTap});

  @override
  Widget build(BuildContext context) {
    final prov  = context.watch<AppProvider>();
    final user  = prov.currentUser!;
    final pts   = prov.getUserPoints(user.id);
    final votes = prov.getUserVoteCount(user.id);
    final resolvedUserVotes = prov.results.entries
        .where((e) => prov.votes.containsKey('${user.id}__${e.key}'))
        .toList();
    final total = resolvedUserVotes.length;
    final correct = resolvedUserVotes
        .where((e) => prov.votes['${user.id}__${e.key}'] == e.value)
        .length;
    final pct = total > 0 ? (correct * 100 ~/ total) : 0;
    final knowledge = _knowledgeStats(prov, user.id);

    final today    = prov.todayMatches.where((m) => m.phase == MatchPhase.groupe).toList();
    final upcoming = prov.upcomingMatches.where((m) => m.phase == MatchPhase.groupe).toList();

    // Phase finale intelligente : on affiche uniquement la phase active.
    // Exemple : tant qu'il reste des 8es non terminés, le carrousel reste sur
    // « 8es de finale ». Dès que tous les 8es sont finis, il passe aux quarts.
    final knockoutAll = kMatches
        .map(prov.resolveMatch)
        .where((m) => m.phase != MatchPhase.groupe && !m.isTBD)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final activeKnockoutPhase = _activeKnockoutPhase(prov, knockoutAll);
    final activeKnockoutMatches = activeKnockoutPhase == null
        ? <FootballMatch>[]
        : (knockoutAll
            .where((m) =>
                m.phase == activeKnockoutPhase &&
                !prov.results.containsKey(m.id))
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime)));

    // En direct / commencés (non terminés) : carte verrouillée + score.
    final knockoutLive = activeKnockoutMatches
        .where((m) =>
            prov.isLiveMatch(m.id) ||
            m.hasStarted ||
            prov.scores.containsKey(m.id))
        .toList();

    // À VENIR uniquement : votables. Jamais un match déjà commencé/en direct.
    final knockoutToVote = activeKnockoutMatches
        .where((m) =>
            !m.hasStarted &&
            !prov.isLiveMatch(m.id) &&
            !prov.scores.containsKey(m.id))
        .toList();

    final activePhaseTitle = activeKnockoutPhase == null
        ? ''
        : _phaseTitle(activeKnockoutPhase);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: CustomScrollView(
          slivers: [
            // ── HERO HEADER ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16, MediaQuery.of(context).padding.top + 14, 16, 12),
                child: Appear(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Row(children: [
                      AvatarBubble(avatar: user.avatar, size: 48, showGlow: true),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bonjour,',
                            style: GoogleFonts.barlowCondensed(
                              color: AppColors.text2, fontSize: 13, letterSpacing: 0.5)),
                          Text(user.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bebasNeue(
                              color: AppColors.text, fontSize: 22, letterSpacing: 1.5)),
                        ],
                      )),
                      if (prov.myTeam != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.mexicoGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.mexicoGreen.withOpacity(0.35)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.shield_rounded, size: 14, color: AppColors.mexicoGreen),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Text(prov.myTeam!.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.barlowCondensed(
                                  color: AppColors.mexicoGreen,
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                            ),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 16),

                    // Hero brand banner
                    _heroBanner(),
                    const SizedBox(height: 14),

                    // Bento stats
                    Row(children: [
                      _statBox('⭐', '$pts', 'Points', AppColors.gold),
                      const SizedBox(width: 8),
                      _statBox('🗳️', '$votes', 'Votes', AppColors.usaBlue),
                      const SizedBox(width: 8),
                      _statBox('🎯', total > 0 ? '$pct%' : '—', 'Succès', AppColors.mexicoGreen),
                    ]),
                    FootballKnowledgeMeter(
                      score: knowledge.score,
                      played: knowledge.played,
                      correct: knowledge.correct,
                      currentStreak: knowledge.currentStreak,
                      goodForm: knowledge.goodForm,
                    ),
                  ],
                )),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(delegate: SliverChildListDelegate([

                // 📢 Annonce pilotée à distance (system/appConfig), sans MAJ.
                const AnnouncementBanner(),

                // 🧩 Cartes admin dynamiques : images/textes ajoutés depuis l'app.
                const DynamicContentFeed(placement: 'home_top'),

                // 📄 Pages complètes dynamiques : règlement, finale, sponsor, cadeau...
                const DynamicPagesFeed(placement: 'home', limit: 3),

                _matchLoungeCTA(context, prov),
                const SizedBox(height: 16),

                // No team CTA / Salon équipe
                if (prov.myTeam == null) ...[
                  _joinTeamCTA(context),
                  const SizedBox(height: 16),
                ] else ...[
                  _teamChatCTA(context, prov),
                  const SizedBox(height: 16),
                ],

                const DynamicContentFeed(placement: 'home_after_team'),

                // Pastilles rondes de la phase finale active.
                if (activeKnockoutMatches.isNotEmpty) ...[
                  _sectionHeader(
                    '⚔️ $activePhaseTitle',
                    badge: '${activeKnockoutMatches.length} restants',
                    badgeColor: AppColors.cyan,
                  ),
                  const SizedBox(height: 10),
                  _knockoutStrip(context, prov, activeKnockoutMatches),
                  const SizedBox(height: 20),
                ],

                // Phase finale EN DIRECT / commencés (verrouillés + score)
                if (knockoutLive.isNotEmpty) ...[
                  _sectionHeader('⚔️ PHASE FINALE EN DIRECT',
                      badge: 'LIVE', badgeColor: AppColors.canadaRed),
                  const SizedBox(height: 10),
                  ...knockoutLive.map((m) => MatchCard(match: m)),
                  const SizedBox(height: 20),
                ],

                // Phase finale (à voter — uniquement les matchs à venir)
                if (knockoutToVote.isNotEmpty) ...[
                  _sectionHeader('⚔️ PHASE FINALE — VOTE !', badge: 'NEW', badgeColor: AppColors.gold),
                  const SizedBox(height: 10),
                  ...knockoutToVote.take(6).map((m) => MatchCard(match: m)),
                  const SizedBox(height: 20),
                ],

                // Accès au Tableau final (arbre)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const BracketScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Text('🏆', style: TextStyle(fontSize: 16)),
                      label: Text('VOIR LE TABLEAU FINAL',
                          style: GoogleFonts.barlowCondensed(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.6)),
                    ),
                  ),
                ),

                // Today
                if (today.isNotEmpty) ...[
                  _sectionHeader("MATCHS D'AUJOURD'HUI", badge: 'LIVE', badgeColor: AppColors.canadaRed),
                  const SizedBox(height: 10),
                  ...today.map((m) => MatchCard(match: m)),
                  const SizedBox(height: 20),
                ],

                // Upcoming
                if (upcoming.isNotEmpty) ...[
                  _sectionHeader('PROCHAINS MATCHS'),
                  const SizedBox(height: 10),
                  ...upcoming.map((m) => MatchCard(match: m)),
                  const SizedBox(height: 20),
                ],

                const DynamicContentFeed(placement: 'home_bottom'),

                // Empty state
                if (today.isEmpty && upcoming.isEmpty && knockoutToVote.isEmpty)
                  _emptyState(),
              ])),
            ),
          ],
        ),
      ),
    );
  }

  MatchPhase? _activeKnockoutPhase(
      AppProvider prov, List<FootballMatch> knockoutMatches) {
    const order = <MatchPhase>[
      MatchPhase.seizieme,
      MatchPhase.huitieme,
      MatchPhase.quart,
      MatchPhase.demi,
      MatchPhase.troisieme,
      MatchPhase.finale,
    ];

    for (final phase in order) {
      final remaining = knockoutMatches.any(
        (m) => m.phase == phase && !prov.results.containsKey(m.id),
      );
      if (remaining) return phase;
    }
    return null;
  }

  String _phaseTitle(MatchPhase phase) {
    switch (phase) {
      case MatchPhase.seizieme:
        return '16es de finale';
      case MatchPhase.huitieme:
        return '8es de finale';
      case MatchPhase.quart:
        return 'Quarts de finale';
      case MatchPhase.demi:
        return 'Demi-finales';
      case MatchPhase.troisieme:
        return 'Match 3e place';
      case MatchPhase.finale:
        return 'Finale';
      case MatchPhase.groupe:
        return 'Phase de groupes';
    }
  }

  // ── Hero banner ─────────────────────────────────────────
  Widget _heroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withOpacity(0.15),
            AppColors.usaBlue.withOpacity(0.10),
            AppColors.mexicoGreen.withOpacity(0.12),
          ],
        ),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Stack(children: [
        Positioned(
          right: -20, top: -20,
          child: Opacity(
            opacity: 0.15,
            child: Text('26',
              style: GoogleFonts.bebasNeue(
                color: AppColors.gold, fontSize: 140, height: 0.85, letterSpacing: -6)),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WC2026Wordmark(fontSize: 11),
            const SizedBox(height: 8),
            ShaderMask(
              shaderCallback: (r) => AppColors.trophyGradient.createShader(r),
              child: Text('PRONOCUP\nMondial 2026',
                style: GoogleFonts.bebasNeue(
                  color: Colors.white, fontSize: 34, height: 0.95, letterSpacing: 3)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _hostChip('🇨🇦', 'CAN', AppColors.canadaRed),
              const SizedBox(width: 6),
              _hostChip('🇺🇸', 'USA', AppColors.usaBlue),
              const SizedBox(width: 6),
              _hostChip('🇲🇽', 'MEX', AppColors.mexicoGreen),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '11 juin – 19 juillet',
                textAlign: TextAlign.right,
                style: GoogleFonts.barlowCondensed(
                  color: AppColors.text2, fontSize: 11, letterSpacing: 0.6),
              )),
            ]),
          ],
        ),
      ]),
    );
  }


  Widget _worldCupCountdown() {
    final kickoffParis = DateTime.utc(2026, 6, 11, 19, 0).toLocal(); // 21:00 France

    String two(int v) => v.toString().padLeft(2, '0');

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final diff = kickoffParis.difference(DateTime.now());
        final started = diff.isNegative;
        final safe = started ? Duration.zero : diff;
        final days = safe.inDays;
        final hours = safe.inHours.remainder(24);
        final minutes = safe.inMinutes.remainder(60);
        final seconds = safe.inSeconds.remainder(60);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg2.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withOpacity(0.22)),
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppColors.trophyGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text('🏆', style: TextStyle(fontSize: 21)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  started ? 'LE MONDIAL EST LANCÉ' : 'DÉPART DU MONDIAL DANS',
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.text2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  started
                    ? 'Les pronostics sont ouverts match par match'
                    : '${days}j ${two(hours)}h ${two(minutes)}m ${two(seconds)}s',
                  style: GoogleFonts.bebasNeue(
                    color: AppColors.gold,
                    fontSize: started ? 18 : 24,
                    letterSpacing: 1.8,
                  ),
                ),
                Text(
                  'Ouverture : 11 juin 2026 à 21:00, heure de France',
                  style: GoogleFonts.barlow(
                    color: AppColors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            )),
          ]),
        );
      },
    );
  }

  Widget _hostChip(String flag, String code, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(flag, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(code, style: GoogleFonts.barlowCondensed(
          color: color, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6)),
      ]),
    );
  }

  Widget _statBox(String icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg2.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.bebasNeue(color: color, fontSize: 22, height: 1)),
            Text(label, style: GoogleFonts.barlowCondensed(
              color: AppColors.text2, fontSize: 10, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _knockoutStrip(
      BuildContext context, AppProvider prov, List<FootballMatch> matches) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final itemWidth = compact ? 78.0 : 86.0;
        final gap = compact ? 10.0 : 14.0;

        return SizedBox(
          height: compact ? 122 : 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (_, __) => SizedBox(width: gap),
            itemBuilder: (_, i) => _knockoutBadge(
              context,
              prov,
              matches[i],
              width: itemWidth,
              compact: compact,
            ),
          ),
        );
      },
    );
  }

  Widget _knockoutBadge(
    BuildContext context,
    AppProvider prov,
    FootballMatch m, {
    required double width,
    required bool compact,
  }) {
    final home = kTeams[m.homeCode];
    final away = kTeams[m.awayCode];
    final result = prov.results[m.id];
    final isLive = (prov.isLiveMatch(m.id) || m.hasStarted) && result == null;
    final isFinished = result != null;
    final circleSize = compact ? 56.0 : 60.0;

    final List<Color> ring = isLive
        ? [AppColors.canadaRed, AppColors.gold]
        : isFinished
            ? [AppColors.grey, AppColors.bg3]
            : [AppColors.cyan, AppColors.usaBlue];

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BracketScreen()),
      ),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: ring),
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: circleSize,
                      height: circleSize,
                      child: Column(children: [
                        Expanded(child: _flagHalf(home)),
                        Expanded(child: _flagHalf(away)),
                      ]),
                    ),
                  ),
                ),
                if (isLive)
                  Positioned(
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.canadaRed,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.bg0, width: 1.5),
                      ),
                      child: Text('LIVE',
                          style: GoogleFonts.barlowCondensed(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 8 : 10),
            SizedBox(
              width: width,
              height: compact ? 17 : 18,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  '${m.homeCode} V ${m.awayCode}',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.text,
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: width,
              child: Text(
                '${m.localDate.substring(8, 10)}/${m.localDate.substring(5, 7)} · ${m.localTime}',
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.barlowCondensed(
                  color: AppColors.grey,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flagHalf(TeamInfo? team) {
    if (team == null || team.flagCode.isEmpty) {
      return Container(
        color: AppColors.bg3,
        alignment: Alignment.center,
        child: Text(team?.emoji ?? '🌍', style: const TextStyle(fontSize: 16)),
      );
    }
    return CachedNetworkImage(
      imageUrl: 'https://flagcdn.com/w160/${team.flagCode.toLowerCase()}.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(color: AppColors.bg3),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.bg3,
        alignment: Alignment.center,
        child: Text(team.emoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? badge, Color? badgeColor}) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            gradient: AppColors.trophyGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(title, style: GoogleFonts.bebasNeue(
          color: AppColors.text, fontSize: 18, letterSpacing: 1.5)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppColors.usaBlue).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (badgeColor ?? AppColors.usaBlue).withOpacity(0.4)),
            ),
            child: Text(badge, style: GoogleFonts.barlowCondensed(
              color: badgeColor ?? AppColors.usaBlue, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ],
      ],
    );
  }

  Widget _matchLoungeCTA(BuildContext context, AppProvider prov) {
    final active = prov.activeMatchLoungeMatch();
    final next = prov.nextLoungeMatch();
    final match = active ?? next;
    if (match == null) return const SizedBox.shrink();

    final home = kTeams[match.homeCode]?.name ?? match.homeCode;
    final away = kTeams[match.awayCode]?.name ?? match.awayCode;
    final dt = match.dateTime;
    final dateLabel = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final isOpen = active != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchLoungeScreen(initialMatch: match),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.gold.withOpacity(0.16),
              AppColors.usaBlue.withOpacity(0.10),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withOpacity(0.32)),
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.trophyGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                isOpen ? Icons.stadium_rounded : Icons.schedule_rounded,
                color: const Color(0xFF151515),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOpen ? 'TRIBUNE DU MATCH OUVERTE' : 'PROCHAINE TRIBUNE DU MATCH',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bebasNeue(
                      color: AppColors.gold,
                      fontSize: 17,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$home vs $away',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlow(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOpen ? 'Réagis avec tous les supporters maintenant.' : 'Ouverture 45 min avant · $dateLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isOpen ? AppColors.mexicoGreen : AppColors.usaBlue).withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isOpen ? AppColors.mexicoGreen : AppColors.usaBlue).withOpacity(0.35),
                ),
              ),
              child: Text(
                isOpen ? 'LIVE' : 'BIENTÔT',
                style: GoogleFonts.barlowCondensed(
                  color: isOpen ? AppColors.mexicoGreen : AppColors.usaBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.text2),
          ]),
        ),
      ),
    );
  }

  Widget _teamChatCTA(BuildContext context, AppProvider prov) {
    final team = prov.myTeam;
    if (team == null) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TeamChatScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.mexicoGreen.withOpacity(0.12),
              AppColors.cyan.withOpacity(0.08),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.mexicoGreen.withOpacity(0.28)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mexicoGreen.withOpacity(0.15),
                border: Border.all(color: AppColors.mexicoGreen.withOpacity(0.4)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.forum_rounded, color: AppColors.mexicoGreen),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SALON DE TON ÉQUIPE',
                  style: GoogleFonts.bebasNeue(color: AppColors.mexicoGreen, fontSize: 16, letterSpacing: 1)),
                Text('Discutez pronos et matchs avec ${team.name}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 13)),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: AppColors.text2),
          ]),
        ),
      ),
    );
  }

  Widget _joinTeamCTA(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onJoinTeamTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Ouvrez l'onglet Équipe pour créer ou rejoindre une équipe.")),
              );
            },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.usaBlue.withOpacity(0.12),
              AppColors.gold.withOpacity(0.10),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withOpacity(0.15),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.group_add_rounded, color: AppColors.gold),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REJOINDRE UNE ÉQUIPE',
                    style: GoogleFonts.bebasNeue(color: AppColors.gold, fontSize: 16, letterSpacing: 1)),
                  Text('Formez une équipe de 4 collègues !',
                    style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 13)),
                ],
              )),
              const Icon(Icons.chevron_right_rounded, color: AppColors.text2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text('⚽', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (r) => AppColors.trophyGradient.createShader(r),
              child: Text('LA COUPE DU MONDE ARRIVE !',
                style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 22, letterSpacing: 1.5),
                textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            Text('Le tournoi commence le 11 juin 2026.\nPréparez votre équipe dès maintenant !',
              style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
