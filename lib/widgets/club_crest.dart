import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Affiche le vrai écusson du club fourni par football-data.org.
/// Les SVG sont pris en charge. Si l'image n'est pas disponible, on affiche
/// un badge neutre avec les initiales du club (jamais un drapeau national).
class ClubCrest extends StatelessWidget {
  final String? url;
  final String clubName;
  final double size;

  const ClubCrest({
    super.key,
    required this.url,
    required this.clubName,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final clean = (url ?? '').trim();
    final child = clean.isEmpty
        ? _fallback()
        : clean.toLowerCase().contains('.svg')
            ? SvgPicture.network(
                clean,
                width: size,
                height: size,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => _loader(),
              )
            : CachedNetworkImage(
                imageUrl: clean,
                width: size,
                height: size,
                fit: BoxFit.contain,
                placeholder: (_, __) => _loader(),
                errorWidget: (_, __, ___) => _fallback(),
              );

    return SizedBox(
      width: size,
      height: size,
      child: Center(child: child),
    );
  }

  Widget _loader() => SizedBox(
        width: size * .42,
        height: size * .42,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.lime,
        ),
      );

  Widget _fallback() {
    final initials = _initials(clubName);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bg3,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lime.withOpacity(.35)),
      ),
      child: Text(
        initials,
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.lime,
          fontWeight: FontWeight.w900,
          fontSize: size * .27,
          letterSpacing: -.5,
        ),
      ),
    );
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'FC';
    if (words.length == 1) {
      final w = words.first.toUpperCase();
      return w.length <= 3 ? w : w.substring(0, 3);
    }
    return words.take(3).map((e) => e[0].toUpperCase()).join();
  }
}
