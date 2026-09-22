import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
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
    if (previous == null) return;
    setState(() {
      _prefs = next;
      _saving = true;
    });

    try {
      if (previous.pushEnabled != next.pushEnabled) {
        await MessagingService.instance.setPushEnabled(next.pushEnabled);
      }
      if (previous.generalAlerts != next.generalAlerts) {
        await MessagingService.instance.setGeneralAlertsEnabled(next.generalAlerts);
      }
      if (previous.favoriteTeamAlerts != next.favoriteTeamAlerts) {
        await MessagingService.instance
            .setFavoriteTeamAlertsEnabled(next.favoriteTeamAlerts);
      }
      if (previous.predictionAlerts != next.predictionAlerts) {
        await MessagingService.instance
            .setPredictionAlertsEnabled(next.predictionAlerts);
      }
      if (previous.teamChatAlerts != next.teamChatAlerts) {
        await MessagingService.instance
            .setTeamChatAlertsEnabled(next.teamChatAlerts);
      }
      if (previous.matchRoomAlerts != next.matchRoomAlerts) {
        await MessagingService.instance
            .setMatchRoomAlertsEnabled(next.matchRoomAlerts);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            'Impossible de modifier les notifications : $e',
            'Unable to update notifications: $e',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _turnEverythingOff(AppProvider provider) async {
    final prefs = _prefs;
    if (prefs == null || _saving) return;
    setState(() => _saving = true);
    try {
      if (provider.voteRemindersEnabled) {
        await provider.setVoteRemindersEnabled(false);
      }
      if (provider.halftimeAlertsEnabled) {
        await provider.setHalftimeAlertsEnabled(false);
      }
      final next = prefs.copyWith(
        pushEnabled: false,
        generalAlerts: false,
        favoriteTeamAlerts: false,
        predictionAlerts: false,
        teamChatAlerts: false,
        matchRoomAlerts: false,
      );
      await MessagingService.instance.setGeneralAlertsEnabled(false);
      await MessagingService.instance.setFavoriteTeamAlertsEnabled(false);
      await MessagingService.instance.setPredictionAlertsEnabled(false);
      await MessagingService.instance.setTeamChatAlertsEnabled(false);
      await MessagingService.instance.setMatchRoomAlertsEnabled(false);
      await MessagingService.instance.setPushEnabled(false);
      if (!mounted) return;
      setState(() => _prefs = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            'Toutes les alertes sont coupées.',
            'All alerts are off.',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
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
                  Theme.of(context).colorScheme.surface.withOpacity(0.94),
              title: Text(
                context.tr('MES ALERTES', 'MY ALERTS'),
                style: GoogleFonts.bebasNeue(letterSpacing: 1.7),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                18,
                16,
                40 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _heroCard(context),
                  const SizedBox(height: 14),
                  if (!supported)
                    _infoCard(
                      context,
                      icon: Icons.phone_android_rounded,
                      title: context.tr(
                        'Notifications indisponibles ici',
                        'Notifications unavailable here',
                      ),
                      subtitle: context.tr(
                        'Les alertes fonctionnent sur Android et iPhone.',
                        'Alerts work on Android and iPhone.',
                      ),
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
                      context,
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.gold,
                      title: context.tr('Notifications push', 'Push notifications'),
                      subtitle: prefs.pushEnabled
                          ? context.tr(
                              'Actives. Choisis seulement ce qui t’intéresse.',
                              'On. Choose only what matters to you.',
                            )
                          : context.tr(
                              'Coupées. Aucun push ne sera envoyé.',
                              'Off. No push will be sent.',
                            ),
                      value: prefs.pushEnabled,
                      onChanged: _saving
                          ? null
                          : (value) => _setPrefs(prefs.copyWith(pushEnabled: value)),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(
                      context,
                      icon: Icons.sports_soccer_rounded,
                      title: context.tr('AVANT LES MATCHS', 'BEFORE MATCHES'),
                    ),
                    const SizedBox(height: 9),
                    _switchCard(
                      context,
                      icon: Icons.alarm_rounded,
                      color: AppColors.usaBlue,
                      title: context.tr(
                        'Rappel de pronostic · 30 min avant',
                        'Prediction reminder · 30 min before',
                      ),
                      subtitle: provider.voteRemindersEnabled
                          ? context.tr(
                              '${provider.scheduledReminderCount} rappel(s) programmé(s).',
                              '${provider.scheduledReminderCount} reminder(s) scheduled.',
                            )
                          : context.tr(
                              'Pas d’alerte pour chaque match : active seulement si tu le souhaites.',
                              'No alert for every match: enable it only if you want.',
                            ),
                      value: provider.voteRemindersEnabled,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              final ok = await provider.setVoteRemindersEnabled(value);
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.tr(
                                      'Autorisation de notification refusée.',
                                      'Notification permission denied.',
                                    )),
                                  ),
                                );
                              }
                            },
                    ),
                    if (provider.voteRemindersEnabled) ...[
                      const SizedBox(height: 10),
                      _scopeCard(context, provider),
                    ],
                    const SizedBox(height: 18),
                    _sectionTitle(
                      context,
                      icon: Icons.star_rounded,
                      title: context.tr('CE QUE JE SUIS', 'WHAT I FOLLOW'),
                    ),
                    const SizedBox(height: 9),
                    _switchCard(
                      context,
                      icon: Icons.star_rounded,
                      color: AppColors.mexicoGreen,
                      title: context.tr('Mes équipes ⭐', 'My teams ⭐'),
                      subtitle: context.tr(
                        provider.favoriteClubCodes.isEmpty
                            ? 'Aucune équipe suivie. Ouvre un match et touche ☆ pour suivre une équipe.'
                            : '${provider.favoriteClubCodes.length} équipe(s) suivie(s) · résultat final uniquement.',
                        provider.favoriteClubCodes.isEmpty
                            ? 'No team followed. Open a match and tap ☆ to follow a team.'
                            : '${provider.favoriteClubCodes.length} followed team(s) · final result only.',
                      ),
                      value: prefs.pushEnabled && prefs.favoriteTeamAlerts,
                      onChanged: (!_saving && prefs.pushEnabled)
                          ? (value) => _setPrefs(
                                prefs.copyWith(favoriteTeamAlerts: value),
                              )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _switchCard(
                      context,
                      icon: Icons.scoreboard_rounded,
                      color: AppColors.canadaRed,
                      title: context.tr(
                        'Tous les résultats',
                        'All results',
                      ),
                      subtitle: context.tr(
                        'Mode intensif : résultat de tous les matchs suivis par PRONO4.',
                        'Intensive mode: results from every match followed by PRONO4.',
                      ),
                      value: prefs.pushEnabled && prefs.generalAlerts,
                      onChanged: (!_saving && prefs.pushEnabled)
                          ? (value) => _setPrefs(prefs.copyWith(generalAlerts: value))
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(
                      context,
                      icon: Icons.groups_rounded,
                      title: context.tr('MON ÉQUIPE', 'MY TEAM'),
                    ),
                    const SizedBox(height: 9),
                    _switchCard(
                      context,
                      icon: Icons.ads_click_rounded,
                      color: AppColors.usaBlue,
                      title: context.tr(
                        'Rappels de pronostic équipe',
                        'Team prediction reminders',
                      ),
                      subtitle: context.tr(
                        'Exemple : tes coéquipiers ont tous joué, il ne manque plus que toi.',
                        'Example: your teammates have picked and only you are missing.',
                      ),
                      value: prefs.pushEnabled && prefs.predictionAlerts,
                      onChanged: (!_saving && prefs.pushEnabled)
                          ? (value) => _setPrefs(
                                prefs.copyWith(predictionAlerts: value),
                              )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _switchCard(
                      context,
                      icon: Icons.chat_bubble_rounded,
                      color: AppColors.mexicoGreen,
                      title: context.tr('Chat équipe', 'Team chat'),
                      subtitle: context.tr(
                        'Garde uniquement les messages importants de ton équipe.',
                        'Keep only important messages from your team.',
                      ),
                      value: prefs.pushEnabled && prefs.teamChatAlerts,
                      onChanged: (!_saving && prefs.pushEnabled)
                          ? (value) => _setPrefs(
                                prefs.copyWith(teamChatAlerts: value),
                              )
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(
                      context,
                      icon: Icons.tune_rounded,
                      title: context.tr('OPTIONNEL', 'OPTIONAL'),
                    ),
                    const SizedBox(height: 9),
                    _switchCard(
                      context,
                      icon: Icons.forum_rounded,
                      color: AppColors.canadaRed,
                      title: context.tr('Tribune du match', 'Match lounge'),
                      subtitle: context.tr(
                        'Désactivée par défaut pour éviter le spam. Active-la seulement si tu la veux.',
                        'Off by default to avoid spam. Enable it only if you want it.',
                      ),
                      value: prefs.pushEnabled && prefs.matchRoomAlerts,
                      onChanged: (!_saving && prefs.pushEnabled)
                          ? (value) => _setPrefs(
                                prefs.copyWith(matchRoomAlerts: value),
                              )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _switchCard(
                      context,
                      icon: Icons.timelapse_rounded,
                      color: AppColors.gold,
                      title: context.tr(
                        'Mi-temps · tous les matchs',
                        'Half-time · all matches',
                      ),
                      subtitle: context.tr(
                        'Option intensive. Laisse-la coupée si tu veux rester tranquille.',
                        'Intensive option. Keep it off for a quieter experience.',
                      ),
                      value: provider.halftimeAlertsEnabled,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              final ok = await provider.setHalftimeAlertsEnabled(value);
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.tr(
                                      'Autorisation de notification refusée.',
                                      'Notification permission denied.',
                                    )),
                                  ),
                                );
                              }
                            },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => _turnEverythingOff(provider),
                        icon: const Icon(Icons.notifications_off_rounded),
                        label: Text(context.tr('TOUT COUPER', 'TURN ALL OFF')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoCard(
                      context,
                      icon: Icons.info_outline_rounded,
                      title: context.tr('Simple à retenir', 'Easy to remember'),
                      subtitle: context.tr(
                        'Recommandé : Duels + Mes équipes. Tribune et Tous les résultats restent optionnels.',
                        'Recommended: Duels + My teams. Lounge and All results stay optional.',
                      ),
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

  Widget _scopeCard(BuildContext context, AppProvider provider) {
    final options = <_ReminderScopeOption>[
      _ReminderScopeOption('duels', context.tr('Duels', 'Duels'), Icons.flash_on_rounded),
      _ReminderScopeOption('favorites', context.tr('Mes équipes', 'My teams'), Icons.star_rounded),
      _ReminderScopeOption('all', context.tr('Tous', 'All'), Icons.sports_soccer_rounded),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Pour quels matchs ?', 'For which matches?'),
            style: GoogleFonts.barlow(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = provider.voteReminderScope == option.id;
              return ChoiceChip(
                avatar: Icon(option.icon, size: 17),
                label: Text(option.label),
                selected: selected,
                onSelected: _saving
                    ? null
                    : (_) => provider.setVoteReminderScope(option.id),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 8),
          Text(
            provider.voteReminderScope == 'duels'
                ? context.tr(
                    'Recommandé · seulement les grandes affiches PRONO4.',
                    'Recommended · only PRONO4 big matches.',
                  )
                : provider.voteReminderScope == 'favorites'
                    ? context.tr(
                        'Seulement les matchs avec une équipe marquée ★.',
                        'Only matches involving a ★ followed team.',
                      )
                    : context.tr(
                        'Intensif · tous les matchs non pronostiqués.',
                        'Intensive · every match without a prediction.',
                      ),
            style: GoogleFonts.barlow(
              color: AppColors.text2,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withOpacity(.16),
            AppColors.mexicoGreen.withOpacity(.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.gold.withOpacity(.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.notifications_none_rounded, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'À toi de choisir ce qui sonne',
                    'You choose what can notify you',
                  ),
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Par défaut : pas de tribune et pas de résultat pour chaque match.',
                    'By default: no lounge alerts and no result alert for every match.',
                  ),
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

  Widget _sectionTitle(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.mexicoGreen, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.barlowCondensed(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _switchCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(.22)),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.overlayBase.withOpacity(.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.text2, size: 21),
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


class _ReminderScopeOption {
  final String id;
  final String label;
  final IconData icon;

  const _ReminderScopeOption(this.id, this.label, this.icon);
}
