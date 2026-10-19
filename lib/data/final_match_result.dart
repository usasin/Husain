/// Shared by all platforms. Live scores stay visible, but settle no bets.
String? finalMatchOutcome(Map<String, dynamic> data) {
  if (!matchHasStarted(data)) return null;
  final primaryStatus = (data['status'] ?? '').toString().trim();
  final status =
      (primaryStatus.isEmpty ? data['liveStatus'] ?? '' : primaryStatus)
          .toString()
          .trim()
          .toUpperCase();
  if (status.isNotEmpty && status != 'FINISHED' && status != 'AWARDED') {
    return null;
  }
  final result = (data['result'] ?? '').toString().trim().toUpperCase();
  if (!const {'HOME', 'DRAW', 'AWAY'}.contains(result)) return null;
  final home = data['homeScore'];
  final away = data['awayScore'];
  // Preserve historical manually entered outcomes without a score.
  if (home == null && away == null) return result;
  if (home is! num ||
      away is! num ||
      !home.isFinite ||
      !away.isFinite ||
      home < 0 ||
      away < 0 ||
      home != home.round() ||
      away != away.round()) {
    return null;
  }
  final outcome = home > away
      ? 'HOME'
      : home < away
          ? 'AWAY'
          : 'DRAW';
  return result == outcome ? result : null;
}

bool matchHasStarted(Map<String, dynamic> data, {DateTime? now}) {
  final kickoff = data['kickoffAtMs'];
  return kickoff is! num ||
      kickoff <= (now ?? DateTime.now()).millisecondsSinceEpoch;
}

String matchDisplayStatus(Map<String, dynamic> data) => !matchHasStarted(data)
    ? 'SCHEDULED'
    : (data['status'] ?? data['liveStatus'] ?? '').toString().trim();
