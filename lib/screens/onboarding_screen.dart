import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/wc26_background.dart';
import '../widgets/avatar_display.dart';
import '../widgets/avatar_picker.dart';
import '../l10n/app_locale.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  String _name = '';
  String _avatar = '⚽';
  bool _loading = false;
  late final AnimationController _trophyCtrl;
  late final Animation<double> _trophyAnim;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _trophyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _trophyAnim = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _trophyCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _trophyCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _openPicker() async {
    final result = await AvatarPicker2026.show(context, _avatar);
    if (result != null && mounted) {
      setState(() => _avatar = result);
    }
  }

  Future<void> _recoverExistingProfile() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(
          context.tr('RÉCUPÉRER MON PROFIL','RECOVER MY PROFILE'),
          style: GoogleFonts.bebasNeue(letterSpacing: 1.4),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Entrez le code de récupération si vous l’aviez noté. Si vous n’avez jamais eu de code, appuyez sur COMMENCER pour créer un nouveau profil.','Enter your recovery code if you saved one. If you never had a code, tap START to create a new profile.'),
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
              decoration: const InputDecoration(
                hintText: 'XXXXXXXX',
                counterText: '',
                prefixIcon: Icon(Icons.key_rounded, color: AppColors.gold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Annuler','Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.tr('Récupérer','Recover')),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (code == null || code.trim().isEmpty || !mounted) return;

    setState(() => _loading = true);
    final error =
        await context.read<AppProvider>().recoverProfileWithCode(code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) _message(error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: WC2026Background(
        intense: true,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _step == 0 ? _buildWelcome() : _buildProfile(),
          ),
        ),
      ),
    );
  }

  // ── Step 0 : Welcome ────────────────────────────────────
  Widget _buildWelcome() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 720;
        final trophySize = isSmall ? 54.0 : 82.0;
        final titleSize = isSmall ? 46.0 : 64.0;
        final padding = isSmall ? 16.0 : 24.0;
        final featurePadding = isSmall ? 14.0 : 20.0;

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: constraints.maxHeight - padding * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _trophyAnim,
                  builder: (_, __) => Transform.rotate(
                    angle: _trophyAnim.value,
                    child: Container(
                      width: trophySize * 1.55,
                      height: trophySize * 1.55,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.lime.withOpacity(.32)),
                        boxShadow: [BoxShadow(color: AppColors.lime.withOpacity(.16), blurRadius: 24)],
                      ),
                      child: Text('P4', style: GoogleFonts.spaceGrotesk(color: AppColors.lime, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: trophySize * .72, letterSpacing: -3)),
                    ),
                  ),
                ),
                SizedBox(height: isSmall ? 8 : 14),
                const WC2026Wordmark(fontSize: 12),
                const SizedBox(height: 6),
                ShaderMask(
                  shaderCallback: (r) =>
                      AppColors.trophyGradient.createShader(r),
                  child: Text(
                    'PRONO4',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: titleSize,
                      height: 0.95,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                SizedBox(height: isSmall ? 8 : 12),
                Text(
                  context.tr('Le foot se pronostique en équipe.','Football predictions are better as a team.'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.text2,
                    fontSize: isSmall ? 14 : 16,
                  ),
                ),
                SizedBox(height: isSmall ? 16 : 24),

                // Compétitions phares
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    _hostBadge('🇫🇷 LIGUE 1', AppColors.cyan),
                    _hostBadge('🏴 PREMIER LEAGUE', AppColors.violet),
                    _hostBadge('⭐ CHAMPIONS', AppColors.gold),
                  ],
                ),
                SizedBox(height: isSmall ? 16 : 22),

                Container(
                  padding: EdgeInsets.all(featurePadding),
                  decoration: BoxDecoration(
                    color: AppColors.bg2.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.gold.withOpacity(0.18)),
                  ),
                  child: Column(
                    children: [
                      _feature('⚡', context.tr('Pronostiquez les grands matchs','Predict the biggest matches'), isSmall),
                      _feature('👥', context.tr('Créez une équipe de 4 joueurs max','Create a team of up to 4 players'), isSmall),
                      _feature('🏆', context.tr('Classement équipe + classement interne','Team ranking + internal ranking'), isSmall),
                      _feature('💬', context.tr('Défiez et chambrez vos amis','Challenge and tease your friends'), isSmall),
                    ],
                  ),
                ),
                SizedBox(height: isSmall ? 18 : 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _step = 1),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: isSmall ? 14 : 17),
                    ),
                    child: Text(
                      context.tr('🚀  COMMENCER','🚀  START'),
                      style: GoogleFonts.bebasNeue(
                        fontSize: isSmall ? 18 : 20,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _recoverExistingProfile,
                    icon: const Icon(Icons.manage_accounts_rounded,
                        color: AppColors.gold),
                    label: Text(
                      context.tr('J’AI UN CODE DE RÉCUPÉRATION','I HAVE A RECOVERY CODE'),
                      style: GoogleFonts.bebasNeue(
                        color: AppColors.gold,
                        fontSize: 16,
                        letterSpacing: 1.4,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.bg2.withOpacity(0.72),
                      side: BorderSide(color: AppColors.gold.withOpacity(0.40)),
                    ),
                  ),
                ),
                SizedBox(height: isSmall ? 10 : 16),
                Text(
                  context.tr('PRONO4 · Pronostiquer. Vibrer. Gagner. Ensemble.','PRONO4 · Predict. Feel it. Win. Together.'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _hostBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: GoogleFonts.barlowCondensed(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6)),
    );
  }

  Widget _feature(String icon, String text, [bool compact = false]) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 9 : 12),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: compact ? 18 : 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.barlow(
                color: AppColors.text2,
                fontSize: compact ? 13 : 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1 : Profile ──────────────────────────────────
  Widget _buildProfile() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 720;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => setState(() => _step = 0),
                    icon: const Icon(Icons.arrow_back, color: AppColors.text2),
                    tooltip: 'Retour',
                  ),
                  const Spacer(),
                  const WC2026Wordmark(fontSize: 11),
                ]),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    context.tr('CRÉEZ VOTRE PROFIL','CREATE YOUR PROFILE'),
                    style: GoogleFonts.bebasNeue(
                      color: AppColors.text,
                      fontSize: isSmall ? 26 : 30,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    context.tr('Choisissez votre avatar et votre pseudo','Choose your avatar and nickname'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                        color: AppColors.text2, fontSize: 14),
                  ),
                ),
                SizedBox(height: isSmall ? 18 : 26),

                // ── Big avatar preview + button to open picker ──
                Center(
                  child: Column(children: [
                    AvatarBubble(avatar: _avatar, size: 110, showGlow: true),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _openPicker,
                      icon: const Icon(Icons.tune_rounded,
                          color: AppColors.gold, size: 18),
                      label: Text(context.tr('PERSONNALISER MON AVATAR','CUSTOMIZE MY AVATAR'),
                          style: GoogleFonts.bebasNeue(
                              color: AppColors.gold,
                              fontSize: 14,
                              letterSpacing: 1.5)),
                      style: OutlinedButton.styleFrom(
                        side:
                            BorderSide(color: AppColors.gold.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(context.tr('Emoji · Icône · Photo','Emoji · Icon · Photo'),
                        style: GoogleFonts.barlowCondensed(
                            color: AppColors.grey,
                            fontSize: 11,
                            letterSpacing: 0.5)),
                  ]),
                ),

                SizedBox(height: isSmall ? 18 : 26),
                Text(
                  context.tr('VOTRE PSEUDO','YOUR NICKNAME'),
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.text2,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameCtrl,
                  onChanged: (v) => setState(() => _name = v),
                  onSubmitted: (_) => _submit(),
                  maxLength: 20,
                  textInputAction: TextInputAction.done,
                  autofocus: false,
                  style:
                      GoogleFonts.barlow(color: AppColors.text, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: context.tr('Ex : Antoine, Léa, Team FRA…','E.g. Alex, Sam, Team ENG…'),
                    counterText: '',
                    prefixIcon:
                        Icon(Icons.person_outline, color: AppColors.text2),
                  ),
                ),
                SizedBox(height: isSmall ? 22 : 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: isSmall ? 14 : 17),
                      disabledBackgroundColor: AppColors.gold.withOpacity(0.3),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: AppColors.bg0, strokeWidth: 2.4),
                          )
                        : Text(
                            context.tr("C'EST PARTI !","LET'S GO!"),
                            style: GoogleFonts.bebasNeue(
                              fontSize: isSmall ? 18 : 20,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _message(context.tr('Veuillez entrer un pseudo pour continuer.','Please enter a nickname to continue.'));
      return;
    }

    if (_loading) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      // createUser is now bulletproof : it ALWAYS succeeds locally,
      // Firestore sync happens in background.
      await context.read<AppProvider>().createUser(name, _avatar);
    } catch (e) {
      // Should never happen now, but just in case
      debugPrint('onboarding submit error: $e');
      _message(context.tr('Une erreur est survenue. Réessayez.','Something went wrong. Please try again.'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
