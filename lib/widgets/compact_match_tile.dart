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

class CompactMatchTile extends StatelessWidget {
  final FootballMatch match;
  final bool showCompetition;

  const CompactMatchTile({
    super.key,
    required this.match,
    this.showCompetition = true,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: AppColors.bg2.withOpacity(.95),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: live
                    ? AppColors.canadaRed.withOpacity(.38)
                    : Colors.white.withOpacity(.06),
              ),
            ),
            child: Column(
              children: [
                if (showCompetition) ...[
                  Row(
                    children: [
                      Text(
                        comp?.shortName ?? match.competitionId.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: AppColors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                      if ((match.stage ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(color: AppColors.grey.withOpacity(.6))),
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
                              ? context.tr('MON PRONO ${myExact.display}', 'MY PICK ${myExact.display}')
                              : context.tr('MON PRONO $myPickSymbol', 'MY PICK $myPickSymbol'),
                          AppColors.lime,
                        ),
                      ],
                      if (live)
                        _status('LIVE', AppColors.canadaRed)
                      else if (finished)
                        _status(context.tr('TERMINÉ','FINISHED'), AppColors.grey),
                    ],
                  ),
                  const SizedBox(height: 9),
                ],
                Row(
                  children: [
                    _crest(
                      isClub: isClub,
                      code: match.homeCode,
                      name: homeName,
                      url: match.homeCrestUrl,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        homeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      child: Column(
                        children: [
                          Text(
                            score?.display ?? match.localTime,
                            style: GoogleFonts.spaceGrotesk(
                              color: live ? AppColors.canadaRed : AppColors.text,
                              fontSize: score == null ? 14 : 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (score == null)
                            Text(
                              live ? context.tr('EN DIRECT','LIVE') : context.tr('À VENIR','UPCOMING'),
                              style: GoogleFonts.inter(
                                color: live ? AppColors.canadaRed : AppColors.grey,
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        awayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    _crest(
                      isClub: isClub,
                      code: match.awayCode,
                      name: awayName,
                      url: match.awayCrestUrl,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.grey, size: 19),
                  ],
                ),
              ],
            ),
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
    if (isClub) return ClubCrest(url: url, clubName: name, size: 34);
    final team = kTeams[code];
    if (team == null) return ClubCrest(url: null, clubName: name, size: 34);
    return FlagWidget(
      flagCode: team.flagCode,
      size: 34,
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
