import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prono4/models/models.dart';
import 'package:prono4/data/reward_checkpoint.dart';
import 'package:prono4/data/reward_celebration_logic.dart';
import 'package:prono4/data/points_reward_logic.dart';
import 'package:prono4/providers/app_provider.dart';
import 'package:prono4/theme/app_theme.dart';
import 'package:prono4/widgets/challenge_score_celebration.dart';
import 'package:prono4/widgets/recent_points_recap.dart';
import 'package:prono4/widgets/reward_celebration_dialog.dart';

class RewardProvider extends ChangeNotifier implements AppProvider {
  String uid = 'me';
  String badge = 'FOOTIX';
  bool ready = true;
  final earned = <String, int>{};
  final statuses = <String, String>{};
  @override
  AppUser get currentUser => AppUser(id: uid, name: 'Moi', avatar: '⚽');
  @override
  bool get loaded => true;
  @override
  bool get rewardDataReady => ready;
  @override
  Map<String, String> get votes => {
        for (final id in earned.keys) '${uid}__$id': 'HOME',
      };
  @override
  Map<String, String> get results => {for (final id in earned.keys) id: 'HOME'};
  @override
  String liveStatusFor(String id) => statuses[id] ?? 'FINISHED';
  @override
  int getUserMatchPoints(String userId, String matchId) => earned[matchId] ?? 0;
  @override
  String getAutoReputationBadge(String userId) => badge;
  @override
  FootballMatch? matchById(String id) => FootballMatch(
        id: id,
        homeCode: 'OM',
        awayCode: 'OL',
        date: DateTime.now()
            .subtract(Duration(days: id.startsWith('old') ? 14 : 1))
            .toIso8601String()
            .split('T')
            .first,
        time: '20:00',
        venue: '',
        phase: MatchPhase.groupe,
      );
  void changed() => notifyListeners();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget harness(RewardProvider provider,
        {GlobalKey<NavigatorState>? nav, String tab = 'Profil'}) =>
    ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
            navigatorKey: nav,
            home: Scaffold(
                body: Stack(children: [
              TickerMode(
                  enabled: false,
                  child: ListView(children: [
                    Text(tab),
                    const SizedBox(height: 3000),
                    const Text('Accueil hors champ'),
                  ])),
              RecentPointsRecap(onRankingTap: () {}, onProfileTap: () {}),
            ]))));

Future<void> waitForRewards(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 350));
}

void previous(
    {String uid = 'me',
    Map<String, int> points = const {},
    String badge = 'FOOTIX'}) {
  SharedPreferences.setMockInitialValues({
    'prono4_points_seen_v1_$uid': jsonEncode(points),
    'prono4_reward_seen_badge_v1_$uid': badge,
    'prono4_reward_presented_v2_$uid': true,
  });
}

Future<void> closeReward(
    WidgetTester tester, GlobalKey<NavigatorState> nav) async {
  nav.currentState!.pop();
  await tester.pumpAndSettle();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    if (Platform.isWindows) {
      for (final entry in {
        'PreviewSans': 'C:/Windows/Fonts/segoeui.ttf',
        'Inter': 'C:/Windows/Fonts/segoeui.ttf',
        'SpaceGrotesk': 'C:/Windows/Fonts/segoeui.ttf',
        for (final family in ['Inter', 'SpaceGrotesk'])
          for (final variant in ['regular', '500', '600', '700', '800', '900'])
            '${family}_$variant': 'C:/Windows/Fonts/segoeui.ttf',
        'PreviewEmoji': 'C:/Windows/Fonts/seguiemj.ttf',
        'MaterialIcons':
            'C:/Users/ibabh/develop/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      }.entries) {
        final file = File(entry.value);
        if (!file.existsSync()) continue;
        final loader = FontLoader(entry.key)
          ..addFont(
              file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
        await loader.load();
      }
    }
  });
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'yesterday gains are presented on first opening instead of silently seeded',
      (tester) async {
    final provider = RewardProvider()..earned['yesterday'] = 3;
    await tester.pumpWidget(harness(provider));
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a reward stays visible until the player dismisses it',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'prono4_points_seen_v1_me': jsonEncode({'yesterday': 0}),
      'prono4_reward_seen_badge_v1_me': 'FOOTIX',
    });
    final provider = RewardProvider()..earned['yesterday'] = 3;
    await tester.pumpWidget(harness(provider));
    await waitForRewards(tester);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RewardCelebrationDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'migration recaps yesterday once even if the old version silently seeded it',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'prono4_points_seen_v1_me': jsonEncode({'yesterday': 3, 'old-season': 5}),
      'prono4_reward_seen_badge_v1_me': 'AMATEUR',
    });
    final provider = RewardProvider()
      ..badge = 'AMATEUR'
      ..earned.addAll({'yesterday': 3, 'old-season': 5});
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(harness(provider, nav: nav));
    await waitForRewards(tester);
    final popup = tester
        .widget<RewardCelebrationDialog>(find.byType(RewardCelebrationDialog));
    expect(popup.recap, isTrue);
    expect(popup.gains.map((g) => g.matchId), ['yesterday']);
    await closeReward(tester, nav);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(provider));
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsNothing);
    expect(provider.earned, {'yesterday': 3, 'old-season': 5});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'partial startup does not seed points or a badge, then confirmed gains appear',
      (tester) async {
    final provider = RewardProvider()..ready = false;
    await tester.pumpWidget(harness(provider));
    await waitForRewards(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('prono4_points_seen_v1_me'), isNull);
    provider
      ..earned['yesterday'] = 5
      ..ready = true;
    provider.changed();
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsOneWidget);
    expect(
        tester
            .widget<RewardCelebrationDialog>(
                find.byType(RewardCelebrationDialog))
            .gains
            .single
            .gained,
        5);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a new player with zero votes can later celebrate the first correct pick',
      (tester) async {
    final provider = RewardProvider();
    await tester.pumpWidget(harness(provider));
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('prono4_points_seen_v1_me'), '{}');
    provider.earned['first'] = 3;
    provider.changed();
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final tab in ['Accueil', 'Classement', 'Profil']) {
    testWidgets(
        'confirmed gains appear on $tab without scrolling the home slivers',
        (tester) async {
      previous();
      final provider = RewardProvider()..earned['yesterday'] = 3;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(harness(provider, nav: nav, tab: tab));
      await waitForRewards(tester);
      expect(find.byType(RewardCelebrationDialog), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('prono4_points_seen_v1_me'), '{}');
      await closeReward(tester, nav);
      expect(jsonDecode(prefs.getString('prono4_points_seen_v1_me')!),
          {'yesterday': 3});
      provider.changed();
      await waitForRewards(tester);
      expect(find.byType(RewardCelebrationDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'the global listener presents gains above a pushed challenge route',
      (tester) async {
    previous();
    final provider = RewardProvider();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(harness(provider, nav: nav));
    await waitForRewards(tester);
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Défis 1 contre 1'))));
    await tester.pumpAndSettle();
    provider.earned['duel'] = 5;
    provider.changed();
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsOneWidget);
    await closeReward(tester, nav);
    expect(find.text('Défis 1 contre 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'backgrounded gains wait for resume and an interrupted popup is not consumed',
      (tester) async {
    previous();
    final provider = RewardProvider()..earned['yesterday'] = 3;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(harness(provider, nav: nav));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('prono4_points_seen_v1_me'), '{}');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byType(RewardCelebrationDialog), findsNothing);
    expect(prefs.getString('prono4_points_seen_v1_me'), '{}');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsOneWidget);
    await closeReward(tester, nav);
    expect(jsonDecode(prefs.getString('prono4_points_seen_v1_me')!),
        {'yesterday': 3});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'badge promotion appears without new points and is acknowledged once visible',
      (tester) async {
    previous(points: {'yesterday': 3}, badge: 'AMATEUR');
    final provider = RewardProvider()
      ..badge = 'CONNAISSEUR'
      ..earned['yesterday'] = 3;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(harness(provider, nav: nav));
    await waitForRewards(tester);
    expect(find.textContaining('NEW BADGE'), findsOneWidget);
    final popup = tester
        .widget<RewardCelebrationDialog>(find.byType(RewardCelebrationDialog));
    expect(popup.gains, isEmpty);
    expect(popup.newBadge, 'CONNAISSEUR');
    await closeReward(tester, nav);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('prono4_reward_seen_badge_v1_me'), 'CONNAISSEUR');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'dismissing points before the badge phase does not consume an unseen badge',
      (tester) async {
    previous(badge: 'AMATEUR');
    final provider = RewardProvider()
      ..badge = 'EXPERT'
      ..earned['yesterday'] = 5;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(harness(provider, nav: nav));
    await waitForRewards(tester);
    await closeReward(tester, nav);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('prono4_reward_seen_badge_v1_me'), 'AMATEUR');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await waitForRewards(tester);
    expect(
        tester
            .widget<RewardCelebrationDialog>(
                find.byType(RewardCelebrationDialog))
            .gains,
        isEmpty);
    await closeReward(tester, nav);
    expect(prefs.getString('prono4_reward_seen_badge_v1_me'), 'EXPERT');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'identity replacement removes old popup without consuming its checkpoint',
      (tester) async {
    previous();
    final provider = RewardProvider()..earned['yesterday'] = 3;
    await tester.pumpWidget(harness(provider));
    await waitForRewards(tester);
    provider
      ..uid = 'other'
      ..earned.clear();
    provider.changed();
    await tester.pumpAndSettle();
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('prono4_points_seen_v1_me'), '{}');
    expect(prefs.getString('prono4_points_seen_v1_other'), '{}');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'UID-preserving email linking and next launch do not replay acknowledged gains',
      (tester) async {
    previous(points: {'yesterday': 5});
    final provider = RewardProvider()..earned['yesterday'] = 5;
    await tester.pumpWidget(harness(provider));
    await waitForRewards(tester);
    provider.changed(); // Same UID after account link.
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(provider));
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'new gains during a celebration remain pending instead of being silently acknowledged',
      (tester) async {
    previous();
    final provider = RewardProvider()..earned['first'] = 3;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(harness(provider, nav: nav));
    await waitForRewards(tester);
    provider.earned['second'] = 5;
    provider.changed();
    await tester.pump();
    await closeReward(tester, nav);
    await waitForRewards(tester);
    final popup = tester
        .widget<RewardCelebrationDialog>(find.byType(RewardCelebrationDialog));
    expect(popup.gains.map((g) => g.matchId), ['second']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'only finished results celebrate; old season history is not replayed on installation',
      (tester) async {
    final provider = RewardProvider()
      ..earned.addAll({'old-season': 5, 'live': 3})
      ..statuses['live'] = 'IN_PLAY';
    await tester.pumpWidget(harness(provider));
    await waitForRewards(tester);
    expect(find.byType(RewardCelebrationDialog), findsNothing);
    provider.statuses['live'] = 'FINISHED';
    provider.changed();
    await waitForRewards(tester);
    final popup = tester
        .widget<RewardCelebrationDialog>(find.byType(RewardCelebrationDialog));
    expect(popup.gains.map((g) => g.matchId), ['live']);
    await tester.pumpWidget(const SizedBox());
  });

  test('checkpoint corrections never celebrate restored or lost points twice',
      () {
    final seen = acknowledgedRewardPoints({'match': 5}, {'match': 0});
    expect(seen, {'match': 5});
    expect(
        pendingRewardGains(
            seen: seen,
            awarded: {'match': 5},
            labels: {},
            kickoffs: {},
            now: DateTime.now()),
        isEmpty);
    expect(readRewardCheckpoint('{broken'), isNull);
    expect(readRewardCheckpoint('{"valid":3,"negative":-2,"string":"5"}'),
        {'valid': 3});
    expect(isBadgePromotion('EXPERT', 'AMATEUR'), isFalse);
    expect(isBadgePromotion('CONFIRME', 'EXPERT'), isTrue);
    expect(isBadgePromotion(null, 'EXPERT'), isFalse);
  });

  testWidgets(
      'duel victories animate actual scores; draws and losses do not claim a win',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final points in [5, 3, 0]) {
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  disableAnimations: true),
              child: child!),
          home: Scaffold(
              body: Padding(
                  padding: const EdgeInsets.all(14),
                  child: ChallengeScoreCelebration(
                      myPoints: points,
                      otherPoints: 3,
                      otherName: 'Un adversaire avec un nom long')))));
      await tester.pumpAndSettle();
      expect(
          find.text('Victory!'), points == 5 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'points and badge celebration fit 320 pixels with large text and reduced motion',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true),
            child: child!),
        home: const Scaffold(
            body: RewardCelebrationDialog(gains: [
          RecentPointsGain(
              matchId: 'a',
              matchLabel: 'OM – OL',
              previousPoints: 0,
              currentPoints: 5)
        ], oldBadge: 'AMATEUR', newBadge: 'CONNAISSEUR'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('NEW BADGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('review renders use actual reward widgets and fictitious gains',
      (tester) async {
    final output = Platform.environment['PRONO4_PREVIEW_DIR'];
    if (output == null) return;
    final priorShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = priorShadows);
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final kind in ['points', 'badge', 'defi']) {
      final boundary = GlobalKey();
      AppColors.lightMode = true;
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(
              locale: const Locale('fr'),
              supportedLocales: const [Locale('fr')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: ThemeData(
                  fontFamily: 'PreviewSans',
                  fontFamilyFallback: const ['PreviewEmoji'],
                  colorSchemeSeed: AppColors.lime),
              home: Scaffold(
                  body: Banner(
                      message: 'DÉMO',
                      textStyle: const TextStyle(
                          fontFamily: 'PreviewSans',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                      location: BannerLocation.topEnd,
                      child: kind == 'defi'
                          ? const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: ChallengeScoreCelebration(
                                      myPoints: 5,
                                      otherPoints: 3,
                                      otherName: 'Lina')))
                          : RewardCelebrationDialog(
                              gains: kind == 'badge'
                                  ? []
                                  : const [
                                      RecentPointsGain(
                                          matchId: 'a',
                                          matchLabel: 'Marseille – Lyon',
                                          previousPoints: 0,
                                          currentPoints: 5)
                                    ],
                              oldBadge: kind == 'badge' ? 'AMATEUR' : null,
                              newBadge:
                                  kind == 'badge' ? 'CONNAISSEUR' : null))))));
      await tester.pump();
      if (kind == 'badge') {
        await tester.runAsync(() => precacheImage(
            const AssetImage('assets/badges/fr/connaisseur.webp'),
            tester.element(find.byType(RewardCelebrationDialog))));
      }
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final picture = await render.toImage(pixelRatio: 1.5);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/animation-$kind.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    debugDisableShadows = priorShadows;
  });
}
