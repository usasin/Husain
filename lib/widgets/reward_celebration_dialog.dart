import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/points_reward_logic.dart';
import '../data/reward_celebration_logic.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import 'reputation_badge.dart';

/// Animation 100 % locale. Lit les points déjà confirmés : n'écrit rien.
class RewardCelebrationDialog extends StatefulWidget {
  final List<RecentPointsGain> gains;
  final String? oldBadge;
  final String? newBadge;

  const RewardCelebrationDialog({
    super.key,
    required this.gains,
    this.oldBadge,
    this.newBadge,
  });

  @override
  State<RewardCelebrationDialog> createState() =>
      _RewardCelebrationDialogState();
}

class _RewardCelebrationDialogState extends State<RewardCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final List<RewardMoment> _moments;
  Timer? _timer;
  int _step = 0;
  bool _reduceMotion = false;

  bool get _badgeUpgrade =>
      widget.oldBadge != null && widget.newBadge != null;
  int get _oldBadgeStep => _moments.length;
  int get _newBadgeStep => _moments.length + 1;
  int get _endStep => _moments.length + (_badgeUpgrade ? 2 : 0);
  bool get _isSummary => _step >= _endStep;
  bool get _showConfetti =>
      (_step < _moments.length && _moments[_step].confetti) ||
      (_badgeUpgrade && _step == _newBadgeStep);

  @override
  void initState() {
    super.initState();
    // On ne bloque jamais le joueur 15 secondes si de nombreux matchs
    // sont terminés : six animations max, mais le TOTAL compte tous les gains.
    final all = buildRewardMoments(widget.gains);
    if (all.length <= 6) {
      _moments = all;
    } else {
      final selected = all.take(5).toList();
      // Même après une longue absence, ne jamais cacher une réussite exacte.
      RewardMoment? lateExact;
      for (final moment in all.skip(5)) {
        if (moment.confetti) {
          lateExact = moment;
          break;
        }
      }
      selected.add(lateExact ?? all[5]);
      _moments = selected;
    }
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_reduceMotion) _animateCurrentAndScheduleNext();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations && !_reduceMotion) {
      _reduceMotion = true;
      _timer?.cancel();
      _step = _endStep;
    }
  }

  void _animateCurrentAndScheduleNext() {
    if (_showConfetti) _confettiController.forward(from: 0);
    if (_isSummary) return;
    final delay = _badgeUpgrade && _step == _newBadgeStep
        ? const Duration(milliseconds: 1650)
        : const Duration(milliseconds: 1100);
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _step++);
      _animateCurrentAndScheduleNext();
    });
  }

  void _skipOrDismiss() {
    if (!_isSummary) {
      _timer?.cancel();
      _confettiController.stop();
      setState(() => _step = _endStep);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  Widget _badgeArt(String badge, {double size = 116}) {
    final asset = reputationBadgeAsset(context, badge);
    return Container(
      width: size + 16,
      height: size + 16,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bg1,
        border: Border.all(color: AppColors.gold.withValues(alpha: .55), width: 2),
        boxShadow: [BoxShadow(
          color: AppColors.gold.withValues(alpha: .16),
          blurRadius: 24,
          spreadRadius: 4,
        )],
      ),
      child: asset == null
          ? Center(child: Text(reputationEmoji(badge),
              style: TextStyle(fontSize: size * .54)))
          : Image.asset(asset, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Center(child: Text(reputationEmoji(badge),
                    style: TextStyle(fontSize: size * .54)))),
    );
  }

  Widget _content() {
    final green = const Color(0xFF32D878);
    if (_isSummary) {
      final total = widget.gains.fold<int>(0, (sum, gain) => sum + gain.gained);
      return Column(key: const ValueKey('summary'),
        mainAxisSize: MainAxisSize.min, children: [
          Icon(_badgeUpgrade ? Icons.workspace_premium_rounded
              : Icons.emoji_events_rounded,
              color: AppColors.gold, size: 55),
          const SizedBox(height: 10),
          Text(context.tr('Bravo !', 'Well done!'),
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text, fontSize: 29,
                fontWeight: FontWeight.w900)),
          if (total > 0) ...[
            const SizedBox(height: 4),
            Text('+$total', style: GoogleFonts.spaceGrotesk(
              color: green, fontSize: 60, fontWeight: FontWeight.w900)),
            Text(context.tr('points gagnés', 'points earned'),
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
          ],
          if (_badgeUpgrade) ...[
            const SizedBox(height: 17),
            _badgeArt(widget.newBadge!, size: 72),
            const SizedBox(height: 8),
            Text(context.tr('Nouveau badge : ${widget.newBadge!}',
                    'New badge: ${reputationLabel(context, widget.newBadge!)}'),
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(color: AppColors.gold,
                    fontSize: 18, fontWeight: FontWeight.w800)),
          ],
          if (widget.gains.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(context.tr('${widget.gains.length} match(s) récompensé(s)',
                    '${widget.gains.length} scoring match(es)'),
                style: TextStyle(color: AppColors.text2, fontSize: 12)),
          ],
        ]);
    }
    if (_badgeUpgrade && _step == _oldBadgeStep) {
      return Column(key: const ValueKey('badge-old'),
        mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr('TU CHANGES DE NIVEAU…', 'LEVEL UP…'),
              style: GoogleFonts.spaceGrotesk(color: AppColors.text,
                  fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 22),
          _badgeArt(widget.oldBadge!),
          const SizedBox(height: 13),
          Text(reputationLabel(context, widget.oldBadge!),
              style: GoogleFonts.spaceGrotesk(color: AppColors.text2,
                  fontSize: 23, fontWeight: FontWeight.w800)),
        ]);
    }
    if (_badgeUpgrade && _step == _newBadgeStep) {
      return Column(key: const ValueKey('badge-new'),
        mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr('🏆 NOUVEAU BADGE !', '🏆 NEW BADGE!'),
              style: GoogleFonts.spaceGrotesk(color: AppColors.gold,
                  fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 19),
          _badgeArt(widget.newBadge!),
          const SizedBox(height: 13),
          Text(reputationLabel(context, widget.newBadge!),
              style: GoogleFonts.spaceGrotesk(color: AppColors.gold,
                  fontSize: 27, fontWeight: FontWeight.w900)),
        ]);
    }
    final moment = _moments[_step];
    final exact = moment.kind == 'exact';
    return Column(key: ValueKey('points-$_step'),
      mainAxisSize: MainAxisSize.min, children: [
        Icon(exact ? Icons.emoji_events_rounded : Icons.sports_score_rounded,
            color: exact ? AppColors.gold : green, size: 48),
        const SizedBox(height: 7),
        Text(context.tr(exact ? 'SCORE EXACT !' : 'BON RÉSULTAT !',
                exact ? 'EXACT SCORE!' : 'CORRECT RESULT!'),
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(color: AppColors.text,
                fontSize: 20, fontWeight: FontWeight.w900)),
        Text('+${moment.points}',
            style: GoogleFonts.spaceGrotesk(color: green,
                fontSize: 83, fontWeight: FontWeight.w900)),
        Text(moment.matchLabel, textAlign: TextAlign.center,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: AppColors.text2,
                fontWeight: FontWeight.w600, fontSize: 13)),
      ]);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: Material(
            color: AppColors.bg2,
            elevation: 22,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              if (_showConfetti && !_reduceMotion)
                Positioned.fill(child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confettiController,
                    builder: (_, __) => CustomPaint(
                      painter: _RewardConfettiPainter(
                        progress: _confettiController.value),
                    ),
                  ),
                )),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: SingleChildScrollView(
                    child: AnimatedSwitcher(
                      duration: _reduceMotion ? Duration.zero
                          : const Duration(milliseconds: 390),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: .7, end: 1)
                              .animate(CurvedAnimation(
                                parent: animation, curve: Curves.easeOutBack)),
                          child: child,
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: _content(),
                      ),
                    ),
                  )),
                  const SizedBox(height: 22),
                  SizedBox(width: double.infinity, child: FilledButton(
                    onPressed: _skipOrDismiss,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.bg0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(_isSummary
                        ? context.tr('C’est parti ! ⚽', 'Let’s play! ⚽')
                        : context.tr('Passer l’animation', 'Skip animation')),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ));
  }
}

/// Confettis légers sans package externe, sans image et sans réseau.
class _RewardConfettiPainter extends CustomPainter {
  final double progress;
  const _RewardConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFFCC47), Color(0xFF32D878), Color(0xFFFCF8EE),
      Color(0xFF5DCDF3), Color(0xFFF8A3B2),
    ];
    final opacity = progress > .85
        ? ((1 - progress) / .15).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final paint = Paint();
    for (var i = 0; i < 45; i++) {
      final x0 = ((i * 67 + 19) % 103) / 103.0;
      final phase = ((i * 29 + 11) % 71) / 71.0;
      final fall = (progress * (.78 + (i % 6) * .09) + phase * .34);
      final x = size.width * x0 + math.sin(progress * 6 + i) * 15;
      final y = size.height * (fall - .28);
      if (y < -16 || y > size.height + 16) continue;
      paint.color = colors[i % colors.length].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((progress * 5 + i * .41));
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: (5 + i % 4).toDouble(),
              height: (10 + i % 5).toDouble()),
          const Radius.circular(1.5)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RewardConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
