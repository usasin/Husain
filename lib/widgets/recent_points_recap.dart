import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/points_reward_logic.dart';
import '../data/reward_celebration_logic.dart';
import '../providers/app_provider.dart';
import 'reward_celebration_dialog.dart';

/// Accueil épuré : AUCUN pavé permanent. Seulement une célébration ponctuelle
/// des vrais gains et/ou d'un nouveau badge, sans aucun appel Firebase ajouté.
class RecentPointsRecap extends StatefulWidget {
  final VoidCallback onRankingTap;
  final VoidCallback onProfileTap;
  const RecentPointsRecap({
    super.key,
    required this.onRankingTap,
    required this.onProfileTap,
  });

  @override
  State<RecentPointsRecap> createState() => _RecentPointsRecapState();
}

class _RecentPointsRecapState extends State<RecentPointsRecap>
    with WidgetsBindingObserver {
  static const _pointsKeyPrefix = 'prono4_points_seen_v1_';
  static const _badgeKeyPrefix = 'prono4_reward_seen_badge_v1_';
  static const _finishedStatuses = <String>{
    'FINISHED', 'AWARDED', 'FT', 'FULL_TIME',
  };

  Timer? _debounce;
  String? _lastSignature;
  String? _observedUid;
  bool _busy = false;
  bool _popupOpen = false;
  bool _pendingRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _lastSignature = null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    super.dispose();
  }

  Map<String, int> _earnedPoints(AppProvider provider, String uid) {
    final points = <String, int>{};
    final prefix = '${uid}__';
    for (final key in provider.votes.keys) {
      if (!key.startsWith(prefix)) continue;
      final matchId = key.substring(prefix.length);
      if (!provider.results.containsKey(matchId)) continue;
      final status = (provider.liveStatusFor(matchId) ?? '').toUpperCase();
      if (!_finishedStatuses.contains(status)) continue;
      points[matchId] = provider.getUserMatchPoints(uid, matchId);
    }
    return points;
  }

  Map<String, String> _matchNames(AppProvider provider, Iterable<String> ids) {
    final names = <String, String>{};
    for (final id in ids) {
      final match = provider.matchById(id);
      if (match == null) {
        names[id] = 'Match';
        continue;
      }
      final home = match.homeName?.trim().isNotEmpty == true
          ? match.homeName!
          : match.homeCode;
      final away = match.awayName?.trim().isNotEmpty == true
          ? match.awayName!
          : match.awayCode;
      names[id] = '$home – $away';
    }
    return names;
  }

  void _considerProvider(AppProvider provider) {
    // Si le joueur consulte une autre page, ne pas lancer de célébration.
    if (!TickerMode.of(context)) {
      _lastSignature = null;
      _debounce?.cancel();
      return;
    }
    final uid = provider.currentUser?.id;
    if (uid == null || uid.isEmpty) return;
    if (_observedUid != uid) {
      _observedUid = uid;
      _lastSignature = null;
      _debounce?.cancel();
    }
    if (!provider.loaded) return;
    // Attendre les votes du compte : évite de prendre un chargement vide
    // pour une disparition de points ou un changement de badge.
    if (!provider.votes.keys.any((key) => key.startsWith('${uid}__'))) return;

    final awarded = _earnedPoints(provider, uid);
    final badge = normalizedRewardBadge(provider.getAutoReputationBadge(uid));
    final sorted = awarded.keys.toList()..sort();
    final signature = '$uid|$badge|${sorted.map((id) => '$id:${awarded[id]}').join(',')}';
    if (_lastSignature == signature) return;
    _lastSignature = signature;
    final names = _matchNames(provider, awarded.keys);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      if (mounted) unawaited(_checkGains(uid, badge, awarded, names));
    });
  }

  Future<void> _checkGains(String uid, String currentBadge,
      Map<String, int> awarded, Map<String, String> names) async {
    if (!mounted || !TickerMode.of(context)) {
      _lastSignature = null;
      return;
    }
    if (_busy || _popupOpen) {
      _pendingRefresh = true;
      return;
    }
    _busy = true;
    try {
      // Le badge/compte peut encore changer pendant le chargement Firebase.
      final provider = context.read<AppProvider>();
      if (provider.currentUser?.id != uid ||
          normalizedRewardBadge(provider.getAutoReputationBadge(uid)) != currentBadge) {
        _lastSignature = null;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final pointsKey = '$_pointsKeyPrefix$uid';
      final badgeKey = '$_badgeKeyPrefix$uid';
      final savedRaw = prefs.getString(pointsKey);
      final previousBadge = prefs.getString(badgeKey);
      if (savedRaw == null) {
        // Première installation : pas de fausse célébration des anciens points
        // ni d'un badge acquis avant cette mise à jour.
        await prefs.setString(pointsKey, jsonEncode(awarded));
        await prefs.setString(badgeKey, currentBadge);
        return;
      }
      final seen = <String, int>{};
      final decoded = jsonDecode(savedRaw);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.value is num) {
            seen[entry.key.toString()] = (entry.value as num).toInt();
          }
        }
      }
      final gains = newPointsSinceLastVisit(
        seen: seen, awarded: awarded, matchLabels: names);
      final promoted = isBadgePromotion(previousBadge, currentBadge);
      if ((gains.isNotEmpty || promoted) && mounted && TickerMode.of(context)) {
        _popupOpen = true;
        try {
          await showGeneralDialog<void>(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Fermer la célébration',
            barrierColor: Colors.black.withValues(alpha: .78),
            transitionDuration: const Duration(milliseconds: 260),
            pageBuilder: (ctx, animation, secondaryAnimation) =>
                RewardCelebrationDialog(
                  gains: gains,
                  oldBadge: promoted ? previousBadge : null,
                  newBadge: promoted ? currentBadge : null,
                ),
            transitionBuilder: (ctx, animation, secondaryAnimation, child) =>
                FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .92, end: 1).animate(animation),
                    child: child,
                  ),
                ),
          );
        } finally {
          _popupOpen = false;
        }
      }
      // Stockage LOCAL, par compte, seulement après fermeture : aucune
      // attribution de points ni nouveau document Firestore.
      await prefs.setString(pointsKey, jsonEncode({...seen, ...awarded}));
      await prefs.setString(badgeKey, currentBadge);
    } catch (error) {
      debugPrint('PRONO4 reward recap (local only): $error');
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
      if (mounted) _considerProvider(provider);
    });
    return const SizedBox.shrink();
  }
}
