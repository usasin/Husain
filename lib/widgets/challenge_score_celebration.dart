import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';

/// Highlights the confirmed duel outcome using the points already displayed by
/// the challenge. Does not award a victory bonus or request any other data.
class ChallengeScoreCelebration extends StatelessWidget {
  final int myPoints;
  final int otherPoints;
  final String otherName;
  const ChallengeScoreCelebration(
      {super.key,
      required this.myPoints,
      required this.otherPoints,
      required this.otherName});

  @override
  Widget build(BuildContext context) {
    final won = myPoints > otherPoints;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget score(String name, int points, Color color) => Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.text2,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
          FittedBox(
              child: Text('$points',
                  style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w900))),
        ]));
    return Row(children: [
      score(context.tr('TOI', 'YOU'), myPoints, AppColors.lime),
      Flexible(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
            key: ValueKey('duel-$myPoints-$otherPoints'),
            tween: Tween(begin: won && !reduceMotion ? .35 : 1, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Icon(
                won ? Icons.emoji_events_rounded : Icons.sports_kabaddi_rounded,
                size: 46,
                color: won ? AppColors.gold : AppColors.text2)),
        if (won)
          Text(context.tr('Victoire !', 'Victory!'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900)),
      ])),
      score(otherName, otherPoints, AppColors.text),
    ]);
  }
}
