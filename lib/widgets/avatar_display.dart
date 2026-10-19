import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
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
  bool get isIcon => raw.startsWith('icon:');
  bool get isRemote => raw.startsWith('url:');
  bool get isEmoji => !isImage && !isIcon && !isRemote;
  String? get imageUrl {
    if (!isRemote) return null;
    final uri = Uri.tryParse(raw.substring(4));
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri.toString()
        : null;
  }

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
  final String? userId;
  final double size;
  final Color? ringColor;
  final double ringWidth;
  final bool showGlow;

  const AvatarBubble({
    super.key,
    required this.avatar,
    this.userId,
    this.size = 48,
    this.ringColor,
    this.ringWidth = 2,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (userId == null || userId!.isEmpty) return _render(avatar);
    final provider = context.read<AppProvider>();
    final known = provider.knownProfileAvatar(userId!);
    if (known != null) return _render(known);
    return FutureBuilder<String>(
      future: provider.profileAvatar(userId!, avatar),
      initialData: avatar,
      builder: (_, snapshot) => _render(snapshot.data ?? avatar),
    );
  }

  Widget _render(String raw) {
    final value = AvatarValue(raw);
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
    } else if (value.isRemote && value.imageUrl != null) {
      content = CachedNetworkImage(
        imageUrl: value.imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Icon(Icons.person_rounded),
        errorWidget: (_, __, ___) => const Icon(Icons.person_rounded),
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
          !value.isEmoji || raw.isEmpty ? '👤' : raw,
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
            ? [
                BoxShadow(
                  color: ring.withOpacity(0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipOval(child: content),
    );
  }
}
