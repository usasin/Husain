import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../data/duel_selector.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/announcement_banner.dart';
import '../widgets/club_crest.dart';
import '../widgets/compact_match_tile.dart';
import '../widgets/dynamic_content_feed.dart';
import '../widgets/dynamic_pages_feed.dart';
import '../widgets/reputation_badge.dart';
import '../widgets/game_loop_card.dart';
import '../widgets/wc26_background.dart';
import '../l10n/app_locale.dart';
import 'match_detail_screen.dart';
import 'settings_screen.dart';

/// PRONO4 — accueil 2026.
/// Objectif : une page compréhensible en quelques secondes :
/// 1) mon badge / ma progression ; 2) les duels par compétition ;
/// 3) les matchs du jour avec pronostic 1/N/2 directement sur la carte.
class CompetitionHomeScreen extends StatefulWidget {
  final VoidCallback onMatchesTap;
  final VoidCallback onRankingTap;
  final VoidCallback onTeamTap;

  const CompetitionHomeScreen({
    super.key,
    required this.onMatchesTap,
    required this.onRankingTap,
    required this.onTeamTap,
  });

  @override
  State<CompetitionHomeScreen> createState() => _CompetitionHomeScreenState();
}

class _CompetitionHomeScreenState extends State<CompetitionHomeScreen> {
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();
    final visible = provider.visibleMatches.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final today = visible
        .where((m) => _sameDay(m.dateTime.toLocal(), now.toLocal()))
        .toList();
    final upcoming = visible.where((m) => m.dateTime.isAfter(now)).toList();
    // L'accueil reste utile même les jours sans rencontre : on montre alors
    // les prochains matchs au lieu d'un écran vide.
    final homeMatches = today.isNotEmpty ? today.take(5).toList() : upcoming.take(5).toList();
    final matchesTitle = today.isNotEmpty
        ? context.tr('Matchs du jour', "Today's matches")
        : context.tr('Prochains matchs', 'Upcoming matches');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                sliver: SliverToBoxAdapter(child: _topBar()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                sliver: SliverToBoxAdapter(child: _badgeHero(provider)),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
                sliver: SliverToBoxAdapter(child: GameLoopCard()),
              ),
              SliverToBoxAdapter(
                child: _duelsSection(provider, today, now),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                sliver: SliverToBoxAdapter(
                  child: _titleRow(
                    '⚽ $matchesTitle',
                    context.tr('Voir tout', 'See all'),
                    widget.onMatchesTap,
                  ),
                ),
              ),
              if (homeMatches.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  sliver: SliverToBoxAdapter(child: _emptyState()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
                  sliver: SliverList.builder(
                    itemCount: homeMatches.length,
                    itemBuilder: (context, index) => CompactMatchTile(
                      match: homeMatches[index],
                      directPrediction: true,
                    ),
                  ),
                ),

              // Le contenu distant est conservé mais placé plus bas pour que
              // l'action principale reste lisible immédiatement.
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(18, 4, 18, 0),
                sliver: SliverToBoxAdapter(child: AnnouncementBanner()),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: DynamicContentFeed(placement: 'home_top'),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: DynamicPagesFeed(placement: 'home', limit: 3),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 118),
                sliver: SliverToBoxAdapter(
                  child: DynamicContentFeed(placement: 'home_bottom'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Text.rich(
          TextSpan(
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
            children: const [
              TextSpan(
                text: 'P4 ',
                style: TextStyle(
                  color: AppColors.lime,
                  fontStyle: FontStyle.italic,
                ),
              ),
              TextSpan(text: 'PRONO4'),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: context.tr('Paramètres', 'Settings'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.bg2.withOpacity(.92),
            foregroundColor: AppColors.text,
            side: BorderSide(color: AppColors.overlayBase.withOpacity(.08)),
          ),
          icon: const Icon(Icons.settings_rounded, size: 22),
        ),
      ],
    );
  }

  Widget _badgeHero(AppProvider provider) {
    final user = provider.currentUser;
    if (user == null) return const SizedBox.shrink();
    final team = provider.myTeam;
    final badge = provider.getAutoReputationBadge(user.id);
    final asset = reputationBadgeAsset(context, badge);
    final knowledge = provider.getUserKnowledgeScore(user.id);
    final teamPoints = team == null ? provider.getUserPoints(user.id) : provider.getTeamPoints(team.id).round();
    final ranking = provider.getTeamRanking();
    var teamRank = 0;
    if (team != null) {
      final idx = ranking.indexWhere((e) => (e['team'] as AppTeam).id == team.id);
      if (idx >= 0) teamRank = idx + 1;
    }
    final next = _nextThreshold(badge, knowledge);
    final remaining = (next - knowledge).clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Bonjour ${user.name} 👋', 'Hi ${user.name} 👋'),
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.text,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.lime.withOpacity(.11),
                AppColors.bg2.withOpacity(.97),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.lime.withOpacity(.35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.lime.withOpacity(.08),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bg1.withOpacity(.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.lime.withOpacity(.22),
                          blurRadius: 25,
                        ),
                      ],
                    ),
                    child: asset == null
                        ? const Center(
                            child: Icon(Icons.shield_rounded,
                                color: AppColors.lime, size: 72),
                          )
                        : Image.asset(asset, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bg3.withOpacity(.72),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.overlayBase.withOpacity(.06),
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 39,
                              height: 39,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.lime.withOpacity(.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.groups_2_rounded,
                                  color: AppColors.lime, size: 23),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    team?.name ?? context.tr('Sans équipe', 'No team'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.spaceGrotesk(
                                      color: AppColors.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    team == null
                                        ? context.tr('Crée ton équipe', 'Create your team')
                                        : '${team.memberIds.length}/4 ${context.tr('membres', 'members')}',
                                    style: GoogleFonts.inter(
                                      color: AppColors.text2,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: _miniMetric(
                              Icons.emoji_events_rounded,
                              teamRank == 0
                                  ? '—'
                                  : context.isEnglish
                                      ? '#$teamRank'
                                      : '${teamRank}e',
                              context.tr('classement', 'ranking'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _miniMetric(
                              Icons.trending_up_rounded,
                              '$teamPoints',
                              team == null
                                  ? context.tr('mes pts', 'my pts')
                                  : context.tr('pts équipe', 'team pts'),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(children: [
                Text(
                  context.tr('Progression', 'Progress'),
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '$knowledge/100',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ]),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: knowledge / 100,
                  minHeight: 9,
                  backgroundColor: AppColors.bg3,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  remaining == 0
                      ? context.tr('Niveau maximum atteint 👑', 'Maximum level reached 👑')
                      : context.tr(
                          'Encore $remaining points pour le niveau suivant !',
                          '$remaining points to the next level!',
                        ),
                  style: GoogleFonts.inter(
                    color: AppColors.text2,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _nextThreshold(String badge, int score) {
    final normalized = badge.toUpperCase();
    if (normalized == 'FOOTIX') return 55;
    if (normalized == 'AMATEUR') return 70;
    if (normalized == 'CONNAISSEUR') return 85;
    if (normalized == 'CONFIRMÉ' || normalized == 'CONFIRME') return 100;
    if (normalized == 'EXPERT') return score;
    return 55;
  }

  Widget _miniMetric(IconData icon, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.bg1.withOpacity(.76),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.05)),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.lime, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: AppColors.grey,
                        fontSize: 8,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ]),
      );

  String _duelDateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Widget _duelsSection(
    AppProvider provider,
    List<FootballMatch> today,
    DateTime now,
  ) {
    if (today.isEmpty) return const SizedBox.shrink();
    final ref = FirebaseFirestore.instance
        .collection('dynamicContents')
        .doc('duel_selection_${_duelDateKey(now)}');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final hasManualSelection = data != null &&
            data.containsKey('selectedMatchIds') &&
            data['enabled'] != false;

        List<FootballMatch> duels;
        if (hasManualSelection && data!['selectedMatchIds'] is List) {
          final ids = (data['selectedMatchIds'] as List)
              .map((e) => e.toString())
              .toSet();
          duels = today.where((m) => ids.contains(m.id)).toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        } else {
          duels = _duelsByCompetition(today, provider);
        }

        if (duels.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: _titleRow(
                '⚔️ ${context.tr('Duels du jour', 'Duels of the day')}',
                context.tr('Voir tout', 'See all'),
                widget.onMatchesTap,
                subtitle: context.tr(
                  'Les grandes affiches sélectionnées pour aujourd’hui.',
                  'The big matches selected for today.',
                ),
              ),
            ),
            _duelsStrip(provider, duels),
          ],
        );
      },
    );
  }

  List<FootballMatch> _duelsByCompetition(
    List<FootballMatch> matches,
    AppProvider provider,
  ) {
    return selectAutomaticDuels(
      matches,
      provider.enabledCompetitions.map((c) => c.id),
      isFavoriteClub: provider.isFavoriteClub,
    );
  }

  Widget _duelsStrip(AppProvider provider, List<FootballMatch> duels) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth * .74).clamp(236.0, 304.0).toDouble();
    return SizedBox(
      height: 318,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: duels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) =>
            _duelCard(provider, duels[index], cardWidth),
      ),
    );
  }

  Widget _duelCard(
    AppProvider provider,
    FootballMatch match,
    double cardWidth,
  ) {
    final comp = competitionById(match.competitionId);
    final home = match.homeName ?? match.homeCode;
    final away = match.awayName ?? match.awayCode;
    return SizedBox(
      width: cardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (comp?.color ?? AppColors.lime).withOpacity(.18),
                  AppColors.bg2.withOpacity(.97),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.lime.withOpacity(.36)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (comp != null)
                    Container(
                      width: 30,
                      height: 30,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.logoPlate,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        comp.emblemUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(comp.emoji, style: const TextStyle(fontSize: 17)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      comp == null
                          ? match.competitionId.toUpperCase()
                          : competitionDisplayShortName(context, comp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.text,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (comp != null)
                    Text(comp.emoji, style: const TextStyle(fontSize: 15)),
                ]),
                const SizedBox(height: 8),
                _duelVisualBanner(match.competitionId),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(
                    child: Column(children: [
                      ClubCrest(url: match.homeCrestUrl, clubName: home, size: 58),
                      const SizedBox(height: 5),
                      Text(home,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: AppColors.text,
                              fontSize: _clubNameFontSize(home),
                              height: 1.05,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(children: [
                      Text(match.localTime,
                          style: GoogleFonts.spaceGrotesk(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      Text(context.tr('Aujourd’hui', 'Today'),
                          style: GoogleFonts.inter(
                              color: AppColors.grey,
                              fontSize: 8,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  Expanded(
                    child: Column(children: [
                      ClubCrest(url: match.awayCrestUrl, clubName: away, size: 58),
                      const SizedBox(height: 5),
                      Text(away,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: AppColors.text,
                              fontSize: _clubNameFontSize(away),
                              height: 1.05,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                Container(
                  height: 38,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.tr('Voir le duel  ›', 'View duel  ›'),
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.bg0,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _clubNameFontSize(String name) {
    final length = name.trim().length;
    if (length >= 22) return 8.2;
    if (length >= 16) return 8.8;
    if (length >= 11) return 9.5;
    return 10.3;
  }

  Widget _duelVisualBanner(String competitionId) {
    final ref = FirebaseFirestore.instance
        .collection('dynamicContents')
        .doc('duel_visual_$competitionId');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final enabled = data?['enabled'] != false;
        final raw = (data?['imageB64'] ?? '').toString().trim();
        if (!enabled || raw.isEmpty) {
          return Container(
            height: 76,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  AppColors.bg3.withOpacity(.88),
                  AppColors.lime.withOpacity(.08),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.stadium_rounded,
              color: AppColors.text2.withOpacity(.55),
              size: 34,
            ),
          );
        }
        try {
          final bytes = base64Decode(raw);
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 76,
              width: double.infinity,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.bg3,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded),
                ),
              ),
            ),
          );
        } catch (_) {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _titleRow(
    String title,
    String action,
    VoidCallback tap, {
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                )),
          ),
          TextButton(onPressed: tap, child: Text(action)),
        ]),
        if (subtitle != null)
          Text(
            subtitle,
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10.5),
          ),
      ],
    );
  }

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.bg2.withOpacity(.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.06)),
        ),
        child: Column(children: [
          const Icon(Icons.sports_soccer_rounded,
              color: AppColors.lime, size: 38),
          const SizedBox(height: 9),
          Text(
            context.tr('Aucun match à venir', 'No upcoming matches'),
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ]),
      );
}
