import 'dart:convert';

import 'points_reward_logic.dart';

/// Local presentation history, never an attribution of points.
Map<String, int>? readRewardCheckpoint(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return {
      for (final entry in decoded.entries)
        if (entry.value is int && (entry.value as int) >= 0)
          entry.key.toString(): entry.value as int,
    };
  } catch (_) {
    return null;
  }
}

/// At installation, show only recent results (including yesterday), without
/// replaying the entire season. Later visits compare all confirmed results.
List<RecentPointsGain> pendingRewardGains({
  required Map<String, int>? seen,
  required Map<String, int> awarded,
  required Map<String, String> labels,
  required Map<String, DateTime> kickoffs,
  required DateTime now,
}) {
  final firstVisitBaseline = {
    for (final entry in awarded.entries)
      if (kickoffs[entry.key] == null ||
          kickoffs[entry.key]!
              .isBefore(now.subtract(const Duration(hours: 48))) ||
          kickoffs[entry.key]!.isAfter(now))
        entry.key: entry.value,
  };
  return newPointsSinceLastVisit(
    seen: seen ?? firstVisitBaseline,
    awarded: awarded,
    matchLabels: labels,
  );
}

/// A temporary correction/loading gap must not turn restored points into a
/// second win. Keep the highest already-presented value for each match.
Map<String, int> acknowledgedRewardPoints(
    Map<String, int>? seen, Map<String, int> awarded) {
  final next = {...?seen};
  for (final entry in awarded.entries) {
    if (entry.value >= (next[entry.key] ?? 0)) next[entry.key] = entry.value;
  }
  return next;
}
