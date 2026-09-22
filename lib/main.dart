import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/ad_service.dart';
import 'services/messaging_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_controller.dart';
import 'l10n/app_locale.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Sur Android, un message 'notification' s'affiche automatiquement dans la
  // barre systeme quand l'app est en arriere-plan : rien a faire ici.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppColors.lightMode = false;

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg1,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // iPhone + iPad : conserve les orientations déclarées côté iOS.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    unawaited(SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
  } else {
    unawaited(SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]));
  }

  // Affiche immédiatement Flutter : Firebase ne peut plus laisser iOS bloqué
  // sur le splash natif pendant son initialisation.
  runApp(const _Prono4Bootstrap());
}

class _Prono4Bootstrap extends StatefulWidget {
  const _Prono4Bootstrap();

  @override
  State<_Prono4Bootstrap> createState() => _Prono4BootstrapState();
}

class _Prono4BootstrapState extends State<_Prono4Bootstrap> {
  bool _starting = true;
  bool _ready = false;
  bool _hasStartupError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // Sur iOS, Codemagic fournit et valide GoogleService-Info.plist.
        await Firebase.initializeApp().timeout(const Duration(seconds: 12));
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 12));
      }

      await Future.wait([
        initializeDateFormatting('fr_FR', null),
        initializeDateFormatting('en_US', null),
      ]).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      setState(() {
        _ready = true;
        _starting = false;
        _hasStartupError = false;
      });

      // Services optionnels : ils démarrent après l'interface et ne bloquent pas
      // l'ouverture de PRONO4.
      unawaited(_initializeOptionalServices());
    } catch (error, stackTrace) {
      debugPrint('PRONO4 startup error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _starting = false;
        _hasStartupError = true;
      });
    }
  }

  Future<void> _initializeOptionalServices() async {
    try {
      await NotificationService.instance.initialize();
    } catch (error) {
      debugPrint('Notification init non bloquante: $error');
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await MessagingService.instance.initialize();
    } catch (error) {
      debugPrint('Messaging init non bloquante: $error');
    }

    try {
      await AdService.instance.initialize();
    } catch (error) {
      debugPrint('AdMob init non bloquante: $error');
    }
  }

  void _retry() {
    if (_starting) return;
    setState(() {
      _starting = true;
      _hasStartupError = false;
    });
    unawaited(_initialize());
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()..load()),
          ChangeNotifierProvider(create: (_) => AppLocaleController()..load()),
          ChangeNotifierProvider(create: (_) => AppThemeController()..load()),
        ],
        child: const Prono4App(),
      );
    }

    return MaterialApp(
      title: 'PRONO4',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF101211),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 124,
                      height: 124,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'PRONO4',
                    style: TextStyle(
                      color: Color(0xFFF7F8F5),
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!_hasStartupError) ...[
                    const CircularProgressIndicator(color: AppColors.lime),
                    const SizedBox(height: 14),
                    const Text(
                      'Chargement de PRONO4…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF7F8F5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Connexion aux services et mise à jour des matchs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFC9CEC8),
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Impossible de charger les services. Vérifiez votre connexion puis réessayez.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFC9CEC8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _starting ? null : _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Prono4App extends StatelessWidget {
  const Prono4App({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<AppLocaleController>();
    final themeController = context.watch<AppThemeController>();
    final brightness = themeController.resolvedBrightness();
    final isLight = brightness == Brightness.light;
    AppColors.lightMode = isLight;
    return MaterialApp(
      locale: localeController.locale,
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'PRONO4 — Le foot se pronostique en équipe',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.mode,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: AppColors.bg1,
          systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _minimumSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1900)).then((_) {
      if (mounted) setState(() => _minimumSplashElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    // Le splash Android natif reste statique par définition. Ce délai minimum
    // rend ensuite l'animation PRONO4 Flutter réellement visible.
    if (!prov.loaded || !_minimumSplashElapsed) {
      return const _Prono4LoadingSplash();
    }

    if (prov.currentUser == null) {
      return const OnboardingScreen();
    }

    return const MainShell();
  }
}

class _Prono4LoadingSplash extends StatefulWidget {
  const _Prono4LoadingSplash();

  @override
  State<_Prono4LoadingSplash> createState() => _Prono4LoadingSplashState();
}

class _Prono4LoadingSplashState extends State<_Prono4LoadingSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final glow = .18 + (_controller.value * .28);
              final scale = .97 + (_controller.value * .035);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lime.withOpacity(glow),
                            blurRadius: 34,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                   Text(
                    'PRONO4',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('Le foot se pronostique en équipe.', 'Football predictions are better as a team.'),
                    style: TextStyle(
                      color: AppColors.text2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('FOOTIX OU EXPERT ? PROUVE-LE.', 'FOOTIX OR EXPERT? PROVE IT.'),
                    style: const TextStyle(
                      color: AppColors.lime,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr(
                      'Mise à jour des matchs et des scores…',
                      'Updating matches and scores…',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.tr(
                      'Cela peut prendre quelques secondes.',
                      'This may take a few seconds.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text2,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child:  LinearProgressIndicator(
                        minHeight: 3,
                        color: AppColors.lime,
                        backgroundColor: AppColors.bg3,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
