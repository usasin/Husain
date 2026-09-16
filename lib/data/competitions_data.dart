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
  final String emblemUrl;
  final CompetitionKind kind;
  final Color color;

  const CompetitionInfo({
    required this.id,
    required this.apiCode,
    required this.name,
    required this.shortName,
    required this.country,
    required this.emoji,
    required this.emblemUrl,
    required this.kind,
    required this.color,
  });
}

/// Compétitions suivies par PRONO4.
/// On garde les grands championnats + la Ligue des champions, avec leurs
/// emblèmes officiels renvoyés par football-data.org.
const List<CompetitionInfo> kCompetitions = [
  CompetitionInfo(
    id: 'ligue-1',
    apiCode: 'FL1',
    name: 'Ligue 1',
    shortName: 'L1',
    country: 'France',
    emoji: '🇫🇷',
    emblemUrl: 'https://crests.football-data.org/FL1.png',
    kind: CompetitionKind.championnat,
    color: Color(0xFF32C653),
  ),
  CompetitionInfo(
    id: 'premier-league',
    apiCode: 'PL',
    name: 'Premier League',
    shortName: 'PL',
    country: 'Angleterre',
    emoji: '🏴',
    emblemUrl: 'https://crests.football-data.org/PL.png',
    kind: CompetitionKind.championnat,
    color: Color(0xFF6E49A8),
  ),
  CompetitionInfo(
    id: 'champions-league',
    apiCode: 'CL',
    name: 'Ligue des champions',
    shortName: 'LDC',
    country: 'Europe',
    emoji: '⭐',
    emblemUrl: 'https://crests.football-data.org/CL.png',
    kind: CompetitionKind.europe,
    color: Color(0xFF3156B8),
  ),
  CompetitionInfo(
    id: 'la-liga',
    apiCode: 'PD',
    name: 'LaLiga',
    shortName: 'LIGA',
    country: 'Espagne',
    emoji: '🇪🇸',
    emblemUrl: 'https://crests.football-data.org/PD.png',
    kind: CompetitionKind.championnat,
    color: Color(0xFFE4548B),
  ),
  CompetitionInfo(
    id: 'bundesliga',
    apiCode: 'BL1',
    name: 'Bundesliga',
    shortName: 'BUND',
    country: 'Allemagne',
    emoji: '🇩🇪',
    emblemUrl: 'https://crests.football-data.org/BL1.png',
    kind: CompetitionKind.championnat,
    color: Color(0xFFD94B52),
  ),
  CompetitionInfo(
    id: 'serie-a',
    apiCode: 'SA',
    name: 'Serie A',
    shortName: 'SERIE A',
    country: 'Italie',
    emoji: '🇮🇹',
    emblemUrl: 'https://crests.football-data.org/SA.png',
    kind: CompetitionKind.championnat,
    color: Color(0xFF2D78D4),
  ),
  CompetitionInfo(
    id: 'championship',
    apiCode: 'ELC',
    name: 'Championship',
    shortName: 'EFL',
    country: 'Angleterre',
    emoji: '🏴',
    emblemUrl: 'https://crests.football-data.org/ELC.png',
    kind: CompetitionKind.championnat,
    color: Color(0xFF365A97),
  ),
  CompetitionInfo(
    id: 'eredivisie',
    apiCode: 'DED',
    name: 'Eredivisie',
    shortName: 'ERED',
    country: 'Pays-Bas',
    emoji: '🇳🇱',
    emblemUrl: 'https://crests.football-data.org/DED.png',
    kind: CompetitionKind.championnat,
    color: Color(0xFFF28C28),
  ),
  CompetitionInfo(
    id: 'primeira-liga',
    apiCode: 'PPL',
    name: 'Primeira Liga',
    shortName: 'LIGA PT',
    country: 'Portugal',
    emoji: '🇵🇹',
    emblemUrl: 'https://crests.football-data.org/PPL.png',
    kind: CompetitionKind.championnat,
    color: Color(0xFF15915A),
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
    case 'CL':
      return 'Champions League';
    default:
      return competition.name;
  }
}

String competitionDisplayShortName(BuildContext context, CompetitionInfo competition) {
  if (context.isEnglish && competition.apiCode == 'CL') return 'UCL';
  return competition.shortName;
}
