import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ad_service.dart';
import '../services/messaging_service.dart';
import '../services/notification_service.dart';

class PermissionsWelcomeGate extends StatefulWidget {
  const PermissionsWelcomeGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PermissionsWelcomeGate> createState() =>
      _PermissionsWelcomeGateState();
}

class _PermissionsWelcomeGateState extends State<PermissionsWelcomeGate> {
  static const String _completedKey = 'prono4_permissions_welcome_v2';
  static const String _notificationsChosenKey =
      'prono4_permissions_notifications_chosen_v2';

  bool _loaded = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _completed = true;
      });
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool completed = prefs.getBool(_completedKey) ?? false;

    if (!mounted) return;
    setState(() {
      _loaded = true;
      _completed = completed;
    });

    if (completed) {
      unawaited(AdService.instance.initialize());
      if (prefs.getBool(_notificationsChosenKey) == true) {
        unawaited(MessagingService.instance.initialize());
      }
    }
  }

  Future<void> _finish(bool notificationsChosen) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
    await prefs.setBool(_notificationsChosenKey, notificationsChosen);

    if (!mounted) return;
    setState(() => _completed = true);

    if (notificationsChosen) {
      unawaited(MessagingService.instance.initialize());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF101211),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF32C653),
          ),
        ),
      );
    }

    if (_completed) {
      return widget.child;
    }

    return PermissionsWelcomeScreen(onCompleted: _finish);
  }
}

class PermissionsWelcomeScreen extends StatefulWidget {
  const PermissionsWelcomeScreen({
    super.key,
    required this.onCompleted,
  });

  final Future<void> Function(bool notificationsChosen) onCompleted;

  @override
  State<PermissionsWelcomeScreen> createState() =>
      _PermissionsWelcomeScreenState();
}

class _PermissionsWelcomeScreenState extends State<PermissionsWelcomeScreen> {
  bool _notificationsChosen = false;
  bool _adsPrivacyChosen = false;
  bool _busyNotifications = false;
  bool _busyAds = false;
  bool _busyContinue = false;

  String _text(BuildContext context, String fr, String en) {
    final String language = Localizations.localeOf(context).languageCode;
    return language == 'en' ? en : fr;
  }

  Future<void> _chooseNotifications() async {
    if (_busyNotifications) return;

    setState(() => _busyNotifications = true);
    try {
      await NotificationService.instance.requestPermission();
      if (!mounted) return;
      setState(() => _notificationsChosen = true);
    } catch (error) {
      debugPrint('PRONO4 notification permission: $error');
    } finally {
      if (mounted) {
        setState(() => _busyNotifications = false);
      }
    }
  }

  Future<void> _chooseAdsPrivacy() async {
    if (_busyAds || _adsPrivacyChosen) return;

    setState(() => _busyAds = true);
    try {
      // IMPORTANT: AdService contient déjà l'appel ATT iOS. Ici il est lancé
      // uniquement après une action explicite de l'utilisateur, alors que
      // l'app est visible et active. ATT est résolu avant UMP/AdMob.
      await AdService.instance.initialize();
      if (!mounted) return;
      setState(() => _adsPrivacyChosen = true);
    } catch (error) {
      debugPrint('PRONO4 ads/privacy permission: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(
                context,
                'La demande de confidentialité n’a pas pu être terminée. Réessayez.',
                'The privacy request could not be completed. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyAds = false);
      }
    }
  }

  Future<void> _continue() async {
    if (_busyContinue) return;

    setState(() => _busyContinue = true);
    try {
      if (!_adsPrivacyChosen) {
        await _chooseAdsPrivacy();
      }
      if (!_adsPrivacyChosen) return;

      await widget.onCompleted(_notificationsChosen);
    } finally {
      if (mounted) {
        setState(() => _busyContinue = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF101211);
    const Color card = Color(0xFF191E1B);
    const Color text = Color(0xFFF7F8F5);
    const Color text2 = Color(0xFFC9CEC8);
    const Color lime = Color(0xFF32C653);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'PRONO4',
                          style: TextStyle(
                            color: text,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'FOOTIX OU EXPERT ? PROUVE-LE.',
                          style: TextStyle(
                            color: lime,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                _text(context, 'Avant de jouer', 'Before you play'),
                style: const TextStyle(
                  color: text,
                  fontSize: 31,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _text(
                  context,
                  'Choisissez simplement vos autorisations. Vous gardez le contrôle et PRONO4 reste accessible quel que soit votre choix.',
                  'Choose your permissions. You stay in control and PRONO4 remains available whatever you choose.',
                ),
                style: const TextStyle(
                  color: text2,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              _PermissionTile(
                icon: Icons.notifications_active_outlined,
                title: _text(context, 'Notifications', 'Notifications'),
                description: _text(
                  context,
                  'Défis, rappels de pronostics et résultats importants.',
                  'Challenges, prediction reminders and important results.',
                ),
                done: _notificationsChosen,
                busy: _busyNotifications,
                buttonText: _notificationsChosen
                    ? _text(context, 'Fait', 'Done')
                    : _text(context, 'Choisir', 'Choose'),
                onPressed: _notificationsChosen
                    ? null
                    : () {
                        unawaited(_chooseNotifications());
                      },
              ),
              const SizedBox(height: 12),
              _PermissionTile(
                icon: Icons.shield_outlined,
                title: _text(
                  context,
                  'Publicités & confidentialité',
                  'Ads & privacy',
                ),
                description: _text(
                  context,
                  'iOS affichera sa fenêtre officielle pour votre choix de suivi publicitaire. Accepter ou refuser ne bloque pas PRONO4.',
                  'iOS will show its official prompt for your advertising tracking choice. Accepting or declining does not block PRONO4.',
                ),
                done: _adsPrivacyChosen,
                busy: _busyAds,
                buttonText: _adsPrivacyChosen
                    ? _text(context, 'Fait', 'Done')
                    : _text(context, 'Choisir', 'Choose'),
                onPressed: _adsPrivacyChosen
                    ? null
                    : () {
                        unawaited(_chooseAdsPrivacy());
                      },
              ),
              const SizedBox(height: 12),
              _PermissionTile(
                icon: Icons.photo_camera_back_outlined,
                title: _text(context, 'Photos', 'Photos'),
                description: _text(
                  context,
                  'Demandé uniquement si vous choisissez une photo de profil.',
                  'Requested only if you choose a profile photo.',
                ),
                done: false,
                busy: false,
                buttonText: _text(context, 'À la demande', 'When needed'),
                onPressed: null,
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: lime,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _text(
                          context,
                          'Vos choix peuvent être modifiés plus tard dans les réglages iOS.',
                          'You can change your choices later in iOS Settings.',
                        ),
                        style: const TextStyle(
                          color: text2,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _busyContinue
                      ? null
                      : () {
                          unawaited(_continue());
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: lime,
                    foregroundColor: bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: _busyContinue
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: bg,
                          ),
                        )
                      : Text(
                          _text(
                            context,
                            'Continuer vers PRONO4',
                            'Continue to PRONO4',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.done,
    required this.busy,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool done;
  final bool busy;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const Color card = Color(0xFF191E1B);
    const Color text = Color(0xFFF7F8F5);
    const Color text2 = Color(0xFFC9CEC8);
    const Color lime = Color(0xFF32C653);
    const Color muted = Color(0xFF838B85);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done ? lime : const Color(0xFF2B312D),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3223),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: lime, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: text2,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 38,
            child: FilledButton.tonal(
              onPressed: busy ? null : onPressed,
              child: busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      buttonText,
                      style: TextStyle(
                        color: done ? lime : muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
