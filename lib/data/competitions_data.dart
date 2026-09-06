import 'package:flutter/material.dart';
import '../l10n/app_locale.dart';

enum CompetitionKind { championnat, coupe, europe }

class CompetitionInfo {
  final String id;
  final String apiCode;
  final String name;
  final String shortName;
  final String country;
  final String emoji;
  final CompetitionKind kind;
  final Color color;

  const CompetitionInfo({
    required this.id,
    required this.apiCode,
    required this.name,
    required this.shortName,
    required this.country,
    required this.emoji,
    required this.kind,
    required this.color,
  });
}

/// PRONO4 utilise uniquement les compétitions essentielles voulues ici :
/// France, Angleterre, Espagne, Allemagne et Ligue des champions.
///
/// Tout le reste est volontairement retiré pour garder l'app simple et claire.
const List<CompetitionInfo> kCompetitions = [
  CompetitionInfo(
    id: 'ligue-1',
    apiCode: 'FL1',
    name: 'Ligue 1',
    shortName: 'L1',
    country: 'France',
    emoji: '🇫🇷',
    kind: CompetitionKind.championnat,
    color: Color(0xFFB6FF3B),
  ),
  CompetitionInfo(
    id: 'premier-league',
    apiCode: 'PL',
    name: 'Premier League',
    shortName: 'PL',
    country: 'Angleterre',
    emoji: '🏴',
    kind: CompetitionKind.championnat,
    color: Color(0xFFB28DFF),
  ),
  CompetitionInfo(
    id: 'champions-league',
    apiCode: 'CL',
    name: 'Ligue des champions',
    shortName: 'LDC',
    country: 'Europe',
    emoji: '⭐',
    kind: CompetitionKind.europe,
    color: Color(0xFFFFD85C),
  ),
  CompetitionInfo(
    id: 'la-liga',
    apiCode: 'PD',
    name: 'LaLiga',
    shortName: 'LIGA',
    country: 'Espagne',
    emoji: '🇪🇸',
    kind: CompetitionKind.championnat,
    color: Color(0xFFFF7DC8),
  ),
  CompetitionInfo(
    id: 'bundesliga',
    apiCode: 'BL1',
    name: 'Bundesliga',
    shortName: 'BUND',
    country: 'Allemagne',
    emoji: '🇩🇪',
    kind: CompetitionKind.championnat,
    color: Color(0xFFFF6E78),
  ),
];

CompetitionInfo? competitionById(String id) {
  for (final competition in kCompetitions) {
    if (competition.id == id) return competition;
  }
  return null;
}

CompetitionInfo? competitionByApiCode(String code) {
  final normalized = code.trim().toUpperCase();
  for (final competition in kCompetitions) {
    if (competition.apiCode == normalized) return competition;
  }
  return null;
}


String competitionDisplayName(BuildContext context, CompetitionInfo competition) {
  if (!context.isEnglish) return competition.name;
  switch (competition.apiCode) {
    case 'CL': return 'Champions League';
    default: return competition.name;
  }
}

String competitionDisplayShortName(BuildContext context, CompetitionInfo competition) {
  if (context.isEnglish && competition.apiCode == 'CL') return 'UCL';
  return competition.shortName;
}
