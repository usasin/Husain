import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/reward_checkpoint.dart';
import '../data/reward_celebration_logic.dart';
import '../providers/app_provider.dart';
import 'reward_celebration_dialog.dart';

/// Single listener beside MainShell, outside lazy home slivers and tab tickers.
/// Remains mounted on pushed challenge pages. Presentation only: no Firebase
/// requests, no attribution of points, no change to scores or rankings.
class RecentPointsRecap extends StatefulWidget {
  final VoidCallback? onRankingTap;
  final VoidCallback? onProfileTap;
  const RecentPointsRecap({super.key, this.onRankingTap, this.onProfileTap});

  @override
  State<RecentPointsRecap> createState() => _RecentPointsRecapState();
}

class _RecentPointsRecapState extends State<RecentPointsRecap>
    with WidgetsBindingObserver {
  static const _pointsKeyPrefix = 'prono4_points_seen_v1_';
  static const _badgeKeyPrefix = 'prono4_reward_seen_badge_v1_';
  static const _presentedKeyPrefix = 'prono4_reward_presented_v2_';
  static const _finishedStatuses = {'FINISHED', 'AWARDED', 'FT', 'FULL_TIME'};
  Timer? _debounce;
  String? _lastSignature;
  bool _busy = false;
  bool _pendingRefresh = false;
  late bool _foreground;
  RawDialogRoute<void>? _dialogRoute;
  bool _interrupted = false;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _interruptDialog() {
    final route = _dialogRoute;
    if (route == null) return;
    _interrupted = true;
    // Remove only our own route, never a form/page opened above it.
    if (route.isActive) route.navigator?.removeRoute(route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _debounce?.cancel();
    _lastSignature = null;
    if (!_foreground) {
      _interruptDialog();
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _interrupted = true;
    super.dispose();
  }

  void _considerProvider(AppProvider provider) {
    final uid = provider.currentUser?.id;
    if (!_foreground ||
        uid == null ||
        uid.isEmpty ||
        !provider.rewardDataReady) {
      _lastSignature = null;
      _debounce?.cancel();
      return;
    }
    final awarded = <String, int>{};
    final names = <String, String>{};
    final kickoffs = <String, DateTime>{};
    final prefix = '${uid}__';
    for (final key in provider.votes.keys) {
      if (!key.startsWith(prefix)) continue;
      final id = key.substring(prefix.length);
      if (!provider.results.containsKey(id) ||
          !_finishedStatuses
              .contains((provider.liveStatusFor(id) ?? '').toUpperCase())) {
        continue;
      }
      awarded[id] = provider.getUserMatchPoints(uid, id);
      final match = provider.matchById(id);
      if (match != null) {
        names[id] =
            '${match.homeName ?? match.homeCode} – ${match.awayName ?? match.awayCode}';
        kickoffs[id] = match.dateTime;
      }
    }
    final badge = normalizedRewardBadge(provider.getAutoReputationBadge(uid));
    final sorted = awarded.keys.toList()..sort();
    final signature =
        '$uid|$badge|${sorted.map((id) => '$id:${awarded[id]}').join(',')}';
    if (_lastSignature == signature) return;
    _lastSignature = signature;
    if (_busy) {
      _pendingRefresh = true;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      unawaited(_checkGains(uid, badge, awarded, names, kickoffs));
    });
  }

  bool _sameAccount(String uid) =>
      mounted &&
      _foreground &&
      context.read<AppProvider>().currentUser?.id == uid;

  bool _stillCurrent(String uid, String badge) =>
      _sameAccount(uid) &&
      context.read<AppProvider>().rewardDataReady &&
      normalizedRewardBadge(
              context.read<AppProvider>().getAutoReputationBadge(uid)) ==
          badge;

  Future<void> _checkGains(String uid, String badge, Map<String, int> awarded,
      Map<String, String> names, Map<String, DateTime> kickoffs) async {
    if (!_stillCurrent(uid, badge)) {
      _lastSignature = null;
      return;
    }
    if (_busy) {
      _pendingRefresh = true;
      return;
    }
    _busy = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_stillCurrent(uid, badge)) return;
      final pointsKey = '$_pointsKeyPrefix$uid';
      final badgeKey = '$_badgeKeyPrefix$uid';
      final presentedKey = '$_presentedKeyPrefix$uid';
      final seen = readRewardCheckpoint(prefs.getString(pointsKey));
      final previouslyPresented = prefs.getBool(presentedKey) == true;
      final previousBadge = prefs.getString(badgeKey);
      final gains = pendingRewardGains(
          // Older versions saved points even when no celebration was shown.
          // One recent recap repairs that omission without adding any points.
          seen: previouslyPresented ? seen : null,
          awarded: awarded,
          labels: names,
          kickoffs: kickoffs,
          now: DateTime.now());
      final promoted = isBadgePromotion(previousBadge, badge);
      var badgeShown = !promoted;
      if (gains.isNotEmpty || promoted) {
        _interrupted = false;
        final route = RawDialogRoute<void>(
          settings: RouteSettings(name: 'prono4-reward', arguments: uid),
          barrierDismissible: true,
          barrierLabel: 'Fermer la célébration',
          barrierColor: Colors.black.withValues(alpha: .78),
          transitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (ctx, animation, secondaryAnimation) =>
              RewardCelebrationDialog(
                  gains: gains,
                  recap: !previouslyPresented && seen != null,
                  oldBadge: promoted ? previousBadge : null,
                  newBadge: promoted ? badge : null,
                  onBadgeShown: () => badgeShown = true),
          transitionBuilder: (ctx, animation, secondaryAnimation, child) =>
              FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                      scale:
                          Tween<double>(begin: .92, end: 1).animate(animation),
                      child: child)),
        );
        _dialogRoute = route;
        try {
          await navigator.push(route);
        } finally {
          _dialogRoute = null;
        }
        if (_interrupted || !_sameAccount(uid)) return;
      }
      if (!_sameAccount(uid)) return;
      await prefs.setString(
          pointsKey, jsonEncode(acknowledgedRewardPoints(seen, awarded)));
      if (badgeShown) await prefs.setString(badgeKey, badge);
      await prefs.setBool(presentedKey, true);
    } catch (error) {
      debugPrint('PRONO4 reward recap (local only): $error');
      _lastSignature = null;
    } finally {
      _busy = false;
      if (_pendingRefresh && mounted) {
        _pendingRefresh = false;
        setState(() => _lastSignature = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_dialogRoute != null &&
          _dialogRoute!.settings.arguments != provider.currentUser?.id) {
        _interruptDialog();
      }
      _considerProvider(provider);
    });
    return const SizedBox.shrink();
  }
}
