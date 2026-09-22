import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../data/teams_data.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/match_detail_screen.dart';
import '../theme/app_theme.dart';
import 'club_crest.dart';
import 'flag_widget.dart';
import '../l10n/app_locale.dart';

/// Carte compacte de match.
/// Sur l'accueil, [directPrediction] affiche immédiatement 1 / N(X) / 2,
/// sans statistiques : le joueur pronostique en un geste.
class CompactMatchTile extends StatelessWidget {
  final FootballMatch match;
  final bool showCompetition;
  final bool directPrediction;

  const CompactMatchTile({
    super.key,
    required this.match,
    this.showCompetition = true,
    this.directPrediction = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final live = provider.isLiveMatch(match.id);
    final score = provider.scores[match.id];
    final finished = provider.results.containsKey(match.id);
    final comp = competitionById(match.competitionId);
    final uid = provider.currentUser?.id;
    final voteKey = uid == null ? null : '${uid}__${match.id}';
    final myPrediction = voteKey == null ? null : provider.votes[voteKey];
    final myExact = provider.getExactPrediction(match.id);
    final myPickSymbol = myPrediction == 'HOME'
        ? '1'
        : myPrediction == 'DRAW'
            ? (context.isEnglish ? 'X' : 'N')
            : '2';
    final isClub = match.competitionId != 'world-cup-2026';
    final homeName = isClub
        ? (match.homeName ?? match.homeCode)
        : (kTeams[match.homeCode]?.name ?? match.homeName ?? match.homeCode);
    final awayName = isClub
        ? (match.awayName ?? match.awayCode)
        : (kTeams[match.awayCode]?.name ?? match.awayName ?? match.awayCode);
    final canVote = !match.hasStarted && !match.isTBD && provider.currentUser != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.bg2.withOpacity(.96),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: live
                    ? AppColors.canadaRed.withOpacity(.38)
                    : AppColors.lime.withOpacity(directPrediction ? .14 : .06),
              ),
            ),
            child: Column(
              children: [
                if (showCompetition) ...[
                  Row(
                    children: [
                      if (comp != null) ...[
                        Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.logoPlate,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Image.network(
                            comp.emblemUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(comp.emoji,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        comp?.shortName ?? match.competitionId.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: AppColors.text2,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                      if ((match.stage ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('•',
                            style: TextStyle(
                                color: AppColors.grey.withOpacity(.6))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            match.stage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppColors.grey,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (myPrediction != null) ...[
                        const SizedBox(width: 6),
                        _status(
                          myExact != null
                              ? context.tr(
                                  'MON PRONO ${myExact.display}',
                                  'MY PICK ${myExact.display}',
                                )
                              : context.tr(
                                  'MON PRONO $myPickSymbol',
                                  'MY PICK $myPickSymbol',
                                ),
                          AppColors.lime,
                        ),
                      ],
                      if (live)
                        _status('LIVE', AppColors.canadaRed)
                      else if (finished)
                        _status(context.tr('TERMINÉ', 'FINISHED'), AppColors.grey),
                    ],
                  ),
                  const SizedBox(height: 9),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _clubColumn(
                        provider: provider,
                        isClub: isClub,
                        code: match.homeCode,
                        name: homeName,
                        url: match.homeCrestUrl,
                      ),
                    ),
                    SizedBox(
                      width: 78,
                      child: Column(
                        children: [
                          Text(
                            score?.display ?? match.localTime,
                            style: GoogleFonts.spaceGrotesk(
                              color: live ? AppColors.canadaRed : AppColors.text,
                              fontSize: score == null ? 17 : 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (score == null)
                            Text(
                              live
                                  ? context.tr('EN DIRECT', 'LIVE')
                                  : context.tr('À VENIR', 'UPCOMING'),
                              style: GoogleFonts.inter(
                                color: live ? AppColors.canadaRed : AppColors.grey,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _clubColumn(
                        provider: provider,
                        isClub: isClub,
                        code: match.awayCode,
                        name: awayName,
                        url: match.awayCrestUrl,
                      ),
                    ),
                  ],
                ),
                if (directPrediction) ...[
                  const SizedBox(height: 11),
                  Row(children: [
                    Expanded(
                      child: _pickButton(
                        context,
                        provider,
                        Prediction.home,
                        '1',
                        selected: myPrediction == 'HOME',
                        enabled: canVote,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _pickButton(
                        context,
                        provider,
                        Prediction.draw,
                        context.isEnglish ? 'X' : 'N',
                        selected: myPrediction == 'DRAW',
                        enabled: canVote && match.allowsDraw,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _pickButton(
                        context,
                        provider,
                        Prediction.away,
                        '2',
                        selected: myPrediction == 'AWAY',
                        enabled: canVote,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _clubColumn({
    required AppProvider provider,
    required bool isClub,
    required String code,
    required String name,
    required String? url,
  }) {
    final favorite = provider.isFavoriteClub(code);
    final cleanName = name.trim();
    final fontSize = cleanName.length > 24
        ? 9.0
        : cleanName.length > 18
            ? 10.0
            : cleanName.length > 13
                ? 11.0
                : 12.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _crest(isClub: isClub, code: code, name: cleanName, url: url),
        const SizedBox(height: 5),
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              favorite ? '★ $cleanName' : cleanName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.text,
                fontSize: fontSize,
                height: 1.08,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pickButton(
    BuildContext context,
    AppProvider provider,
    Prediction prediction,
    String label, {
    required bool selected,
    required bool enabled,
  }) {
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: !enabled
            ? null
            : () async {
                final error = await provider.castVote(match.id, prediction);
                if (!context.mounted || error == null) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              },
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor:
              selected ? AppColors.lime.withOpacity(.18) : AppColors.bg1,
          side: BorderSide(
            color: selected
                ? AppColors.lime
                : AppColors.overlayBase.withOpacity(.12),
            width: selected ? 1.5 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: selected ? AppColors.lime : AppColors.text2,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _crest({
    required bool isClub,
    required String code,
    required String name,
    required String? url,
  }) {
    // Les écussons sont volontairement un peu plus grands sur l'accueil.
    if (isClub) return ClubCrest(url: url, clubName: name, size: 48);
    final team = kTeams[code];
    if (team == null) return ClubCrest(url: null, clubName: name, size: 48);
    return FlagWidget(
      flagCode: team.flagCode,
      size: 48,
      fallbackEmoji: team.emoji,
    );
  }

  Widget _status(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(.11),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: .4,
          ),
        ),
      );
}
