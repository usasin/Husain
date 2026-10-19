import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prono4/data/final_match_result.dart';

void main() {
  test('future old live score stays scheduled before kickoff', () {
    final data = <String, dynamic>{
      'kickoffAtMs': 4102444800000,
      'status': 'IN_PLAY',
      'homeScore': 0,
      'awayScore': 0
    };
    expect(matchHasStarted(data), false);
    expect(matchDisplayStatus(data), 'SCHEDULED');
    expect(
        matchHasStarted(data,
            now: DateTime.fromMillisecondsSinceEpoch(4102444800000)),
        true);
  });
  final cases = jsonDecode(
      File('test/fixtures/final_result_cases.json').readAsStringSync()) as List;
  for (final sample in cases.cast<Map<String, dynamic>>()) {
    test(sample['name'] as String, () {
      expect(
          finalMatchOutcome(Map<String, dynamic>.from(sample['data'] as Map)),
          sample['expected']);
    });
  }
}
