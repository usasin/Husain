import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Préférences locales des compétitions visibles dans PRONO4.
/// L'utilisateur peut librement cocher/décocher les compétitions proposées.
class CompetitionSettingsCard extends StatelessWidget {
  const CompetitionSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final enabled = provider.enabledCompetitionIds;
    final allSelected = enabled.length == kCompetitions.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lime.withOpacity(.11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lime.withOpacity(.24)),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.lime, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Mes compétitions', 'My competitions'),
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                        'Choisis une, plusieurs ou toutes les compétitions.',
                        'Choose one, several or all competitions.',
                      ),
                      style: GoogleFonts.inter(
                        color: AppColors.text2,
                        fontSize: 10.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () async {
              if (allSelected) {
                await provider.setEnabledCompetitions([kCompetitions.first.id]);
              } else {
                await provider.enableAllCompetitions();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: allSelected
                    ? AppColors.lime.withOpacity(.10)
                    : AppColors.bg3,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: allSelected
                      ? AppColors.lime.withOpacity(.45)
                      : AppColors.overlayBase.withOpacity(.09),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    allSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: AppColors.lime,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('Tout sélectionner', 'Select all'),
                    style: GoogleFonts.inter(
                      color: AppColors.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kCompetitions.map((competition) {
              final selected = enabled.contains(competition.id);
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final ok = await provider.toggleCompetitionEnabled(competition.id);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr(
                          'Garde au moins une compétition active.',
                          'Keep at least one competition active.',
                        )),
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 104,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.lime.withOpacity(.10)
                        : AppColors.bg3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.lime.withOpacity(.55)
                          : AppColors.overlayBase.withOpacity(.08),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Image.network(
                              competition.emblemUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(competition.emoji,
                                    style: const TextStyle(fontSize: 23)),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected ? AppColors.lime : AppColors.grey,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        competitionDisplayShortName(context, competition),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: selected ? AppColors.text : AppColors.text2,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'Ces choix personnalisent l’accueil, les duels, les matchs, les rappels et les classements.',
              'These choices personalize Home, duels, matches, reminders and standings.',
            ),
            style: GoogleFonts.inter(
              color: AppColors.text2,
              fontSize: 9.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
