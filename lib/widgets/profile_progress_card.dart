import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import 'reputation_badge.dart';

/// Presentation of existing provider values. No scoring or badge attribution.
class ProfileLevelCard extends StatelessWidget {
  final String badge;
  final int knowledge;
  final int played;
  final bool available;
  final VoidCallback onInfo;
  final VoidCallback? onRetry;
  const ProfileLevelCard(
      {super.key,
      required this.badge,
      required this.knowledge,
      required this.played,
      required this.available,
      required this.onInfo,
      this.onRetry});

  @override
  Widget build(BuildContext context) {
    final evaluated = available && played >= 3;
    final asset = reputationBadgeAsset(context, badge);
    final normalized = badge.toUpperCase().replaceAll('CONFIRME', 'CONFIRMÉ');
    const steps = {
      'FOOTIX': ('AMATEUR', 40),
      'AMATEUR': ('CONNAISSEUR', 55),
      'CONNAISSEUR': ('CONFIRMÉ', 70),
      'CONFIRMÉ': ('EXPERT', 85)
    };
    final next = steps[normalized];
    return _ProfileCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text(context.tr('MON NIVEAU FOOT', 'MY FOOTBALL LEVEL'),
                style: TextStyle(
                    color: AppColors.text2,
                    fontSize: 11,
                    letterSpacing: .6,
                    fontWeight: FontWeight.w800))),
        IconButton(
            onPressed: onInfo,
            tooltip: context.tr('Comprendre mon niveau', 'Understand my level'),
            icon: Icon(Icons.info_outline_rounded, color: AppColors.text2)),
      ]),
      if (!available) ...[
        Text(context.tr('Chargement du niveau…', 'Loading your level…'),
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        if (onRetry != null)
          TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('Actualiser', 'Refresh'))),
      ] else ...[
        LayoutBuilder(builder: (context, box) {
          final picture = SizedBox(
              width: 84,
              height: 90,
              child: asset == null
                  ? const Icon(Icons.shield_rounded,
                      size: 64, color: AppColors.lime)
                  : Image.asset(asset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => const Icon(
                          Icons.shield_rounded,
                          size: 64,
                          color: AppColors.lime)));
          final details =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reputationLabel(context, badge),
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
                evaluated
                    ? context.tr('Niveau récent', 'Recent level')
                    : context.tr('Premiers matchs', 'First matches'),
                style: TextStyle(color: AppColors.text2, fontSize: 12)),
            if (evaluated)
              Text('$knowledge/100',
                  style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 27,
                      fontWeight: FontWeight.w900)),
          ]);
          if (MediaQuery.textScalerOf(context).scale(19) > 26) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [picture, const SizedBox(height: 8), details]);
          }
          return Row(children: [
            picture,
            const SizedBox(width: 14),
            Expanded(child: details)
          ]);
        }),
        const SizedBox(height: 12),
        ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
                minHeight: 8,
                value: evaluated
                    ? knowledge.clamp(0, 100) / 100
                    : played.clamp(0, 3) / 3,
                backgroundColor: AppColors.bg3,
                color: AppColors.lime)),
        const SizedBox(height: 12),
        if (!evaluated)
          Text(
              context.tr('$played/3 pronos terminés pour évaluer ton niveau',
                  '$played/3 finished picks to assess your level'),
              style: TextStyle(color: AppColors.text2, fontSize: 12)),
        if (evaluated && next != null)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.flag_outlined, color: AppColors.lime, size: 19),
            const SizedBox(width: 7),
            Expanded(
                child: Text(
                    context.tr(
                        'Prochain badge : ${reputationLabel(context, next.$1)} à ${next.$2}/100',
                        'Next badge: ${reputationLabel(context, next.$1)} at ${next.$2}/100'),
                    style: TextStyle(color: AppColors.text2, fontSize: 12))),
          ]),
        if (evaluated && normalized == 'EXPERT')
          Text(
              context.tr('Le plus haut badge atteint', 'Highest badge reached'),
              style: TextStyle(
                  color: AppColors.lime, fontWeight: FontWeight.w700)),
      ],
    ]));
  }
}

class ProfileStatisticsCard extends StatelessWidget {
  final int points;
  final int played;
  final int correct;
  final bool available;
  const ProfileStatisticsCard(
      {super.key,
      required this.points,
      required this.played,
      required this.correct,
      required this.available});

  @override
  Widget build(BuildContext context) {
    final accuracy =
        available && played > 0 ? '${(correct * 100 / played).round()}%' : '—';
    Widget metric(String value, String title, String subtitle, IconData icon) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.lime, size: 21),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 27,
                  fontWeight: FontWeight.w900)),
          Text(title,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: TextStyle(color: AppColors.text2, fontSize: 11)),
        ]);
    final pointsView = metric(
        available ? '$points' : '—',
        context.tr('Points au classement', 'Ranking points'),
        context.tr('Total cumulé', 'Accumulated total'),
        Icons.emoji_events_outlined);
    final accuracyView = metric(
        accuracy,
        context.tr('Réussite globale', 'Overall accuracy'),
        available
            ? context.tr('$correct bons / $played terminés',
                '$correct correct / $played finished')
            : context.tr('Chargement…', 'Loading…'),
        Icons.check_circle_outline_rounded);
    return _ProfileCard(child: LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 270 ||
          MediaQuery.textScalerOf(context).scale(12) > 18) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [pointsView, const SizedBox(height: 14), accuracyView]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: pointsView),
        const SizedBox(width: 16),
        Expanded(child: accuracyView)
      ]);
    }));
  }
}

/// Detailed explanation is requested explicitly; it does not fill the profile.
class ProfileLevelExplanation extends StatelessWidget {
  const ProfileLevelExplanation({super.key});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('Comment ça marche ?', 'How does it work?'),
            style: TextStyle(
                color: AppColors.text,
                fontSize: 21,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        _explanation(
            context,
            Icons.shield_outlined,
            context.tr(
                'Le badge : ton niveau récent', 'Badge: your recent level'),
            context.tr(
                'Il dépend de tes 30 derniers pronostics terminés, avec un bonus pour les scores exacts. '
                    'Le niveau peut monter ou descendre. Il commence à être évalué après 3 pronostics terminés.',
                'Based on your last 30 finished picks, with extra weight for exact scores. '
                    'Your level can rise or fall. Assessment starts after 3 finished picks.')),
        const SizedBox(height: 16),
        _explanation(
            context,
            Icons.emoji_events_outlined,
            context.tr('Les points : ton classement', 'Points: your ranking'),
            context.tr(
                'Un bon résultat vaut 3 points, et le score exact ajoute 2 points. '
                    'Ces points ne s’ajoutent pas directement au niveau sur 100.',
                'A correct outcome earns 3 points; an exact score adds 2. '
                    'These points do not directly increase the level out of 100.')),
        const SizedBox(height: 16),
        _explanation(
            context,
            Icons.check_circle_outline_rounded,
            context.tr('La réussite : tous tes résultats',
                'Accuracy: all your results'),
            context.tr(
                'Elle compare tous tes bons pronostics à tous tes pronostics terminés. '
                    'Ce pourcentage peut être différent du niveau récent.',
                'It compares all your correct picks with all your finished picks. '
                    'This percentage can differ from your recent level.')),
        const SizedBox(height: 16),
        Text(
            context.tr('Chaque championnat a aussi son propre niveau.',
                'Each competition also has its own level.'),
            style: TextStyle(color: AppColors.text2, fontSize: 13)),
      ]);

  Widget _explanation(
          BuildContext context, IconData icon, String title, String body) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.lime),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(body,
              style: TextStyle(
                  color: AppColors.text2, fontSize: 13, height: 1.45)),
        ])),
      ]);
}

class _ProfileCard extends StatelessWidget {
  final Widget child;
  const _ProfileCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.lime.withValues(alpha: .20))),
      child: child);
}
