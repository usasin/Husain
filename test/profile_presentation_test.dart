import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:prono4/models/models.dart';
import 'package:prono4/providers/app_provider.dart';
import 'package:prono4/screens/profile_screen.dart';
import 'package:prono4/theme/app_theme.dart';
import 'package:prono4/theme/app_theme_controller.dart';
import 'package:prono4/widgets/admob_banner.dart';
import 'package:prono4/widgets/profile_progress_card.dart';

class _Database extends Fake implements FirebaseFirestore {}

class _GoogleInfo extends Fake implements auth.UserInfo {
  @override
  String get providerId => 'google.com';
}

class _User extends Fake implements auth.User {
  @override
  List<auth.UserInfo> get providerData => [_GoogleInfo()];
  @override
  String get uid => 'me';
}

class _Auth extends Fake implements auth.FirebaseAuth {
  final bool connected;
  _Auth(this.connected);
  @override
  auth.User? get currentUser => connected ? _User() : null;
}

class ProfileData extends AppProvider {
  ProfileData({bool connected = true, this.competitions = false})
      : super(firestore: _Database(), auth: _Auth(connected));
  final bool competitions;
  bool available = true;
  @override
  AppUser get currentUser =>
      const AppUser(id: 'me', name: "T-men Allez l'om", avatar: '⚽');
  @override
  bool get adminMode => true;
  @override
  bool hasUserRecordedStats(String uid) => available;
  @override
  int getUserPoints(String uid) => 188;
  @override
  int getUserResolvedVoteCount(String uid) => 111;
  @override
  int getUserCorrectCount(String uid) => 62;
  @override
  int getUserKnowledgeScore(String uid) => 54;
  @override
  String getAutoReputationBadge(String uid) => 'AMATEUR';
  @override
  List<FootballMatch> get matches => !competitions
      ? []
      : List.generate(
          28,
          (i) => FootballMatch(
              id: 'pl-$i',
              homeCode: 'ARS',
              awayCode: 'CHE',
              venue: '',
              competitionId: 'premier-league',
              date: '2026-10-18',
              time: '20:00',
              phase: MatchPhase.groupe));
  @override
  Map<String, String> get results => {for (final m in matches) m.id: 'HOME'};
  @override
  Map<String, String> get votes => {
        for (var i = 0; i < matches.length; i++)
          'me__pl-$i': i < 10 ? 'HOME' : 'AWAY'
      };
  @override
  Map<String, MatchScore> get scores =>
      {'pl-0': const MatchScore(homeScore: 2, awayScore: 1)};
  @override
  MatchScore? getExactPrediction(String id, {String? userId}) =>
      id == 'pl-0' ? const MatchScore(homeScore: 2, awayScore: 1) : null;
  @override
  List<Map<String, dynamic>> getUserRecentExactWins(String uid,
          {int limit = 3, Duration maxAge = const Duration(days: 7)}) =>
      [];
  @override
  bool get rankingDataLoading => false;
}

Widget host(Widget child,
        {bool dark = false,
        double scale = 1,
        String language = 'fr',
        ProfileData? provider}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(
              value: provider ?? ProfileData()),
          ChangeNotifierProvider(create: (_) => AppThemeController()),
        ],
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: Locale(language),
            supportedLocales: const [Locale('fr'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(
                fontFamily: 'PreviewSans',
                fontFamilyFallback: const ['PreviewEmoji'],
                brightness: dark ? Brightness.dark : Brightness.light,
                colorSchemeSeed: AppColors.lime),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: child));

Widget level(
        {String badge = 'AMATEUR',
        int score = 54,
        int played = 111,
        bool available = true}) =>
    Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: ProfileLevelCard(
                badge: badge,
                knowledge: score,
                played: played,
                available: available,
                onInfo: () {})));

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (!Platform.isWindows) return;
    for (final entry in {
      'PreviewSans': 'C:/Windows/Fonts/segoeui.ttf',
      'PreviewEmoji': 'C:/Windows/Fonts/seguiemj.ttf',
      for (final family in ['Inter', 'SpaceGrotesk'])
        for (final variant in ['regular', '500', '600', '700', '800', '900'])
          '${family}_$variant': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons':
          'C:/Users/ibabh/develop/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    }.entries) {
      final file = File(entry.value);
      if (!file.existsSync()) continue;
      final loader = FontLoader(entry.key)
        ..addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
      await loader.load();
    }
  });
  setUp(() => AppColors.lightMode = true);

  testWidgets(
      '54 remains AMATEUR with a threshold at 55 and no promise of one ranking point',
      (tester) async {
    await tester.pumpWidget(host(level()));
    await tester.pumpAndSettle();
    expect(find.text('54/100'), findsOneWidget);
    expect(find.text('AMATEUR'), findsOneWidget);
    expect(find.text('Prochain badge : CONNAISSEUR à 55/100'), findsOneWidget);
    expect(find.textContaining('Encore'), findsNothing);
    expect(find.textContaining('catastrophes'), findsNothing);
  });

  testWidgets(
      'all badge thresholds including expert are presented without modifying the badge',
      (tester) async {
    for (final data in [
      ('FOOTIX', 39, '40/100'),
      ('AMATEUR', 54, '55/100'),
      ('CONNAISSEUR', 69, '70/100'),
      ('CONFIRME', 84, '85/100'),
      ('EXPERT', 90, '')
    ]) {
      await tester.pumpWidget(host(level(badge: data.$1, score: data.$2)));
      await tester.pumpAndSettle();
      if (data.$3.isEmpty) {
        expect(find.text('Le plus haut badge atteint'), findsOneWidget);
        expect(find.textContaining('Prochain badge'), findsNothing);
      } else {
        expect(find.textContaining(data.$3), findsOneWidget);
      }
    }
  });

  testWidgets(
      'new players are not promised a badge before three completed predictions',
      (tester) async {
    await tester.pumpWidget(host(level(badge: 'FOOTIX', score: 50, played: 1)));
    expect(find.text('1/3 pronos terminés pour évaluer ton niveau'),
        findsOneWidget);
    expect(find.text('50/100'), findsNothing);
    expect(find.textContaining('Prochain badge'), findsNothing);
  });

  testWidgets('loading and zero history never invent a zero accuracy or level',
      (tester) async {
    await tester.pumpWidget(host(level(available: false)));
    expect(find.textContaining('Chargement du niveau'), findsOneWidget);
    expect(find.text('54/100'), findsNothing);
    await tester.pumpWidget(host(const Scaffold(
        body: ProfileStatisticsCard(
            points: 0, played: 0, correct: 0, available: true))));
    expect(find.text('0%'), findsNothing);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets(
      'ranking points, 54 recent level and 62 of 111 overall accuracy stay distinct',
      (tester) async {
    await tester.pumpWidget(host(const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileLevelCard), findsOneWidget);
    expect(find.text('54/100'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(ProfileStatisticsCard), 120);
    expect(find.text('188'), findsOneWidget);
    expect(find.text('56%'), findsOneWidget);
    expect(find.text('62 bons / 111 terminés'), findsOneWidget);
    expect(find.text('PROGRESSION'), findsNothing);
  });

  testWidgets('explanation and badge meanings are accessible on demand',
      (tester) async {
    await tester.pumpWidget(host(const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('30 derniers'), findsNothing);
    await tester.tap(find.byTooltip('Comprendre mon niveau'));
    await tester.pumpAndSettle();
    expect(find.text('Comment ça marche ?'), findsOneWidget);
    expect(find.textContaining('30 derniers'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mon parcours'), 160,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Mon parcours'), findsOneWidget);
    await tester.ensureVisible(find.text('EXPERT').last);
    await tester.tap(find.text('EXPERT').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('avenir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected account is compact but linking buttons stay available',
      (tester) async {
    await tester.pumpWidget(host(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Compte connecté'), 160);
    expect(find.text('Google connecté'), findsNothing);
    await tester.tap(find.text('Compte connecté'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continuer avec Apple'), 140);
    expect(find.text('Google connecté'), findsOneWidget);
    expect(find.text('Continuer avec Apple'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'profile and information fit 320 pixels at 180 percent text, dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.lightMode = !dark;
      await tester
          .pumpWidget(host(const ProfileScreen(), dark: dark, scale: 1.8));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Comprendre mon niveau'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('advertising label sits above the entire untouched creative',
      (tester) async {
    await tester.pumpWidget(host(const Scaffold(
        body: Align(
            alignment: Alignment.bottomCenter,
            child: AdvertisementFrame(
                child: SizedBox(
                    key: Key('creative'),
                    width: 320,
                    height: 50,
                    child: ColoredBox(color: Colors.green)))))));
    await tester.pumpAndSettle();
    expect(find.text('PUBLICITÉ'), findsOneWidget);
    expect(
        tester.getSize(find.byKey(const Key('creative'))), const Size(320, 50));
    expect(tester.getBottomLeft(find.text('PUBLICITÉ')).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('creative'))).dy));
  });

  testWidgets('English level labels keep the same thresholds', (tester) async {
    await tester.pumpWidget(host(level(), language: 'en'));
    expect(find.text('Next badge: CONNOISSEUR at 55/100'), findsOneWidget);
    expect(find.text('54/100'), findsOneWidget);
  });

  testWidgets(
      'anonymous access remains directly available without opening a connected-account panel',
      (tester) async {
    await tester.pumpWidget(
        host(const ProfileScreen(), provider: ProfileData(connected: false)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continuer avec Google'), 150);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Compte connecté'), findsNothing);
  });

  testWidgets('competition scores retain the screenshot values with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(const ProfileScreen(),
        scale: 1.8, provider: ProfileData(competitions: true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Premier League'), 150);
    expect(find.text('28 pronos · 36% bons'), findsOneWidget);
    expect(find.text('Niveau 39/100'), findsOneWidget);
    expect(find.text('🎯 1 score exact'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'nickname editing still opens, cancels and reopens without a Flutter error',
      (tester) async {
    await tester.pumpWidget(host(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Mon nouveau pseudo');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile review renders real widgets with demo data',
      (tester) async {
    final output = Platform.environment['PRONO4_PROFILE_PREVIEW_DIR'];
    if (output == null) return;
    tester.view.physicalSize = const Size(390, 1030);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dark in [false, true]) {
      AppColors.lightMode = !dark;
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: host(const ProfileScreen(),
              dark: dark, provider: ProfileData(competitions: true))));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/badges/fr/amateur.webp'),
          tester.element(find.byType(ProfileLevelCard))));
      await tester.pump();
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final picture = await render.toImage(pixelRatio: 1.5);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/profil-${dark ? 'sombre' : 'clair'}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      expect(tester.takeException(), isNull);
    }
  });
}
