import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Badge PRONO4 pour les équipes de pronostiqueurs.
///
/// - Quelques noms connus reçoivent un pictogramme dédié (Expert, ZCT, Footix...).
/// - Toutes les autres équipes reçoivent automatiquement un écusson basé sur leurs initiales.
/// - L'ancien emoji choisi par le capitaine est conservé en petit accent, mais ne remplace plus le badge.
class TeamBadge extends StatelessWidget {
  final AppTeam team;
  final double size;
  final bool showLegacyAccent;

  const TeamBadge({
    super.key,
    required this.team,
    this.size = 42,
    this.showLegacyAccent = true,
  });

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(team.name);
    final initials = _initials(team.name);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * .30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: spec.colors,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: spec.colors.last.withOpacity(.20),
                    blurRadius: size * .22,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    right: -size * .14,
                    top: -size * .10,
                    child: Container(
                      width: size * .55,
                      height: size * .55,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(.10),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  if (spec.icon != null)
                    Icon(
                      spec.icon,
                      size: size * .40,
                      color: spec.foreground,
                    )
                  else
                    Text(
                      initials,
                      maxLines: 1,
                      style: GoogleFonts.spaceGrotesk(
                        color: spec.foreground,
                        fontSize: initials.length >= 3 ? size * .24 : size * .30,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -.5,
                      ),
                    ),
                  Positioned(
                    left: size * .12,
                    right: size * .12,
                    bottom: size * .08,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: spec.foreground.withOpacity(.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showLegacyAccent && team.icon.trim().isNotEmpty)
            Positioned(
              right: -size * .04,
              bottom: -size * .05,
              child: Container(
                width: size * .34,
                height: size * .34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bg0,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.lime, width: 1.2),
                ),
                child: Text(
                  team.icon,
                  style: TextStyle(fontSize: size * .17, height: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _normalize(String value) {
    const from = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿœ';
    const to =   'aaaaaaceeeeiiiinooooouuuuyyo';
    var s = value.toLowerCase().trim();
    for (var i = 0; i < from.length && i < to.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static String _initials(String name) {
    final parts = _normalize(name)
        .split(' ')
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P4';
    if (parts.length == 1) {
      final p = parts.first.toUpperCase();
      return p.length <= 3 ? p : p.substring(0, 2);
    }
    return parts.take(3).map((e) => e[0].toUpperCase()).join();
  }

  static _TeamBadgeSpec _specFor(String name) {
    final n = _normalize(name);

    if (n.contains('expert')) {
      return const _TeamBadgeSpec(
        icon: Icons.workspace_premium_rounded,
        colors: [Color(0xFF232A24), AppColors.lime],
        foreground: AppColors.bg0,
      );
    }
    if (n.contains('footix')) {
      return const _TeamBadgeSpec(
        icon: Icons.sports_soccer_rounded,
        colors: [Color(0xFF202622), Color(0xFF85D81A)],
        foreground: AppColors.text,
      );
    }
    if (n.contains('zct')) {
      return const _TeamBadgeSpec(
        icon: Icons.bolt_rounded,
        colors: [Color(0xFF212722), Color(0xFF94A8FF)],
        foreground: AppColors.text,
      );
    }
    if (n.contains('prono')) {
      return const _TeamBadgeSpec(
        icon: Icons.query_stats_rounded,
        colors: [Color(0xFF202622), Color(0xFF8CE9D3)],
        foreground: AppColors.text,
      );
    }
    if (n.contains('tiki') || n.contains('taka')) {
      return const _TeamBadgeSpec(
        icon: Icons.auto_awesome_rounded,
        colors: [Color(0xFF2A2419), Color(0xFFFFD66B)],
        foreground: AppColors.bg0,
      );
    }
    if (n.contains('var')) {
      return const _TeamBadgeSpec(
        icon: Icons.videocam_rounded,
        colors: [Color(0xFF251D25), Color(0xFFFF86C8)],
        foreground: AppColors.text,
      );
    }
    if (n.contains('analyste')) {
      return const _TeamBadgeSpec(
        icon: Icons.bar_chart_rounded,
        colors: [Color(0xFF20252A), Color(0xFF94A8FF)],
        foreground: AppColors.text,
      );
    }
    if (n.contains('bleu')) {
      return const _TeamBadgeSpec(
        icon: Icons.shield_rounded,
        colors: [Color(0xFF172033), Color(0xFF436DFF)],
        foreground: AppColors.text,
      );
    }
    if (n.contains('goal')) {
      return const _TeamBadgeSpec(
        icon: Icons.emoji_events_rounded,
        colors: [Color(0xFF2A2517), Color(0xFFFFD65A)],
        foreground: AppColors.bg0,
      );
    }

    final palettes = <List<Color>>[
      const [Color(0xFF202622), AppColors.lime],
      const [Color(0xFF20252A), AppColors.usaBlue],
      const [Color(0xFF1D2825), AppColors.cyan],
      const [Color(0xFF271F2C), AppColors.violet],
      const [Color(0xFF2B2027), AppColors.magenta],
      const [Color(0xFF2A2419), Color(0xFFFFD66B)],
    ];
    final hash = n.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return _TeamBadgeSpec(
      colors: palettes[hash % palettes.length],
      foreground: AppColors.text,
    );
  }
}

class _TeamBadgeSpec {
  final IconData? icon;
  final List<Color> colors;
  final Color foreground;

  const _TeamBadgeSpec({
    this.icon,
    required this.colors,
    required this.foreground,
  });
}
