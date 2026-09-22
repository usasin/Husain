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
/// Compétitions suivies dans l'app : 4 grands championnats, Ligue des champions et EURO.
const List<CompetitionInfo> kCompetitions = [
  CompetitionInfo(id: 'ligue-1', apiCode: 'FL1', name: 'Ligue 1', shortName: 'L1', country: 'France', emoji: '🇫🇷', emblemUrl: 'https://crests.football-data.org/FL1.png', kind: CompetitionKind.championnat, color: Color(0xFF32C653)),
  CompetitionInfo(id: 'premier-league', apiCode: 'PL', name: 'Premier League', shortName: 'PL', country: 'Angleterre', emoji: '🏴', emblemUrl: 'https://crests.football-data.org/PL.png', kind: CompetitionKind.championnat, color: Color(0xFF6E49A8)),
  CompetitionInfo(id: 'serie-a', apiCode: 'SA', name: 'Serie A', shortName: 'SERIE A', country: 'Italie', emoji: '🇮🇹', emblemUrl: 'https://crests.football-data.org/SA.png', kind: CompetitionKind.championnat, color: Color(0xFF2D78D4)),
  CompetitionInfo(id: 'bundesliga', apiCode: 'BL1', name: 'Bundesliga', shortName: 'BUND', country: 'Allemagne', emoji: '🇩🇪', emblemUrl: 'https://crests.football-data.org/BL1.png', kind: CompetitionKind.championnat, color: Color(0xFFD94B52)),
  CompetitionInfo(id: 'champions-league', apiCode: 'CL', name: 'Ligue des champions', shortName: 'LDC', country: 'Europe', emoji: '⭐', emblemUrl: 'https://crests.football-data.org/CL.png', kind: CompetitionKind.europe, color: Color(0xFF3156B8)),
  CompetitionInfo(id: 'euro', apiCode: 'EC', name: "Championnat d'Europe", shortName: 'EURO', country: 'Europe', emoji: '🇪🇺', emblemUrl: 'https://crests.football-data.org/EC.png', kind: CompetitionKind.europe, color: Color(0xFF169B62)),
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
    case 'EC':
      return 'European Championship';
    default:
      return competition.name;
  }
}

String competitionDisplayShortName(BuildContext context, CompetitionInfo competition) {
  if (context.isEnglish && competition.apiCode == 'CL') return 'UCL';
  return competition.shortName;
}
