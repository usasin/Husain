import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';

class FootballKnowledgeMeter extends StatefulWidget {
  final int score;
  final int played;
  final int correct;
  final int currentStreak;
  final bool goodForm;

  const FootballKnowledgeMeter({
    super.key,
    required this.score,
    required this.played,
    required this.correct,
    required this.currentStreak,
    required this.goodForm,
  });

  @override
  State<FootballKnowledgeMeter> createState() => _FootballKnowledgeMeterState();
}

class _FootballKnowledgeMeterState extends State<FootballKnowledgeMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _syncGlow();
  }

  @override
  void didUpdateWidget(covariant FootballKnowledgeMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goodForm != widget.goodForm ||
        oldWidget.currentStreak != widget.currentStreak) {
      _syncGlow();
    }
  }

  void _syncGlow() {
    if (widget.goodForm) {
      _glowController.repeat();
    } else {
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String? _tierKey() {
    if (widget.played < 3) return null;
    final s = widget.score;
    if (s < 40) return 'footix';
    if (s < 55) return 'amateur';
    if (s < 70) return 'connaisseur';
    if (s < 85) return 'confirme';
    return 'expert';
  }

  String _level(BuildContext context) {
    final tier = _tierKey();
    if (tier == null) return context.tr('À PROUVER', 'TO PROVE');
    switch (tier) {
      case 'footix':
        return 'FOOTIX';
      case 'amateur':
        return 'AMATEUR';
      case 'connaisseur':
        return context.tr('CONNAISSEUR', 'CONNOISSEUR');
      case 'confirme':
        return context.tr('CONFIRMÉ', 'CONFIRMED');
      case 'expert':
        return 'EXPERT';
      default:
        return 'PRONO4';
    }
  }

  String? _badgeAsset(BuildContext context) {
    final tier = _tierKey();
    if (tier == null) return null;
    final lang = context.isEnglish ? 'en' : 'fr';
    final file = context.isEnglish
        ? switch (tier) {
            'connaisseur' => 'connoisseur',
            'confirme' => 'confirmed',
            _ => tier,
          }
        : switch (tier) {
            'confirme' => 'confirme',
            _ => tier,
          };
    return 'assets/badges/$lang/$file.webp';
  }

  int _nextThreshold() {
    if (widget.score < 40) return 40;
    if (widget.score < 55) return 55;
    if (widget.score < 70) return 70;
    if (widget.score < 85) return 85;
    return 100;
  }

  String _nextLevel(BuildContext context) {
    if (widget.score < 40) return 'Amateur';
    if (widget.score < 55) {
      return context.tr('Connaisseur', 'Connoisseur');
    }
    if (widget.score < 70) {
      return context.tr('Confirmé', 'Confirmed');
    }
    return 'Expert';
  }

  String _pressureLine(BuildContext context) {
    if (widget.played < 3) {
      final left = 3 - widget.played;
      return context.tr(
        'Encore $left résultat${left > 1 ? 's' : ''} pour révéler ton niveau.',
        '$left more result${left > 1 ? 's' : ''} to reveal your level.',
      );
    }

    if (widget.score >= 85) {
      if (widget.currentStreak >= 2) {
        return context.tr(
          'Niveau Expert — série de ${widget.currentStreak} bons pronos 🔥',
          'Expert level — ${widget.currentStreak} correct picks in a row 🔥',
        );
      }
      return context.tr(
        'Niveau Expert. Maintenant il faut le conserver.',
        'Expert level. Now keep it.',
      );
    }

    final missing = (_nextThreshold() - widget.score).clamp(0, 100);
    final next = _nextLevel(context);
    return context.tr(
      'Plus que $missing point${missing > 1 ? 's' : ''} pour passer $next.',
      '$missing point${missing > 1 ? 's' : ''} left to reach $next.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.score.clamp(0, 100) / 100.0;
    final activeGlow = widget.goodForm && widget.played >= 3;
    final badgeAsset = _badgeAsset(context);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeGlow
              ? AppColors.lime.withOpacity(.48)
              : Colors.white.withOpacity(.08),
        ),
        boxShadow: activeGlow
            ? [
                BoxShadow(
                  color: AppColors.lime.withOpacity(.10),
                  blurRadius: 26,
                  spreadRadius: -6,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (badgeAsset != null) ...[
                Container(
                  width: 70,
                  height: 70,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.035),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(.07)),
                  ),
                  child: Image.asset(
                    badgeAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.lime,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('TON NIVEAU FOOT', 'YOUR FOOTBALL LEVEL'),
                      style: GoogleFonts.inter(
                        color: AppColors.text2,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _level(context),
                      style: GoogleFonts.spaceGrotesk(
                        color: activeGlow ? AppColors.lime : AppColors.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                        'Footix → Amateur → Connaisseur → Confirmé → Expert',
                        'Footix → Amateur → Connoisseur → Confirmed → Expert',
                      ),
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        color: AppColors.grey,
                        fontSize: 8.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lime.withOpacity(.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.lime.withOpacity(.26)),
                ),
                child: Text(
                  '${widget.score}/100',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.lime,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FOOTIX',
                style: GoogleFonts.inter(
                  color: AppColors.grey,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .9,
                ),
              ),
              Text(
                'EXPERT',
                style: GoogleFonts.inter(
                  color: AppColors.lime,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: 18,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.075),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        final fillWidth = width * value;
                        return SizedBox(
                          width: fillWidth,
                          height: 18,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 7,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.limeDark,
                                        AppColors.lime,
                                        AppColors.limeSoft,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.lime.withOpacity(.42),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                if (activeGlow && fillWidth > 28)
                                  AnimatedBuilder(
                                    animation: _glowController,
                                    builder: (context, _) {
                                      final sweepWidth = math.min(70.0, fillWidth);
                                      final travel = fillWidth + sweepWidth;
                                      final left =
                                          (_glowController.value * travel) - sweepWidth;
                                      return Positioned(
                                        left: left,
                                        width: sweepWidth,
                                        top: 2,
                                        bottom: 2,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Colors.white.withOpacity(.08),
                                                Colors.white.withOpacity(.72),
                                                Colors.white.withOpacity(.08),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        final x = (width * value - 8)
                            .clamp(0.0, width - 16)
                            .toDouble();
                        return Positioned(
                          left: x,
                          child: AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              final pulse = activeGlow
                                  ? 1.0 +
                                      .10 *
                                          math.sin(_glowController.value * math.pi * 2)
                                  : 1.0;
                              return Transform.scale(scale: pulse, child: child);
                            },
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.lime,
                                border: Border.all(color: AppColors.bg0, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.lime.withOpacity(
                                        activeGlow ? .78 : .36),
                                    blurRadius: activeGlow ? 16 : 8,
                                    spreadRadius: activeGlow ? 1 : 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _pressureLine(context),
                  style: GoogleFonts.inter(
                    color: AppColors.text2,
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.currentStreak >= 2) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lime.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+${widget.currentStreak} 🔥',
                    style: GoogleFonts.inter(
                      color: AppColors.lime,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Text(
            widget.played == 0
                ? context.tr(
                    'Ton niveau évoluera avec tes pronostics terminés.',
                    'Your level will evolve with completed predictions.',
                  )
                : context.tr(
                    '${widget.correct}/${widget.played} bons pronostics récents pris en compte.',
                    '${widget.correct}/${widget.played} recent correct predictions counted.',
                  ),
            style: GoogleFonts.inter(
              color: AppColors.grey,
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
