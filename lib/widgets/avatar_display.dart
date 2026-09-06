import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/avatar_data.dart';

/// ════════════════════════════════════════════════════════════
///  AvatarValue : représentation d'un avatar utilisateur.
///
///  Stocké comme `String` dans Firestore et compatible
///  rétro-compatible avec l'ancien système (emoji simple).
///
///  Format :
///   - emoji  : "⚽"
///   - image  : "img:<base64-png>"
///   - icone  : "icon:<codepoint>"
/// ════════════════════════════════════════════════════════════
class AvatarValue {
  final String raw;
  const AvatarValue(this.raw);

  bool get isImage => raw.startsWith('img:');
  bool get isIcon  => raw.startsWith('icon:');
  bool get isEmoji => !isImage && !isIcon;

  Uint8List? get imageBytes {
    if (!isImage) return null;
    try {
      return base64Decode(raw.substring(4));
    } catch (_) {
      return null;
    }
  }

  IconData? get iconData {
    if (!isIcon) return null;

    // IMPORTANT (release Android): ne jamais reconstruire IconData avec un
    // codePoint dynamique. Flutter ne peut alors plus tree-shaker la police
    // Material Icons et bloque le build AOT.
    //
    // On conserve le format Firestore historique `icon:<codepoint>`, mais on
    // résout ce code vers les constantes IconData déjà présentes dans notre
    // catalogue kAvatarIcons. Ainsi les anciens avatars restent compatibles
    // et le build release peut tree-shaker normalement les icônes.
    final cp = int.tryParse(raw.substring(5));
    if (cp == null) return null;

    for (final icon in kAvatarIcons) {
      if (icon.codePoint == cp) return icon;
    }

    // Ancienne valeur inconnue / retirée du catalogue : avatar neutre plutôt
    // qu'une construction IconData dynamique.
    return Icons.person_rounded;
  }

  static String encodeImage(Uint8List bytes) => 'img:${base64Encode(bytes)}';
  static String encodeIcon(IconData icon) => 'icon:${icon.codePoint}';
}

/// ════════════════════════════════════════════════════════════
///  AvatarBubble — rendu universel d'un avatar (emoji / image
///  / icône) dans un cercle stylisé "WC 2026".
/// ════════════════════════════════════════════════════════════
class AvatarBubble extends StatelessWidget {
  final String avatar;
  final double size;
  final Color? ringColor;
  final double ringWidth;
  final bool showGlow;

  const AvatarBubble({
    super.key,
    required this.avatar,
    this.size = 48,
    this.ringColor,
    this.ringWidth = 2,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = AvatarValue(avatar);
    final ring = ringColor ?? AppColors.gold.withOpacity(0.45);

    Widget content;
    if (value.isImage && value.imageBytes != null) {
      content = ClipOval(
        child: Image.memory(
          value.imageBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              Text('👤', style: TextStyle(fontSize: size * 0.55)),
        ),
      );
    } else if (value.isIcon && value.iconData != null) {
      content = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Icon(value.iconData, size: size * 0.55, color: AppColors.gold),
      );
    } else {
      content = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Text(
          avatar.isEmpty ? '👤' : avatar,
          style: TextStyle(fontSize: size * 0.55),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring.withOpacity(0.10),
        border: Border.all(color: ring, width: ringWidth),
        boxShadow: showGlow
            ? [BoxShadow(color: ring.withOpacity(0.35), blurRadius: 18, spreadRadius: 1)]
            : null,
      ),
      child: ClipOval(child: content),
    );
  }
}
