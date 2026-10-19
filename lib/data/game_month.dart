import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A single calendar for every player, including when travelling abroad.
class GameMonth {
  static tz.Location? _paris;
  static tz.Location get paris {
    if (_paris == null) {
      // Do not reset tz.local: notification reminders already use the
      // device's configured location.
      if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
      _paris = tz.getLocation('Europe/Paris');
    }
    return _paris!;
  }

  final int year;
  final int month;
  const GameMonth(this.year, this.month);

  factory GameMonth.at(DateTime instant) {
    final local = tz.TZDateTime.from(instant, paris);
    return GameMonth(local.year, local.month);
  }

  String get key => '$year-${month.toString().padLeft(2, '0')}';
  String get documentId => 'gameMonth_$key';
  DateTime get start => tz.TZDateTime(paris, year, month).toUtc();
  DateTime get end => tz.TZDateTime(paris, year, month + 1).toUtc();
  int get days => DateTime.utc(year, month + 1, 0).day;
  GameMonth get previous {
    final date = DateTime.utc(year, month - 1);
    return GameMonth(date.year, date.month);
  }

  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);

  double progressAt(DateTime instant) =>
      (instant.difference(start).inMilliseconds /
              end.difference(start).inMilliseconds)
          .clamp(0.0, 1.0);

  String label(bool french) {
    const fr = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];
    const en = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${(french ? fr : en)[month - 1]} $year';
  }
}

class GameMonthlyPlayer {
  final String id, name, avatar;
  final int points, votes;
  const GameMonthlyPlayer(
      {required this.id,
      required this.name,
      required this.avatar,
      required this.points,
      required this.votes});
}

class GameMonthlySnapshot {
  final GameMonth month;
  final List<GameMonthlyPlayer> players;
  final DateTime? updatedAt;
  final bool truncated;
  const GameMonthlySnapshot(
      {required this.month,
      required this.players,
      this.updatedAt,
      this.truncated = false});

  int? rankOf(String uid) {
    final index = players.indexWhere((player) => player.id == uid);
    return index < 0 ? null : index + 1;
  }

  GameMonthlyPlayer? player(String uid) {
    for (final player in players) {
      if (player.id == uid) return player;
    }
    return null;
  }
}
