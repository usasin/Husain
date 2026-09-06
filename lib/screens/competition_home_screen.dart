import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_match_tile.dart';
import '../widgets/wc26_background.dart';
import '../widgets/knowledge_meter.dart';
import '../widgets/reputation_badge.dart';
import '../l10n/app_locale.dart';

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
  String _selected = 'all';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();
    final matches = provider.matches
        .where((m) =>
            (_selected == 'all' || m.competitionId == _selected) &&
            m.dateTime.isAfter(now))
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                sliver: SliverToBoxAdapter(child: _topBar(provider)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                sliver: SliverToBoxAdapter(child: _teamOverview(provider)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                sliver: SliverToBoxAdapter(child: _quickActions(provider)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                sliver: SliverToBoxAdapter(child: _sectionTitle()),
              ),
              SliverToBoxAdapter(child: _competitionPicker()),
              if (matches.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  sliver: SliverToBoxAdapter(child: _emptyState(provider)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                  sliver: SliverList.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) => CompactMatchTile(match: matches[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(AppProvider provider) {
    final name = provider.currentUser?.name.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const WC2026Wordmark(fontSize: 15),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.bg2.withOpacity(.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(.07)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 15, color: AppColors.lime),
              const SizedBox(width: 4),
              Text(
                name == null || name.isEmpty ? 'PRONO4' : name,
                style: GoogleFonts.inter(
                  color: AppColors.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teamOverview(AppProvider provider) {
    final user = provider.currentUser;
    final team = provider.myTeam;
    final myPoints = user == null ? 0 : provider.getUserPoints(user.id);
    final teamPoints = team == null ? 0.0 : provider.getTeamPoints(team.id);
    final ranking = provider.getTeamRanking();
    var teamRank = 0;
    if (team != null) {
      final idx = ranking.indexWhere((e) => (e['team'] as AppTeam).id == team.id);
      if (idx >= 0) teamRank = idx + 1;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.93),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lime.withOpacity(.16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withOpacity(.06),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Bonjour ${user?.name ?? 'joueur'} 👋', 'Hi ${user?.name ?? 'player'} 👋'),
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            context.tr('Une équipe. Plus de foot. Plus de victoires.', 'One team. More football. More wins.'),
            style: GoogleFonts.inter(
              color: AppColors.text2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg3.withOpacity(.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lime.withOpacity(.12),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.lime.withOpacity(.24)),
                  ),
                  child: const Icon(Icons.groups_2_rounded,
                      color: AppColors.lime, size: 27),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team?.name ?? context.tr('Crée ton équipe', 'Create your team'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        team == null
                            ? context.tr('Jusqu’à 4 joueurs', 'Up to 4 players')
                            : context.isEnglish
                                ? '${team.memberIds.length}/4 members'
                                : '${team.memberIds.length}/4 membres',
                        style: GoogleFonts.inter(
                          color: AppColors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lime.withOpacity(.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    children: [
                      Text(
                        team == null ? '$myPoints' : teamPoints.toStringAsFixed(0),
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.lime,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      Text(
                        team == null ? context.tr('MES PTS','MY PTS') : context.tr('PTS ÉQUIPE','TEAM PTS'),
                        style: GoogleFonts.inter(
                          color: AppColors.text2,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metric(
                  Icons.emoji_events_rounded,
                  teamRank == 0 ? '—' : (context.isEnglish ? '#$teamRank' : '${teamRank}e'),
                  context.tr('classement équipe','team ranking'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  Icons.trending_up_rounded,
                  '$myPoints',
                  context.tr('mes points','my points'),
                ),
              ),
            ],
          ),
          if (user != null) ...[
            FootballKnowledgeMeter(
              score: provider.getUserKnowledgeScore(user.id),
              played: provider.getUserResolvedVoteCount(user.id),
              correct: provider.getUserCorrectCount(user.id),
              currentStreak: provider.getUserCurrentStreak(user.id),
              goodForm: provider.getUserGoodForm(user.id),
            ),
            const SizedBox(height: 10),
            Row(children: [
              ReputationBadgeChip(badge: provider.reputationBadgeFor(user.id)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                context.tr('Ta réputation évolue avec tes résultats et les votes de tes coéquipiers.', 'Your reputation evolves with results and teammate votes.'),
                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9.5, height: 1.25),
              )),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _quickActions(AppProvider provider) {
    final hasTeam = provider.myTeam != null;
    return Row(
      children: [
        _quickAction(Icons.sports_soccer_rounded, context.tr('Matchs', 'Matches'), widget.onMatchesTap),
        const SizedBox(width: 8),
        _quickAction(Icons.leaderboard_rounded, context.tr('Classement', 'Ranking'), widget.onRankingTap),
        const SizedBox(width: 8),
        _quickAction(hasTeam ? Icons.groups_2_rounded : Icons.group_add_rounded,
            context.tr('Équipe', 'Team'), widget.onTeamTap),
        const SizedBox(width: 8),
        _quickAction(Icons.person_add_alt_1_rounded, context.tr('Inviter', 'Invite'), widget.onTeamTap),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback tap) => Expanded(
        child: Material(
          color: AppColors.bg2.withOpacity(.94),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
              child: Column(
                children: [
                  Icon(icon, color: AppColors.lime, size: 20),
                  const SizedBox(height: 5),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppColors.text2,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _metric(IconData icon, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.bg1.withOpacity(.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.lime, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          height: 1)),
                  const SizedBox(height: 2),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppColors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sectionTitle() => Row(
        children: [
          Expanded(
            child: Text(
              context.tr('Matchs à venir','Upcoming matches'),
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onMatchesTap,
            child: Text(context.tr('Voir tout','See all')),
          ),
        ],
      );

  Widget _competitionPicker() {
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        children: [
          _chip('all', context.tr('Tout','All')),
          ...kCompetitions.map((c) => _chip(c.id, competitionDisplayShortName(context, c))),
        ],
      ),
    );
  }

  Widget _chip(String id, String label) {
    final selected = _selected == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _selected = id),
        label: Text(label),
        selectedColor: AppColors.lime,
        backgroundColor: AppColors.bg2,
        side: BorderSide(
          color: selected ? AppColors.lime : Colors.white.withOpacity(.07),
        ),
        labelStyle: GoogleFonts.inter(
          color: selected ? AppColors.bg0 : AppColors.text2,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _emptyState(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Column(
        children: [
          const Icon(Icons.sports_soccer_rounded,
              color: AppColors.lime, size: 42),
          const SizedBox(height: 10),
          Text(
            context.tr('Aucun match à venir', 'No upcoming matches'),
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            provider.adminMode
                ? context.tr('Lance la synchronisation des calendriers officiels depuis l’onglet Matchs.', 'Sync official fixtures from the Matches tab.')
                : context.tr('Les rencontres apparaîtront ici dès leur publication.', 'Fixtures will appear here as soon as they are published.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
