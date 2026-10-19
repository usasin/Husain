import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/game_month.dart';

abstract class GameMonthlySource {
  Stream<GameMonthlySnapshot?> watch(GameMonth month);
  Future<List<GameMonthlySnapshot>> history(GameMonth current,
      {bool refresh = false});
}

class GameMonthlyRepository implements GameMonthlySource {
  final FirebaseFirestore firestore;
  final Map<String, Future<List<GameMonthlySnapshot>>> _history = {};
  GameMonthlyRepository(this.firestore);

  GameMonthlySnapshot? _parse(GameMonth month, Map<String, dynamic>? data) {
    if (data == null) return null;
    if (data['period'] != 'gameMonth' ||
        data['monthKey'] != month.key ||
        data['timeZone'] != 'Europe/Paris' ||
        data['schemaVersion'] != 1) {
      throw const FormatException('Monthly ranking period does not match');
    }
    final players = <GameMonthlyPlayer>[];
    final ids = <String>{};
    for (final raw in (data['individuals'] as List? ?? const [])) {
      if (raw is! Map) throw const FormatException('Invalid monthly player');
      final id = raw['id'];
      if (id is! String ||
          id.isEmpty ||
          !ids.add(id) ||
          raw['points'] is! int ||
          raw['votes'] is! int ||
          (raw['points'] as int) < 0 ||
          (raw['votes'] as int) < 1) {
        throw const FormatException('Invalid monthly ranking');
      }
      players.add(GameMonthlyPlayer(
          id: id,
          name: (raw['name'] ?? 'Joueur').toString(),
          avatar: (raw['avatar'] ?? '⚽').toString(),
          points: raw['points'] as int,
          votes: raw['votes'] as int));
    }
    return GameMonthlySnapshot(
        month: month,
        players: players,
        truncated: data['truncated'] == true,
        updatedAt: data['updatedAt'] is Timestamp
            ? (data['updatedAt'] as Timestamp).toDate()
            : null);
  }

  @override
  Stream<GameMonthlySnapshot?> watch(GameMonth month) => firestore
      .collection('rankingSnapshots')
      .doc(month.documentId)
      .snapshots()
      .map((snapshot) => _parse(month, snapshot.data()));

  @override
  Future<List<GameMonthlySnapshot>> history(GameMonth current,
      {bool refresh = false}) {
    if (refresh) _history.remove(current.key);
    return _history.putIfAbsent(current.key, () async {
      try {
        final months = <GameMonth>[];
        var month = current.previous;
        for (var i = 0; i < 12; i++) {
          months.add(month);
          month = month.previous;
        }
        final documents = await Future.wait(months.map((m) =>
            firestore.collection('rankingSnapshots').doc(m.documentId).get()));
        return [
          for (var i = 0; i < documents.length; i++)
            if (documents[i].exists) _parse(months[i], documents[i].data())!
        ];
      } catch (_) {
        _history.remove(current.key);
        rethrow;
      }
    });
  }
}
