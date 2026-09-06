import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../data/avatar_data.dart';
import '../theme/app_theme.dart';
import 'avatar_display.dart';

/// ════════════════════════════════════════════════════════════
///  AvatarPicker2026 — picker plein écran style 2026
///  Onglets : Emoji · Icônes · Photo (galerie / caméra).
///
///  Renvoie un `String` unifié (cf. AvatarValue) :
///   - "⚽"            (emoji)
///   - "icon:0xe..."   (icône Material)
///   - "img:<b64>"     (photo recadrée 256x256 PNG)
/// ════════════════════════════════════════════════════════════
class AvatarPicker2026 extends StatefulWidget {
  final String initial;
  const AvatarPicker2026({super.key, required this.initial});

  /// Convenient launcher
  static Future<String?> show(BuildContext context, String initial) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AvatarPicker2026(initial: initial),
      ),
    );
  }

  @override
  State<AvatarPicker2026> createState() => _AvatarPicker2026State();
}

class _AvatarPicker2026State extends State<AvatarPicker2026>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late String _current;
  String _emojiCategory = kAvatarCategories.keys.first;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _current = widget.initial.isEmpty ? '⚽' : widget.initial;

    final v = AvatarValue(_current);
    if (v.isImage) _tab.index = 2;
    else if (v.isIcon) _tab.index = 1;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Image picking + resize ──────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      final processed = await _resizeAndCompress(bytes);
      if (processed == null) {
        _toast("Impossible de traiter l'image. Essayez une autre.");
        setState(() => _busy = false);
        return;
      }

      setState(() {
        _current = AvatarValue.encodeImage(processed);
        _busy = false;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('image pick error: $e');
      _toast('Sélection annulée ou non autorisée.');
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Resize to a 256x256 square PNG so it fits comfortably
  /// in Firestore (<50KB typical) and stays sharp on device.
  Future<Uint8List?> _resizeAndCompress(Uint8List input) async {
    try {
      final decoded = img.decodeImage(input);
      if (decoded == null) return null;

      // Center-crop to square
      final s = decoded.width < decoded.height ? decoded.width : decoded.height;
      final x = (decoded.width - s) ~/ 2;
      final y = (decoded.height - s) ~/ 2;
      final cropped = img.copyCrop(decoded, x: x, y: y, width: s, height: s);

      final resized = img.copyResize(cropped, width: 256, height: 256);
      final png = img.encodePng(resized, level: 6);
      return Uint8List.fromList(png);
    } catch (_) {
      return null;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _confirm() => Navigator.of(context).pop(_current);

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: Text('AVATAR', style: GoogleFonts.bebasNeue(letterSpacing: 2.5)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Annuler',
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.text2,
          indicatorColor: AppColors.gold,
          indicatorWeight: 2,
          labelStyle: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.6),
          tabs: const [
            Tab(text: '😀  Emoji'),
            Tab(text: '✦  Icônes'),
            Tab(text: '📸  Photo'),
          ],
        ),
      ),
      body: Column(children: [
        // ── Live preview ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            children: [
              AvatarBubble(avatar: _current, size: 76, showGlow: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aperçu de votre avatar',
                      style: GoogleFonts.barlowCondensed(
                        color: AppColors.text2, fontSize: 12, letterSpacing: 0.6)),
                    const SizedBox(height: 4),
                    Text(_typeLabel(_current),
                      style: GoogleFonts.bebasNeue(
                        color: AppColors.gold, fontSize: 20, letterSpacing: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Tabs body ──
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildEmojiTab(),
              _buildIconTab(),
              _buildPhotoTab(),
            ],
          ),
        ),

        // ── Confirm bar ──
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _confirm,
                child: Text('VALIDER  ✓',
                  style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 2)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  String _typeLabel(String raw) {
    final v = AvatarValue(raw);
    if (v.isImage) return 'Photo personnelle';
    if (v.isIcon) return 'Icône';
    return 'Emoji  $raw';
  }

  // ── Tab : Emoji ────────────────────────────────────────
  Widget _buildEmojiTab() {
    final emojis = kAvatarCategories[_emojiCategory] ?? const <String>[];
    return Column(children: [
      SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          children: kAvatarCategories.keys.map((label) {
            final active = label == _emojiCategory;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _emojiCategory = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active
                      ? AppColors.gold.withOpacity(0.15)
                      : Colors.white.withOpacity(0.04),
                    border: Border.all(
                      color: active
                        ? AppColors.gold.withOpacity(0.5)
                        : Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(label,
                    style: GoogleFonts.barlowCondensed(
                      color: active ? AppColors.gold : AppColors.text2,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 10, crossAxisSpacing: 10),
          itemCount: emojis.length,
          itemBuilder: (_, i) {
            final e = emojis[i];
            final sel = e == _current;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _current = e);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: sel
                    ? AppColors.gold.withOpacity(0.15)
                    : Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: sel ? AppColors.gold : Colors.white.withOpacity(0.08),
                    width: sel ? 1.6 : 1),
                ),
                alignment: Alignment.center,
                child: Text(e, style: const TextStyle(fontSize: 30)),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ── Tab : Icônes Material ──────────────────────────────
  Widget _buildIconTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10),
      itemCount: kAvatarIcons.length,
      itemBuilder: (_, i) {
        final icon = kAvatarIcons[i];
        final encoded = AvatarValue.encodeIcon(icon);
        final sel = _current == encoded;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _current = encoded);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: sel
                ? AppColors.gold.withOpacity(0.15)
                : Colors.white.withOpacity(0.04),
              border: Border.all(
                color: sel ? AppColors.gold : Colors.white.withOpacity(0.08),
                width: sel ? 1.6 : 1),
            ),
            alignment: Alignment.center,
            child: Icon(icon,
              size: 30,
              color: sel ? AppColors.gold : AppColors.text),
          ),
        );
      },
    );
  }

  // ── Tab : Photo ────────────────────────────────────────
  Widget _buildPhotoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(children: [
            const Icon(Icons.photo_library_rounded,
              size: 56, color: AppColors.gold),
            const SizedBox(height: 14),
            Text('VOTRE PHOTO PERSO',
              style: GoogleFonts.bebasNeue(
                color: AppColors.text, fontSize: 22, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text(
              "L'image sera recadrée carrée (256×256) pour garder l'app rapide.",
              textAlign: TextAlign.center,
              style: GoogleFonts.barlow(
                color: AppColors.text2, fontSize: 13, height: 1.4)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: Text(
                    _busy ? '...' : 'GALERIE',
                    style: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.gold),
                  label: Text('CAMÉRA',
                    style: GoogleFonts.bebasNeue(
                      color: AppColors.gold, fontSize: 14, letterSpacing: 1.5)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.gold.withOpacity(0.4))),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        if (AvatarValue(_current).isImage)
          OutlinedButton.icon(
            onPressed: () => setState(() => _current = '⚽'),
            icon: const Icon(Icons.delete_outline,
              size: 18, color: AppColors.canadaRed),
            label: Text('Retirer la photo',
              style: GoogleFonts.barlowCondensed(
                color: AppColors.canadaRed, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.canadaRed.withOpacity(0.35))),
          ),
        const SizedBox(height: 12),
        Text(
          'Vos données restent privées et ne sont visibles que par vos collègues '
          'partageant le code de votre équipe.',
          textAlign: TextAlign.center,
          style: GoogleFonts.barlow(
            color: AppColors.grey, fontSize: 11, height: 1.4)),
      ]),
    );
  }
}
