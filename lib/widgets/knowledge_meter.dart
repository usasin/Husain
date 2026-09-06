import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';

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

  String _level(BuildContext context) {
    final s = widget.score;
    if (widget.played < 3) return context.tr('À PROUVER','TO PROVE');
    if (s < 40) return 'FOOTIX';
    if (s < 55) return context.tr('AMATEUR','ROOKIE');
    if (s < 70) return context.tr('CONNAISSEUR','KNOWLEDGEABLE');
    return 'EXPERT';
  }

  String _pressureLine(BuildContext context) {
    if (widget.played < 3) {
      return context.tr('Encore ${3 - widget.played} résultat${3 - widget.played > 1 ? 's' : ''} pour révéler ton niveau.', '${3 - widget.played} more result${3 - widget.played > 1 ? 's' : ''} to reveal your level.');
    }
    if (widget.score >= 70) {
      if (widget.currentStreak >= 2) {
        return context.tr('Tu es en zone Expert — série de ${widget.currentStreak} bons pronos 🔥', 'Expert zone — ${widget.currentStreak} correct picks in a row 🔥');
      }
      return context.tr('Zone Expert. Maintenant il faut y rester.', 'Expert zone. Now stay there.');
    }
    final missing = 70 - widget.score;
    if (widget.score < 40) {
      return context.tr('Encore $missing points pour sortir du mode Footix et atteindre Expert.', '$missing points left to leave Footix mode and reach Expert.');
    }
    return context.tr('Plus que $missing points pour atteindre Expert.', '$missing points left to reach Expert.');
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.score.clamp(0, 100)) / 100.0;
    final activeGlow = widget.goodForm && widget.played >= 3;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('TON NIVEAU FOOT','YOUR FOOTBALL LEVEL'),
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
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                border: Border.all(
                                    color: AppColors.bg0, width: 2.5),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                ? context.tr('Ton niveau évoluera avec tes pronostics terminés.','Your level will evolve with completed predictions.')
                : context.tr('${widget.correct}/${widget.played} bons pronostics récents pris en compte.','${widget.correct}/${widget.played} recent correct predictions counted.'),
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
