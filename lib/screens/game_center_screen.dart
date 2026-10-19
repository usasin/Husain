import 'dart:async';
import '../data/game_month.dart';
import '../services/game_monthly_repository.dart';
import '../widgets/game_center_dashboard.dart';
import '../widgets/challenge_score_celebration.dart';
import 'game_monthly_history_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../data/competitions_data.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_display.dart';
import '../widgets/prono4_art.dart';
import '../widgets/admob_banner.dart';
import '../widgets/wc26_background.dart';
import 'match_detail_screen.dart';

class GameCenterScreen extends StatefulWidget {
  /// Affiche seulement le mode Défis depuis l’accueil.
  /// Le Centre de jeu reste disponible avec ses missions et saisons.
  final bool challengesOnly;
  final GameMonthlySource? monthlySource;
  const GameCenterScreen({super.key, this.challengesOnly = false, this.monthlySource});

  @override
  State<GameCenterScreen> createState() => _GameCenterScreenState();
}

class _GameCenterScreenState extends State<GameCenterScreen> with WidgetsBindingObserver {
  GameMonth _month = GameMonth.at(DateTime.now());
  late GameMonthlySource _monthlySource;
  Stream<GameMonthlySnapshot?>? _monthStream;
  Timer? _monthTimer;

  void _watchMonth() {
    _monthStream = _monthlySource.watch(_month);
    _monthTimer?.cancel();
    _monthTimer = Timer(_month.end.difference(DateTime.now()) + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() { _month = GameMonth.at(DateTime.now()); _watchMonth(); });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || widget.challengesOnly) return;
    final next = GameMonth.at(DateTime.now());
    if (next.key != _month.key) setState(() { _month = next; _watchMonth(); });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monthTimer?.cancel();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.challengesOnly) {
      _monthlySource = widget.monthlySource ?? context.read<AppProvider>().gameMonthlySource;
      _watchMonth();
    }
    // BUILD80: one ranking request per screen opening. Never trigger network
    // work from build(): provider notifications would otherwise rebuild this
    // widget and immediately launch the same request again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.challengesOnly) return;
      final prov = context.read<AppProvider>();
      if (!prov.rankingDataLoaded && !prov.rankingDataLoading) {
        prov.ensureRankingDataLoaded();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final user = prov.currentUser;
    if (user == null) return const SizedBox.shrink();

    if (widget.challengesOnly) {
      return Scaffold(
        backgroundColor: AppColors.bg0,
        appBar: AppBar(
          title: Text(context.tr('Mode Défis', 'Challenge mode')),
          backgroundColor: AppColors.bg1,
          foregroundColor: AppColors.text,
        ),
        body: WC2026Background(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
            children: [
              Row(children: [
                const Prono4Art(name: 'duel', size: 72),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('DÉFIS 1 CONTRE 1', 'HEAD-TO-HEAD'),
                      style: GoogleFonts.spaceGrotesk(color: AppColors.text,
                        fontWeight: FontWeight.w900, fontSize: 19)),
                    const SizedBox(height: 4),
                    Text(context.tr('Même match. Deux pronos. Un vainqueur.',
                      'One match. Two predictions. One winner.'),
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11)),
                  ],
                )),
              ]),
              const SizedBox(height: 14),
              const _ChallengesPanel(),
            ],
          ),
        ),
      );
    }

    final streak = prov.getUserDailyActivityStreak(user.id);
    final playedToday = prov.getUserHasPlayedToday(user.id);
    final xp = prov.getUserGameXp(user.id);
    final level = prov.getUserGameLevel(user.id);
    final xpInLevel = prov.getUserGameXpInLevel(user.id);
    final recap = prov.getUserLatestGameRecap(user.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(context.tr('Centre de jeu', 'Game Center')),
        backgroundColor: AppColors.bg1,
        foregroundColor: AppColors.text,
      ),
      body: WC2026Background(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            GameProgressHeader(level: level, xp: xp, xpInLevel: xpInLevel,
              streak: streak, playedToday: playedToday,
              canPlayToday: prov.hasPlayableTodayMatch),
            const SizedBox(height: 18),
            _sectionTitle(context, '🎯', context.tr('Aujourd’hui', 'Today')),
            const SizedBox(height: 8),
            _missionsCard(context, prov, user.id),
            const SizedBox(height: 18),
            StreamBuilder<GameMonthlySnapshot?>(stream: _monthStream,
              builder: (context, state) {
                final monthData = state.data?.month.key == _month.key ? state.data : null;
                return GameMonthlyCard(month: _month, snapshot: monthData,
                  userId: user.id, now: DateTime.now(),
                  loading: state.connectionState == ConnectionState.waiting,
                  hasError: state.hasError,
                  onHistory: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => GameMonthlyHistoryScreen(source: _monthlySource,
                      current: _month, userId: user.id))),
                  onStandings: () {
                    if (monthData == null) return;
                    Navigator.push(context, MaterialPageRoute<void>(
                      builder: (_) => GameMonthlyStandingsScreen(snapshot: monthData,
                        userId: user.id)));
                  });
              }),
            if (recap != null) ...[
              const SizedBox(height: 18),
              _sectionTitle(context, '📊', context.tr('Dernier bilan', 'Latest recap')),
              const SizedBox(height: 8),
              _recapCard(context, recap),
            ],
            const SizedBox(height: 18),
            _sectionTitle(context, '⚔️', context.tr('Défis 1 contre 1', '1v1 challenges')),
            const SizedBox(height: 8),
            const _ChallengesPanel(),
            const SizedBox(height: 16),
            const AdMobBanner(),
          ],
        ),
      ),
    );
  }

  Widget _missionsCard(BuildContext context, AppProvider prov, String userId) {
    final picks = prov.getUserTodayPredictionCount(userId);
    final target = prov.getUserTodayPredictionTarget(userId);
    final exactDone = prov.getUserHasTodayExactPick(userId);
    final duelDone = prov.getUserHasTodayDuelPick(userId);
    final duels = prov.todayGameDuels;

    final rows = <Widget>[];
    if (target > 0) {
      rows.add(_missionRow(
        context,
        icon: '🗳️',
        title: context.tr('$target pronos du jour', '$target picks today'),
        subtitle: context.tr('Chaque prono fait avancer ton niveau.', 'Every pick moves your level forward.'),
        progress: picks.clamp(0, target).toInt(),
        target: target,
        done: picks >= target,
        onTap: picks >= target ? null : () => Navigator.of(context).pop(),
      ));
    }

    if (prov.hasPlayableTodayMatch || exactDone) {
      rows.add(_missionRow(
        context,
        icon: '🎯',
        title: context.tr('Un score exact', 'An exact score'),
        subtitle: context.tr('Le score exact rapporte aussi +2 points au classement.', 'An exact score also adds +2 ranking points.'),
        progress: exactDone ? 1 : 0,
        target: 1,
        done: exactDone,
        onTap: exactDone ? null : () => Navigator.of(context).pop(),
      ));
    }

    if (duels.isNotEmpty || duelDone) {
      rows.add(_missionRow(
        context,
        icon: '⚔️',
        title: context.tr('Le duel du jour', 'Today’s duel'),
        subtitle: context.tr('Les grosses affiches comptent dans ta routine gaming.', 'Big fixtures are part of your gaming routine.'),
        progress: duelDone ? 1 : 0,
        target: 1,
        done: duelDone,
        onTap: duelDone || duels.isEmpty
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchDetailScreen(match: duels.first),
                  ),
                ),
      ));
    }

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('😌', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr(
                  'Les missions reviennent au prochain match.',
                  'Missions return with the next match.',
                ),
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Column(children: _withDividers(rows)),
    );
  }

  List<Widget> _withDividers(List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i += 1) {
      if (i > 0) {
        out.add(Divider(height: 18, color: AppColors.overlayBase.withOpacity(.08)));
      }
      out.add(rows[i]);
    }
    return out;
  }

  Widget _missionRow(BuildContext context, {
    required String icon, required String title, required String subtitle,
    required int progress, required int target, required bool done, VoidCallback? onTap,
  }) => GameMissionTile(title: title,
    icon: icon == '🎯' ? Icons.gps_fixed_rounded
      : icon == '⚔️' ? Icons.sports_soccer_rounded : Icons.how_to_vote_rounded,
    progress: progress, target: target, done: done, onTap: onTap);

  Widget _recapCard(BuildContext context, GameDayRecap recap) {
    final d = recap.date;
    final dateLabel = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Bilan du $dateLabel', 'Recap for $dateLabel'),
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _recapStat('🗳️', '${recap.played}', context.tr('pronos', 'picks')),
              _recapStat('✅', '${recap.correct}', context.tr('bons', 'correct')),
              _recapStat('🎯', '${recap.exact}', context.tr('exacts', 'exact')),
              _recapStat('⭐', '+${recap.points}', context.tr('points', 'points')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recapStat(String icon, String value, String label) => Container(
        constraints: const BoxConstraints(minWidth: 86),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                Text(label, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 9)),
              ],
            ),
          ],
        ),
      );

  Widget _sectionTitle(BuildContext context, String icon, String title) => Row(
        children: [
          Prono4Art(
            name: icon == '⚔️' ? 'duel'
                : icon == '🎯' ? 'etoile' : 'classement',
            size: 33,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      );
}

class _ChallengesPanel extends StatefulWidget {
  const _ChallengesPanel();

  @override
  State<_ChallengesPanel> createState() => _ChallengesPanelState();
}

class _ChallengesPanelState extends State<_ChallengesPanel> {
  String _challengeFilter = 'all';
  String? _streamUid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _challengeStreamCache;

  Stream<QuerySnapshot<Map<String, dynamic>>> _challengeStream(String uid) {
    if (_challengeStreamCache == null || _streamUid != uid) {
      _streamUid = uid;
      _challengeStreamCache = FirebaseFirestore.instance
          .collection('gameChallenges')
          .where('participants', arrayContains: uid)
          .limit(20)
          .snapshots();
    }
    return _challengeStreamCache!;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final me = prov.currentUser;
    final team = prov.myTeam;
    if (me == null) return const SizedBox.shrink();

    if (team == null) {
      return _infoBox(
        context,
        icon: '👥',
        text: context.tr(
          'Rejoins une équipe pour lancer des défis 1 contre 1.',
          'Join a team to start 1v1 challenges.',
        ),
      );
    }

    final authUid = prov.firebaseUid;
    if (authUid == null || authUid != me.id) {
      return _infoBox(
        context,
        icon: '🔄',
        text: context.tr(
          'Connexion du profil en cours. Les défis seront disponibles dans quelques secondes.',
          'Profile connection in progress. Challenges will be available in a few seconds.',
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
          ),
          child: Row(
            children: [
              Icon(
                me.acceptChallenges ? Icons.notifications_active_rounded : Icons.do_not_disturb_alt_rounded,
                color: me.acceptChallenges ? AppColors.lime : AppColors.grey,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Accepter les nouveaux défis', 'Accept new challenges'),
                      style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 11.5),
                    ),
                    // Un interrupteur lisible suffit : détails enlevés.
                  ],
                ),
              ),
              Switch.adaptive(
                value: me.acceptChallenges,
                onChanged: (value) => prov.setAcceptChallenges(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openCreateChallenge(context, prov),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.lime,
              side: BorderSide(color: AppColors.lime.withOpacity(.40)),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Prono4Art(name: 'duel', size: 32),
            label: Text(
              context.tr('NOUVEAU DÉFI', 'NEW CHALLENGE'),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // Keep the same Stream instance across widget rebuilds. Recreating
          // snapshots() here used to tear down/re-open the listener repeatedly,
          // causing extra Firestore reads and visible UI stalls.
          stream: _challengeStream(me.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _infoBox(
                context,
                icon: '⚠️',
                text: context.tr(
                  'Les défis ne sont pas encore disponibles sur ce compte. Vérifie les règles Firestore BUILD89.',
                  'Challenges are not available on this account yet. Check BUILD89 Firestore rules.',
                ),
              );
            }
            final docs = snapshot.data?.docs.toList() ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            docs.sort((a, b) {
              final at = a.data()['createdAt'];
              final bt = b.data()['createdAt'];
              final ad = at is Timestamp ? at.millisecondsSinceEpoch : 0;
              final bd = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
              return bd.compareTo(ad);
            });
            if (docs.isEmpty) {
              return _infoBox(
                context,
                icon: '⚔️',
                text: context.tr(
                  'Aucun défi. Lance ton premier duel !',
                  'No challenges yet. Start your first duel!',
                ),
              );
            }
            final displayed = docs.where((doc) {
              final state = (doc.data()['status'] ?? 'pending').toString();
              final ready = prov.results.containsKey(
                  (doc.data()['matchId'] ?? '').toString());
              switch (_challengeFilter) {
                case 'pending': return state == 'pending';
                case 'active': return state == 'active' && !ready;
                case 'finished': return (state == 'active' && ready) ||
                    state == 'declined' || state == 'cancelled';
                default: return true;
              }
            }).take(12).toList(growable: false);
            final filters = [
              ('all', context.tr('Tous', 'All')),
              ('pending', context.tr('En attente', 'Pending')),
              ('active', context.tr('En cours', 'Active')),
              ('finished', context.tr('Terminés', 'Finished')),
            ];
            return Column(
              children: [
                SizedBox(
                  height: 43,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 7),
                    itemBuilder: (context, i) {
                      final filter = filters[i];
                      final chosen = _challengeFilter == filter.$1;
                      return ChoiceChip(
                        label: Text(filter.$2),
                        selected: chosen,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _challengeFilter = filter.$1),
                        selectedColor: AppColors.lime,
                        backgroundColor: AppColors.bg2,
                        side: BorderSide(color: chosen ? AppColors.lime :
                          AppColors.overlayBase.withOpacity(.10)),
                        labelStyle: GoogleFonts.inter(
                          color: chosen ? const Color(0xFF101510) : AppColors.text2,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 9),
                if (displayed.isEmpty)
                  _infoBox(context, icon: '⚽',
                    text: context.tr('Aucun défi dans cette catégorie.',
                        'No challenges in this category.')),
                ...displayed.map((doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _challengeCard(context, prov, doc),
                )),
              ],
            );
          },
        ),
      ],
    );
  }

  static Widget _infoBox(BuildContext context, {required String icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _challengeCard(
    BuildContext context,
    AppProvider prov,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final me = prov.currentUser!;
    final challengerId = (data['challengerId'] ?? '').toString();
    final opponentId = (data['opponentId'] ?? '').toString();
    final otherId = challengerId == me.id ? opponentId : challengerId;
    final status = (data['status'] ?? 'pending').toString();
    final matchId = (data['matchId'] ?? '').toString();
    final match = prov.matchById(matchId);
    final other = _findUser(prov, otherId);
    final resultReady = prov.results.containsKey(matchId);
    final expired = status == 'pending' &&
        (resultReady || (match != null && match.hasStarted));
    final incoming = opponentId == me.id && status == 'pending' && !expired;
    final myPoints = resultReady ? prov.getUserMatchPoints(me.id, matchId) : 0;
    final otherPoints = resultReady ? prov.getUserMatchPoints(otherId, matchId) : 0;

    String statusText;
    Color statusColor;
    if (status == 'declined') {
      statusText = context.tr('Refusé', 'Declined');
      statusColor = AppColors.grey;
    } else if (status == 'cancelled') {
      statusText = context.tr('Annulé', 'Cancelled');
      statusColor = AppColors.grey;
    } else if (status == 'pending' && expired) {
      statusText = context.tr('Expiré', 'Expired');
      statusColor = AppColors.grey;
    } else if (status == 'pending') {
      statusText = incoming
          ? context.tr('À toi de répondre', 'Your turn to answer')
          : context.tr('En attente', 'Waiting');
      statusColor = AppColors.gold;
    } else if (resultReady) {
      if (myPoints > otherPoints) {
        statusText = context.tr('🏆 Victoire', '🏆 Win');
        statusColor = AppColors.lime;
      } else if (myPoints < otherPoints) {
        statusText = context.tr('Défaite', 'Loss');
        statusColor = AppColors.canadaRed;
      } else {
        statusText = context.tr('Égalité', 'Draw');
        statusColor = AppColors.usaBlue;
      }
    } else {
      statusText = context.tr('Défi actif', 'Active challenge');
      statusColor = AppColors.lime;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarBubble(avatar: other?.avatar ?? '⚽', size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      other?.name ?? context.tr('Joueur', 'Player'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      match == null ? context.tr('Match indisponible', 'Match unavailable') : _matchLabel(match),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 104),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (status == 'active' && !resultReady) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(children: [
                Expanded(child: Text(context.tr('TOI', 'YOU'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.text,
                    fontWeight: FontWeight.w900, fontSize: 12))),
                const Prono4Art(name: 'duel', size: 47),
                Expanded(child: Text(other?.name ?? context.tr('RIVAL', 'RIVAL'),
                  textAlign: TextAlign.center,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppColors.text,
                    fontWeight: FontWeight.w900, fontSize: 12))),
              ]),
            ),
          ],
          if (status == 'active' && resultReady) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ChallengeScoreCelebration(myPoints: myPoints,
                otherPoints: otherPoints,
                otherName: other?.name ?? context.tr('RIVAL', 'RIVAL')),
            ),
          ],
          if (incoming) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setChallengeStatus(context, doc.reference, 'declined'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text2,
                      side: BorderSide(color: AppColors.overlayBase.withOpacity(.12)),
                    ),
                    child: Text(context.tr('Refuser', 'Decline')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setChallengeStatus(context, doc.reference, 'active'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: const Color(0xFF101510),
                    ),
                    child: Text(context.tr('Accepter', 'Accept')),
                  ),
                ),
              ],
            ),
          ] else if (status == 'pending' && challengerId == me.id) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _setChallengeStatus(context, doc.reference, 'cancelled'),
                child: Text(context.tr('Annuler le défi', 'Cancel challenge')),
              ),
            ),
          ],
          if (status == 'active' && match != null && !match.hasStarted && !resultReady) ...[
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
                ),
                icon: const Icon(Icons.sports_soccer_rounded, size: 18),
                label: Text(context.tr('FAIRE / VOIR MON PRONO', 'MAKE / VIEW MY PICK')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static AppUser? _findUser(AppProvider prov, String uid) {
    for (final user in prov.users) {
      if (user.id == uid) return user;
    }
    return null;
  }

  static String _matchLabel(FootballMatch match) {
    final d = match.dateTime.toLocal();
    final home = match.homeName ?? match.homeCode;
    final away = match.awayName ?? match.awayCode;
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$home – $away · $date $time';
  }

  Future<void> _openCreateChallenge(BuildContext context, AppProvider prov) async {
    final me = prov.currentUser!;
    final team = prov.myTeam!;
    final teammates = team.memberIds.toSet();

    // Annuaire en mémoire : aucune lecture Firebase à chaque frappe.
    final opponents = prov.users
        .where((p) => p.id != me.id &&
            !prov.isUserBlocked(p.id) && p.acceptChallenges)
        .toList()
      ..sort((a, b) {
        final aMate = teammates.contains(a.id) ? 0 : 1;
        final bMate = teammates.contains(b.id) ? 0 : 1;
        if (aMate != bMate) return aMate.compareTo(bMate);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final matches = prov.visibleMatches
        .map(prov.resolveMatch)
        .where((m) => !m.isTBD && !m.hasStarted &&
            !prov.results.containsKey(m.id))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (opponents.isEmpty || matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(opponents.isEmpty
          ? context.tr('Aucun joueur disponible.', 'No player available.')
          : context.tr('Aucun match à venir.', 'No upcoming match.')),
      ));
      return;
    }

    final competitionIds = <String>[];
    for (final competition in kCompetitions) {
      if (matches.any((m) => m.competitionId == competition.id)) {
        competitionIds.add(competition.id);
      }
    }
    for (final match in matches) {
      if (!competitionIds.contains(match.competitionId)) {
        competitionIds.add(match.competitionId);
      }
    }
    final searchController = TextEditingController();
    AppUser? selectedUser;
    FootballMatch? selectedMatch = matches.first;
    String selectedCompetitionId = matches.first.competitionId;
    String query = '';
    var step = 0;
    var saving = false;
    final hostContext = context;

    String teamLabel(AppUser player) {
      if (player.teamId == team.id) {
        return hostContext.tr('Mon équipe', 'My team');
      }
      for (final otherTeam in prov.teams) {
        if (otherTeam.id == player.teamId) return otherTeam.name;
      }
      return hostContext.tr('Autre joueur', 'Other player');
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final visible = opponents.where((p) => query.trim().isEmpty ||
              p.name.toLowerCase().contains(query.trim().toLowerCase()))
              .take(20).toList(growable: false);
          final filteredMatches = matches.where((m) =>
              m.competitionId == selectedCompetitionId)
              .toList(growable: false);
          final canContinue = step == 0
              ? selectedUser != null
              : step == 1 ? selectedMatch != null : true;

          Widget stepMarker(int index, String label) {
            final done = index <= step;
            return Expanded(child: InkWell(
              onTap: saving || index > step ? null : () =>
                  setModalState(() => step = index),
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 30, height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.lime : AppColors.bg3,
                  ),
                  child: Text('${index + 1}',
                    style: GoogleFonts.spaceGrotesk(
                      color: done ? const Color(0xFF101510) : AppColors.text2,
                      fontWeight: FontWeight.w900,
                    )),
                ),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: done ? AppColors.text : AppColors.text2,
                    fontWeight: done ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 10,
                  )),
              ]),
            ));
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              height: (MediaQuery.sizeOf(context).height * .84 -
                MediaQuery.of(context).viewInsets.bottom)
                  .clamp(240.0, MediaQuery.sizeOf(context).height * .84)
                  .toDouble(),
              child: Column(children: [
                const SizedBox(height: 10),
                Container(width: 39, height: 4,
                  decoration: BoxDecoration(color: AppColors.grey.withOpacity(.55),
                    borderRadius: BorderRadius.circular(10))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
                  child: Row(children: [
                    const Prono4Art(name: 'duel', size: 61),
                    const SizedBox(width: 7),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('NOUVEAU DÉFI', 'NEW CHALLENGE'),
                          style: GoogleFonts.spaceGrotesk(color: AppColors.text,
                            fontSize: 21, fontWeight: FontWeight.w900)),
                        Text(context.tr('2 joueurs · 1 match', '2 players · 1 match'),
                          style: GoogleFonts.inter(color: AppColors.text2,
                            fontSize: 11)),
                      ],
                    )),
                    IconButton(
                      tooltip: context.tr('Fermer', 'Close'),
                      onPressed: saving ? null : () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: AppColors.text2),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
                  child: Row(children: [
                    stepMarker(0, context.tr('Joueur', 'Player')),
                    stepMarker(1, context.tr('Match', 'Match')),
                    stepMarker(2, context.tr('Duel', 'Duel')),
                  ]),
                ),
                const SizedBox(height: 7),
                Divider(color: AppColors.overlayBase.withOpacity(.09), height: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: step == 0
                      ? Column(key: const ValueKey('player'), children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(17, 15, 17, 9),
                            child: TextField(
                              controller: searchController,
                              onChanged: (value) => setModalState(() => query = value),
                              textInputAction: TextInputAction.search,
                              style: GoogleFonts.inter(color: AppColors.text),
                              decoration: InputDecoration(
                                hintText: context.tr('Chercher un pseudo',
                                    'Find a nickname'),
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: query.isEmpty ? null : IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() => query = '');
                                  },
                                ),
                                filled: true,
                                fillColor: AppColors.bg2,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          Expanded(child: visible.isEmpty
                            ? Center(child: Text(context.tr('Aucun joueur trouvé',
                                'No player found'),
                                style: TextStyle(color: AppColors.text2)))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(17, 0, 17, 15),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 7),
                                itemBuilder: (ctx, index) {
                                  final player = visible[index];
                                  final chosen = selectedUser?.id == player.id;
                                  return Material(
                                    color: chosen ? AppColors.lime.withOpacity(.13)
                                        : AppColors.bg2,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: saving ? null : () {
                                        FocusScope.of(context).unfocus();
                                        setModalState(() {
                                          selectedUser = player;
                                          step = 1;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Row(children: [
                                          AvatarBubble(avatar: player.avatar, size: 42),
                                          const SizedBox(width: 11),
                                          Expanded(child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(player.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: AppColors.text,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900)),
                                              Text(teamLabel(player),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: AppColors.text2,
                                                  fontSize: 10)),
                                            ],
                                          )),
                                          Icon(chosen ? Icons.check_circle_rounded
                                              : Icons.chevron_right_rounded,
                                            color: chosen ? AppColors.lime : AppColors.text2),
                                        ]),
                                      ),
                                    ),
                                  );
                                },
                              )),
                        ])
                      : step == 1
                        ? Column(key: const ValueKey('match'), children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(17, 13, 17, 5),
                              child: Align(alignment: Alignment.centerLeft,
                                child: Text(context.tr('Choisis une compétition',
                                    'Choose a competition'),
                                  style: GoogleFonts.inter(color: AppColors.text2,
                                    fontSize: 11, fontWeight: FontWeight.w800))),
                            ),
                            SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                itemCount: competitionIds.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 7),
                                itemBuilder: (ctx, index) {
                                  final id = competitionIds[index];
                                  final info = competitionById(id);
                                  final chosen = id == selectedCompetitionId;
                                  return ChoiceChip(
                                    showCheckmark: false,
                                    selected: chosen,
                                    selectedColor: AppColors.lime,
                                    backgroundColor: AppColors.bg2,
                                    side: BorderSide(color: chosen
                                        ? AppColors.lime :
                                        AppColors.overlayBase.withOpacity(.11)),
                                    label: Text(info == null ? id
                                        : '${info.emoji} ${competitionDisplayShortName(context, info)}'),
                                    labelStyle: GoogleFonts.inter(
                                      color: chosen ? const Color(0xFF101510)
                                          : AppColors.text2,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11),
                                    onSelected: saving ? null : (_) {
                                      final first = matches.where((m) =>
                                          m.competitionId == id).first;
                                      setModalState(() {
                                        selectedCompetitionId = id;
                                        selectedMatch = first;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 9),
                            Expanded(child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(17, 0, 17, 12),
                              itemCount: filteredMatches.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, index) {
                                final match = filteredMatches[index];
                                return _challengeMatchChoice(context,
                                  match: match,
                                  selected: selectedMatch?.id == match.id,
                                  onTap: saving ? null : () => setModalState(
                                    () => selectedMatch = match),
                                );
                              },
                            )),
                          ])
                        : Center(key: const ValueKey('confirm'),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(17),
                              child: Column(children: [
                                const SizedBox(height: 5),
                                Text(context.tr('PRÊTS POUR LE DUEL ?',
                                  'READY TO DUEL?'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AppColors.text,
                                    fontSize: 20, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 19),
                                Row(children: [
                                  Expanded(child: Column(children: [
                                    AvatarBubble(avatar: me.avatar, size: 64),
                                    const SizedBox(height: 7),
                                    Text(me.name, textAlign: TextAlign.center,
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(color: AppColors.text,
                                        fontWeight: FontWeight.w900)),
                                  ])),
                                  const Prono4Art(name: 'duel', size: 82),
                                  Expanded(child: Column(children: [
                                    AvatarBubble(avatar: selectedUser!.avatar, size: 64),
                                    const SizedBox(height: 7),
                                    Text(selectedUser!.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(color: AppColors.text,
                                        fontWeight: FontWeight.w900)),
                                  ])),
                                ]),
                                const SizedBox(height: 20),
                                if (selectedMatch != null)
                                  _challengeMatchChoice(context,
                                    match: selectedMatch!,
                                    selected: true,
                                    onTap: null,
                                  ),
                                const SizedBox(height: 14),
                                Text(context.tr(
                                    'Vos pronostics habituels décideront du gagnant.',
                                    'Your regular predictions decide the winner.'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: AppColors.text2, fontSize: 12)),
                              ]),
                            ),
                          ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(17, 10, 17,
                    11 + MediaQuery.of(context).padding.bottom),
                  decoration: BoxDecoration(
                    color: AppColors.bg1,
                    border: Border(top: BorderSide(
                      color: AppColors.overlayBase.withOpacity(.10))),
                  ),
                  child: Row(children: [
                    if (step > 0) ...[
                      OutlinedButton(
                        onPressed: saving ? null : () =>
                            setModalState(() => step--),
                        child: Text(context.tr('Retour', 'Back')),
                      ),
                      const SizedBox(width: 9),
                    ],
                    Expanded(child: ElevatedButton(
                      onPressed: saving || !canContinue ? null : () async {
                        if (step < 2) {
                          setModalState(() => step++);
                          return;
                        }
                        setModalState(() => saving = true);
                        final error = await _createChallenge(
                          prov, selectedUser!, selectedMatch!);
                        if (!context.mounted || !hostContext.mounted) return;
                        if (error == null) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(hostContext).showSnackBar(SnackBar(
                            content: Text(hostContext.tr('Défi envoyé !',
                                'Challenge sent!')),
                          ));
                        } else {
                          setModalState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: const Color(0xFF101510),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      ),
                      child: saving
                          ? const SizedBox(width: 19, height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(step == 2
                              ? context.tr('ENVOYER LE DÉFI', 'SEND CHALLENGE')
                              : context.tr('CONTINUER', 'CONTINUE'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13, fontWeight: FontWeight.w900)),
                    )),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
    // La fermeture du bottom-sheet se termine après son animation.
    await Future<void>.delayed(const Duration(milliseconds: 360));
    searchController.dispose();
  }

  Widget _challengeMatchChoice(
    BuildContext context, {
    required FootballMatch match,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final info = competitionById(match.competitionId);
    final d = match.dateTime.toLocal();
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final home = match.homeName ?? match.homeCode;
    final away = match.awayName ?? match.awayCode;

    Widget crest(String? url, String fallback) {
      if (url == null || url.trim().isEmpty) {
        return CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.bg3,
          child: Text(
            fallback.isEmpty ? '⚽' : fallback.substring(0, 1).toUpperCase(),
            style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w900),
          ),
        );
      }
      return ClipOval(
        child: Container(
          width: 34,
          height: 34,
          color: AppColors.bg3,
          padding: const EdgeInsets.all(4),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                fallback.isEmpty ? '⚽' : fallback.substring(0, 1).toUpperCase(),
                style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      );
    }

    Widget teamRow(String name, String code, String? crestUrl) {
      return Row(
        children: [
          crest(crestUrl, code),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.text,
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.lime.withOpacity(.10) : AppColors.bg2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.lime : AppColors.overlayBase.withOpacity(.08),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    teamRow(home, match.homeCode, match.homeCrestUrl),
                    const SizedBox(height: 8),
                    teamRow(away, match.awayCode, match.awayCrestUrl),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 74,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 9.5),
                    ),
                    if (info != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${info.emoji} ${competitionDisplayShortName(context, info)}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.grey,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.lime : AppColors.grey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _createChallenge(
    AppProvider prov,
    AppUser opponent,
    FootballMatch match,
  ) async {
    final me = prov.currentUser;
    if (me == null || prov.firebaseUid != me.id) return 'Profil non synchronisé.';
    if (match.hasStarted || prov.results.containsKey(match.id)) return 'Ce match a déjà commencé.';
    if (opponent.id == me.id) return 'Adversaire invalide.';
    try {
      final target = await FirebaseFirestore.instance.collection('users').doc(opponent.id).get();
      if (!target.exists) return 'Ce joueur n’est plus disponible.';
      if (target.data()?['acceptChallenges'] == false) {
        return 'Ce joueur n’accepte pas les défis pour le moment.';
      }
    } catch (_) {
      return 'Impossible de vérifier la disponibilité de ce joueur.';
    }

    final pair = <String>[me.id, opponent.id]..sort();
    final safeMatchId = match.id.replaceAll('/', '_');
    final docId = '${safeMatchId}__${pair[0]}__${pair[1]}';
    try {
      await FirebaseFirestore.instance.collection('gameChallenges').doc(docId).set({
        'challengerId': me.id,
        'opponentId': opponent.id,
        'participants': pair,
        'teamId': prov.myTeam?.id,
        'matchId': match.id,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? 'Défi refusé par Firestore. Déploie les règles BUILD89.'
          : 'Défi impossible : ${e.code}';
    } catch (_) {
      return 'Défi impossible. Vérifie Internet.';
    }
  }

  Future<void> _setChallengeStatus(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    try {
      await ref.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firestore : ${e.code}')),
      );
    }
  }
}
