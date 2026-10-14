import '../widgets/home_match_status_bar.dart';
import '../widgets/social_auth_panel.dart';
import '../widgets/club_match_editor.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../data/home_match_filter.dart';
import '../data/home_live_score_feed.dart';
import '../data/duel_selector.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/announcement_banner.dart';
import '../widgets/club_crest.dart';
import '../widgets/compact_match_tile.dart';
import '../widgets/dynamic_content_feed.dart';
import '../widgets/dynamic_pages_feed.dart';
import '../widgets/home_player_card.dart';
import '../widgets/recent_points_recap.dart';
import '../theme/app_theme_controller.dart';
import 'calendar_screen.dart';
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
  final VoidCallback onRankingTap;
  final VoidCallback onTeamTap;
  final VoidCallback onProfileTap;

  const CompetitionHomeScreen({
    super.key,
    required this.onRankingTap,
    required this.onTeamTap,
    required this.onProfileTap,
  });

  @override
  State<CompetitionHomeScreen> createState() => _CompetitionHomeScreenState();
}

class _CompetitionHomeScreenState extends State<CompetitionHomeScreen> {
  DateTime _now = DateTime.now();
  DateTime? _selectedDay;
  final _matchesAnchor = GlobalKey();
  String _competition = 'all';
  HomeMatchStatus _status = HomeMatchStatus.upcoming;
  // Une seule écoute Firestore pour tous les scores de l'accueil.
  // Séparée des résultats officiels / points / duels.
  StreamSubscription<User?>? _authForLiveSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveScoresSub;
  Map<String, HomeLiveScore> _liveScores = {};
  DateTime? _liveScoreCheckedAt;
  late final Timer _clock;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _selectionStream;
  late final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>>
      _visualStreams;

  @override
  void initState() {
    super.initState();
    _selectionStream = _selectionFor(_now);
    _visualStreams = {
      for (final comp in kCompetitions)
        comp.id: FirebaseFirestore.instance
            .collection('dynamicContents')
            .doc('duel_visual_${comp.id}')
            .snapshots(),
    };
    _authForLiveSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _liveScoresSub?.cancel();
      _liveScoresSub = null;
      if (!mounted) return;
      if (user == null) {
        setState(() { _liveScores = {}; _liveScoreCheckedAt = null; });
        return;
      }
      _liveScoresSub = FirebaseFirestore.instance
          .collection('system')
          .doc('prono4LiveScores')
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        final data = snap.data();
        final rawTime = data?['checkedAt'];
        setState(() {
          _liveScoreCheckedAt = rawTime is Timestamp ? rawTime.toDate() : null;
          _liveScores = parseHomeLiveScores(data, DateTime.now());
        });
      }, onError: (error) {
        // Mode dégradé : l'accueil garde ses données précédentes.
        debugPrint('PRONO4 live scores: $error');
      });
    });
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final next = DateTime.now();
      setState(() {
        if (_duelDateKey(next) != _duelDateKey(_now)) {
          _selectionStream = _selectionFor(next);
        }
        _now = next;
      });
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _selectionFor(DateTime day) =>
      FirebaseFirestore.instance
          .collection('dynamicContents')
          .doc('duel_selection_${_duelDateKey(day)}')
          .snapshots();

  @override
  void dispose() {
    _clock.cancel();
    _authForLiveSub?.cancel();
    _liveScoresSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = _now;
    // Accueil : un statut de match en cours prévaut sur un score provisoire.
    // Aucune modification des résultats, des points ou des autres pages.
    final visibleMatches = provider.visibleMatches;
    final visibleMatchesById = {
      for (final match in visibleMatches) match.id: match,
    };
    HomeLiveScore? freshScore(String matchId) {
      final checked = _liveScoreCheckedAt;
      if (checked == null || now.difference(checked) > const Duration(minutes: 45)) {
        return null;
      }
      return _liveScores[matchId];
    }
    bool homeLive(String matchId) {
      final liveScore = freshScore(matchId);
      if (liveScore?.isLive == true) return true;
      if (liveScore?.isFinished == true) return false;
      final match = visibleMatchesById[matchId];
      return match != null && isHomeLiveMatch(
        match: match,
        now: now,
        liveStatus: provider.liveStatusFor(matchId),
        hasRecordedResult: provider.results.containsKey(matchId),
      );
    }
    bool homeFinished(String matchId) =>
        freshScore(matchId)?.isFinished == true ||
        (!homeLive(matchId) && isHomeFinishedMatch(
          liveStatus: provider.liveStatusFor(matchId),
          hasRecordedResult: provider.results.containsKey(matchId),
        ));

    final today = filterHomeMatches(
      matches: visibleMatches,
      now: now,
      isLive: homeLive,
      isFinished: homeFinished,
    );
    final selectedDay = _selectedDay ?? now;
    final dayMatches = filterHomeMatches(
        matches: visibleMatches,
        now: now,
        day: selectedDay,
        isLive: homeLive,
        isFinished: homeFinished);
    final effectiveCompetition =
        _competition == 'all' || provider.isCompetitionEnabled(_competition)
            ? _competition
            : 'all';
    final homeMatches = filterHomeMatches(
      matches: dayMatches,
      now: now,
      day: selectedDay,
      competitionId: effectiveCompetition,
      status: _status,
      isLive: homeLive,
      isFinished: homeFinished,
    );

    return Scaffold(
      floatingActionButton: provider.adminMode
          ? FloatingActionButton(
              tooltip: context.tr('Ajouter un match', 'Add match'),
              onPressed: () => showClubMatchEditor(context, provider,
                  initialCompetition: effectiveCompetition),
              child: const Icon(Icons.add_rounded))
          : null,
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                sliver: SliverToBoxAdapter(child: _topBar()),
              ),
              if (!provider.hasConnectedAccount)
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    sliver: SliverToBoxAdapter(
                        child: Column(children: [
                      const SocialAuthPanel(compact: true),
                      TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(
                                      initialSection: 'account'))),
                          icon: const Icon(Icons.manage_accounts_rounded,
                              size: 16),
                          label: Text(context.tr('Retrouver mon ancien profil',
                              'Recover my previous profile'))),
                    ]))),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: HomePlayerCard(
                    provider: provider,
                    onCreateTeam: () => _openTeam('create'),
                    onJoinTeam: () => _openTeam('join'),
                    onTeamTap: widget.onTeamTap,
                    onProfileTap: widget.onProfileTap,
                    onRankingTap: widget.onRankingTap,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: RecentPointsRecap(
                    onRankingTap: widget.onRankingTap,
                    onProfileTap: widget.onProfileTap,
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
                sliver: SliverToBoxAdapter(child: GameLoopCard()),
              ),
              SliverToBoxAdapter(child: _duelsSection(provider, today, now)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                sliver: SliverToBoxAdapter(
                  child: KeyedSubtree(
                      key: _matchesAnchor,
                      child: _titleRow(
                        '⚽ ${context.tr('Matchs du jour', "Today’s matches")}',
                        _dayLabel(selectedDay),
                        _chooseDay,
                        subtitle:
                            '${dayMatches.length} ${context.tr('rencontres', 'matches')}',
                      )),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _HomeFiltersDelegate(
                  height: 122 +
                      (MediaQuery.textScalerOf(context).scale(13) - 13).clamp(
                            0.0,
                            30.0,
                          ) *
                          4,
                  child: _filters(provider, effectiveCompetition),
                ),
              ),
              if (homeMatches.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  sliver: SliverToBoxAdapter(
                      child: _emptyState(dayMatches.isEmpty)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
                  sliver: SliverList.builder(
                    itemCount: homeMatches.length,
                    itemBuilder: (context, index) => CompactMatchTile(
                      match: homeMatches[index],
                      directPrediction: true,
                      homeLiveOverride: homeLive(homeMatches[index].id),
                      homeFinishedOverride: homeFinished(homeMatches[index].id),
                      homeLiveScoreOverride: freshScore(homeMatches[index].id)?.score,
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
                padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
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

  String _dayLabel(DateTime value) {
    final today = DateTime(_now.year, _now.month, _now.day);
    final date = DateTime(value.year, value.month, value.day);
    if (date == today) return context.tr('Aujourd’hui ▾', 'Today ▾');
    return '${DateFormat.MMMd(context.isEnglish ? 'en' : 'fr').format(date)} ▾';
  }

  Future<void> _chooseDay() async {
    final current = _selectedDay ?? _now;
    final picked = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(_now.year - 1),
        lastDate: DateTime(_now.year + 2, 12, 31));
    if (picked == null || !mounted) return;
    final today = DateTime(_now.year, _now.month, _now.day);
    setState(() {
      _selectedDay = picked == today ? null : picked;
      _status = picked.isBefore(today)
          ? HomeMatchStatus.finished
          : HomeMatchStatus.upcoming;
    });
  }

  void _showTodayMatches() {
    setState(() {
      _selectedDay = null;
      _competition = 'all';
      _status = HomeMatchStatus.upcoming;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _matchesAnchor.currentContext;
      if (target != null)
        Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 250), alignment: 0);
    });
  }

  void _openTeam(String mode) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TeamScreen(initialMode: mode)));
  }

  Widget _topBar() {
    final theme = context.watch<AppThemeController>();
    final light = theme.mode == ThemeMode.light;
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
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
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: light
              ? context.tr('Mode sombre', 'Dark mode')
              : context.tr('Mode clair', 'Light mode'),
          onPressed: () =>
              theme.setMode(light ? ThemeMode.dark : ThemeMode.light),
          icon: Icon(
            light ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          ),
        ),
        IconButton(
          tooltip: context.tr('Paramètres', 'Settings'),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.settings_rounded, size: 22),
        ),
      ],
    );
  }

  Widget _filters(AppProvider provider, String competition) {
    Widget row(List<Widget> children) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: children),
        );
    Widget gap(Widget child) =>
        Padding(padding: const EdgeInsets.only(right: 8), child: child);
    return Container(
      color: AppColors.bg0.withValues(alpha: .98),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          row([
            gap(
              ChoiceChip(
                label: Text(context.tr('⚽ Tout', '⚽ All')),
                selected: competition == 'all',
                onSelected: (_) => setState(() => _competition = 'all'),
              ),
            ),
            for (final comp in provider.enabledCompetitions)
              gap(
                ChoiceChip(
                  label: Text(competitionDisplayShortName(context, comp)),
                  selected: competition == comp.id,
                  onSelected: (_) => setState(() => _competition = comp.id),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: HomeMatchStatusBar(
              value: _status,
              onChanged: (value) => setState(() => _status = value),
            ),
          ),
        ],
      ),
    );
  }

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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _selectionStream,
      builder: (context, snap) {
        final data = snap.data?.data();
        final hasManualSelection = data != null &&
            data.containsKey('selectedMatchIds') &&
            data['enabled'] != false;

        List<FootballMatch> duels;
        if (hasManualSelection && data['selectedMatchIds'] is List) {
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
                _showTodayMatches,
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
      height: 284 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 5,
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
                Row(
                  children: [
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
                            child: Text(
                              comp.emoji,
                              style: const TextStyle(fontSize: 17),
                            ),
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
                  ],
                ),
                const SizedBox(height: 8),
                _duelVisualBanner(match.competitionId),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          ClubCrest(
                            url: match.homeCrestUrl,
                            clubName: home,
                            size: 46,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            home,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: AppColors.text,
                              fontSize: _clubNameFontSize(home),
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          Text(
                            match.localTime,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            context.tr('Aujourd’hui', 'Today'),
                            style: GoogleFonts.inter(
                              color: AppColors.grey,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          ClubCrest(
                            url: match.awayCrestUrl,
                            clubName: away,
                            size: 46,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            away,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: AppColors.text,
                              fontSize: _clubNameFontSize(away),
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _visualStreams[competitionId],
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
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(onPressed: tap, child: Text(action)),
          ],
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10.5),
          ),
      ],
    );
  }

  Widget _emptyState(bool noMatchesToday) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.bg2.withOpacity(.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.06)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.sports_soccer_rounded,
              color: AppColors.lime,
              size: 38,
            ),
            const SizedBox(height: 9),
            Text(
              noMatchesToday
                  ? context.tr('Aucun match pour cette journée',
                      'No matches for this day')
                  : context.tr(
                      'Aucun match avec ces filtres',
                      'No matches with these filters',
                    ),
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ],
        ),
      );
}

class _HomeFiltersDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  _HomeFiltersDelegate({required this.height, required this.child});
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      child;
  @override
  bool shouldRebuild(covariant _HomeFiltersDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}
