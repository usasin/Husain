import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/avatar_display.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/reputation_badge.dart';
import 'settings_screen.dart';
import 'match_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Le Profil écoute directement Clair/Sombre afin de mettre à jour ses AppColors.
    context.watch<AppThemeController>();
    final prov = context.watch<AppProvider>();
    final user = prov.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          context.tr('Profil indisponible', 'Profile unavailable'),
          style: GoogleFonts.inter(color: AppColors.text2),
        ),
      );
    }

    final points = prov.getUserPoints(user.id);
    final played = prov.getUserResolvedVoteCount(user.id);
    final correct = prov.getUserCorrectCount(user.id);
    final knowledge = prov.getUserKnowledgeScore(user.id);
    final badge = prov.getAutoReputationBadge(user.id);
    final specialties = _specialties(context, prov, user.id);
    final recentExactWins = prov.getUserRecentExactWins(user.id, limit: 3);

    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('MON PROFIL', 'MY PROFILE'),
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                if (prov.adminMode) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.gold.withOpacity(.35)),
                    ),
                    child: Text(
                      'ADMIN',
                      style: GoogleFonts.inter(
                        color: AppColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                IconButton.filledTonal(
                  tooltip: context.tr('Paramètres', 'Settings'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _hero(context, prov, user, badge, knowledge),
            const SizedBox(height: 12),
            _badgeJourney(context, badge),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _stat(context, '$points', context.tr('POINTS', 'POINTS'))),
                const SizedBox(width: 8),
                Expanded(child: _stat(context, '$played', context.tr('PRONOS', 'PICKS'))),
                const SizedBox(width: 8),
                Expanded(child: _stat(context, '$correct', context.tr('BONS', 'RIGHT'))),
              ],
            ),
            if (recentExactWins.isNotEmpty) ...[
              const SizedBox(height: 14),
              _recentExactChips(context, recentExactWins),
            ],
            const SizedBox(height: 22),
            _sectionTitle(context.tr('MES SPÉCIALITÉS', 'MY SPECIALTIES')),
            const SizedBox(height: 6),
            Text(
              context.tr(
                'Ton niveau est calculé séparément pour chaque championnat. Tu peux être Footix au général et Expert en Ligue 1.',
                'Your level is calculated separately for each competition. You can be Footix overall and Expert in Ligue 1.',
              ),
              style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 12),
            if (specialties.isEmpty)
              _emptySpecialties(context)
            else
              ...specialties.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _specialtyCard(context, s),
                  )),
            const SizedBox(height: 14),
            _sectionTitle(context.tr('PROGRESSION', 'PROGRESS')),
            const SizedBox(height: 10),
            _progressCard(context, played, correct, knowledge),
          ],
        ),
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    AppProvider prov,
    AppUser user,
    String badge,
    int knowledge,
  ) {
    final asset = reputationBadgeAsset(context, badge);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lime.withOpacity(.30)),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withOpacity(.08),
            blurRadius: 26,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _editAvatar(context, prov, user),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.lime, width: 2),
                      ),
                      child: AvatarBubble(avatar: user.avatar, size: 72),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: const BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit_rounded,
                            color: AppColors.bg0, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('Modifier', 'Edit'),
                          onPressed: () => _editName(context, prov, user),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                        ),
                      ],
                    ),
                    Text(
                      context.tr(
                        'Passionné de foot et de pronos ⚽',
                        'Football & prediction fan ⚽',
                      ),
                      style: GoogleFonts.inter(
                        color: AppColors.text2,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg1.withOpacity(.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.lime.withOpacity(.20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  padding: const EdgeInsets.all(4),
                  child: asset == null
                      ? const Icon(Icons.shield_rounded,
                          color: AppColors.lime, size: 74)
                      : Image.asset(asset, fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _badgePhrase(context, badge),
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text,
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: knowledge / 100,
                          minHeight: 9,
                          backgroundColor: AppColors.bg3,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.lime),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$knowledge/100',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editAvatar(
      BuildContext context, AppProvider prov, AppUser user) async {
    final next = await AvatarPicker2026.show(context, user.avatar);
    if (next == null || next.isEmpty || !context.mounted) return;
    await prov.updateUser(avatar: next);
  }

  String _badgePhrase(BuildContext context, String badge) {
    switch (badge.toUpperCase()) {
      case 'FOOTIX':
        return context.tr(
          'Tu pronostiques avec le cœur… et parfois complètement au hasard 😅',
          'You predict with your heart… and sometimes completely at random 😅',
        );
      case 'AMATEUR':
        return context.tr(
          'Tu commences à comprendre le foot… mais il y a encore quelques catastrophes 😂',
          'You are starting to understand football… but there are still a few disasters 😂',
        );
      case 'CONNAISSEUR':
        return context.tr(
          'Là, tu ne regardes plus seulement les matchs : tu les analyses 👀',
          'Now you do not just watch matches: you analyse them 👀',
        );
      case 'CONFIRMÉ':
      case 'CONFIRME':
        return context.tr(
          'Tes potes commencent à te demander tes pronos avant de jouer 😎',
          'Your friends are starting to ask for your picks before they play 😎',
        );
      case 'EXPERT':
        return context.tr(
          'Tu ne pronostiques plus les matchs… tu annonces l’avenir. 🔮⚽',
          'You no longer predict matches… you announce the future. 🔮⚽',
        );
      default:
        return context.tr(
          'Chaque match est une nouvelle chance de progresser.',
          'Every match is another chance to improve.',
        );
    }
  }

  void _showBadgeMeaning(BuildContext context, String badge) {
    final asset = reputationBadgeAsset(context, badge);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: asset == null
                    ? Icon(Icons.shield_rounded, color: AppColors.lime, size: 72)
                    : Image.asset(asset, fit: BoxFit.contain),
              ),
              const SizedBox(height: 10),
              Text(
                reputationLabel(context, badge),
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.lime,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _badgePhrase(context, badge),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.text,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Les badges évoluent selon tes pronostics et tes résultats.',
                  'Badges evolve with your predictions and results.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.text2,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeJourney(BuildContext context, String activeBadge) {
    const badges = ['FOOTIX', 'AMATEUR', 'CONNAISSEUR', 'CONFIRMÉ', 'EXPERT'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.track_changes_rounded,
                color: AppColors.lime, size: 19),
            const SizedBox(width: 7),
            Text(
              context.tr('Mon parcours', 'My journey'),
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ]),
          const SizedBox(height: 3),
          Text(
            context.tr(
              'Appuie sur un badge pour découvrir ce qu’il signifie.',
              'Tap a badge to discover what it means.',
            ),
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10),
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: badges.map((badge) {
              final asset = reputationBadgeAsset(context, badge);
              final active = badge == activeBadge.toUpperCase();
              return Expanded(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _showBadgeMeaning(context, badge),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: active ? 58 : 48,
                        height: active ? 58 : 48,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? AppColors.lime.withOpacity(.10)
                              : Colors.transparent,
                          border: Border.all(
                            color: active
                                ? AppColors.lime
                                : AppColors.overlayBase.withOpacity(.06),
                            width: active ? 1.6 : 1,
                          ),
                        ),
                        child: asset == null
                            ? Icon(Icons.shield_rounded,
                                color: AppColors.grey)
                            : Image.asset(asset, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      reputationLabel(context, badge),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: active ? AppColors.lime : AppColors.grey,
                        fontSize: 7.5,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, AppProvider prov, AppUser user) async {
    // Avoid disposing a TextEditingController while the dialog route is still
    // animating out. On some devices that produced a red Flutter error screen
    // immediately after saving the nickname.
    var draftName = user.name;
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Modifier le profil', 'Edit profile')),
        content: TextFormField(
          initialValue: user.name,
          maxLength: 24,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (value) => draftName = value,
          onFieldSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          decoration: InputDecoration(labelText: context.tr('Pseudo', 'Nickname')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, draftName.trim()),
            child: Text(context.tr('Enregistrer', 'Save')),
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty || !context.mounted) return;
    await prov.updateUser(name: next);
  }

  List<_Specialty> _specialties(BuildContext context, AppProvider prov, String uid) {
    final matchById = <String, FootballMatch>{
      for (final match in prov.matches) match.id: match,
    };
    final rows = <_Specialty>[];

    for (final competition in kCompetitions) {
      var played = 0;
      var correct = 0;
      var exact = 0;

      for (final result in prov.results.entries) {
        final match = matchById[result.key];
        if (match == null || match.competitionId != competition.id) continue;
        final vote = prov.votes['${uid}__${result.key}'];
        if (vote == null) continue;
        played++;
        if (vote == result.value) correct++;
        final prediction = prov.getExactPrediction(result.key, userId: uid);
        final score = prov.scores[result.key];
        if (prediction != null &&
            score != null &&
            prediction.homeScore == score.homeScore &&
            prediction.awayScore == score.awayScore) {
          exact++;
        }
      }

      if (played == 0) continue;
      final weighted = correct + (exact * .45);
      final score = (((weighted + 2) / (played + 4)) * 100)
          .round()
          .clamp(0, 100)
          .toInt();
      final level = _level(context, score, played);
      rows.add(_Specialty(
        competition: competition,
        played: played,
        correct: correct,
        exact: exact,
        score: score,
        level: level,
      ));
    }

    rows.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : b.played.compareTo(a.played);
    });
    return rows;
  }

  String _level(BuildContext context, int score, int played) {
    if (played < 3) return 'FOOTIX';
    if (score < 40) return 'FOOTIX';
    if (score < 55) return 'AMATEUR';
    if (score < 70) return context.tr('CONNAISSEUR', 'CONNOISSEUR');
    if (score < 85) return context.tr('CONFIRMÉ', 'CONFIRMED');
    return 'EXPERT';
  }

  Widget _specialtyCard(BuildContext context, _Specialty s) {
    final accuracy = s.played == 0 ? 0 : ((s.correct * 100) / s.played).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: s.competition.color.withOpacity(.28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _competitionMarkerVisual(s.competition),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      competitionDisplayName(context, s.competition),
                      style: GoogleFonts.inter(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${s.played} ${context.tr('pronos', 'picks')} · $accuracy% ${context.tr('bons', 'correct')}',
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11),
                    ),
                  ],
                ),
              ),
              _specialtyBadgeVisual(context, s),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: s.score / 100,
              minHeight: 7,
              backgroundColor: AppColors.bg3,
              valueColor: AlwaysStoppedAnimation<Color>(s.competition.color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${context.tr('Score', 'Score')} ${s.score}/100',
                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10),
              ),
              const Spacer(),
              if (s.exact > 0)
                Text(
                  '🎯 ${s.exact} ${context.tr('scores exacts', 'exact scores')}',
                  style: GoogleFonts.inter(color: AppColors.gold, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specialtyBadgeVisual(BuildContext context, _Specialty s) {
    final asset = reputationBadgeAsset(context, s.level);
    if (asset == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: s.competition.color.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          s.level,
          style: GoogleFonts.spaceGrotesk(
            color: s.competition.color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    return Tooltip(
      message: reputationLabel(context, s.level),
      child: SizedBox(
        width: 58,
        height: 58,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }

  Widget _competitionMarkerVisual(CompetitionInfo competition) {
    if (competition.apiCode == 'PL') {
      return Container(
        width: 34,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.10)),
        ),
        child: Stack(
          children: [
            Center(child: Container(height: 5, color: const Color(0xFFCE1124))),
            Center(child: Container(width: 5, color: const Color(0xFFCE1124))),
          ],
        ),
      );
    }
    final marker = switch (competition.apiCode) {
      'FL1' => '🇫🇷',
      'SA' => '🇮🇹',
      'BL1' => '🇩🇪',
      'CL' => '⭐',
      _ => competition.emoji,
    };
    return SizedBox(
      width: 34,
      child: Center(child: Text(marker, style: const TextStyle(fontSize: 24))),
    );
  }

  Widget _recentExactChips(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lime.withOpacity(.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lime.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('🎯 TES SCORES EXACTS RÉCENTS', '🎯 YOUR RECENT EXACT SCORES'),
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.lime,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: rows.map((row) {
              final match = row['match'] as FootballMatch;
              final score = row['score'] as MatchScore;
              final home = match.homeName ?? match.homeCode;
              final away = match.awayName ?? match.awayCode;
              return ActionChip(
                avatar: const Text('🏆'),
                label: SizedBox(
                  width: 220,
                  child: Text(
                    '$home ${score.display} $away · +5 pts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _emptySpecialties(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
        ),
        child: Text(
          context.tr(
            'Fais tes premiers pronostics pour débloquer tes spécialités par championnat.',
            'Make your first predictions to unlock competition specialties.',
          ),
          style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, height: 1.45),
        ),
      );

  Widget _progressCard(BuildContext context, int played, int correct, int knowledge) {
    final accuracy = played == 0 ? 0 : ((correct * 100) / played).round();
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
            context.tr('Niveau général', 'Overall level'),
            style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: knowledge / 100,
              minHeight: 9,
              backgroundColor: AppColors.bg3,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'Score de niveau : $knowledge/100 · $accuracy% de bons pronostics.',
              'Level score: $knowledge/100 · $accuracy% correct predictions.',
            ),
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      );

  Widget _stat(BuildContext context, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.lime,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.grey,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(.11),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w900),
        ),
      );
}

class _Specialty {
  final CompetitionInfo competition;
  final int played;
  final int correct;
  final int exact;
  final int score;
  final String level;

  const _Specialty({
    required this.competition,
    required this.played,
    required this.correct,
    required this.exact,
    required this.score,
    required this.level,
  });
}
