import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/points_reward_logic.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import 'prono4_art.dart';
import 'reputation_badge.dart';

/// PRONO4 ARENA — un seul récapitulatif court des points DÉJÀ crédités.
/// Aucun calcul des scores, aucune modification de Firebase ni du classement.
class RewardCelebrationDialog extends StatefulWidget {
  final List<RecentPointsGain> gains;
  final String? oldBadge;
  final String? newBadge;
  final VoidCallback? onBadgeShown;
  final bool recap;

  const RewardCelebrationDialog({
    super.key,
    required this.gains,
    this.oldBadge,
    this.newBadge,
    this.onBadgeShown,
    this.recap = false,
  });

  @override
  State<RewardCelebrationDialog> createState() =>
      _RewardCelebrationDialogState();
}

class _RewardCelebrationDialogState extends State<RewardCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fx;
  Timer? _phaseTimer;
  bool _showBadge = false;
  bool _reduceMotion = false;
  bool _badgeReported = false;

  bool get _promotion => widget.oldBadge != null && widget.newBadge != null;
  int get _total => widget.gains.fold(0, (sum, gain) => sum + gain.gained);

  @override
  void initState() {
    super.initState();
    // Une promotion sans nouveau gain va directement au nouveau badge.
    if (_promotion && widget.gains.isEmpty) _showBadge = true;
    _fx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_reduceMotion) _fx.forward();
      // Une célébration pour tous les matchs, pas une séquence par match.
      if (_promotion && !_showBadge) {
        _phaseTimer = Timer(const Duration(milliseconds: 1550), () {
          if (!mounted) return;
          setState(() => _showBadge = true);
          if (!_reduceMotion) _fx.forward(from: 0);
        });
      }
      // The player dismisses the recap. A timer must not silently acknowledge
      // overnight gains while the app is paused or another route covers it.
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
  }

  void _close() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _nextOrClose() {
    if (_promotion && !_showBadge) {
      _phaseTimer?.cancel();
      setState(() => _showBadge = true);
      if (!_reduceMotion) _fx.forward(from: 0);
      return;
    }
    _close();
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _fx.dispose();
    super.dispose();
  }

  Widget _badgePicture(String badge, {double size = 128}) {
    final file = reputationBadgeAsset(context, badge);
    return Container(
      height: size + 16,
      width: size + 16,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bg1,
        border: Border.all(color: AppColors.gold.withOpacity(.55), width: 2),
        boxShadow: [BoxShadow(
          color: AppColors.gold.withOpacity(.24),
          blurRadius: 32,
          spreadRadius: 4,
        )],
      ),
      child: file == null
          ? Center(child: Text(reputationEmoji(badge),
              style: TextStyle(fontSize: size * .58)))
          : Image.asset(file, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Text(reputationEmoji(badge),
                    style: TextStyle(fontSize: size * .58)),
              )),
    );
  }

  Widget _pointsView() {
    final total = _total;
    return Column(
      key: const ValueKey('points'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Prono4Art(name: 'etoile', size: 104),
        const SizedBox(height: 5),
        Text(widget.recap ? context.tr('TES DERNIERS GAINS', 'YOUR RECENT GAINS')
          : context.tr('BRAVO !', 'WELL DONE!'),
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.text, fontSize: 26, fontWeight: FontWeight.w900,
          )),
        const SizedBox(height: 5),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: total.toDouble()),
          duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => Text(
            '+${value.round()}',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.lime, fontSize: 67,
              fontWeight: FontWeight.w900, height: 1.05,
            ),
          ),
        ),
        Text(context.tr('POINTS GAGNÉS', 'POINTS EARNED'),
          style: GoogleFonts.inter(color: AppColors.text2,
            fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .8)),
        const SizedBox(height: 5),
        Text(context.tr('Déjà comptés au classement', 'Already included in your ranking'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.lime.withOpacity(.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            context.tr(
              '${widget.gains.length} match${widget.gains.length == 1 ? '' : 's'} récompensé${widget.gains.length == 1 ? '' : 's'}',
              '${widget.gains.length} match${widget.gains.length == 1 ? '' : 'es'} rewarded',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.text,
              fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _badgeView() {
    final badge = widget.newBadge!;
    return Column(
      key: const ValueKey('badge'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.tr('NOUVEAU BADGE !', 'NEW BADGE!'),
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(color: AppColors.gold,
            fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 22),
        _badgePicture(badge),
        const SizedBox(height: 13),
        Text(reputationLabel(context, badge),
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(color: AppColors.gold,
            fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(context.tr(
          '${reputationLabel(context, widget.oldBadge!)} → ${reputationLabel(context, badge)}',
          '${reputationLabel(context, widget.oldBadge!)} → ${reputationLabel(context, badge)}'),
          style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
        if (_total > 0) ...[
          const SizedBox(height: 8),
          Text('+$_total ${context.tr('points', 'points')}',
              style: GoogleFonts.inter(color: AppColors.lime,
                fontWeight: FontWeight.w800)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showBadge && !_badgeReported) {
      _badgeReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onBadgeShown?.call();
      });
    }
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 370,
              maxHeight: MediaQuery.sizeOf(context).height * .78,
            ),
            child: Material(
              elevation: 22,
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(27),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (!_reduceMotion)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _fx,
                          builder: (_, __) => CustomPaint(
                            painter: _RewardConfettiPainter(progress: _fx.value),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(19, 21, 19, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            child: AnimatedSwitcher(
                              duration: _reduceMotion ? Duration.zero
                                  : const Duration(milliseconds: 420),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(begin: .83, end: 1)
                                          .animate(CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutBack,
                                          )),
                                      child: child,
                                    ),
                                  ),
                              child: _showBadge ? _badgeView() : _pointsView(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _nextOrClose,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.lime,
                              foregroundColor: const Color(0xFF101510),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: Text(_promotion && !_showBadge
                              ? context.tr('Voir mon badge', 'See my badge')
                              : context.tr('Continuer', 'Continue'),
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Effet local, léger, sans dépendance supplémentaire.
class _RewardConfettiPainter extends CustomPainter {
  const _RewardConfettiPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFFCC47), Color(0xFF32D878), Color(0xFFF5F8EE),
      Color(0xFF5DCDF3),
    ];
    final opacity = progress > .85
        ? ((1 - progress) / .15).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final paint = Paint();
    for (var i = 0; i < 40; i++) {
      final x0 = ((i * 67 + 19) % 103) / 103.0;
      final phase = ((i * 29 + 11) % 71) / 71.0;
      final fall = progress * (.78 + (i % 6) * .09) + phase * .34;
      final x = size.width * x0 + math.sin(progress * 6 + i) * 15;
      final y = size.height * (fall - .28);
      if (y < -16 || y > size.height + 16) continue;
      paint.color = colors[i % colors.length].withOpacity(opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 5 + i * .41);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero,
          width: (5 + i % 4).toDouble(), height: (10 + i % 5).toDouble()),
        const Radius.circular(1.5)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RewardConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
