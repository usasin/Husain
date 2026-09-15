import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'notification_settings_screen.dart';
import 'support_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final user = prov.currentUser;
    final blocked = prov.blockedUserIds.toList();

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: Text(context.tr('PARAMÈTRES', 'SETTINGS')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionTitle(context.tr('PRÉFÉRENCES', 'PREFERENCES')),
          _tile(
            icon: Icons.notifications_active_rounded,
            title: context.tr('Notifications', 'Notifications'),
            subtitle: context.tr(
              'Rappels de pronostics et alertes de match',
              'Prediction reminders and match alerts',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          _tile(
            icon: Icons.support_agent_rounded,
            title: context.tr('Aide et support', 'Help and support'),
            subtitle: context.tr(
              'Contacter le support PRONO4',
              'Contact PRONO4 support',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(context.tr('CONFIDENTIALITÉ', 'PRIVACY')),
          _card(
            children: [
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppColors.canadaRed),
                title: Text(
                  context.tr('Joueurs bloqués', 'Blocked players'),
                  style: GoogleFonts.inter(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  blocked.isEmpty
                      ? context.tr('Aucun joueur bloqué', 'No blocked players')
                      : context.tr(
                          '${blocked.length} joueur(s) bloqué(s)',
                          '${blocked.length} blocked player(s)',
                        ),
                  style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
                ),
              ),
              if (blocked.isNotEmpty) ...[
                const Divider(height: 1),
                ...blocked.map((uid) {
                  String name = context.tr('Joueur', 'Player');
                  for (final u in prov.users) {
                    if (u.id == uid) {
                      name = u.name;
                      break;
                    }
                  }
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_off_rounded, size: 20),
                    title: Text(name, style: TextStyle(color: AppColors.text)),
                    trailing: TextButton(
                      onPressed: () async {
                        final error = await prov.unblockUser(uid);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error ?? context.tr(
                              '$name est débloqué.',
                              '$name is unblocked.',
                            )),
                          ),
                        );
                      },
                      child: Text(context.tr('Débloquer', 'Unblock')),
                    ),
                  );
                }),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle(context.tr('COMPTE', 'ACCOUNT')),
          if (user != null)
            _card(
              children: [
                ListTile(
                  leading: const Icon(Icons.key_rounded, color: AppColors.lime),
                  title: Text(
                    context.tr('Code de récupération', 'Recovery code'),
                    style: GoogleFonts.inter(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: SelectableText(
                    user.recoveryCode.isEmpty
                        ? context.tr('Code en cours de synchronisation', 'Code is syncing')
                        : user.recoveryCode,
                    style: GoogleFonts.spaceGrotesk(
                      color: user.recoveryCode.isEmpty ? AppColors.text2 : AppColors.lime,
                      fontSize: user.recoveryCode.isEmpty ? 12 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: user.recoveryCode.isEmpty ? 0 : 2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    context.tr(
                      'Conserve ce code. Il permet de récupérer ton profil sur un autre appareil.',
                      'Keep this code. It can restore your profile on another device.',
                    ),
                    style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          _card(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: AppColors.canadaRed),
                title: Text(
                  context.tr('Supprimer mon profil', 'Delete my profile'),
                  style: GoogleFonts.inter(
                    color: AppColors.canadaRed,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  context.tr(
                    'Suppression définitive du profil et des données associées.',
                    'Permanently delete the profile and associated data.',
                  ),
                  style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
                ),
                onTap: _deleting ? null : () => _confirmDelete(prov),
              ),
              if (_deleting)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'PRONO4 · 2.5.3',
              style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(AppProvider prov) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Supprimer le profil ?', 'Delete profile?')),
        content: Text(context.tr(
          'Cette action est définitive. Tes pronostics, messages et données de profil seront supprimés.',
          'This action is permanent. Your predictions, messages and profile data will be deleted.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Annuler', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.canadaRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Supprimer', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final error = await prov.deleteAccount();
    if (!mounted) return;
    setState(() => _deleting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? context.tr(
          'Profil supprimé.',
          'Profile deleted.',
        )),
      ),
    );
    if (error == null && mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: Icon(icon, color: AppColors.lime),
            title: Text(
              title,
              style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              subtitle,
              style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ),
        ),
      );

  Widget _card({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
        ),
        child: Column(children: children),
      );
}
