import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
import '../services/social_auth_service.dart';
import '../theme/app_theme.dart';

class SocialAuthPanel extends StatelessWidget {
  final VoidCallback? onConnected;
  final bool compact;
  const SocialAuthPanel({super.key, this.onConnected, this.compact = false});
  Future<void> _connect(BuildContext context, String id) async {
    final provider = context.read<AppProvider>();
    var result = await provider.connectSocial(id);
    if (!context.mounted) return;
    if (result.status == SocialAuthStatus.conflict) {
      if (provider.currentUser != null) {
        await showDialog<void>(context: context, builder: (dialog) => AlertDialog(
          title: Text(context.tr('Compte déjà associé', 'Account already linked')),
          content: Text(context.tr(
            'Ce compte appartient à un autre profil PRONO4. Ton profil actuel reste ouvert avec ses points et son équipe. Pour changer de profil, sécurise d’abord ton accès dans les réglages, puis déconnecte-toi explicitement.',
            'This account belongs to another PRONO4 profile. Your current profile stays open with its points and team. To switch profiles, first secure your access in settings, then explicitly sign out.')),
          actions: [TextButton(onPressed: () => Navigator.pop(dialog),
            child: Text(context.tr('Garder mon profil', 'Keep my profile')))],
        ));
        return;
      }
      // Rien n'est fusionné. Un changement de profil nécessite une confirmation
      // puis une NOUVELLE authentification chez Google / Apple.
      final openExisting = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(context.tr('Compte déjà associé', 'Account already linked')),
          content: Text(context.tr(
            'Ce compte Google ou Apple est déjà associé à un autre profil PRONO4. '
            'Ton profil actuel et ses points resteront intacts. '
            'Veux-tu te connecter au compte déjà associé ?',
            'This Google or Apple account is already linked to another PRONO4 profile. '
            'Your current profile and points will remain unchanged. '
            'Do you want to sign in to the linked account?',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(context.tr('Rester ici', 'Stay here')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(context.tr('Ouvrir ce compte', 'Open this account')),
            ),
          ],
        ),
      );
      if (openExisting != true || !context.mounted) return;
      result = await provider.connectSocial(id, useExistingAccount: true);
      if (!context.mounted) return;
    }
    if (result.status == SocialAuthStatus.conflict) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(
          'Ce compte est déjà associé. Aucun profil n’a été modifié.',
          'This account is already linked. No profile was changed.',
        )),
      ));
      return;
    }
    if (result.status == SocialAuthStatus.canceled) return;
    if (result.status == SocialAuthStatus.connected) {
      onConnected?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Connexion réussie. Ton profil PRONO4 est conservé.',
              'Signed in successfully. Your PRONO4 profile is preserved.',
            ),
          ),
        ),
      );
      return;
    }
    const configuration = {
      'operation-not-allowed',
      'sign_in_failed',
      'invalid-oauth-client-id',
      'unauthorized-domain',
      'app-not-authorized',
      'invalid-credential',
    };
    final message = result.code == 'legacy-link-requires-secure-recovery'
        ? context.tr(
            'Ton ancien profil doit être sécurisé avant l’association. Ne te déconnecte pas : tes points et ton équipe sont conservés.',
            'Your older profile must be secured before linking. Do not sign out: your points and team are preserved.',
          )
        : result.code == 'profile-sync-pending'
        ? context.tr(
            'Ton profil doit finir de se synchroniser. Réessaie avec Internet.',
            'Your profile needs to finish syncing. Try again with Internet.',
          )
        : result.code == 'legacy-code-unavailable'
            ? context.tr(
                'Ce profil n’a pas de code enregistré. Ne te déconnecte pas : utilise la récupération du profil pour sécuriser tes points.',
                'This profile has no saved code. Do not sign out: restore the profile first to keep your points.',
              )
            : result.code == 'legacy-session-not-verified'
                ? context.tr(
                    'Impossible de vérifier ton ancien profil pour le moment. Rien n’a été transféré. Vérifie Internet et réessaie sans te déconnecter.',
                    'Unable to verify your previous profile yet. No data was moved. Check your connection and retry without signing out.',
                  )
                : result.code == 'profile-session-mismatch'
                    ? context.tr(
                        'Le profil doit être vérifié avant de l’associer.',
                        'Your profile must be verified before linking it.',
                      )
                    : configuration.contains(result.code)
                ? context.tr(
                    'Cette connexion doit être configurée pour cette version de PRONO4.',
                    'This sign-in method needs to be configured for this version of PRONO4.',
                  )
                : context.tr(
                    'Connexion impossible. Vérifie Internet puis réessaie.',
                    'Unable to sign in. Check Internet and try again.',
                  );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final google = provider.isProviderLinked('google.com');
    final apple = provider.isProviderLinked('apple.com');
    final busy = provider.socialAuthBusy;
    if (compact) {
      return Container(
          key: const Key('home-account-access'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lime.withValues(alpha: .4))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                context.tr('Connecte-toi pour garder tes points',
                    'Sign in to keep your points'),
                style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      key: const Key('home-google-sign-in'),
                      onPressed: busy || google
                          ? null
                          : () => _connect(context, 'google.com'),
                      icon: Icon(
                          google
                              ? Icons.check_circle_rounded
                              : Icons.login_rounded,
                          size: 18),
                      label: Text(google
                          ? context.tr('Google lié', 'Google linked')
                          : 'Google'))),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton.icon(
                      key: const Key('home-apple-sign-in'),
                      onPressed: busy || apple
                          ? null
                          : () => _connect(context, 'apple.com'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white),
                      icon: Icon(
                          apple ? Icons.check_circle_rounded : Icons.apple,
                          size: 20),
                      label: Text(apple
                          ? context.tr('Apple lié', 'Apple linked')
                          : 'Apple'))),
            ]),
            if (busy) const LinearProgressIndicator(),
          ]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          provider.hasConnectedAccount
              ? context.tr(
                  'Ton compte est connecté',
                  'Your account is connected',
                )
              : context.tr(
                  'Connecte-toi pour conserver ton profil',
                  'Sign in to keep your profile',
                ),
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(
            'Retrouve ton équipe et tes pronostics en changeant de téléphone.',
            'Restore your team and predictions when you change phones.',
          ),
          style: TextStyle(color: AppColors.text2, fontSize: 12),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed:
              busy || google ? null : () => _connect(context, 'google.com'),
          icon: Icon(
            google ? Icons.check_circle_rounded : Icons.login_rounded,
            size: 20,
          ),
          label: Text(
            google
                ? context.tr('Google connecté', 'Google connected')
                : context.tr('Continuer avec Google', 'Continue with Google'),
          ),
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed:
              busy || apple ? null : () => _connect(context, 'apple.com'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          icon: Icon(
            apple ? Icons.check_circle_rounded : Icons.apple,
            size: 22,
          ),
          label: Text(
            apple
                ? context.tr('Apple connecté', 'Apple connected')
                : context.tr('Continuer avec Apple', 'Continue with Apple'),
          ),
        ),
        if (provider.hasConnectedAccount && provider.currentUser == null)
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    try {
                      await provider.refreshConnectedProfile();
                      if (context.mounted) onConnected?.call();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(
                                'Profil indisponible. Vérifie Internet.',
                                'Profile unavailable. Check Internet.',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
            child: Text(context.tr('Charger mon profil', 'Load my profile')),
          ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class AccountSafetyBanner extends StatelessWidget {
  const AccountSafetyBanner({super.key});
  @override
  Widget build(BuildContext context) {
    if (context.watch<AppProvider>().hasConnectedAccount) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.lock_outline_rounded, size: 18),
      label: Text(
        context.tr(
          'Connecte-toi pour conserver ton profil',
          'Sign in to keep your profile',
        ),
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: SocialAuthPanel(),
            ),
          ),
        ),
      ),
    );
  }
}
