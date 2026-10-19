import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/points_reward_logic.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/reward_celebration_dialog.dart';

/// Démo locale : n'écrit NI les points NI les badges NI SharedPreferences.
/// Page seulement affichée aux profils avec users/{uid}.isAdmin == true.
class AdminRewardPreviewScreen extends StatelessWidget {
  const AdminRewardPreviewScreen({super.key});

  Future<void> _preview(BuildContext context, {
    required int total,
    required int matches,
    String? from,
    String? to,
  }) async {
    final provider = context.read<AppProvider>();
    if (!provider.adminMode || !(await provider.refreshAdminAccess())) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accès administrateur requis.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final gains = <RecentPointsGain>[];
    // Le montant est une simulation, jamais une écriture sur un compte.
    if (total > 0 && matches > 0) {
      final perMatch = total ~/ matches;
      final remainder = total % matches;
      for (var i = 0; i < matches; i++) {
        gains.add(RecentPointsGain(
          matchId: 'test_admin_$i',
          matchLabel: 'Match de démonstration ${i + 1}',
          previousPoints: 0,
          currentPoints: perMatch + (i < remainder ? 1 : 0),
        ));
      }
    }
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer le test',
      barrierColor: Colors.black.withValues(alpha: .78),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => RewardCelebrationDialog(
        gains: gains,
        oldBadge: from,
        newBadge: to,
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .92, end: 1).animate(animation),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AppProvider>().adminMode) {
      return const Scaffold(body: Center(child: Text('Accès réservé à l’administration.')));
    }
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(title: const Text('TESTER LES ANIMATIONS')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('MODE DÉMONSTRATION',
          style: TextStyle(color: AppColors.lime, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Teste les animations immédiatement, même sans match. Aucun point ni badge réel n’est modifié.',
          style: TextStyle(color: AppColors.text2, height: 1.4)),
        const SizedBox(height: 22),
        _button(context, '🏆  +3 points · 1 match',
          () => _preview(context, total: 3, matches: 1)),
        _button(context, '⚡  +24 points · 8 matchs',
          () => _preview(context, total: 24, matches: 8)),
        _button(context, '🛡️  FOOTIX → AMATEUR',
          () => _preview(context, total: 3, matches: 1, from: 'FOOTIX', to: 'AMATEUR')),
        _button(context, '👑  AMATEUR → CONNAISSEUR',
          () => _preview(context, total: 0, matches: 0, from: 'AMATEUR', to: 'CONNAISSEUR')),
        const SizedBox(height: 20),
        Text('Seul le vrai calcul des résultats déclenche ensuite les récompenses des joueurs.',
          style: TextStyle(color: AppColors.text2, fontSize: 12)),
      ]),
    );
  }

  Widget _button(BuildContext context, String title, VoidCallback onTap) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.bg0,
        ),
        child: Text(title, textAlign: TextAlign.center),
      ));
}
