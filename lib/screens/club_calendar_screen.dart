import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_match_tile.dart';
import '../widgets/wc26_background.dart';
import '../l10n/app_locale.dart';

class ClubCalendarScreen extends StatefulWidget {
  const ClubCalendarScreen({super.key});

  @override
  State<ClubCalendarScreen> createState() => _ClubCalendarScreenState();
}

class _ClubCalendarScreenState extends State<ClubCalendarScreen> {
  String _competition = 'all';
  int _mode = 0; // 0=à venir, 1=live, 2=terminés, 3=mes pronos

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();
    final matches = provider.matches.where((match) {
      if (_competition != 'all' && match.competitionId != _competition) {
        return false;
      }
      final live = provider.isLiveMatch(match.id);
      if (_mode == 1) return live;
      if (_mode == 2) return !live && !match.dateTime.isAfter(now);
      if (_mode == 3) {
        final uid = provider.currentUser?.id;
        return uid != null && provider.votes.containsKey('${uid}__${match.id}');
      }
      return !live && match.dateTime.isAfter(now);
    }).toList();

    return Scaffold(
      floatingActionButton: provider.adminMode
          ? FloatingActionButton.extended(
              onPressed: () => _showMatchEditor(context, provider),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg0,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('Ajouter un match','Add match')),
            )
          : null,
      body: WC2026Background(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                sliver: SliverToBoxAdapter(child: _header(context, matches.length)),
              ),
              SliverToBoxAdapter(child: _filters()),
              if (matches.isEmpty)
                SliverFillRemaining(
                    hasScrollBody: false, child: _empty(provider))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 96),
                  sliver: SliverList.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      final previous = index == 0 ? null : matches[index - 1];
                      final showDate = previous?.localDate != match.localDate;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDate) _dateHeader(match),
                          CompactMatchTile(match: match),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int count) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Matchs','Matches'),
              style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8)),
          const SizedBox(height: 4),
          Text(
            context.isEnglish ? '$count match${count == 1 ? '' : 'es'}' : '$count rencontre${count > 1 ? 's' : ''}',
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text(context.tr('À venir','Upcoming'))),
                ButtonSegment(value: 1, label: Text(context.tr('En direct','Live'))),
                ButtonSegment(value: 2, label: Text(context.tr('Terminés','Finished'))),
                ButtonSegment(value: 3, label: Text(context.tr('Mes pronos','My picks'))),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => setState(() => _mode = value.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.lime
                        : AppColors.bg2),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.bg0
                        : AppColors.text2),
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
                ),
                side: WidgetStatePropertyAll(
                  BorderSide(color: Colors.white.withOpacity(.07)),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _filters() => SizedBox(
        height: 52,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          scrollDirection: Axis.horizontal,
          children: [
            _chip('all', context.tr('⚽ Tout','⚽ All')),
            ...kCompetitions.map(
              (item) => _chip(item.id, '${item.emoji} ${competitionDisplayShortName(context, item)}'),
            ),
          ],
        ),
      );

  Widget _chip(String id, String label) {
    final selected = _competition == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => setState(() => _competition = id),
        selectedColor: AppColors.gold.withOpacity(.18),
        side: BorderSide(
          color: selected
              ? AppColors.gold.withOpacity(.55)
              : Colors.white.withOpacity(.08),
        ),
      ),
    );
  }

  Widget _dateHeader(FootballMatch match) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 9),
        child: Text(
          DateFormat('EEEE d MMMM', context.isEnglish ? 'en_US' : 'fr_FR')
              .format(match.dateTime)
              .toUpperCase(),
          style: GoogleFonts.barlowCondensed(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
            letterSpacing: .9,
          ),
        ),
      );

  Widget _empty(AppProvider provider) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: AppColors.cyan, size: 54),
              const SizedBox(height: 14),
              Text(
                _mode == 1
                    ? context.tr('AUCUN MATCH EN DIRECT','NO LIVE MATCHES')
                    : _mode == 2
                        ? context.tr('AUCUN MATCH TERMINÉ','NO FINISHED MATCHES')
                        : _mode == 3
                            ? context.tr('AUCUN PRONOSTIC','NO PREDICTIONS YET')
                            : context.tr('AUCUN MATCH PROGRAMMÉ','NO SCHEDULED MATCHES'),
                textAlign: TextAlign.center,
                style: GoogleFonts.bebasNeue(
                    color: AppColors.text, fontSize: 24, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text(
                provider.adminMode
                    ? context.tr('Synchronisez les calendriers officiels ou ajoutez une rencontre manuellement.', 'Sync official fixtures or add a match manually.')
                    : (_mode == 3
                        ? context.tr('Fais ton premier pronostic pour le retrouver ici.', 'Make your first prediction to see it here.')
                        : context.tr('Le calendrier sera mis à jour dès la publication des rencontres.', 'The calendar updates as soon as fixtures are published.')),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text2, height: 1.4),
              ),
              if (provider.adminMode) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final count = await provider.syncMatchesToFirestore();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          count > 0
                              ? '✅ $count matchs synchronisés.'
                              : 'Synchronisation impossible : vérifiez la Cloud Function et le token football-data.org.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cloud_sync_rounded),
                  label: const Text('Synchroniser maintenant'),
                ),
              ],
            ],
          ),
        ),
      );

  Future<void> _showMatchEditor(
    BuildContext context,
    AppProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final home = TextEditingController();
    final away = TextEditingController();
    final venue = TextEditingController();
    final stage = TextEditingController();
    final matchday = TextEditingController();
    var competitionId =
        _competition == 'all' ? kCompetitions.first.id : _competition;
    var kickoff = DateTime.now().add(const Duration(days: 1));
    var allowsDraw = true;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouvelle rencontre'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: competitionId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Compétition'),
                    items: kCompetitions
                        .map((item) => DropdownMenuItem(
                              value: item.id,
                              child: Text('${item.emoji} ${item.name}'),
                            ))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(() {
                              competitionId = value ?? competitionId;
                              final kind = competitionById(competitionId)?.kind;
                              allowsDraw = kind == CompetitionKind.championnat;
                            }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: home,
                      decoration:
                          const InputDecoration(labelText: 'Club à domicile')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: away,
                      decoration: const InputDecoration(
                          labelText: 'Club à l’extérieur')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: venue,
                      decoration: const InputDecoration(
                          labelText: 'Stade (facultatif)')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: stage,
                      decoration: const InputDecoration(
                          labelText: 'Tour / phase (facultatif)')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: matchday,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Journée (facultatif)'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded,
                        color: AppColors.gold),
                    title:
                        Text(DateFormat('dd/MM/yyyy à HH:mm').format(kickoff)),
                    subtitle: const Text('Heure locale de l’appareil'),
                    onTap: saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: kickoff,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 30)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 730)),
                            );
                            if (date == null || !context.mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(kickoff),
                            );
                            if (time == null) return;
                            setDialogState(() {
                              kickoff = DateTime(date.year, date.month,
                                  date.day, time.hour, time.minute);
                            });
                          },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: allowsDraw,
                    title: const Text('Pronostic « match nul »'),
                    subtitle: const Text(
                        'Désactivez-le pour une rencontre à élimination directe.'),
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(() => allowsDraw = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      final error = await provider.saveClubMatch(
                        competitionId: competitionId,
                        homeName: home.text,
                        awayName: away.text,
                        kickoff: kickoff,
                        venue: venue.text,
                        stage: stage.text,
                        matchday: int.tryParse(matchday.text.trim()),
                        allowsDraw: allowsDraw,
                      );
                      if (!dialogContext.mounted) return;
                      if (error == null) {
                        Navigator.pop(dialogContext);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Rencontre publiée.')),
                        );
                      } else {
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                      }
                    },
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_rounded),
              label: const Text('Publier'),
            ),
          ],
        ),
      ),
    );

    home.dispose();
    away.dispose();
    venue.dispose();
    stage.dispose();
    matchday.dispose();
  }
}
