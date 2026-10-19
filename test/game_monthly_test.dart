import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../lib/data/game_month.dart';
import '../lib/services/game_monthly_repository.dart';
import '../lib/screens/game_monthly_history_screen.dart';
import '../lib/theme/app_theme.dart';
import '../lib/widgets/game_center_dashboard.dart';

const month = GameMonth(2026, 10);
const people = [
  GameMonthlyPlayer(id: 'a', name: 'Lina', avatar: '⚽', points: 68, votes: 21),
  GameMonthlyPlayer(
      id: 'b', name: 'Karim', avatar: '🏆', points: 61, votes: 19),
  GameMonthlyPlayer(id: 'me', name: 'Toi', avatar: '🎯', points: 48, votes: 18),
];
const ranking = GameMonthlySnapshot(month: month, players: people);

class Source implements GameMonthlySource {
  int reads = 0;
  bool fail = false;
  @override
  Stream<GameMonthlySnapshot?> watch(GameMonth month) => Stream.value(ranking);
  @override
  Future<List<GameMonthlySnapshot>> history(GameMonth current,
      {bool refresh = false}) async {
    reads++;
    if (fail) throw StateError('offline');
    return const [
      GameMonthlySnapshot(month: GameMonth(2026, 9), players: people)
    ];
  }
}

Widget app(Widget body, {bool dark = false, double scale = 1}) => MaterialApp(
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'PreviewSans',
        fontFamilyFallback: const ['PreviewEmoji'],
        brightness: dark ? Brightness.dark : Brightness.light,
        colorSchemeSeed: AppColors.lime),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: body);

Future<void> size(WidgetTester tester, double width,
    [double height = 960]) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget card({GameMonthlySnapshot? snapshot = ranking, VoidCallback? history}) =>
    GameMonthlyCard(
        month: month,
        snapshot: snapshot,
        userId: 'me',
        loading: false,
        hasError: false,
        now: DateTime.utc(2026, 10, 19, 7),
        onHistory: history ?? () {},
        onStandings: () {});

void main() {
  setUpAll(() async {
    if (Platform.isWindows) {
      final icons = File(
          'C:/Users/ibabh/develop/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
      if (icons.existsSync()) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(icons.readAsBytes().then((b) => ByteData.sublistView(b)));
        await loader.load();
      }
      for (final entry in {
        'PreviewSans': 'segoeui.ttf',
        'PreviewEmoji': 'seguiemj.ttf'
      }.entries) {
        final file = File('C:/Windows/Fonts/${entry.value}');
        if (file.existsSync()) {
          final loader = FontLoader(entry.key)
            ..addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
          await loader.load();
        }
      }
    }
  });
  test(
      'Paris months have identical boundaries to server, including DST and leap day',
      () {
    tzdata.initializeTimeZones();
    final original = tz.local;
    addTearDown(() => tz.setLocalLocation(original));
    tz.setLocalLocation(tz.getLocation('America/New_York'));
    expect(GameMonth.at(DateTime.parse('2026-09-30T21:59:59Z')).key, '2026-09');
    expect(GameMonth.at(DateTime.parse('2026-09-30T22:00:00Z')).key, '2026-10');
    expect(month.start, DateTime.parse('2026-09-30T22:00:00Z'));
    expect(month.end, DateTime.parse('2026-10-31T23:00:00Z'));
    expect(const GameMonth(2028, 2).days, 29);
    expect(const GameMonth(2027, 1).previous.key, '2026-12');
    expect(tz.local.name, 'America/New_York',
        reason: 'Monthly calendar must preserve notification time zone');
  });
  testWidgets(
      'streak is labelled separately and XP explanation stays behind the info button',
      (tester) async {
    await size(tester, 390);
    AppColors.lightMode = true;
    await tester.pumpWidget(app(const Scaffold(
        body: SingleChildScrollView(
            child: GameProgressHeader(
                level: 7,
                xp: 3075,
                xpInLevel: 75,
                streak: 7,
                playedToday: true,
                canPlayToday: true)))));
    expect(find.text('Série · 7 jours joués'), findsOneWidget);
    expect(find.text('75 / 500 XP'), findsOneWidget);
    expect(find.textContaining('Prono : +10'), findsNothing);
    await tester.tap(find.byTooltip('Comment gagner des XP'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Prono : +10'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'missing server snapshot never invents a global first place or uses the old season',
      (tester) async {
    await size(tester, 390);
    await tester.pumpWidget(app(Scaffold(body: card(snapshot: null))));
    expect(find.text('#1'), findsNothing);
    expect(find.text('Rang —'), findsOneWidget);
    expect(find.textContaining('en préparation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'history opens, retains prior-month rows and never reloads on rebuild',
      (tester) async {
    final source = Source();
    await size(tester, 390);
    AppColors.lightMode = true;
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
            body: card(
                history: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => GameMonthlyHistoryScreen(
                            source: source,
                            current: month,
                            userId: 'me'))))))));
    await tester.tap(find.byTooltip('Historique des mois'));
    await tester.pumpAndSettle();
    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(source.reads, 1);
    await tester.tap(find.text('Voir ce mois'));
    await tester.pumpAndSettle();
    expect(find.text('Lina'), findsOneWidget);
    expect(find.text('68'), findsOneWidget);
    expect(source.reads, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('history has an explicit retry after network failure',
      (tester) async {
    final source = Source()..fail = true;
    await size(tester, 390);
    await tester.pumpWidget(app(GameMonthlyHistoryScreen(
        source: source, current: month, userId: 'me')));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
    source.fail = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(source.reads, 2);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true])
    testWidgets(
        'dashboard handles 320 pixels and large accessible text (dark=$dark)',
        (tester) async {
      await size(tester, 320, 720);
      AppColors.lightMode = !dark;
      await tester.pumpWidget(app(
          Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        const GameProgressHeader(
                            level: 17,
                            xp: 8075,
                            xpInLevel: 75,
                            streak: 127,
                            playedToday: false,
                            canPlayToday: true),
                        const SizedBox(height: 12),
                        card()
                      ])))),
          dark: dark,
          scale: 1.8));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  for (final dark in [false, true])
    testWidgets('render review preview (dark=$dark)', (tester) async {
      await size(tester, 390, 1050);
      AppColors.lightMode = !dark;
      await tester.pumpWidget(app(
          RepaintBoundary(
              key: const Key('preview'),
              child: Scaffold(
                  backgroundColor: AppColors.bg0,
                  appBar: AppBar(
                      title: const Text('Centre de jeu'),
                      backgroundColor: AppColors.bg0,
                      leading: const Icon(Icons.arrow_back_rounded)),
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('APERÇU · DONNÉES DE DÉMONSTRATION',
                                    style: TextStyle(
                                        fontSize: 9, color: AppColors.text2)),
                                const SizedBox(height: 12),
                                const GameProgressHeader(
                                    level: 7,
                                    xp: 3075,
                                    xpInLevel: 75,
                                    streak: 7,
                                    playedToday: true,
                                    canPlayToday: true),
                                const SizedBox(height: 18),
                                Text('Aujourd’hui',
                                    style: TextStyle(
                                        fontSize: 17,
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 10),
                                const GameDashboardCard(
                                    child: Column(children: [
                                  GameMissionTile(
                                      title: '3 pronos du jour',
                                      icon: Icons.how_to_vote_rounded,
                                      progress: 3,
                                      target: 3,
                                      done: true),
                                  Divider(height: 20),
                                  GameMissionTile(
                                      title: 'Un score exact',
                                      icon: Icons.gps_fixed_rounded,
                                      progress: 0,
                                      target: 1,
                                      done: false),
                                ])),
                                const SizedBox(height: 18),
                                card(),
                              ]))))),
          dark: dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final folder = Platform.environment['PRONO4_PREVIEW_DIR'];
      if (folder != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('preview')));
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$folder/centre-jeu-${dark ? 'sombre' : 'clair'}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  testWidgets('render the usable historical podium screen for review',
      (tester) async {
    await size(tester, 390, 800);
    AppColors.lightMode = true;
    await tester.pumpWidget(app(RepaintBoundary(
        key: const Key('historyPreview'),
        child: Column(children: [
          const Material(
              child: SafeArea(
                  child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('APERÇU · DONNÉES DE DÉMONSTRATION',
                          style: TextStyle(fontSize: 9))))),
          Expanded(
              child: GameMonthlyHistoryScreen(
                  source: Source(), current: month, userId: 'me')),
        ]))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final folder = Platform.environment['PRONO4_PREVIEW_DIR'];
    if (folder != null) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('historyPreview')));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$folder/centre-jeu-historique.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
