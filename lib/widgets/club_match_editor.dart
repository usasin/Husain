import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/competitions_data.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

Future<void> showClubMatchEditor(
  BuildContext context,
  AppProvider provider, {
  String initialCompetition = 'all',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final home = TextEditingController();
  final away = TextEditingController();
  final venue = TextEditingController();
  final stage = TextEditingController();
  final matchday = TextEditingController();
  var competitionId =
      initialCompetition == 'all' ? kCompetitions.first.id : initialCompetition;
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
                            allowsDraw = kind == CompetitionKind.championnat ||
                                competitionId == 'europa-league';
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
                    decoration:
                        const InputDecoration(labelText: 'Club à l’extérieur')),
                const SizedBox(height: 10),
                TextField(
                    controller: venue,
                    decoration:
                        const InputDecoration(labelText: 'Stade (facultatif)')),
                const SizedBox(height: 10),
                TextField(
                    controller: stage,
                    decoration: const InputDecoration(
                        labelText: 'Tour / phase (facultatif)')),
                const SizedBox(height: 10),
                TextField(
                  controller: matchday,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Journée (facultatif)'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.schedule_rounded, color: AppColors.gold),
                  title: Text(DateFormat('dd/MM/yyyy à HH:mm').format(kickoff)),
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
                            kickoff = DateTime(date.year, date.month, date.day,
                                time.hour, time.minute);
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
