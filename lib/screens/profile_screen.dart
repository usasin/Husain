import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_display.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lime.withOpacity(.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.lime, width: 2),
            ),
            child: AvatarBubble(avatar: user.avatar, size: 66),
          ),
          const SizedBox(width: 14),
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
                      icon: const Icon(Icons.edit_rounded, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: [
                    _chip('🏅 $badge', AppColors.gold),
                    _chip(
                      context.tr('Niveau $knowledge/100', 'Level $knowledge/100'),
                      AppColors.cyan,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, AppProvider prov, AppUser user) async {
    final controller = TextEditingController(text: user.name);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Modifier le profil', 'Edit profile')),
        content: TextField(
          controller: controller,
          maxLength: 24,
          autofocus: true,
          decoration: InputDecoration(labelText: context.tr('Pseudo', 'Nickname')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.tr('Enregistrer', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
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
    if (played < 3) return context.tr('À PROUVER', 'TO PROVE');
    if (score < 40) return 'FOOTIX';
    if (score < 55) return 'AMATEUR';
    if (score < 70) return context.tr('CONNAISSEUR', 'KNOWLEDGEABLE');
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
              Text(s.competition.emoji, style: const TextStyle(fontSize: 24)),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: s.competition.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  s.level,
                  style: GoogleFonts.spaceGrotesk(
                    color: s.competition.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
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
              '$accuracy% de bons pronostics sur les matchs résolus.',
              '$accuracy% correct predictions on resolved matches.',
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
