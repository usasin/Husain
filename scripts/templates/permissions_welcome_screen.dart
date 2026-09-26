import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_locale.dart';
import '../services/ad_service.dart';
import '../services/messaging_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class PermissionsWelcomeGate extends StatefulWidget {
  const PermissionsWelcomeGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PermissionsWelcomeGate> createState() => _PermissionsWelcomeGateState();
}

class _PermissionsWelcomeGateState extends State<PermissionsWelcomeGate> {
  static const _completedKey = 'prono4_permissions_welcome_v1';
  static const _notificationsChosenKey =
      'prono4_permissions_notifications_chosen_v1';

  bool _loaded = false;
  bool _completed = false;
  bool _servicesStarted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _completed = true;
        });
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_completedKey) ?? false;

    if (!mounted) return;
    setState(() {
      _loaded = true;
      _completed = completed;
    });

    if (completed) {
      unawaited(_startDeferredServices());
    }
  }

  Future<void> _startDeferredServices() async {
    if (_servicesStarted) return;
    _servicesStarted = true;

    try {
      await AdService.instance.initialize();
    } catch (error) {
      debugPrint('AdMob init après autorisations: $error');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_notificationsChosenKey) == true) {
        await MessagingService.instance.initialize();
      }
    } catch (error) {
      debugPrint('Messaging init après autorisations: $error');
    }
  }

  void _finish() {
    if (!mounted) return;
    setState(() => _completed = true);
    unawaited(_startDeferredServices());
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppColors.bg0,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.lime),
        ),
      );
    }

    if (_completed) return widget.child;

    return PermissionsWelcomeScreen(onCompleted: _finish);
  }
}

class PermissionsWelcomeScreen extends StatefulWidget {
  const PermissionsWelcomeScreen({
    super.key,
    required this.onCompleted,
  });

  final VoidCallback onCompleted;

  @override
  State<PermissionsWelcomeScreen> createState() =>
      _PermissionsWelcomeScreenState();
}

class _PermissionsWelcomeScreenState extends State<PermissionsWelcomeScreen> {
  static const _completedKey = 'prono4_permissions_welcome_v1';
  static const _notificationsChosenKey =
      'prono4_permissions_notifications_chosen_v1';

  bool _notificationsChosen = false;
  bool _trackingChosen = false;
  bool _busyNotifications = false;
  bool _busyTracking = false;
  bool _busyContinue = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLocalState());
  }

  Future<void> _restoreLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsChosen =
          prefs.getBool(_notificationsChosenKey) ?? false;
    });
  }

  Future<void> _chooseNotifications() async {
    if (_busyNotifications) return;
    setState(() => _busyNotifications = true);

    try {
      await NotificationService.instance.requestPermission();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsChosenKey, true);
      if (mounted) setState(() => _notificationsChosen = true);
    } catch (error) {
      debugPrint('Choix notifications: $error');
    } finally {
      if (mounted) setState(() => _busyNotifications = false);
    }
  }

  Future<bool> _waitUntilIosIsActive() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return true;
    for (var attempt = 0; attempt < 40; attempt++) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<bool> _chooseTracking() async {
    if (_busyTracking) return _trackingChosen;
    setState(() => _busyTracking = true);

    var resolved = false;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final isActive = await _waitUntilIosIsActive();
        if (isActive) {
          var status =
              await AppTrackingTransparency.trackingAuthorizationStatus;
          if (status == TrackingStatus.notDetermined) {
            status =
                await AppTrackingTransparency.requestTrackingAuthorization();
          }
          resolved = status != TrackingStatus.notDetermined;
        }
      } else {
        resolved = true;
      }

      if (mounted && resolved) {
        setState(() => _trackingChosen = true);
      }
    } catch (error) {
      debugPrint('Choix ATT: $error');
    } finally {
      if (mounted) setState(() => _busyTracking = false);
    }

    if (!resolved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'La demande iOS n’a pas pu s’afficher. Réessayez dans un instant.',
              'The iOS permission request could not be shown. Please try again.',
            ),
          ),
        ),
      );
    }
    return resolved;
  }

  Future<void> _continue() async {
    if (_busyContinue) return;
    setState(() => _busyContinue = true);

    try {
      var trackingResolved = _trackingChosen;
      if (!trackingResolved) {
        trackingResolved = await _chooseTracking();
      }
      if (!trackingResolved) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedKey, true);

      unawaited(AdService.instance.initialize());

      if (_notificationsChosen) {
        unawaited(MessagingService.instance.initialize());
      }

      widget.onCompleted();
    } finally {
      if (mounted) setState(() => _busyContinue = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;

    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppColors.logoPlate,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.logoPlateBorder),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PRONO4',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tr(
                                  'Vos choix, simplement.',
                                  'Your choices, simply.',
                                ),
                                style: TextStyle(
                                  color: AppColors.lime,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      tr('Avant de jouer', 'Before you play'),
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 31,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        'Choisissez vos autorisations. Vous gardez le contrôle et PRONO4 fonctionne même si vous refusez le suivi.',
                        'Choose your permissions. You stay in control, and PRONO4 works even if you decline tracking.',
                      ),
                      style: TextStyle(
                        color: AppColors.text2,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PermissionCard(
                      icon: Icons.notifications_active_outlined,
                      title: tr('Notifications', 'Notifications'),
                      description: tr(
                        'Défis, rappels de pronostics et résultats importants.',
                        'Challenges, prediction reminders and important results.',
                      ),
                      status: _notificationsChosen
                          ? tr('Choix enregistré', 'Choice saved')
                          : tr('Facultatif', 'Optional'),
                      done: _notificationsChosen,
                      busy: _busyNotifications,
                      buttonLabel: _notificationsChosen
                          ? tr('Fait', 'Done')
                          : tr('Choisir', 'Choose'),
                      onPressed:
                          _notificationsChosen ? null : _chooseNotifications,
                    ),
                    const SizedBox(height: 12),
                    _PermissionCard(
                      icon: Icons.shield_outlined,
                      title: tr(
                        'Publicités & confidentialité',
                        'Ads & privacy',
                      ),
                      description: tr(
                        'iOS vous demandera votre choix concernant le suivi pour les publicités. Accepter ou refuser ne bloque jamais PRONO4.',
                        'iOS will ask for your tracking choice for ads. Accepting or declining never blocks PRONO4.',
                      ),
                      status: _trackingChosen
                          ? tr('Choix enregistré', 'Choice saved')
                          : tr('Choix iOS', 'iOS choice'),
                      done: _trackingChosen,
                      busy: _busyTracking,
                      buttonLabel: _trackingChosen
                          ? tr('Fait', 'Done')
                          : tr('Choisir', 'Choose'),
                      onPressed: _trackingChosen ? null : _chooseTracking,
                    ),
                    const SizedBox(height: 12),
                    _PermissionCard(
                      icon: Icons.photo_camera_back_outlined,
                      title: tr('Photos', 'Photos'),
                      description: tr(
                        'Demandé uniquement lorsque vous choisissez une photo de profil.',
                        'Requested only when you choose a profile photo.',
                      ),
                      status: tr('À la demande', 'When needed'),
                      done: false,
                      busy: false,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.overlayBase.withOpacity(.06),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.lime,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr(
                                'Aucune autorisation n’est obligatoire pour jouer. Vos choix restent modifiables dans les réglages iOS.',
                                'No permission is required to play. You can change your choices later in iOS Settings.',
                              ),
                              style: TextStyle(
                                color: AppColors.text2,
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busyContinue ? null : _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: const Color(0xFF101211),
                        minimumSize: const Size.fromHeight(56),
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
                                color: Color(0xFF101211),
                              ),
                            )
                          : Text(
                              tr(
                                'Continuer vers PRONO4',
                                'Continue to PRONO4',
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        'Si vous n’avez pas encore choisi pour la confidentialité, iOS affichera sa fenêtre officielle en appuyant sur Continuer.',
                        'If you have not chosen your privacy setting yet, iOS will show its official prompt when you tap Continue.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.grey,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.done,
    required this.busy,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;
  final bool done;
  final bool busy;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done
              ? AppColors.lime.withOpacity(.40)
              : AppColors.overlayBase.withOpacity(.07),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            spreadRadius: -13,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.lime.withOpacity(.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.lime, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.text2,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: done ? AppColors.lime : AppColors.grey,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: TextStyle(
                        color: done ? AppColors.lime : AppColors.grey,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (buttonLabel != null) ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 38,
              child: FilledButton.tonal(
                onPressed: busy ? null : onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        buttonLabel!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
