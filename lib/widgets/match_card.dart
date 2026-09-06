import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../data/teams_data.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'flag_widget.dart';
import 'club_crest.dart';
import '../services/ad_service.dart';
import 'anims.dart';
import '../l10n/app_locale.dart';

class MatchCard extends StatelessWidget {
  final FootballMatch match;
  const MatchCard({super.key, required this.match});

  Color _predColor(Prediction p) {
    switch (p) {
      case Prediction.home:
        return AppColors.lime;
      case Prediction.draw:
        return AppColors.grey;
      case Prediction.away:
        return AppColors.lime;
    }
  }

  String _weekday(int d) {
    const days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[d];
  }

  String _month(int m) {
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
    return months[m];
  }

  String _shortPhase(MatchPhase p) {
    switch (p) {
      case MatchPhase.seizieme:
        return '1/16';
      case MatchPhase.huitieme:
        return '1/8';
      case MatchPhase.quart:
        return '1/4';
      case MatchPhase.demi:
        return '1/2';
      case MatchPhase.troisieme:
        return '3e place';
      case MatchPhase.finale:
        return 'Finale';
      case MatchPhase.groupe:
        return 'Groupe';
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final myVote = prov.getVote(match.id);
    final result = PredictionLabel.fromKey(prov.results[match.id]);
    final officialScore = prov.scores[match.id];
    final canVote =
        !match.hasStarted && !match.isTBD && prov.currentUser != null;
    final isCorrect = result != null && myVote != null && myVote == result;
    final isWrong = result != null && myVote != null && myVote != result;
    // Les codes de clubs peuvent entrer en collision avec les codes des
    // sélections (ex. MAR = Marseille et Maroc). Pour les compétitions de
    // clubs, on n'utilise donc JAMAIS kTeams/les drapeaux nationaux.
    final isClubMatch = match.competitionId != 'world-cup-2026';
    final homeTeam = (!isClubMatch ? kTeams[match.homeCode] : null) ??
        TeamInfo(
          code: match.homeCode,
          name: match.homeName ?? match.homeCode,
          flagCode: '',
          group: '',
          emoji: '⚽',
        );
    final awayTeam = (!isClubMatch ? kTeams[match.awayCode] : null) ??
        TeamInfo(
          code: match.awayCode,
          name: match.awayName ?? match.awayCode,
          flagCode: '',
          group: '',
          emoji: '⚽',
        );

    final phaseColors = {
      MatchPhase.groupe: AppColors.lime,
      MatchPhase.seizieme: AppColors.cyan,
      MatchPhase.huitieme: AppColors.violet,
      MatchPhase.quart: AppColors.magenta,
      MatchPhase.demi: AppColors.lime,
      MatchPhase.troisieme: AppColors.canadaRed,
      MatchPhase.finale: AppColors.gold,
    };

    final Color phaseColor = phaseColors[match.phase] ?? AppColors.usaBlue;
    final bool isKnockout = match.phase != MatchPhase.groupe;

    // Statut du match : en direct / terminé / à venir
    final bool isLiveNow =
        (prov.isLiveMatch(match.id) || match.hasStarted) && result == null;
    final bool isFinished = result != null;

    // Couleur de la carte selon le statut
    Color cardBg = AppColors.bg2;
    Color borderColor = Colors.white.withOpacity(0.07);
    if (isLiveNow) {
      cardBg = Color.alphaBlend(
          AppColors.canadaRed.withOpacity(0.07), AppColors.bg2);
      borderColor = AppColors.canadaRed.withOpacity(0.50);
    } else if (isFinished) {
      cardBg = AppColors.bg1; // plus sombre = match joué
      borderColor = Colors.white.withOpacity(0.05);
    } else {
      borderColor = phaseColor.withOpacity(isKnockout ? 0.40 : 0.18);
    }
    if (isCorrect) borderColor = AppColors.mexicoGreen.withOpacity(0.55);
    if (isWrong) borderColor = AppColors.canadaRed.withOpacity(0.35);

    // Dégradé "choc" pour les matchs à élimination (plus ludique)
    final Gradient? cardGradient = isKnockout
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(phaseColor.withOpacity(0.12), cardBg),
              cardBg,
            ],
          )
        : null;

    String phaseLabel;
    if (match.stage != null && match.stage!.isNotEmpty) {
      phaseLabel = match.stage!;
    } else if (match.matchday != null) {
      phaseLabel = context.tr('Journée ${match.matchday}', 'Matchday ${match.matchday}');
    } else if (match.phase == MatchPhase.groupe) {
      phaseLabel =
          match.group == null ? 'Championnat' : 'Groupe ${match.group}';
    } else {
      phaseLabel = _shortPhase(match.phase);
    }

    final dt = match.dateTime;
    final dateStr = '${_weekday(dt.weekday)} ${dt.day} ${_month(dt.month)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardGradient == null ? cardBg : null,
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isKnockout ? 1.3 : 1),
        boxShadow: isCorrect
            ? [
                BoxShadow(
                    color: AppColors.mexicoGreen.withOpacity(0.12),
                    blurRadius: 18)
              ]
            : isLiveNow
                ? [
                    BoxShadow(
                        color: AppColors.canadaRed.withOpacity(0.12),
                        blurRadius: 16)
                  ]
                : isKnockout
                    ? [
                        BoxShadow(
                            color: phaseColor.withOpacity(0.10), blurRadius: 14)
                      ]
                    : null,
      ),
      child: Column(children: [
        // ── HEADER ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.025),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: phaseColors[match.phase] ?? AppColors.grey,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: (phaseColors[match.phase] ?? AppColors.grey)
                          .withOpacity(0.6),
                      blurRadius: 6)
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isKnockout) ...[
              const Text('⚔️', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(phaseLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                      color: phaseColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ),
            const Spacer(),
            Flexible(
              child: Text(dateStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.barlowCondensed(
                      color: AppColors.text2, fontSize: 12)),
            ),
            const SizedBox(width: 5),
            // L'heure reste TOUJOURS visible (en gras), même sur petit écran.
            Text(match.localTime,
                style: GoogleFonts.barlowCondensed(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            if ((prov.isLiveMatch(match.id) || match.hasStarted) &&
                result == null) ...[
              const SizedBox(width: 6),
              _LiveBadge(halftime: prov.isHalftime(match.id)),
            ],
          ]),
        ),

        // ── TEAMS ──
        if (match.isTBD)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(context.tr('À déterminer','TBD'),
                style: GoogleFonts.barlowCondensed(
                    color: AppColors.grey, fontSize: 15)),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Expanded(child: _teamBlock(homeTeam, true, isClubMatch, match.homeCrestUrl)),
              // Score / VS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(children: [
                  if (officialScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.gold.withOpacity(0.28)),
                      ),
                      child: Column(children: [
                        Text(
                          officialScore.display,
                          style: GoogleFonts.bebasNeue(
                            fontSize: 30,
                            height: 0.95,
                            letterSpacing: 2.5,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SCORE FINAL',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.text2,
                          ),
                        ),
                      ]),
                    )
                  else if (result != null)
                    Text(context.tr('TERMINÉ','FINISHED'),
                        style: GoogleFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: AppColors.gold))
                  else
                    Text('VS',
                        style: GoogleFonts.bebasNeue(
                            fontSize: 22,
                            color: AppColors.gold,
                            letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(match.venue,
                      style: GoogleFonts.barlowCondensed(
                          color: AppColors.text2, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ]),
              ),
              Expanded(child: _teamBlock(awayTeam, false, isClubMatch, match.awayCrestUrl)),
            ]),
          ),

        // ── RESULT INDICATOR ──
        if (myVote != null && result != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: (isCorrect ? AppColors.mexicoGreen : AppColors.canadaRed)
                  .withOpacity(0.08),
              border: Border(
                  top: BorderSide(
                      color: (isCorrect
                              ? AppColors.mexicoGreen
                              : AppColors.canadaRed)
                          .withOpacity(0.25))),
            ),
            child: Row(children: [
              Pop(
                  child: Text(isCorrect ? '✅' : '❌',
                      style: const TextStyle(fontSize: 16))),
              const SizedBox(width: 8),
              Text(
                  isCorrect
                      ? '+3 points — Bonne prédiction !'
                      : context.tr('Mauvaise prédiction','Wrong prediction'),
                  style: GoogleFonts.barlowCondensed(
                      color: isCorrect
                          ? AppColors.mexicoGreen
                          : AppColors.canadaRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ]),
          ),

        // ── VOTE BUTTONS ──
        if (!match.isTBD)
          _buildVoteSection(
              context, prov, canVote, myVote, result, homeTeam, awayTeam),

        // ── ADMIN ──
        if (prov.adminMode && !match.isTBD)
          _buildAdminSection(context, prov, officialScore),
      ]),
    );
  }

  Widget _teamBlock(
      TeamInfo? team, bool isHome, bool isClubMatch, String? crestUrl) {
    final name = team?.name ?? 'TBD';
    return Column(
      crossAxisAlignment:
          isHome ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        if (isClubMatch)
          ClubCrest(url: crestUrl, clubName: name, size: 44)
        else if (team != null && team.flagCode.isNotEmpty)
          FlagWidget(
              flagCode: team.flagCode, size: 42, fallbackEmoji: team.emoji)
        else
          Text(team?.emoji ?? '🌍', style: const TextStyle(fontSize: 30)),
        const SizedBox(height: 6),
        Text(name,
            style: GoogleFonts.barlowCondensed(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: isHome ? TextAlign.left : TextAlign.right),
      ],
    );
  }

  Widget _buildVoteSection(BuildContext context, AppProvider prov, bool canVote,
      Prediction? myVote, Prediction? result, TeamInfo? home, TeamInfo? away) {
    if (prov.canChangeAtHalftime(match.id) && result == null) {
      return _buildHalftimeChange(context, prov, myVote, home, away);
    }
    if (canVote) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('VOTRE PRONOSTIC',
              style: GoogleFonts.barlowCondensed(
                  color: AppColors.text2, fontSize: 11, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Row(children: [
            _voteBtn(context, prov, Prediction.home,
                home?.name.split(' ').first ?? 'Dom.', myVote),
            const SizedBox(width: 6),
            // Pas de "Nul" en élimination : une équipe passe forcément.
            if (match.allowsDraw) ...[
              _voteBtn(context, prov, Prediction.draw, 'Nul', myVote),
              const SizedBox(width: 6),
            ],
            _voteBtn(context, prov, Prediction.away,
                away?.name.split(' ').first ?? 'Ext.', myVote),
          ]),
        ]),
      );
    } else if (result == null) {
      final color = myVote == null ? AppColors.grey : _predColor(myVote);
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Text(myVote?.icon ?? '🔒'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              myVote == null
                  ? context.tr('Pronostics fermés — aucun vote enregistré','Predictions closed — no pick saved')
                  : context.tr('Vote verrouillé : ${myVote.label}','Pick locked: ${myVote.label}'),
              style: GoogleFonts.barlowCondensed(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          if (myVote != null)
            Text('En attente…',
                style: GoogleFonts.barlowCondensed(
                    color: AppColors.text2, fontSize: 11)),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHalftimeChange(BuildContext context, AppProvider prov,
      Prediction? myVote, TeamInfo? home, TeamInfo? away) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.40)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🎬', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: Text('MI-TEMPS — CHANGE TON PRONO (1 FOIS)',
                style: GoogleFonts.barlowCondensed(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
            myVote == null
                ? 'Regarde une pub pour voter maintenant :'
                : 'Ton prono : ${myVote.label}. Regarde une pub pour le changer :',
            style: GoogleFonts.barlowCondensed(
                color: AppColors.text2, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          _halftimeBtn(context, prov, Prediction.home,
              home?.name.split(' ').first ?? 'Dom.', myVote),
          const SizedBox(width: 6),
          if (match.allowsDraw) ...[
            _halftimeBtn(context, prov, Prediction.draw, 'Nul', myVote),
            const SizedBox(width: 6),
          ],
          _halftimeBtn(context, prov, Prediction.away,
              away?.name.split(' ').first ?? 'Ext.', myVote),
        ]),
      ]),
    );
  }

  Widget _halftimeBtn(BuildContext context, AppProvider prov, Prediction pred,
      String label, Prediction? current) {
    final selected = current == pred;
    final color = _predColor(pred);
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeAtHalftime(context, prov, pred),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.22) : AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? color : Colors.white.withOpacity(0.10),
                width: selected ? 2 : 1),
          ),
          child: Column(children: [
            Text(pred.icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                    color: selected ? color : AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            Text('🎬 pub',
                style: GoogleFonts.barlowCondensed(
                    color: AppColors.text2, fontSize: 9)),
          ]),
        ),
      ),
    );
  }

  Future<void> _changeAtHalftime(
      BuildContext context, AppProvider prov, Prediction newPick) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('Chargement de la pub…'),
        duration: Duration(seconds: 1)));
    final ok = await AdService.instance.showRewardedAd();
    if (!context.mounted) return;
    if (!ok) {
      messenger.showSnackBar(SnackBar(
          content: Text(context.tr('Pub non terminée — prono non modifié.','Ad not completed — prediction unchanged.'))));
      return;
    }
    final err = await prov.castHalftimeVote(match.id, newPick);
    if (!context.mounted) return;
    messenger.showSnackBar(
        SnackBar(content: Text(err ?? context.tr('Prono modifié à la mi-temps ✅','Halftime prediction updated ✅'))));
  }

  Widget _voteBtn(BuildContext context, AppProvider prov, Prediction pred,
      String label, Prediction? current) {
    final selected = current == pred;
    final color = _predColor(pred);
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.selectionClick();
          final error = await prov.castVote(match.id, pred);
          if (!context.mounted) return;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          } else {
            HapticFeedback.mediumImpact();
            unawaited(AdService.instance.maybeShowPredictionInterstitial());
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  duration: const Duration(milliseconds: 1100),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: color,
                  content: Text(context.tr('Prono enregistré ! ${pred.icon}','Prediction saved! ${pred.icon}'),
                      style: GoogleFonts.barlowCondensed(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
              );
          }
        },
        child: AnimatedScale(
          scale: selected ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.elasticOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? color.withOpacity(0.18)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: selected
                      ? color.withOpacity(0.55)
                      : Colors.white.withOpacity(0.08),
                  width: selected ? 1.6 : 1),
              boxShadow: selected
                  ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12)]
                  : null,
            ),
            child: Column(children: [
              Text(pred.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 3),
              Text(pred == Prediction.draw ? 'Nul' : 'Victoire',
                  style: GoogleFonts.barlowCondensed(
                      color: selected ? color : AppColors.text2,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              Text(label,
                  style: GoogleFonts.barlowCondensed(
                      color: selected ? color : AppColors.grey, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminSection(
    BuildContext context,
    AppProvider prov,
    MatchScore? score,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🔧 SCORE OFFICIEL',
            style: GoogleFonts.barlowCondensed(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(
              score == null
                  ? 'Aucun score saisi'
                  : 'Score actuel : ${score.display}',
              style: GoogleFonts.barlowCondensed(
                color: AppColors.text2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showScoreDialog(context, prov, score),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: Text(score == null ? 'Saisir' : 'Modifier'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold.withOpacity(0.16),
              foregroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
                side: BorderSide(color: AppColors.gold.withOpacity(0.35)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _showScoreDialog(
    BuildContext context,
    AppProvider prov,
    MatchScore? current,
  ) async {
    final homeController = TextEditingController(
      text: current?.homeScore.toString() ?? '',
    );
    final awayController = TextEditingController(
      text: current?.awayScore.toString() ?? '',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Saisir le score officiel'),
        content: Row(children: [
          Expanded(
            child: TextField(
              controller: homeController,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: match.competitionId != 'world-cup-2026'
                    ? (match.homeName ?? match.homeCode)
                    : (kTeams[match.homeCode]?.name ?? match.homeName ?? 'Domicile'),
                hintText: '0',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('–', style: TextStyle(fontSize: 24)),
          ),
          Expanded(
            child: TextField(
              controller: awayController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: match.competitionId != 'world-cup-2026'
                    ? (match.awayName ?? match.awayCode)
                    : (kTeams[match.awayCode]?.name ?? match.awayName ?? 'Extérieur'),
                hintText: '0',
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (shouldSave != true) {
      homeController.dispose();
      awayController.dispose();
      return;
    }

    final homeScore = int.tryParse(homeController.text.trim());
    final awayScore = int.tryParse(awayController.text.trim());
    homeController.dispose();
    awayController.dispose();

    if (homeScore == null || awayScore == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saisissez les deux scores.')),
        );
      }
      return;
    }

    final error = await prov.setMatchScore(match.id, homeScore, awayScore);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }
}

class _LiveBadge extends StatefulWidget {
  final bool halftime;
  const _LiveBadge({this.halftime = false});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.halftime ? AppColors.gold : AppColors.canadaRed;
    final label = widget.halftime ? 'MI-TEMPS' : 'LIVE';
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withOpacity(0.18),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.withOpacity(0.45)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.barlowCondensed(
                  color: c,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ]),
      ),
    );
  }
}
