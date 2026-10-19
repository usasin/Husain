import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
import '../screens/game_center_screen.dart';
import '../theme/app_theme.dart';
import 'prono4_art.dart';

/// BUILD87 — accueil allégé.
/// Le badge/progression reste dans CompetitionHomeScreen.
/// Ici, on garde uniquement l'accès principal au jeu/défis + un état discret.
class GameLoopCard extends StatefulWidget {
  const GameLoopCard({super.key});

  @override
  State<GameLoopCard> createState() => _GameLoopCardState();
}

class _GameLoopCardState extends State<GameLoopCard> {
  String? _loadedUid;
  Future<QuerySnapshot<Map<String, dynamic>>>? _challengeFuture;

  Future<QuerySnapshot<Map<String, dynamic>>> _loadChallenges(String uid) {
    if (_challengeFuture == null || _loadedUid != uid) {
      _loadedUid = uid;
      // Une seule lecture légère à l'ouverture de l'accueil, pas de listener
      // permanent et aucun recalcul serveur déclenché par l'utilisateur.
      _challengeFuture = FirebaseFirestore.instance
          .collection('gameChallenges')
          .where('participants', arrayContains: uid)
          .limit(20)
          .get();
    }
    return _challengeFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final user = prov.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _quickAction(
                context,
                label: context.tr('MODE DÉFIS', 'CHALLENGES'),
                image: 'duel',
                primary: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) =>
                      const GameCenterScreen(challengesOnly: true)),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              flex: 2,
              child: _quickAction(
                context,
                label: context.tr('MES MISSIONS', 'MISSIONS'),
                image: 'etoile',
                primary: false,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GameCenterScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: _loadChallenges(user.id),
          builder: (context, snapshot) {
            String label;
            IconData icon;
            Color color;

            if (snapshot.connectionState == ConnectionState.waiting) {
              label = context.tr('Vérification des défis…', 'Checking challenges…');
              icon = Icons.hourglass_top_rounded;
              color = AppColors.grey;
            } else if (snapshot.hasError) {
              label = context.tr('Voir mes défis', 'View my challenges');
              icon = Icons.sports_kabaddi_rounded;
              color = AppColors.text2;
            } else {
              final docs = snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final pending = docs.where((doc) {
                final data = doc.data();
                return (data['status'] ?? 'pending').toString() == 'pending';
              }).length;

              if (pending == 0) {
                label = context.tr('Aucun défi en attente', 'No pending challenge');
                icon = Icons.check_circle_outline_rounded;
                color = AppColors.text2;
              } else if (pending == 1) {
                label = context.tr('1 défi en attente', '1 pending challenge');
                icon = Icons.bolt_rounded;
                color = AppColors.gold;
              } else {
                label = context.tr(
                  '$pending défis en attente',
                  '$pending pending challenges',
                );
                icon = Icons.bolt_rounded;
                color = AppColors.gold;
              }
            }

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) =>
                    const GameCenterScreen(challengesOnly: true)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required String label,
    required String image,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: primary ? AppColors.lime : AppColors.bg2,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: primary ? AppColors.lime : AppColors.lime.withOpacity(.30),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Prono4Art(name: image, size: 37),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: GoogleFonts.spaceGrotesk(
                    color: primary ? const Color(0xFF101510) : AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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
