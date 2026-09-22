import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/wc26_background.dart';

/// Admin — visuels des cartes « Duel du jour ».
/// Les images sont stockées dans dynamicContents pour réutiliser les règles
/// Firestore déjà présentes. Chaque visuel est recadré 16:9 et compressé afin
/// d'être stable sur petits/grands Android et iPhone.
class AdminDuelVisualsScreen extends StatefulWidget {
  const AdminDuelVisualsScreen({super.key});

  @override
  State<AdminDuelVisualsScreen> createState() => _AdminDuelVisualsScreenState();
}

class _AdminDuelVisualsScreenState extends State<AdminDuelVisualsScreen> {
  final Set<String> _busy = <String>{};

  CollectionReference<Map<String, dynamic>> get _contents =>
      FirebaseFirestore.instance.collection('dynamicContents');

  Future<void> _pickAndSave(CompetitionInfo competition) async {
    if (_busy.contains(competition.id)) return;
    setState(() => _busy.add(competition.id));
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 92,
      );
      if (picked == null) return;

      final input = await picked.readAsBytes();
      final output = _prepareDuelImage(input);
      if (output == null) {
        _toast(context.tr(
          'Impossible de traiter cette image.',
          'Unable to process this image.',
        ));
        return;
      }

      final provider = context.read<AppProvider>();
      final allowed = provider.adminMode || await provider.refreshAdminAccess();
      if (!allowed) {
        _toast(context.tr('Accès admin refusé.', 'Admin access denied.'));
        return;
      }

      await _contents.doc('duel_visual_${competition.id}').set({
        'placement': 'duel_visual',
        'competitionId': competition.id,
        'title': 'Duel ${competition.name}',
        'enabled': true,
        'imageB64': base64Encode(output),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': provider.firebaseUid ?? provider.currentUser?.id ?? 'admin',
      }, SetOptions(merge: true));

      _toast(context.tr('Image du duel enregistrée ✅', 'Duel image saved ✅'));
    } on FirebaseException catch (e) {
      _toast('Firestore : ${e.code}');
    } catch (e) {
      _toast(context.tr('Erreur image : $e', 'Image error: $e'));
    } finally {
      if (mounted) setState(() => _busy.remove(competition.id));
    }
  }

  Uint8List? _prepareDuelImage(Uint8List input) {
    try {
      final decoded = img.decodeImage(input);
      if (decoded == null) return null;

      const targetRatio = 16 / 9;
      final sourceRatio = decoded.width / decoded.height;
      late img.Image cropped;
      if (sourceRatio > targetRatio) {
        final cropWidth = (decoded.height * targetRatio).round();
        final x = ((decoded.width - cropWidth) / 2).round();
        cropped = img.copyCrop(
          decoded,
          x: x,
          y: 0,
          width: cropWidth,
          height: decoded.height,
        );
      } else {
        final cropHeight = (decoded.width / targetRatio).round();
        final y = ((decoded.height - cropHeight) / 2).round();
        cropped = img.copyCrop(
          decoded,
          x: 0,
          y: y,
          width: decoded.width,
          height: cropHeight,
        );
      }

      final resized = img.copyResize(cropped, width: 960, height: 540);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
    } catch (_) {
      return null;
    }
  }

  Future<void> _remove(CompetitionInfo competition) async {
    final provider = context.read<AppProvider>();
    final allowed = provider.adminMode || await provider.refreshAdminAccess();
    if (!allowed) {
      _toast(context.tr('Accès admin refusé.', 'Admin access denied.'));
      return;
    }
    await _contents.doc('duel_visual_${competition.id}').delete();
    _toast(context.tr('Image supprimée.', 'Image removed.'));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(.96),
              title: Text(
                context.tr('VISUELS DES DUELS', 'DUEL VISUALS'),
                style: GoogleFonts.bebasNeue(letterSpacing: 1.4, fontSize: 22),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                30 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bg2.withOpacity(.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.lime.withOpacity(.18)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.crop_16_9_rounded, color: AppColors.lime),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr(
                              'Choisis une photo par compétition. PRONO4 la recadre automatiquement en 16:9 et l’adapte à tous les écrans pour éviter les débordements.',
                              'Choose one photo per competition. PRONO4 automatically crops it to 16:9 and adapts it to every screen to prevent overflow.',
                            ),
                            style: GoogleFonts.inter(
                              color: AppColors.text2,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...kCompetitions.map(_competitionCard),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _competitionCard(CompetitionInfo competition) {
    final ref = _contents.doc('duel_visual_${competition.id}');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final raw = (data?['imageB64'] ?? '').toString().trim();
        Uint8List? bytes;
        if (raw.isNotEmpty) {
          try {
            bytes = base64Decode(raw);
          } catch (_) {
            bytes = null;
          }
        }
        final busy = _busy.contains(competition.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg2.withOpacity(.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.overlayBase.withOpacity(.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.logoPlate,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Image.network(
                      competition.emblemUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(competition.emoji),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          competitionDisplayName(context, competition),
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          bytes == null
                              ? context.tr('Aucune image personnalisée', 'No custom image')
                              : context.tr('Image personnalisée active', 'Custom image active'),
                          style: GoogleFonts.inter(
                            color: AppColors.text2,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: bytes == null
                      ? Container(
                          color: AppColors.bg3,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.add_photo_alternate_rounded,
                            color: AppColors.text2.withOpacity(.55),
                            size: 42,
                          ),
                        )
                      : Image.memory(
                          bytes,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _pickAndSave(competition),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_rounded),
                      label: Text(
                        bytes == null
                            ? context.tr('CHOISIR UNE IMAGE', 'CHOOSE IMAGE')
                            : context.tr('REMPLACER', 'REPLACE'),
                      ),
                    ),
                  ),
                  if (bytes != null) ...[
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: context.tr('Supprimer', 'Remove'),
                      onPressed: busy ? null : () => _remove(competition),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
