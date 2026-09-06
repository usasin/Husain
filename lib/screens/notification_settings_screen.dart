import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/messaging_service.dart';
import '../theme/app_theme.dart';
import '../widgets/wc26_background.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationPrefs? _prefs;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await MessagingService.instance.getPreferences();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  Future<void> _setPrefs(NotificationPrefs next) async {
    final previous = _prefs;
    setState(() {
      _prefs = next;
      _saving = true;
    });

    try {
      if (previous == null || previous.pushEnabled != next.pushEnabled) {
        await MessagingService.instance.setPushEnabled(next.pushEnabled);
      }
      if (previous == null || previous.generalAlerts != next.generalAlerts) {
        await MessagingService.instance.setGeneralAlertsEnabled(next.generalAlerts);
      }
      if (previous == null || previous.teamChatAlerts != next.teamChatAlerts) {
        await MessagingService.instance.setTeamChatAlertsEnabled(next.teamChatAlerts);
      }
      if (previous == null || previous.matchRoomAlerts != next.matchRoomAlerts) {
        await MessagingService.instance.setMatchRoomAlertsEnabled(next.matchRoomAlerts);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préférences notifications mises à jour.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de modifier les notifications : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = MessagingService.instance.isSupported;
    final prefs = _prefs;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withOpacity(0.90),
              title: Text(
                'NOTIFICATIONS',
                style: GoogleFonts.bebasNeue(letterSpacing: 2),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _heroCard(),
                  const SizedBox(height: 16),
                  if (!supported)
                    _infoCard(
                      icon: Icons.phone_android_rounded,
                      title: 'Notifications indisponibles ici',
                      subtitle:
                          'Les notifications push fonctionnent sur Android et iPhone, pas sur le web ou certains modes de test.',
                    )
                  else if (_loading || prefs == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    _switchCard(
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.gold,
                      title: 'Toutes les notifications push',
                      subtitle: prefs.pushEnabled
                          ? 'Activées. Tu peux choisir les catégories ci-dessous.'
                          : 'Désactivées. L’app se désabonne des topics FCM.',
                      value: prefs.pushEnabled,
                      onChanged: _saving
                          ? null
                          : (value) => _setPrefs(prefs.copyWith(
                                pushEnabled: value,
                                generalAlerts: value,
                                teamChatAlerts: value,
                                matchRoomAlerts: value,
                              )),
                    ),
                    const SizedBox(height: 12),
                    _switchCard(
                      icon: Icons.sports_soccer_rounded,
                      color: AppColors.usaBlue,
                      title: 'Matchs, scores et résultats',
                      subtitle:
                          'Tribune ouverte, match bientôt, score mis à jour et match terminé.',
                      value: prefs.pushEnabled && prefs.generalAlerts,
                      onChanged: (!_saving && prefs.pushEnabled)
                          ? (value) => _setPrefs(prefs.copyWith(generalAlerts: value))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _switchCard(
                      icon: Icons.groups_rounded,
                      color: AppColors.mexicoGreen,
                      title: 'Salon de mon équipe',
                      subtitle:
                          'Notifications groupées pour le salon équipe, sans spam.',
                      value: prefs.pushEnabled && prefs.teamChatAlerts,
                      onChanged: (!_saving && prefs.pushEnabled)
                          ? (value) => _setPrefs(prefs.copyWith(teamChatAlerts: value))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _switchCard(
                      icon: Icons.forum_rounded,
                      color: AppColors.canadaRed,
                      title: 'Tribune du match',
                      subtitle:
                          'Messages importants dans les salons de match que tu as ouverts.',
                      value: prefs.pushEnabled && prefs.matchRoomAlerts,
                      onChanged: (!_saving && prefs.pushEnabled)
                          ? (value) => _setPrefs(prefs.copyWith(matchRoomAlerts: value))
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _infoCard(
                      icon: Icons.tune_rounded,
                      title: 'Contrôle utilisateur',
                      subtitle:
                          'Si tu désactives une catégorie, l’app se désabonne du topic correspondant. Tu peux aussi couper les notifications dans les réglages Android/iPhone.',
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withOpacity(0.18),
            AppColors.usaBlue.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.notifications_rounded, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choisis ce que tu veux recevoir',
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scores, fin de match, salon équipe ou tribune : tu gardes le contrôle.',
                  style: GoogleFonts.barlow(
                    color: AppColors.text2,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(0.90),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.barlow(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.barlow(
                    color: AppColors.text2,
                    fontSize: 11,
                    height: 1.30,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.text2, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.barlow(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.barlow(
                    color: AppColors.text2,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
