import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Administration des matchs de Ligue Europa - aucune API payante.
/// La Cloud Function protège l'écriture et met à jour les manifestes BUILD83.
class AdminEuropaLeagueScreen extends StatefulWidget {
  const AdminEuropaLeagueScreen({super.key, this.firestore});

  final FirebaseFirestore? firestore;

  @override
  State<AdminEuropaLeagueScreen> createState() => _AdminEuropaLeagueScreenState();
}

class _AdminEuropaLeagueScreenState extends State<AdminEuropaLeagueScreen> {
  bool _busy = false;
  late final _manifest = (widget.firestore ?? FirebaseFirestore.instance)
      .collection('fixtureManifests').doc('europa-league');
  static const _endpoint =
      'https://europe-west1-mundial2026-ibab-01.cloudfunctions.net/manageEuropaLeague';

  Future<void> _post(Map<String, dynamic> args) async {
    if (_busy) return;
    final prov = context.read<AppProvider>();
    if (!prov.adminMode || !(await prov.refreshAdminAccess())) {
      throw StateError('Accès administrateur refusé.');
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Connecte-toi à Firebase.');
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) throw StateError('Session expirée.');
      final response = await http.post(Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'data': args}),
      ).timeout(const Duration(seconds: 45));
      dynamic body;
      try { body = jsonDecode(response.body); } catch (_) { body = null; }
      if (response.statusCode >= 400 || body is! Map || body['error'] != null) {
        final error = body is Map ? body['error'] : null;
        final message = error is Map ? (error['message'] ?? error['status']) : null;
        throw StateError(message?.toString() ??
          'Enregistrement impossible (HTTP ${response.statusCode}). Vérifie que la fonction serveur est déployée.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ligue Europa : modification enregistrée.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')),
    );
  }

  Future<T?> _showFormDialog<T>({required WidgetBuilder builder}) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<T>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: builder,
    );
    final result = await navigator.push<T>(route);
    // Navigator.pop resolves before the closing animation removes the fields.
    // The caller may dispose their controllers only after this future completes.
    await route.completed;
    return result;
  }

  Future<void> _addMatch() async {
    final home = TextEditingController();
    final away = TextEditingController();
    final homeCode = TextEditingController();
    final awayCode = TextEditingController();
    final stage = TextEditingController(text: 'Phase de ligue');
    final dayController = TextEditingController();
    var date = DateTime.now().add(const Duration(days: 1));
    var time = const TimeOfDay(hour: 20, minute: 45);
    var stageCode = 'LEAGUE_STAGE';
    var allowsDraw = true;
    bool confirmed = false;
    try {
      final info = await _showFormDialog<Map<String, dynamic>>(
        builder: (dialogContext) => StatefulBuilder(builder: (ctx, refresh) {
          final dateString = '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year} '
              '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}';
          return AlertDialog(
            title: const Text('Ajouter un match Europa'),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: home, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Club à domicile')),
                TextField(controller: away, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Club à l’extérieur')),
                TextField(controller: homeCode, textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Sigle domicile (facultatif, ex. OM)')),
                TextField(controller: awayCode, textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Sigle extérieur (facultatif)')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event), label: Text(dateString),
                  onPressed: () async {
                    final picked = await showDatePicker(context: ctx,
                      initialDate: date, firstDate: DateTime(2025), lastDate: DateTime(2031));
                    if (picked == null || !ctx.mounted) return;
                    final t = await showTimePicker(context: ctx, initialTime: time);
                    if (!ctx.mounted) return;
                    refresh(() { date = picked; if (t != null) time = t; });
                  },
                ),
                TextField(controller: stage,
                  decoration: const InputDecoration(labelText: 'Phase')),
                DropdownButtonFormField<String>(
                  initialValue: stageCode,
                  decoration: const InputDecoration(labelText: 'Type de phase'),
                  items: const [
                    DropdownMenuItem(value: 'LEAGUE_STAGE', child: Text('Phase de ligue')),
                    DropdownMenuItem(value: 'PLAYOFFS', child: Text('Barrages')),
                    DropdownMenuItem(value: 'LAST_16', child: Text('Huitièmes')),
                    DropdownMenuItem(value: 'QUARTER_FINALS', child: Text('Quarts')),
                    DropdownMenuItem(value: 'SEMI_FINALS', child: Text('Demi-finales')),
                    DropdownMenuItem(value: 'FINAL', child: Text('Finale')),
                  ],
                  onChanged: (value) => refresh(() => stageCode = value ?? stageCode),
                ),
                SwitchListTile(title: const Text('Résultat nul autorisé'),
                  value: allowsDraw, onChanged: (value) => refresh(() => allowsDraw = value)),
                const Text('La date et l’heure utilisent le fuseau de cet appareil.', style: TextStyle(fontSize: 11)),
                TextField(controller: dayController, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Journée (facultative)')),
              ],
            )),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler')),
              FilledButton(onPressed: () {
                if (home.text.trim().isEmpty || away.text.trim().isEmpty ||
                    home.text.trim().toLowerCase() == away.text.trim().toLowerCase()) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Saisis deux clubs différents.')));
                  return;
                }
                final matchday = int.tryParse(dayController.text.trim());
                if (dayController.text.trim().isNotEmpty && matchday == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Numéro de journée invalide.')));
                  return;
                }
                final kickoff = DateTime(date.year, date.month, date.day,
                  time.hour, time.minute);
                Navigator.pop(dialogContext, {
                  'action': 'addMatch',
                  'homeName': home.text.trim(), 'awayName': away.text.trim(),
                  'homeCode': homeCode.text.trim(), 'awayCode': awayCode.text.trim(),
                  'kickoffUtc': kickoff.toUtc().toIso8601String(),
                  'stage': stage.text.trim(), 'stageCode': stageCode,
                  'allowsDraw': allowsDraw, 'matchday': matchday,
                });
              }, child: const Text('Enregistrer')),
            ],
          );
        }),
      );
      if (info == null) return;
      await _post(info);
      confirmed = true;
    } catch (e) {
      _showError(e);
    } finally {
      home.dispose(); away.dispose(); homeCode.dispose(); awayCode.dispose();
      stage.dispose(); dayController.dispose();
    }
    if (confirmed && mounted) setState(() {});
  }

  Future<void> _enterScore(Map<String, dynamic> row) async {
    final homeScore = TextEditingController();
    final awayScore = TextEditingController();
    final oldHome = row['homeScore'];
    final oldAway = row['awayScore'];
    final correcting = oldHome is num && oldAway is num;
    String? decisiveWinner;
    if (correcting) {
      homeScore.text = oldHome.toString();
      awayScore.text = oldAway.toString();
    }
    try {
      final scores = await _showFormDialog<Map<String, dynamic>>(
        builder: (dialogContext) => AlertDialog(
          title: Text(correcting ? 'Corriger le résultat' : 'Résultat officiel'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${row['homeName']} – ${row['awayName']}', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: homeScore,
                textAlign: TextAlign.center, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Domicile'))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('–')),
              Expanded(child: TextField(controller: awayScore,
                textAlign: TextAlign.center, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Extérieur'))),
            ]),
            const SizedBox(height: 12),
            if (row['allowsDraw'] == false)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Vainqueur si égalité après le match'),
                items: [DropdownMenuItem(value: 'HOME', child: Text('${row['homeName']}')),
                  DropdownMenuItem(value: 'AWAY', child: Text('${row['awayName']}'))],
                onChanged: (value) => decisiveWinner = value,
              ),
            const Text('Attention : enregistrer un score officiel influence les vrais points des joueurs.',
              style: TextStyle(fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(onPressed: () {
              final h = int.tryParse(homeScore.text.trim());
              final a = int.tryParse(awayScore.text.trim());
              if (h == null || a == null || h < 0 || a < 0 || h > 99 || a > 99) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Scores entre 0 et 99 requis.')));
                return;
              }
              Navigator.pop(dialogContext, {
                'action': 'setScore', 'matchId': row['id'],
                'homeScore': h, 'awayScore': a,
                'confirmCorrection': correcting,
                'expectedHomeScore': row['homeScore'],
                'expectedAwayScore': row['awayScore'],
                'expectedResult': row['result'],
                'decisiveWinner': decisiveWinner,
              });
            }, child: Text(correcting ? 'Confirmer correction' : 'Confirmer le score')),
          ],
        ),
      );
      if (scores != null) await _post(scores);
    } catch (e) { _showError(e); }
    finally { homeScore.dispose(); awayScore.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AppProvider>().adminMode) {
      return const Scaffold(body: Center(child: Text('Accès administrateur requis.')));
    }
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(title: const Text('LIGUE EUROPA · ADMIN')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addMatch,
        backgroundColor: AppColors.lime,
        icon: const Icon(Icons.add), label: const Text('Ajouter un match'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _manifest.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Impossible de charger le calendrier.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data();
          final rows = (data?['rows'] is List)
              ? (data!['rows'] as List)
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row)).toList()
              : <Map<String, dynamic>>[];
          rows.sort((a, b) => (a['kickoffAtMs'] as num? ?? 0)
              .compareTo((b['kickoffAtMs'] as num? ?? 0)));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 15, 16, 100), children: [
            Container(padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: AppColors.bg2,
                borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🏆 LIGUE EUROPA', style: TextStyle(
                  color: AppColors.lime, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('${rows.length} rencontre(s) · Calendrier et scores manuels',
                  style: TextStyle(color: AppColors.text2)),
                const SizedBox(height: 6),
                Text('Toutes les équipes. Aucune requête à Football-Data.',
                  style: TextStyle(color: AppColors.text2, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Padding(padding: EdgeInsets.all(25),
                child: Text('Aucun match saisi. Appuie sur « Ajouter un match ».')),
            ...rows.map((row) {
              final ms = row['kickoffAtMs'];
              final date = ms is num
                ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()).toLocal()
                : DateTime.now();
              final formatted = '${date.day.toString().padLeft(2, '0')}/'
                '${date.month.toString().padLeft(2, '0')} '
                '${date.hour.toString().padLeft(2, '0')}:'
                '${date.minute.toString().padLeft(2, '0')}';
              final played = row['result'] != null;
              return Card(color: AppColors.bg2,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${row['homeName']}  –  ${row['awayName']}',
                        style: TextStyle(color: AppColors.text,
                          fontWeight: FontWeight.w800, fontSize: 15))),
                      if (played)
                        Text('${row['homeScore']}–${row['awayScore']}',
                          style: const TextStyle(color: AppColors.lime,
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 7),
                    Text('$formatted · ${row['stage'] ?? 'Phase de ligue'}',
                      style: TextStyle(color: AppColors.text2, fontSize: 12)),
                    Align(alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy ? null : () => _enterScore(row),
                        icon: Icon(played ? Icons.edit : Icons.sports_score),
                        label: Text(played ? 'Corriger le score' : 'Saisir le score'),
                      )),
                  ]),
                ),
              );
            }),
          ]);
        },
      ),
    );
  }
}
