import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admob_banner.dart';
import '../widgets/avatar_display.dart';
import '../widgets/club_crest.dart';
import '../widgets/community_prediction_stats.dart';
import '../widgets/match_card.dart';
import '../widgets/wc26_background.dart';
import 'match_lounge_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final FootballMatch match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool _analysisUnlocked = false;
  bool _adBusy = false;

  Future<void> _unlockAnalysis() async {
    if (_adBusy) return;
    setState(() => _adBusy = true);
    final ok = await AdService.instance.showRewardedAd();
    if (!mounted) return;
    setState(() {
      _adBusy = false;
      _analysisUnlocked = ok;
    });
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            'La pub doit être regardée jusqu’au bout pour débloquer les stats.',
            'Watch the ad to the end to unlock the stats.',
          )),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final comp = competitionById(match.competitionId);
    final provider = context.watch<AppProvider>();
    final me = provider.currentUser;
    final points = me == null ? 0 : provider.getUserMatchPoints(me.id, match.id);
    final finished = provider.results.containsKey(match.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.text, size: 20),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          if (comp != null) ...[
                            Container(
                              width: 32,
                              height: 32,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.logoPlate,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.network(
                                comp.emblemUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(comp.emoji,
                                      style: const TextStyle(fontSize: 17)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comp == null
                                      ? context.tr('Match', 'Match')
                                      : competitionDisplayName(context, comp),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  (match.stage ?? '').isEmpty
                                      ? context.tr('Saison régulière', 'Regular season')
                                      : match.stage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppColors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FavoriteClubButton(match: match, home: true),
                    const SizedBox(width: 3),
                    _FavoriteClubButton(match: match, home: false),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final content = <Widget>[
                      _Heading(match: match),
                      const SizedBox(height: 12),
                      MatchCard(match: match, showCommunityStats: false),
                      const SizedBox(height: 12),
                      _ExactScorePicker(match: match),
                      const SizedBox(height: 12),
                      _MatchLoungeEntry(match: match),
                      if (finished && points >= 3) ...[
                        const SizedBox(height: 12),
                        _WinCelebration(match: match, points: points),
                      ],
                      const SizedBox(height: 12),
                      _AnalysisGate(
                        match: match,
                        unlocked: _analysisUnlocked,
                        busy: _adBusy,
                        onUnlock: _unlockAnalysis,
                      ),
                      const SizedBox(height: 14),
                      const AdMobBanner(),
                      const SizedBox(height: 12),
                      Text(
                        context.tr(
                          'Le foot se pronostique en équipe.',
                          'Football predictions are better as a team.',
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            color: AppColors.grey, fontSize: 11),
                      ),
                    ];

                    if (constraints.maxWidth < 760) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                        children: content,
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(children: content),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _MatchLoungeEntry extends StatelessWidget {
  final FootballMatch match;
  const _MatchLoungeEntry({required this.match});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return StreamBuilder<CommunitySettings>(
      stream: prov.communitySettingsStream(),
      builder: (context, snap) {
        final settings = snap.data ?? const CommunitySettings();
        if (!settings.matchLoungeEnabled) return const SizedBox.shrink();
        final active = prov.activeMatchLoungeMatch();
        if (active?.id != match.id) return const SizedBox.shrink();
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MatchLoungeScreen(initialMatch: match)),
            ),
            icon: const Icon(Icons.stadium_rounded),
            label: Text(context.tr('TRIBUNE DU MATCH · OUVERTE', 'MATCH LOUNGE · OPEN')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF151515),
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteClubButton extends StatelessWidget {
  final FootballMatch match;
  final bool home;
  const _FavoriteClubButton({required this.match, required this.home});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final code = home ? match.homeCode : match.awayCode;
    final selected = prov.isFavoriteClub(code);
    final name = home
        ? (match.homeName ?? match.homeCode)
        : (match.awayName ?? match.awayCode);
    return Tooltip(
      message: selected
          ? context.tr('Retirer $name des favoris', 'Remove $name from favorites')
          : context.tr('Ajouter $name aux favoris', 'Add $name to favorites'),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () => prov.toggleFavoriteClub(code),
        icon: Icon(
          selected ? Icons.star_rounded : Icons.star_border_rounded,
          color: selected ? AppColors.lime : AppColors.grey,
          size: 20,
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final FootballMatch match;
  const _Heading({required this.match});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClubCrest(
          url: match.homeCrestUrl,
          clubName: match.homeName ?? match.homeCode,
          size: 44,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.tr('Mon pronostic', 'My prediction'),
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        ClubCrest(
          url: match.awayCrestUrl,
          clubName: match.awayName ?? match.awayCode,
          size: 44,
        ),
      ],
    );
  }
}

/// Avant la pub : aucune statistique ni aucun prono des collègues n'est visible.
/// Après la pub récompensée : pronos équipe + répartition communauté + forme récente.
class _AnalysisGate extends StatelessWidget {
  final FootballMatch match;
  final bool unlocked;
  final bool busy;
  final VoidCallback onUnlock;

  const _AnalysisGate({
    required this.match,
    required this.unlocked,
    required this.busy,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    if (!unlocked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg2.withOpacity(.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.lime.withOpacity(.24)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.lime.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.lock_rounded,
                color: AppColors.lime, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('ANALYSE AVANCÉE', 'ADVANCED ANALYSIS'),
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(
                    'Regarde une courte pub pour voir les pronos de ton équipe et les stats 1 / N / 2.',
                    'Watch a short ad to reveal your team picks and the 1 / X / 2 stats.',
                  ),
                  style: GoogleFonts.inter(
                    color: AppColors.text2,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: busy ? null : onUnlock,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ondemand_video_rounded, size: 17),
            label: Text(context.tr('VOIR', 'VIEW')),
          ),
        ]),
      );
    }

    return _UnlockedAnalysis(match: match);
  }
}

class _UnlockedAnalysis extends StatelessWidget {
  final FootballMatch match;
  const _UnlockedAnalysis({required this.match});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final picks = prov.teamMatchPicks(match.id);
    final homeForm = prov.recentClubForm(match.homeCode, excludeMatchId: match.id);
    final awayForm = prov.recentClubForm(match.awayCode, excludeMatchId: match.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lime.withOpacity(.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.verified_rounded,
                color: AppColors.lime, size: 18),
            const SizedBox(width: 7),
            Text(
              context.tr('ANALYSE AVANCÉE ACTIVÉE', 'ADVANCED ANALYSIS UNLOCKED'),
              style: GoogleFonts.inter(
                color: AppColors.lime,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
          ]),
          if (prov.myTeam != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.groups_2_rounded,
                  color: AppColors.lime, size: 17),
              const SizedBox(width: 7),
              Text(
                context.tr('PRONOS DE TON ÉQUIPE', 'YOUR TEAM PICKS'),
                style: GoogleFonts.inter(
                  color: AppColors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ]),
            const SizedBox(height: 9),
            SizedBox(
              // Keep enough vertical room on small Android/iPhone screens.
              // The previous 90px box could overflow when a teammate had
              // a long name or an exact-score label.
              height: 108,
              child: picks.isEmpty
                  ? Center(
                      child: Text(
                        context.tr('Aucun prono équipe pour le moment.', 'No team picks yet.'),
                        style: GoogleFonts.inter(
                            color: AppColors.grey, fontSize: 10),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: picks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final row = picks[index];
                        final user = row['user'] as AppUser;
                        final prediction = row['prediction']?.toString();
                        final exact = row['exact'] as MatchScore?;
                        final label = exact != null
                            ? exact.display
                            : prediction == 'HOME'
                                ? '1'
                                : prediction == 'DRAW'
                                    ? (context.isEnglish ? 'X' : 'N')
                                    : prediction == 'AWAY'
                                        ? '2'
                                        : '—';
                        return Container(
                          width: 92,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.bg1,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.overlayBase.withOpacity(.07)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AvatarBubble(avatar: user.avatar, size: 34),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  user.name,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppColors.text2,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: AppColors.lime,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
          const SizedBox(height: 12),
          CommunityPredictionStats(
            matchId: match.id,
            reveal: true,
            compact: false,
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('FORME RÉCENTE', 'RECENT FORM'),
            style: GoogleFonts.inter(
              color: AppColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 9),
          _formLine(context, match.homeName ?? match.homeCode, homeForm),
          const SizedBox(height: 8),
          _formLine(context, match.awayName ?? match.awayCode, awayForm),
        ],
      ),
    );
  }

  Widget _formLine(BuildContext context, String name, List<String> form) {
    String label(String value) {
      if (!context.isEnglish) return value == 'W' ? 'V' : value == 'D' ? 'N' : 'D';
      return value;
    }

    Color color(String value) => value == 'W'
        ? AppColors.lime
        : value == 'D'
            ? AppColors.gold
            : Colors.orangeAccent;

    return Row(children: [
      Expanded(
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                color: AppColors.text2,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ),
      if (form.isEmpty)
        Text(context.tr('Pas assez de données', 'Not enough data'),
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9))
      else
        ...form.map(
          (v) => Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(left: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color(v).withOpacity(.12),
              shape: BoxShape.circle,
              border: Border.all(color: color(v).withOpacity(.32)),
            ),
            child: Text(label(v),
                style: GoogleFonts.spaceGrotesk(
                    color: color(v),
                    fontSize: 9,
                    fontWeight: FontWeight.w900)),
          ),
        ),
    ]);
  }
}

/// Animation de résultat gagnant. Le score exact (5 pts = 3 + bonus 2)
/// reçoit une célébration plus spectaculaire.
class _WinCelebration extends StatefulWidget {
  final FootballMatch match;
  final int points;
  const _WinCelebration({required this.match, required this.points});

  @override
  State<_WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<_WinCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exact = widget.points >= 5;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 1 + (_controller.value * .018);
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.lime.withOpacity(.24 + _controller.value * .08),
                  AppColors.bg2,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.lime, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withOpacity(.20 + _controller.value * .12),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(right: 6, top: 0, child: _spark('✦', _controller.value)),
                Positioned(left: 4, bottom: 2, child: _spark('◆', 1 - _controller.value)),
                Column(children: [
                  Text(
                    exact
                        ? context.tr('🏆 BON PRONOSTIC !', '🏆 GREAT PICK!')
                        : context.tr('✅ BON PRONOSTIC !', '✅ GREAT PICK!'),
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exact
                        ? context.tr('Résultat exact trouvé !', 'Exact score found!')
                        : context.tr('Bon résultat trouvé !', 'Correct result found!'),
                    style: GoogleFonts.inter(
                      color: AppColors.lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.lime.withOpacity(.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.lime.withOpacity(.6)),
                    ),
                    child: Text(
                      exact
                          ? context.tr('+2 points bonus', '+2 bonus points')
                          : context.tr('+3 points', '+3 points'),
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.lime,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (exact) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Tu fais gagner des points à ton équipe !',
                        'You score extra points for your team!',
                      ),
                      style: GoogleFonts.inter(
                          color: AppColors.text2, fontSize: 10),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _spark(String text, double value) => Opacity(
        opacity: .35 + value * .65,
        child: Transform.rotate(
          angle: value * 1.8,
          child: Text(text,
              style: const TextStyle(color: AppColors.gold, fontSize: 26)),
        ),
      );
}

class _ExactScorePicker extends StatefulWidget {
  final FootballMatch match;
  const _ExactScorePicker({required this.match});
  @override
  State<_ExactScorePicker> createState() => _ExactScorePickerState();
}

class _ExactScorePickerState extends State<_ExactScorePicker> {
  int home = 1, away = 1;
  bool initialized = false, busy = false;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final saved = prov.getExactPrediction(widget.match.id);
    if (!initialized) {
      initialized = true;
      if (saved != null) {
        home = saved.homeScore;
        away = saved.awayScore;
      }
    }
    final locked = widget.match.hasStarted;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lime.withOpacity(.14)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(context.tr('Score exact', 'Exact score'),
                  style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.lime.withOpacity(.10),
                  borderRadius: BorderRadius.circular(99)),
              child: Text(context.tr('+2 pts bonus', '+2 bonus pts'),
                  style: GoogleFonts.inter(
                      color: AppColors.lime,
                      fontSize: 9,
                      fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 5),
        Text(
            context.tr(
                'Le bon résultat vaut 3 pts. Le score exact ajoute 2 pts.',
                'Correct result earns 3 pts. Exact score adds 2 pts.'),
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10.5)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _scoreSide(
                  widget.match.homeName ?? widget.match.homeCode,
                  home,
                  locked ? null : (v) => setState(() => home = v))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('-',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppColors.grey,
                      fontSize: 24,
                      fontWeight: FontWeight.w900))),
          Expanded(
              child: _scoreSide(
                  widget.match.awayName ?? widget.match.awayCode,
                  away,
                  locked ? null : (v) => setState(() => away = v))),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy || locked
                ? null
                : () async {
                    setState(() => busy = true);
                    final err =
                        await prov.castExactScore(widget.match.id, home, away);
                    if (mounted) setState(() => busy = false);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(err ??
                            context.tr('Score exact enregistré 🎯',
                                'Exact score saved 🎯'))));
                    if (err == null) {
                      unawaited(
                          AdService.instance.maybeShowPredictionInterstitial());
                    }
                  },
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(locked ? Icons.lock_rounded : Icons.check_rounded),
            label: Text(locked
                ? context.tr('PRONOSTIC VERROUILLÉ', 'PREDICTION LOCKED')
                : context.tr('VALIDER LE SCORE EXACT', 'SAVE EXACT SCORE')),
          ),
        ),
      ]),
    );
  }

  Widget _scoreSide(
          String name, int value, ValueChanged<int>? onChanged) =>
      Column(children: [
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                color: AppColors.text2,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _round(Icons.remove_rounded,
              onChanged == null
                  ? null
                  : () => onChanged((value - 1).clamp(0, 20).toInt())),
          SizedBox(
              width: 36,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900))),
          _round(Icons.add_rounded,
              onChanged == null
                  ? null
                  : () => onChanged((value + 1).clamp(0, 20).toInt())),
        ]),
      ]);

  Widget _round(IconData icon, VoidCallback? tap) => InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: AppColors.bg3,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.overlayBase.withOpacity(.08))),
          child: Icon(icon,
              size: 16,
              color: tap == null ? AppColors.grey : AppColors.lime)));
}
