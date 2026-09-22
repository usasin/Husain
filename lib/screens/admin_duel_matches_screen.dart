import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../data/duel_selector.dart';
import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/club_crest.dart';
import '../widgets/wc26_background.dart';

/// Admin — sélection manuelle des « Duels du jour ».
/// Sans réglage admin, PRONO4 garde sa sélection automatique.
/// Dès qu'un admin modifie la journée, la liste enregistrée devient la source
/// exacte : on peut retirer un duel, en ajouter un autre, ou en garder plusieurs.
class AdminDuelMatchesScreen extends StatelessWidget {
  const AdminDuelMatchesScreen({super.key});

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  List<FootballMatch> _autoDuels(
    List<FootballMatch> matches,
    AppProvider provider,
  ) {
    return selectAutomaticDuels(
      matches,
      provider.enabledCompetitions.map((c) => c.id),
      isFavoriteClub: provider.isFavoriteClub,
    );
  }

  Future<bool> _ensureAdmin(BuildContext context) async {
    final provider = context.read<AppProvider>();
    return provider.adminMode || await provider.refreshAdminAccess();
  }

  Future<void> _saveSelection(
    BuildContext context,
    DateTime day,
    Set<String> selectedIds,
  ) async {
    if (!await _ensureAdmin(context)) {
      _toast(context, context.tr('Accès admin refusé.', 'Admin access denied.'));
      return;
    }
    final provider = context.read<AppProvider>();
    final key = _dateKey(day);
    await FirebaseFirestore.instance
        .collection('dynamicContents')
        .doc('duel_selection_$key')
        .set({
      'placement': 'duel_selection',
      'date': key,
      'selectedMatchIds': selectedIds.toList(),
      'enabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': provider.firebaseUid ?? provider.currentUser?.id ?? 'admin',
    }, SetOptions(merge: true));
  }

  Future<void> _resetAuto(BuildContext context, DateTime day) async {
    if (!await _ensureAdmin(context)) {
      _toast(context, context.tr('Accès admin refusé.', 'Admin access denied.'));
      return;
    }
    final key = _dateKey(day);
    await FirebaseFirestore.instance
        .collection('dynamicContents')
        .doc('duel_selection_$key')
        .delete();
    _toast(
      context,
      context.tr(
        'Sélection automatique réactivée.',
        'Automatic duel selection restored.',
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();
    final today = provider.visibleMatches
        .where((m) => _sameDay(m.dateTime.toLocal(), now.toLocal()))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final autoIds = _autoDuels(today, provider).map((m) => m.id).toSet();
    final key = _dateKey(now);
    final ref = FirebaseFirestore.instance
        .collection('dynamicContents')
        .doc('duel_selection_$key');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withOpacity(.96),
              title: Text(
                context.tr('MATCHS DES DUELS', 'DUEL MATCHES'),
                style: GoogleFonts.bebasNeue(letterSpacing: 1.3, fontSize: 22),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                30 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: ref.snapshots(),
                  builder: (context, snap) {
                    final data = snap.data?.data();
                    final hasOverride = data != null &&
                        data.containsKey('selectedMatchIds') &&
                        data['enabled'] != false;
                    final stored = <String>{
                      if (data?['selectedMatchIds'] is List)
                        ...(data!['selectedMatchIds'] as List)
                            .map((e) => e.toString()),
                    };
                    final selected = hasOverride ? stored : autoIds;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.bg2.withOpacity(.95),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.lime.withOpacity(.22),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    color: AppColors.lime,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      context.tr(
                                        'L’API fournit les matchs du jour. PRONO4 propose les grosses affiches ; ici tu peux les valider, en retirer ou en ajouter.',
                                        'The API provides today’s matches. PRONO4 proposes the big fixtures; here you can confirm, remove or add any match.',
                                      ),
                                      style: GoogleFonts.inter(
                                        color: AppColors.text,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                hasOverride
                                    ? context.tr(
                                        'Mode manuel actif : ${selected.length} duel(s).',
                                        'Manual mode active: ${selected.length} duel(s).',
                                      )
                                    : context.tr(
                                        'Mode automatique PRONO4 actif. Aucun fournisseur ne marque officiellement un match comme “Duel”.',
                                        'PRONO4 automatic mode is active. No provider officially labels a match as a “Duel”.',
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
                        const SizedBox(height: 12),
                        if (today.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.bg2,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              context.tr(
                                "Aucun match aujourd'hui.",
                                'No matches today.',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: AppColors.text2),
                            ),
                          )
                        else
                          ...today.map((match) => _matchTile(
                                context,
                                match,
                                selected.contains(match.id),
                                () async {
                                  final next = Set<String>.from(selected);
                                  if (next.contains(match.id)) {
                                    next.remove(match.id);
                                  } else {
                                    next.add(match.id);
                                  }
                                  await _saveSelection(context, now, next);
                                },
                              )),
                        const SizedBox(height: 8),
                        if (hasOverride)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _resetAuto(context, now),
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: Text(context.tr(
                                'REVENIR À LA SÉLECTION AUTOMATIQUE',
                                'RESTORE AUTOMATIC SELECTION',
                              )),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchTile(
    BuildContext context,
    FootballMatch match,
    bool selected,
    VoidCallback onTap,
  ) {
    final comp = competitionById(match.competitionId);
    final home = match.homeName ?? match.homeCode;
    final away = match.awayName ?? match.awayCode;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.lime.withOpacity(.10)
            : AppColors.bg2.withOpacity(.96),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: selected
              ? AppColors.lime.withOpacity(.55)
              : AppColors.overlayBase.withOpacity(.08),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    if (comp != null)
                      Container(
                        width: 28,
                        height: 28,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.logoPlate,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.network(
                          comp.emblemUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(comp.emoji),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      match.localTime,
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ClubCrest(url: match.homeCrestUrl, clubName: home, size: 34),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  home,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  'VS',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.lime,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  away,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    color: AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              ClubCrest(url: match.awayCrestUrl, clubName: away, size: 34),
              const SizedBox(width: 7),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: selected ? AppColors.lime : AppColors.grey,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
