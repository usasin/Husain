import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import 'calendar_screen.dart' as legacy;

/// Petit rappel permanent pour rendre le blocage compréhensible :
/// 1) on bloque depuis le menu ⋮ d'un message d'un autre joueur ;
/// 2) on gère ensuite la liste dans « Joueurs bloqués » du profil.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.bg2.withOpacity(.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.canadaRed.withOpacity(.24)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.block_rounded,
                      color: AppColors.canadaRed, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Comment bloquer un joueur ?', 'How do I block a player?'),
                          style: GoogleFonts.inter(
                            color: AppColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr(
                            'Dans un salon, touche ⋮ à côté du pseudo puis « Bloquer ». La rubrique « Joueurs bloqués » ci-dessous affiche qui tu as bloqué et permet de débloquer.',
                            'In a chat, tap ⋮ next to a nickname, then “Block”. The “Blocked players” section below shows who you blocked and lets you unblock them.',
                          ),
                          style: GoogleFonts.inter(
                            color: AppColors.text2,
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Expanded(child: legacy.ProfileScreen()),
      ],
    );
  }
}
