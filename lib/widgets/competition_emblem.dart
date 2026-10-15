import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/competitions_data.dart';

/// Local emblems also work for competitions managed without a data provider.
class CompetitionEmblem extends StatelessWidget {
  final CompetitionInfo competition;
  const CompetitionEmblem({super.key, required this.competition});

  @override
  Widget build(BuildContext context) {
    final asset = competition.emblemAsset;
    if (asset != null) {
      return SvgPicture.asset(asset,
          fit: BoxFit.contain,
          semanticsLabel: competitionDisplayName(context, competition));
    }
    return Image.network(competition.emblemUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
            child:
                Text(competition.emoji, style: const TextStyle(fontSize: 23))));
  }
}
