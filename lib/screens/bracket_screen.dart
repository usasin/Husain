import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../data/matches_data.dart';
import '../data/teams_data.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../services/ad_service.dart';
import '../widgets/flag_widget.dart';

class _Round {
  final String label;
  final MatchPhase phase;
  final Color color;
  const _Round(this.label, this.phase, this.color);
}

class BracketScreen extends StatefulWidget {
  const BracketScreen({super.key});

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen> {
  @override
  void initState() {
    super.initState();

    // L'interstitiel se déclenche seulement après l'arrivée sur le Tableau
    // final, et AdService applique le plafond pour éviter de gêner les joueurs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AdService.instance.maybeShowBracketInterstitial());
    });
  }

  // Quel(s) match(s) nourrit chaque match du tableau (officiel FIFA 2026).
  static const Map<String, List<String>> feeders = {
    'M089': ['M074', 'M077'], 'M090': ['M073', 'M075'],
    'M091': ['M076', 'M078'], 'M092': ['M079', 'M080'],
    'M093': ['M083', 'M084'], 'M094': ['M081', 'M082'],
    'M095': ['M086', 'M088'], 'M096': ['M085', 'M087'],
    'M097': ['M089', 'M090'], 'M098': ['M093', 'M094'],
    'M099': ['M091', 'M092'], 'M100': ['M095', 'M096'],
    'M101': ['M097', 'M098'], 'M102': ['M099', 'M100'],
    'M103': ['M101', 'M102'], // 3e place : perdants des demies
    'M104': ['M101', 'M102'], // finale : vainqueurs des demies
  };

  static const List<_Round> rounds = [
    _Round('1/16', MatchPhase.seizieme, AppColors.cyan),
    _Round('1/8', MatchPhase.huitieme, AppColors.violet),
    _Round('1/4', MatchPhase.quart, AppColors.magenta),
    _Round('1/2', MatchPhase.demi, AppColors.lime),
    _Round('Finale', MatchPhase.finale, AppColors.gold),
    _Round('3e place', MatchPhase.troisieme, AppColors.canadaRed),
  ];

  String _matchNo(String id) {
    final n = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), ''));
    return n?.toString() ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        title: Text('🏆 Tableau final',
            style: GoogleFonts.bebasNeue(
                fontSize: 24, letterSpacing: 1.5, color: AppColors.text)),
      ),
      // Défilement à la fois vertical (beaucoup de matchs) et horizontal (tours).
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rounds) _roundColumn(prov, r),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundColumn(AppProvider prov, _Round round) {
    final matches = kMatches.where((m) => m.phase == round.phase).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: round.color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: round.color.withOpacity(0.45)),
            ),
            child: Text(round.label.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                    color: round.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
          ),
          const SizedBox(height: 10),
          for (final m in matches) _bracketCard(prov, m, round),
        ],
      ),
    );
  }

  FootballMatch? _matchById(String id) {
    for (final m in kMatches) {
      if (m.id == id) return m;
    }
    return null;
  }

  String? _winnerCode(AppProvider prov, String matchId) {
    final r = prov.results[matchId];
    if (r != 'HOME' && r != 'AWAY') return null;
    final m = _matchById(matchId);
    if (m == null) return null;
    final res = _resolveDeep(prov, m);
    if (res.homeCode == 'TBD' || res.awayCode == 'TBD') return null;
    return r == 'HOME' ? res.homeCode : res.awayCode;
  }

  FootballMatch _resolveDeep(AppProvider prov, FootballMatch m) {
    final base = prov.resolveMatch(m);
    if (base.homeCode != 'TBD' && base.awayCode != 'TBD') return base;
    final feed = feeders[m.id];
    if (feed == null) return base;
    final h = _winnerCode(prov, feed[0]);
    final a = _winnerCode(prov, feed[1]);
    return base.copyWith(
      homeCode: base.homeCode != 'TBD' ? base.homeCode : (h ?? 'TBD'),
      awayCode: base.awayCode != 'TBD' ? base.awayCode : (a ?? 'TBD'),
    );
  }

  Widget _bracketCard(AppProvider prov, FootballMatch match, _Round round) {
    final resolved = _resolveDeep(prov, match);
    final resultKey = prov.results[match.id];
    final score = prov.scores[match.id];
    final isThird = match.phase == MatchPhase.troisieme;
    final feedIds = feeders[match.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: round.color.withOpacity(0.30), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // M°XX en petite pastille (plus épuré)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: round.color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('M°${_matchNo(match.id)}',
                  style: GoogleFonts.barlowCondensed(
                      color: round.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
            Text('${match.localDate.substring(8)}/${match.localDate.substring(5, 7)} · ${match.localTime}',
                style: GoogleFonts.barlowCondensed(
                    color: AppColors.text2, fontSize: 10)),
          ]),
          const SizedBox(height: 10),
          _slot(resolved, true, feedIds, isThird, resultKey, score),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
                height: 1, color: Colors.white.withOpacity(0.06)),
          ),
          _slot(resolved, false, feedIds, isThird, resultKey, score),
        ],
      ),
    );
  }

  Widget _slot(FootballMatch resolved, bool home, List<String>? feedIds,
      bool isThird, String? resultKey, MatchScore? score) {
    final code = home ? resolved.homeCode : resolved.awayCode;
    final team = kTeams[code];
    final isWinner = resultKey != null &&
        ((home && resultKey == 'HOME') || (!home && resultKey == 'AWAY'));
    final goals = score == null
        ? null
        : (home ? score.homeScore : score.awayScore);

    if (code != 'TBD' && team != null) {
      return Row(children: [
        FlagWidget(flagCode: team.flagCode, size: 22, fallbackEmoji: team.emoji),
        const SizedBox(width: 7),
        Expanded(
          child: Text(team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.barlowCondensed(
                  color: isWinner ? AppColors.mexicoGreen : AppColors.text,
                  fontSize: 14,
                  fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600)),
        ),
        if (goals != null)
          Text('$goals',
              style: GoogleFonts.bebasNeue(
                  color: isWinner ? AppColors.mexicoGreen : AppColors.text2,
                  fontSize: 18)),
      ]);
    }

    // Placeholder : vainqueur (ou perdant pour la 3e place) du match nourricier.
    final feedId = feedIds == null ? null : (home ? feedIds[0] : feedIds[1]);
    final n = feedId == null ? '?' : _matchNo(feedId);
    return Row(children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(Icons.help_outline,
            size: 13, color: AppColors.grey),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text('${isThird ? "Perdant" : "Vainq."} M°$n',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.barlowCondensed(
                color: AppColors.grey,
                fontSize: 13,
                fontStyle: FontStyle.italic)),
      ),
    ]);
  }
}
