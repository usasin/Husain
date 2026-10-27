import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/avatar_display.dart';
import '../widgets/social_auth_panel.dart';
import '../widgets/sources_licenses_tile.dart';
import '../widgets/competition_settings_card.dart';
import '../widgets/language_settings_card.dart';
import '../widgets/theme_settings_card.dart';
import '../widgets/wc26_background.dart';
import 'admin_community_screen.dart';
import 'admin_content_screen.dart';
import 'admin_dynamic_pages_screen.dart';
import 'admin_duel_matches_screen.dart';
import 'admin_duel_visuals_screen.dart';
import 'admin_support_screen.dart';
import 'admin_reward_preview_screen.dart';
import 'admin_europa_league_screen.dart';
import 'notification_settings_screen.dart';
import 'support_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String initialSection;
  const SettingsScreen({super.key, this.initialSection = 'preferences'});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _adminMsg = '';
  String _settingsSection = 'preferences';

  @override
  void initState() {
    super.initState();
    _settingsSection = widget.initialSection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppProvider>().refreshAdminAccess();
    });
  }

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mundial.app';
  static const String _appStoreId = String.fromEnvironment(
    'APP_STORE_ID',
    defaultValue: '',
  );
  static const String _appStoreSearchUrl =
      'https://apps.apple.com/fr/search?term=PRONO4';

  String get _storeShareUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return _appStoreId.isNotEmpty
          ? 'https://apps.apple.com/app/id$_appStoreId'
          : _appStoreSearchUrl;
    }
    return _playStoreUrl;
  }

  Future<void> _shareApp() async {
    await Share.share(
      '${context.tr('⚽ Rejoins PRONO4 et prouve à tes amis que tu connais vraiment le foot !', '⚽ Join PRONO4 and prove to your friends you really know football!')}\n$_storeShareUrl',
      subject: context.tr(
        'PRONO4 – Le foot se pronostique en équipe',
        'PRONO4 – Football predictions are better as a team',
      ),
    );
  }

  Future<void> _rateApp() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      if (_appStoreId.isEmpty) {
        await launchUrl(
          Uri.parse(_appStoreSearchUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }
      await launchUrl(
        Uri.parse(
          'itms-apps://itunes.apple.com/app/id$_appStoreId?action=write-review',
        ),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    final marketUri = Uri.parse('market://details?id=com.mundial.app');
    if (!kIsWeb && await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(
      Uri.parse(_playStoreUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _recoverOldProfile(AppProvider prov) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(
          context.tr(
            'RÉCUPÉRER MON ANCIEN PROFIL',
            'RECOVER MY OLD PROFILE',
          ),
          style: GoogleFonts.bebasNeue(letterSpacing: 1.2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                'Entre ton code personnel de 8 caractères. Ton équipe, tes pronostics et ton classement seront transférés sur ce téléphone.',
                'Enter your 8-character personal code. Your team, predictions and ranking will be restored on this device.',
              ),
              style: GoogleFonts.barlow(color: AppColors.text2, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 8,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
              ],
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              style: GoogleFonts.bebasNeue(
                color: AppColors.gold,
                fontSize: 24,
                letterSpacing: 3,
              ),
              decoration: InputDecoration(
                labelText: context.tr('Code personnel', 'Personal code'),
                hintText: 'XXXXXXXX',
                counterText: '',
                prefixIcon:
                    const Icon(Icons.key_rounded, color: AppColors.gold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.tr('Récupérer', 'Recover')),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (code == null || code.trim().isEmpty || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final error = await prov.recoverProfileWithCode(code);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              context.tr(
                'Ancien profil récupéré avec succès.',
                'Old profile recovered successfully.',
              ),
        ),
        backgroundColor:
            error == null ? AppColors.mexicoGreen : AppColors.canadaRed,
      ),
    );
  }

  Future<void> _manageBlockedUsers(AppProvider prov) async {
    final blocked = prov.blockedUserIds.toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('JOUEURS BLOQUÉS', 'BLOCKED PLAYERS'),
                style: GoogleFonts.bebasNeue(
                  color: AppColors.text,
                  fontSize: 22,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.tr(
                  'Leurs messages sont masqués pour toi uniquement. Ils restent dans les équipes et ne sont pas avertis.',
                  'Their messages are hidden only for you. They stay in teams and are not notified.',
                ),
                style: GoogleFonts.inter(
                  color: AppColors.text2,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              if (blocked.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      context.tr('Aucun joueur bloqué.', 'No blocked players.'),
                      style: GoogleFonts.inter(
                        color: AppColors.text2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              else
                ...blocked.map((id) {
                  AppUser? user;
                  for (final candidate in prov.users) {
                    if (candidate.id == id) {
                      user = candidate;
                      break;
                    }
                  }
                  final name = user?.name ?? context.tr('Joueur', 'Player');
                  final avatar = user?.avatar ?? '⚽';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarBubble(avatar: avatar, size: 38),
                    title: Text(
                      name,
                      style: GoogleFonts.inter(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        await prov.unblockUser(id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(context.tr('Débloquer', 'Unblock')),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  /// Une déconnexion n'est pas une suppression de compte.
  Future<void> _signOut(AppProvider prov) async {
    final profile = prov.currentUser;
    if (profile == null) return;
    final linked = prov.hasConnectedAccount;
    final code = prov.privateRecoveryCode;
    final hasValidCode = RegExp(r'^[A-F0-9]{32}$').hasMatch(code);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.tr('SE DÉCONNECTER ?', 'SIGN OUT?')),
        content: Text(
          linked
              ? context.tr(
                  'Tu quitteras ce compte sur cet appareil. Tes points, pronostics, duels et ton équipe restent enregistrés. Pour les retrouver, reconnecte-toi avec Google ou Apple.',
                  'You will sign out on this device. Your points, predictions, duels and team remain saved. Sign back in with Google or Apple.',
                )
              : context.tr(
                  'Ce profil est encore utilisé avec un code. Note ton code de récupération avant de continuer : après la déconnexion, tu en auras besoin pour retrouver tes données. Code : ${!hasValidCode ? "INDISPONIBLE" : code}',
                  'This profile still uses a code. Save your recovery code before continuing: you will need it to restore your data. Code: ${!hasValidCode ? "UNAVAILABLE" : code}',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.tr('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: !linked && !hasValidCode
                ? null
                : () => Navigator.pop(dialog, true),
            child: Text(context.tr('Me déconnecter', 'Sign out')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error = await prov.signOutCurrentAccount();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: AppColors.canadaRed),
    );
  }

  Future<void> _deleteProfile(AppProvider prov) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.tr('SUPPRIMER LE COMPTE ?', 'DELETE ACCOUNT?'),
          style: GoogleFonts.bebasNeue(letterSpacing: 1.1),
        ),
        content: Text(
          context.tr(
            'Cette action supprime ton compte/profil PRONO4, tes pronostics, ton classement et ton code de récupération. Cette action est définitive.',
            'This deletes your PRONO4 account/profile, predictions, ranking and recovery code. This action is permanent.',
          ),
          style: GoogleFonts.inter(color: AppColors.text2, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.canadaRed),
            child: Text(
              context.tr('Supprimer définitivement', 'Delete permanently'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final error = await prov.deleteCurrentProfile();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.canadaRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppThemeController>();
    final prov = context.watch<AppProvider>();
    final code = prov.privateRecoveryCode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withOpacity(.94),
              title: Text(
                context.tr('PARAMÈTRES', 'SETTINGS'),
                style: GoogleFonts.bebasNeue(
                  letterSpacing: 1.5,
                  fontSize: 22,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                40 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _introCard(),
                  Center(
                      child: Text('PRONO4 2.8.20 · ${const String.fromEnvironment('APP_BUILD_NUMBER', defaultValue: '101')}',
                          key: const Key('installed-app-version'),
                          style:
                              TextStyle(color: AppColors.text2, fontSize: 11))),
                  const SizedBox(height: 14),
                  _sectionChips(prov),
                  const SizedBox(height: 16),
                  if (_settingsSection == 'preferences') ...[
                    _groupTitle(context.tr('PRÉFÉRENCES', 'PREFERENCES')),
                    const SizedBox(height: 10),
                    const ThemeSettingsCard(),
                    const SizedBox(height: 10),
                    const LanguageSettingsCard(),
                    const SizedBox(height: 10),
                    const CompetitionSettingsCard(),
                    const SizedBox(height: 22),
                  ],
                  if (_settingsSection == 'notifications') ...[
                    _groupTitle(context.tr('NOTIFICATIONS', 'NOTIFICATIONS')),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.tune_rounded,
                      title: context.tr(
                        'Notifications push',
                        'Push notifications',
                      ),
                      subtitle: context.tr(
                        'Choisir précisément ce qui peut sonner',
                        'Choose exactly what can notify you',
                      ),
                      color: AppColors.gold,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _infoCard(
                      context.tr('Tout est regroupé au même endroit',
                          'Everything is in one place'),
                      context.tr(
                        'Duels, équipes suivies, pronostics, chat et tribune se règlent dans « Notifications push ».',
                        'Duels, followed teams, predictions, chat and lounge are all managed in “Push notifications”.',
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                  if (_settingsSection == 'privacy') ...[
                    _groupTitle(context.tr('CONFIDENTIALITÉ', 'PRIVACY')),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.privacy_tip_outlined,
                      title: context.tr(
                        'Confidentialité des publicités',
                        'Ad privacy',
                      ),
                      subtitle: context.tr(
                        'Consulter ou modifier mes choix',
                        'Review or change my choices',
                      ),
                      color: AppColors.mexicoGreen,
                      onTap: () async {
                        final error =
                            await AdService.instance.showPrivacyOptions();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error ??
                                  context.tr(
                                    'Options de confidentialité ouvertes.',
                                    'Privacy options opened.',
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.block_rounded,
                      title: context.tr('Joueurs bloqués', 'Blocked players'),
                      subtitle: prov.blockedUserIds.isEmpty
                          ? context.tr(
                              'Aucun joueur bloqué',
                              'No blocked players',
                            )
                          : context.tr(
                              '${prov.blockedUserIds.length} joueur(s) · gérer ou débloquer',
                              '${prov.blockedUserIds.length} player(s) · manage or unblock',
                            ),
                      color: AppColors.canadaRed,
                      onTap: () => _manageBlockedUsers(prov),
                    ),
                    const SizedBox(height: 22),
                  ],
                  if (_settingsSection == 'account') ...[
                    _groupTitle(
                      context.tr('COMPTE & SÉCURITÉ', 'ACCOUNT & SECURITY'),
                    ),
                    const SizedBox(height: 10),
                    _recoveryCodeCard(code),
                    const SizedBox(height: 12),
                    const SocialAuthPanel(),
                    const SizedBox(height: 12),
                    _actionCard(
                      icon: Icons.manage_accounts_rounded,
                      title: context.tr(
                        'Récupérer mon ancien profil',
                        'Recover my old profile',
                      ),
                      subtitle: context.tr(
                        'Retrouver mon équipe, mes pronostics et mon classement',
                        'Recover my team, predictions and ranking',
                      ),
                      color: AppColors.mexicoGreen,
                      onTap: () => _recoverOldProfile(prov),
                    ),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.logout_rounded,
                      title: context.tr('Se déconnecter', 'Sign out'),
                      subtitle: context.tr(
                        'Quitter ce téléphone sans effacer mon compte ni mes points',
                        'Leave this device without deleting my account or points',
                      ),
                      color: AppColors.usaBlue,
                      onTap: () => _signOut(prov),
                    ),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.delete_forever_rounded,
                      title: context.tr(
                        'Supprimer mon compte et mes données',
                        'Delete my account and data',
                      ),
                      subtitle: context.tr(
                        'Profil, pronostics, classement et code de récupération',
                        'Profile, predictions, ranking and recovery code',
                      ),
                      color: AppColors.canadaRed,
                      onTap: () => _deleteProfile(prov),
                    ),
                    const SizedBox(height: 22),
                  ],
                  if (_settingsSection == 'app') ...[
                    _groupTitle(context.tr('APPLICATION', 'APP')),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.share_rounded,
                      title: context.tr(
                        'Partager l’application',
                        'Share the app',
                      ),
                      subtitle: context.tr(
                        'Inviter mes amis à jouer',
                        'Invite friends to play',
                      ),
                      color: AppColors.usaBlue,
                      onTap: _shareApp,
                    ),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.star_rounded,
                      title: context.tr(
                        'Noter l’application',
                        'Rate the app',
                      ),
                      subtitle:
                          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                              ? context.tr(
                                  'Ouvrir l’App Store',
                                  'Open the App Store',
                                )
                              : context.tr(
                                  'Donner une note sur Google Play',
                                  'Leave a Google Play rating',
                                ),
                      color: AppColors.gold,
                      onTap: _rateApp,
                    ),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.help_outline_rounded,
                      title: context.tr('Aide & Contact', 'Help & Contact'),
                      subtitle: context.tr(
                        'Une question ou un souci ? Écris-nous',
                        'A question or issue? Contact us',
                      ),
                      color: AppColors.cyan,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SupportScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const SourcesLicensesTile(),
                  ],
                  if (_settingsSection == 'admin') ...[
                    if (!prov.adminMode) ...[
                      const SizedBox(height: 22),
                      _groupTitle('ADMINISTRATION'),
                      const SizedBox(height: 10),
                      _actionCard(
                        icon: Icons.admin_panel_settings_rounded,
                        title: context.tr('Vérifier mon accès admin',
                            'Check my admin access'),
                        subtitle: context.tr(
                          'Recharge le champ isAdmin de ton profil Firebase',
                          'Reload the isAdmin field from your Firebase profile',
                        ),
                        color: AppColors.gold,
                        onTap: () async {
                          final ok = await prov.refreshAdminAccess();
                          if (!mounted) return;
                          setState(() {
                            _adminMsg = ok
                                ? '✅ Accès admin confirmé.'
                                : 'Accès admin non trouvé sur ce profil Firebase.';
                          });
                        },
                      ),
                      if (_adminMsg.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _adminMsg,
                          style: GoogleFonts.barlowCondensed(
                            color: AppColors.text2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                    if (prov.adminMode) ...[
                      const SizedBox(height: 22),
                      _groupTitle('ADMINISTRATION'),
                      const SizedBox(height: 10),
                      _actionCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Tester les animations',
                        subtitle: 'Points et badges fictifs · Aucun changement réel',
                        color: AppColors.lime,
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const AdminRewardPreviewScreen(),
                          ));
                        },
                      ),
                      const SizedBox(height: 8),
                      _actionCard(
                        icon: Icons.emoji_events_rounded,
                        title: 'Ligue Europa · Matchs et résultats',
                        subtitle: 'Créer les matchs et saisir les scores',
                        color: AppColors.gold,
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const AdminEuropaLeagueScreen(),
                          ));
                        },
                      ),
                      const SizedBox(height: 8),
                      _actionCard(
                        icon: Icons.sports_soccer_rounded,
                        title: context.tr('Matchs des duels', 'Duel matches'),
                        subtitle: context.tr(
                          'Ajouter ou retirer les grands matchs du jour',
                          'Add or remove today’s big matches',
                        ),
                        color: AppColors.gold,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminDuelMatchesScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _actionCard(
                        icon: Icons.photo_library_rounded,
                        title: context.tr('Visuels des duels', 'Duel visuals'),
                        subtitle: context.tr(
                          'Choisir une image responsive pour chaque compétition',
                          'Choose a responsive image for each competition',
                        ),
                        color: AppColors.lime,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminDuelVisualsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _actionCard(
                        icon: Icons.dashboard_customize_rounded,
                        title: 'Contenu dynamique',
                        subtitle: 'Ajouter images, textes et cartes d’accueil',
                        color: AppColors.cyan,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminContentScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _actionCard(
                        icon: Icons.article_rounded,
                        title: 'Pages dynamiques',
                        subtitle: 'Créer des pages sans mise à jour',
                        color: AppColors.violet,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminDynamicPagesScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _actionCard(
                        icon: Icons.forum_rounded,
                        title: 'Messagerie (admin)',
                        subtitle: 'Répondre aux joueurs · publier une annonce',
                        color: AppColors.gold,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminSupportScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _actionCard(
                        icon: Icons.stadium_rounded,
                        title: 'Animation salons',
                        subtitle: 'Activer/désactiver salons · message épinglé',
                        color: AppColors.mexicoGreen,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminCommunityScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.overlayBase.withOpacity(.04),
                        ),
                        child: const Text(
                          'Matchs et classements : mises à jour automatiques côté serveur.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      if (_adminMsg.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _adminMsg,
                          style: GoogleFonts.barlowCondensed(
                            color: AppColors.text2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'PRONO4 · 2.8.4 (83)',
                      style: GoogleFonts.inter(
                        color: AppColors.text2,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionChips(AppProvider prov) {
    final sections = <({String key, String label, IconData icon, Color color})>[
      (
        key: 'preferences',
        label: context.tr('Préférences', 'Preferences'),
        icon: Icons.tune_rounded,
        color: AppColors.lime
      ),
      (
        key: 'notifications',
        label: context.tr('Notifications', 'Notifications'),
        icon: Icons.notifications_active_rounded,
        color: AppColors.gold
      ),
      (
        key: 'privacy',
        label: context.tr('Confidentialité', 'Privacy'),
        icon: Icons.shield_outlined,
        color: AppColors.usaBlue
      ),
      (
        key: 'account',
        label: context.tr('Compte & données', 'Account & data'),
        icon: Icons.lock_person_rounded,
        color: AppColors.canadaRed
      ),
      (
        key: 'app',
        label: context.tr('Application', 'App'),
        icon: Icons.apps_rounded,
        color: AppColors.mexicoGreen
      ),
      (
        key: 'admin',
        label: 'Admin',
        icon: Icons.admin_panel_settings_rounded,
        color: AppColors.gold
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: sections.map((item) {
          final selected = _settingsSection == item.key;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => setState(() => _settingsSection = item.key),
            avatar: Icon(
              item.icon,
              size: 16,
              color: selected ? AppColors.bg0 : item.color,
            ),
            label: Text(item.label),
            labelStyle: GoogleFonts.barlowCondensed(
              color: selected ? AppColors.bg0 : AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            selectedColor: item.color,
            backgroundColor: AppColors.bg3,
            side: BorderSide(
              color: selected
                  ? item.color
                  : AppColors.overlayBase.withOpacity(.12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.usaBlue.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: AppColors.usaBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Tout au même endroit', 'Everything in one place'),
                  style: GoogleFonts.inter(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(
                    'Préférences, notifications, confidentialité et sécurité du compte.',
                    'Preferences, notifications, privacy and account security.',
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
    );
  }

  Widget _recoveryCodeCard(String code) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded,
                  color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(
                    'MON CODE DE RÉCUPÉRATION',
                    'MY RECOVERY CODE',
                  ),
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Garde-le en lieu sûr pour retrouver ton profil après une réinstallation ou un changement de téléphone.',
              'Keep it safe to restore your profile after reinstalling or changing phone.',
            ),
            style: GoogleFonts.inter(
              color: AppColors.text2,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (code.isEmpty)
            Text(
              context.tr(
                'Code privé indisponible. Réessaie avec Internet ou associe Google/Apple avant de quitter ce profil.',
                'Private code unavailable. Retry online or link Google/Apple before leaving this profile.',
              ),
              style: GoogleFonts.inter(
                color: AppColors.text2,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bg1,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: context.tr('Copier', 'Copy'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr(
                            'Code copié ✅',
                            'Code copied ✅',
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _groupTitle(String title) {
    final upper = title.toUpperCase();
    IconData icon = Icons.tune_rounded;
    Color accent = AppColors.usaBlue;
    if (upper.contains('NOTIF')) {
      icon = Icons.notifications_active_rounded;
      accent = AppColors.gold;
    } else if (upper.contains('CONFIDENT') || upper.contains('PRIVACY')) {
      icon = Icons.shield_outlined;
      accent = AppColors.mexicoGreen;
    } else if (upper.contains('COMPTE') || upper.contains('ACCOUNT')) {
      icon = Icons.lock_person_rounded;
      accent = AppColors.cyan;
    } else if (upper.contains('APPLICATION') || upper == 'APP') {
      icon = Icons.apps_rounded;
      accent = AppColors.violet;
    } else if (upper.contains('ADMIN')) {
      icon = Icons.admin_panel_settings_rounded;
      accent = AppColors.lime;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withOpacity(.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 7),
            Text(
              title,
              style: GoogleFonts.barlowCondensed(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: AppColors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppColors.text2,
                        fontSize: 10,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.text2, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.text2,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required Color color,
    required Future<void> Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.text2,
                    fontSize: 10,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? (v) => onChanged(v) : null,
          ),
        ],
      ),
    );
  }
}
