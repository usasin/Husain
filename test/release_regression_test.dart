import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prono4/models/models.dart';
import 'package:prono4/data/home_match_filter.dart';
import 'package:prono4/data/home_live_score_feed.dart';
import 'package:prono4/data/user_identity.dart';
import 'package:prono4/data/team_identity.dart';
import 'package:prono4/data/points_reward_logic.dart';
import 'package:prono4/data/reward_celebration_logic.dart';

void main() {
  const player = AppUser(id: 'old-uid', name: 'Ihab', avatar: 'photo', recoveryCode: 'CODE1234');
  test('An incomplete same-account snapshot preserves the avatar and recovery code', () {
    final restored = userFromProfileData('old-uid', {'name': 'Ihab'}, cached: player);
    expect(restored.avatar, 'photo');
    expect(restored.recoveryCode, 'CODE1234');
  });
  test('Changing accounts cannot reuse another account photo or pending edit', () {
    final restored = userFromProfileData('new-uid', {}, cached: player,
      pending: {'id': 'old-uid', 'name': 'Wrong name', 'avatar': 'Wrong photo'});
    expect(restored.name, 'Joueur');
    expect(restored.avatar, '👤');
    expect(restored.recoveryCode, isEmpty);
  });
  const team = AppTeam(id: 'team', name: 'OM', code: 'CODE', memberIds: ['old-uid'], createdBy: 'old-uid');
  test('Ranking refresh keeps the team image from its live document', () {
    final restored = teamWithLiveImage(team, team.copyWith(imageB64: 'saved-image'));
    expect(restored.imageB64, 'saved-image');
    expect(restored.memberIds, team.memberIds);
  });
  test('A different team cannot supply the image', () {
    const other = AppTeam(id: 'other', name: 'Other', code: 'OTHER', memberIds: [], createdBy: 'other', imageB64: 'wrong-image');
    expect(teamWithLiveImage(team, other).imageB64, isEmpty);
  });
  test('A late exact-score bonus celebrates only the two newly credited points', () {
    final gains = newPointsSinceLastVisit(seen: {'match': 3}, awarded: {'match': 5}, matchLabels: {});
    final moments = buildRewardMoments(gains);
    expect(moments, hasLength(1));
    expect(moments.single.kind, 'exact');
    expect(moments.single.points, 2);
  });
  test('Unchanged scores and corrections cannot award another celebration', () {
    expect(newPointsSinceLastVisit(seen: {'match': 5}, awarded: {'match': 3}, matchLabels: {}), isEmpty);
    expect(newPointsSinceLastVisit(seen: {'match': 5}, awarded: {'match': 5}, matchLabels: {}), isEmpty);
  });
  test('Initial badges and demotions are not promotions', () {
    expect(isBadgePromotion(null, 'EXPERT'), false);
    expect(isBadgePromotion('EXPERT', 'AMATEUR'), false);
    expect(isBadgePromotion('CONFIRME', 'EXPERT'), true);
  });
  test('A provisional result at half-time remains live', () {
    expect(isHomeFinishedMatch(liveStatus: 'PAUSED', hasRecordedResult: true), false);
  });
  test('Old or future live feeds are ignored without touching stored results', () {
    final now = DateTime.utc(2026, 10, 14, 18);
    for (final checked in [now.subtract(const Duration(minutes: 46)), now.add(const Duration(minutes: 6))]) {
      expect(parseHomeLiveScores({'checkedAt': Timestamp.fromDate(checked), 'matches': {'m': {'status': 'IN_PLAY', 'homeScore': 2, 'awayScore': 1}}}, now), isEmpty);
    }
  });
  test('Fresh half-time feed provides a display score', () {
    final now = DateTime.utc(2026, 10, 14, 18);
    final feed = parseHomeLiveScores({'checkedAt': Timestamp.fromDate(now), 'matches': {'m': {'status': 'PAUSED', 'homeScore': 2, 'awayScore': 1}}}, now);
    expect(feed['m']!.isLive, true);
    expect(feed['m']!.isFinished, false);
    expect(feed['m']!.score!.homeScore, 2);
  });
}
