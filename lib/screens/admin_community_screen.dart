import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class AdminCommunityScreen extends StatefulWidget {
  const AdminCommunityScreen({super.key});

  @override
  State<AdminCommunityScreen> createState() => _AdminCommunityScreenState();
}

class _AdminCommunityScreenState extends State<AdminCommunityScreen> {
  final _pinController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _savePin(AppProvider prov) async {
    setState(() => _busy = true);
    final error = await prov.adminUpdateCommunitySettings(
      pinnedMessage: _pinController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Message épinglé mis à jour.')),
    );
  }

  Future<void> _toggle(AppProvider prov, {bool? team, bool? match}) async {
    setState(() => _busy = true);
    final error = await prov.adminUpdateCommunitySettings(
      teamChatEnabled: team,
      matchLoungeEnabled: match,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        title: Text('Animation salons',
            style: GoogleFonts.bebasNeue(letterSpacing: 1.2)),
      ),
      body: StreamBuilder<CommunitySettings>(
        stream: prov.communitySettingsStream(),
        builder: (context, snap) {
          final settings = snap.data ?? const CommunitySettings();
          if (_pinController.text.isEmpty && settings.pinnedMessage.isNotEmpty) {
            _pinController.text = settings.pinnedMessage;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _hero(),
              const SizedBox(height: 16),
              _reportsCard(prov),
              const SizedBox(height: 16),
              _switchCard(
                icon: Icons.shield_rounded,
                title: 'Salons par équipe',
                subtitle: 'Autoriser ou couper les discussions privées des équipes.',
                value: settings.teamChatEnabled,
                onChanged: _busy ? null : (v) => _toggle(prov, team: v),
                color: AppColors.mexicoGreen,
              ),
              const SizedBox(height: 12),
              _switchCard(
                icon: Icons.stadium_rounded,
                title: 'Tribune du match',
                subtitle: 'Salon commun ouvert automatiquement autour des rencontres.',
                value: settings.matchLoungeEnabled,
                onChanged: _busy ? null : (v) => _toggle(prov, match: v),
                color: AppColors.gold,
              ),
              const SizedBox(height: 18),
              _pinCard(prov, settings),
              const SizedBox(height: 18),
              _infoCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.usaBlue.withOpacity(0.18),
          AppColors.violet.withOpacity(0.14),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(children: [
        const Text('🎙️', style: TextStyle(fontSize: 34)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Moteur communautaire',
              style: GoogleFonts.bebasNeue(
                  color: AppColors.text, fontSize: 22, letterSpacing: 1.2)),
          Text('Pilote les salons sans redéployer l’application.',
              style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 13)),
        ])),
      ]),
    );
  }

  Widget _reportsCard(AppProvider prov) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: prov.contentReportsStream(),
      builder: (context, snapshot) {
        final reports = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['status'] != 'resolved')
            .toList();
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.canadaRed.withOpacity(0.24)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.flag_rounded, color: AppColors.canadaRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SIGNALEMENTS OUVERTS (${reports.length})',
                  style: GoogleFonts.bebasNeue(
                    color: AppColors.text,
                    fontSize: 18,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ]),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (reports.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Aucun signalement en attente.',
                    style: GoogleFonts.barlow(color: AppColors.text2)),
              )
            else
              ...reports.take(10).map((doc) {
                final data = doc.data();
                final name = (data['reportedUserName'] ?? 'Joueur').toString();
                final message = (data['message'] ?? '').toString();
                final location = data['chatType'] == 'team'
                    ? 'Salon équipe'
                    : 'Tribune du match';
                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$name · $location',
                        style: GoogleFonts.barlowCondensed(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 5),
                    Text(message,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlow(color: AppColors.text)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      OutlinedButton.icon(
                        onPressed: () => _resolveReport(prov, doc.id, true),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text('Supprimer le message'),
                      ),
                      TextButton(
                        onPressed: () => _resolveReport(prov, doc.id, false),
                        child: const Text('Classer sans supprimer'),
                      ),
                    ]),
                  ]),
                );
              }),
          ]),
        );
      },
    );
  }

  Future<void> _resolveReport(
    AppProvider prov,
    String reportId,
    bool removeMessage,
  ) async {
    final error = await prov.adminResolveContentReport(
      reportId,
      removeMessage: removeMessage,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Signalement traité.'),
        backgroundColor: error == null ? AppColors.mexicoGreen : AppColors.canadaRed,
      ),
    );
  }

  Widget _switchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.30)),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.barlowCondensed(
                  color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 12.5, height: 1.3)),
        ])),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }

  Widget _pinCard(AppProvider prov, CommunitySettings settings) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.push_pin_rounded, color: AppColors.gold, size: 19),
          const SizedBox(width: 8),
          Text('Message épinglé',
              style: GoogleFonts.barlowCondensed(
                  color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _pinController,
          minLines: 1,
          maxLines: 3,
          maxLength: 180,
          style: GoogleFonts.barlow(color: AppColors.text),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Ex : Restez fair-play, la tribune ouvre 45 min avant match.',
            hintStyle: GoogleFonts.barlow(color: AppColors.grey),
            filled: true,
            fillColor: AppColors.bg3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : () => _savePin(prov),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Enregistrer'),
          ),
        ),
      ]),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cyan.withOpacity(0.20)),
      ),
      child: Text(
        'Optimisation coût : les salons ne lisent que les derniers messages, la présence est légère et les salons peuvent être coupés instantanément par l’admin.',
        style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 12.5, height: 1.35),
      ),
    );
  }
}
