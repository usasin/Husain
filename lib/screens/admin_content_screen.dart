import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/remote_image.dart';

/// ADMIN : création de cartes texte/image pilotées à distance.
/// Les cartes s'affichent dans l'app sans redéploiement.
class AdminContentScreen extends StatelessWidget {
  const AdminContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        title: Text(
          'CONTENU DYNAMIQUE',
          style: GoogleFonts.bebasNeue(
            fontSize: 22,
            letterSpacing: 1.4,
            color: AppColors.text,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Ajouter une carte',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_circle_rounded, color: AppColors.gold),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg0,
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'AJOUTER',
          style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('dynamicContents')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }

          final docs = (snap.data?.docs ?? []).toList()
            ..sort((a, b) {
              final ad = _ContentDraft.fromDoc(a);
              final bd = _ContentDraft.fromDoc(b);
              final order = ad.order.compareTo(bd.order);
              if (order != 0) return order;
              return bd.updatedAt.compareTo(ad.updatedAt);
            });

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: AppColors.gold,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun contenu dynamique',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlowCondensed(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ajoute une carte image/texte pour l’afficher sur l’accueil sans refaire de mise à jour.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlow(
                        color: AppColors.text2,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Créer ma première carte'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final draft = _ContentDraft.fromDoc(doc);
              return _AdminContentTile(
                draft: draft,
                onEdit: () => _openEditor(context, doc: doc),
                onDuplicate: () => _duplicate(context, draft),
                onToggle: () => _toggle(context, doc.id, !draft.enabled),
                onDelete: () => _delete(context, doc.id, draft.title),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final prov = context.read<AppProvider>();
    final isAdmin = await prov.refreshAdminAccess();
    if (!context.mounted) return;
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Accès admin refusé. Mets isAdmin = true sur ton utilisateur.'),
      ));
      return;
    }

    final initial = doc == null ? _ContentDraft.empty() : _ContentDraft.fromDoc(doc);
    final result = await showDialog<_ContentDraft>(
      context: context,
      builder: (_) => _ContentEditorDialog(initial: initial),
    );
    if (result == null) return;

    if (result.enabled && !result.hasContent) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ajoute au moins un titre, un message ou une image.'),
        ));
      }
      return;
    }

    final data = result.toFirestore(prov.firebaseUid ?? prov.currentUser?.id ?? 'admin');
    try {
      if (doc == null) {
        await FirebaseFirestore.instance.collection('dynamicContents').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('dynamicContents')
            .doc(doc.id)
            .set(data, SetOptions(merge: true));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(doc == null ? 'Carte publiée ✅' : 'Carte mise à jour ✅'),
        ));
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.code == 'permission-denied'
              ? 'Firestore refuse l’écriture : déploie les règles et vérifie isAdmin.'
              : 'Erreur Firestore : ${e.code}'),
        ));
      }
    }
  }

  Future<void> _toggle(BuildContext context, String id, bool enabled) async {
    try {
      await FirebaseFirestore.instance.collection('dynamicContents').doc(id).set({
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Action impossible : ${e.code}'),
        ));
      }
    }
  }

  Future<void> _duplicate(BuildContext context, _ContentDraft draft) async {
    final copy = draft.copyForDuplicate();
    try {
      await FirebaseFirestore.instance.collection('dynamicContents').add(
            copy.toFirestore(context.read<AppProvider>().firebaseUid ?? 'admin'),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Carte dupliquée ✅'),
        ));
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Duplication impossible : ${e.code}'),
        ));
      }
    }
  }

  Future<void> _delete(BuildContext context, String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: Text(
          'Supprimer ?',
          style: GoogleFonts.barlowCondensed(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          title.isEmpty ? 'Cette carte sera supprimée.' : 'Supprimer “$title” ?',
          style: GoogleFonts.barlow(color: AppColors.text2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.canadaRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('dynamicContents').doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Carte supprimée ✅'),
        ));
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Suppression impossible : ${e.code}'),
        ));
      }
    }
  }
}

class _AdminContentTile extends StatelessWidget {
  final _ContentDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AdminContentTile({
    required this.draft,
    required this.onEdit,
    required this.onDuplicate,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = draft.enabled ? AppColors.mexicoGreen : AppColors.grey;
    final window = draft.windowLabel;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: draft.imageUrl.isEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            color: AppColors.bg3,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.article_rounded,
                            color: AppColors.gold,
                          ),
                        )
                      : RemoteImage(
                          source: draft.imageUrl,
                          borderRadius: BorderRadius.circular(15),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: statusColor.withOpacity(0.35)),
                            ),
                            child: Text(
                              draft.enabled ? 'ACTIVE' : 'CACHÉE',
                              style: GoogleFonts.barlowCondensed(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              draft.placementLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.barlow(
                                color: AppColors.text2,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        draft.title.isEmpty ? '(Sans titre)' : draft.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlowCondensed(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (draft.message.isNotEmpty)
                        Text(
                          draft.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlow(
                            color: AppColors.text2,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      if (window.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          window,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlow(
                            color: AppColors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _miniAction(Icons.edit_rounded, 'Modifier', onEdit),
                          _miniAction(
                            draft.enabled ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            draft.enabled ? 'Cacher' : 'Activer',
                            onToggle,
                          ),
                          _miniAction(Icons.copy_rounded, 'Dupliquer', onDuplicate),
                          _miniAction(Icons.delete_rounded, 'Supprimer', onDelete, danger: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniAction(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    final color = danger ? AppColors.canadaRed : AppColors.gold;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.barlow(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentDraft {
  final String id;
  final bool enabled;
  final String placement;
  final String style;
  final String title;
  final String message;
  final String imageUrl;
  final String buttonText;
  final String buttonUrl;
  final String backgroundColor;
  final String textColor;
  final int order;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime updatedAt;

  const _ContentDraft({
    required this.id,
    required this.enabled,
    required this.placement,
    required this.style,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.buttonText,
    required this.buttonUrl,
    required this.backgroundColor,
    required this.textColor,
    required this.order,
    required this.startAt,
    required this.endAt,
    required this.updatedAt,
  });

  factory _ContentDraft.empty() => _ContentDraft(
        id: '',
        enabled: true,
        placement: 'home_top',
        style: 'hero',
        title: '',
        message: '',
        imageUrl: '',
        buttonText: '',
        buttonUrl: '',
        backgroundColor: '#172B43',
        textColor: '#F8FBFF',
        order: 100,
        startAt: null,
        endAt: null,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  factory _ContentDraft.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _ContentDraft(
      id: doc.id,
      enabled: data['enabled'] == true,
      placement: (data['placement'] ?? 'home_top').toString(),
      style: (data['style'] ?? 'hero').toString(),
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      buttonText: (data['buttonText'] ?? '').toString(),
      buttonUrl: (data['buttonUrl'] ?? '').toString(),
      backgroundColor: (data['backgroundColor'] ?? '#172B43').toString(),
      textColor: (data['textColor'] ?? '#F8FBFF').toString(),
      order: _toInt(data['order'], 100),
      startAt: _toDate(data['startAt']),
      endAt: _toDate(data['endAt']),
      updatedAt: _toDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get hasContent =>
      title.trim().isNotEmpty || message.trim().isNotEmpty || imageUrl.trim().isNotEmpty;

  String get placementLabel {
    switch (placement) {
      case 'home_top':
        return 'Accueil · haut de page';
      case 'home_after_team':
        return 'Accueil · après équipe/chat';
      case 'home_bottom':
        return 'Accueil · bas de page';
      case 'profile':
        return 'Page profil';
      default:
        return placement;
    }
  }

  String get windowLabel {
    final fmt = DateFormat('d MMM HH:mm', 'fr_FR');
    if (startAt == null && endAt == null) return '';
    if (startAt != null && endAt != null) {
      return 'Du ${fmt.format(startAt!)} au ${fmt.format(endAt!)}';
    }
    if (startAt != null) return 'À partir du ${fmt.format(startAt!)}';
    return 'Jusqu’au ${fmt.format(endAt!)}';
  }

  _ContentDraft copyForDuplicate() => _ContentDraft(
        id: '',
        enabled: false,
        placement: placement,
        style: style,
        title: title.isEmpty ? 'Copie' : '$title · copie',
        message: message,
        imageUrl: imageUrl,
        buttonText: buttonText,
        buttonUrl: buttonUrl,
        backgroundColor: backgroundColor,
        textColor: textColor,
        order: order + 1,
        startAt: startAt,
        endAt: endAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toFirestore(String updatedBy) => {
        'enabled': enabled && hasContent,
        'placement': placement,
        'style': style,
        'title': _cut(title.trim(), 100),
        'message': _cut(message.trim(), 900),
        'imageUrl': _cut(imageUrl.trim(), 600),
        'buttonText': _cut(buttonText.trim(), 45),
        'buttonUrl': _cut(buttonUrl.trim(), 600),
        'backgroundColor': _safeHex(backgroundColor, '#172B43'),
        'textColor': _safeHex(textColor, '#F8FBFF'),
        'order': order,
        'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
        'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      };

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _cut(String value, int max) => value.length <= max ? value : value.substring(0, max);

  static String _safeHex(String value, String fallback) {
    final trimmed = value.trim();
    final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    final ok = RegExp(r'^[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(hex);
    return ok ? '#$hex' : fallback;
  }
}

class _ContentEditorDialog extends StatefulWidget {
  final _ContentDraft initial;
  const _ContentEditorDialog({required this.initial});

  @override
  State<_ContentEditorDialog> createState() => _ContentEditorDialogState();
}

class _ContentEditorDialogState extends State<_ContentEditorDialog> {
  late bool _enabled;
  late String _placement;
  late String _style;
  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _imageUrl;
  late final TextEditingController _buttonText;
  late final TextEditingController _buttonUrl;
  late final TextEditingController _backgroundColor;
  late final TextEditingController _textColor;
  late final TextEditingController _order;
  DateTime? _startAt;
  DateTime? _endAt;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _enabled = initial.enabled;
    _placement = _safePlacement(initial.placement);
    _style = _safeStyle(initial.style);
    _title = TextEditingController(text: initial.title);
    _message = TextEditingController(text: initial.message);
    _imageUrl = TextEditingController(text: initial.imageUrl);
    _buttonText = TextEditingController(text: initial.buttonText);
    _buttonUrl = TextEditingController(text: initial.buttonUrl);
    _backgroundColor = TextEditingController(text: initial.backgroundColor);
    _textColor = TextEditingController(text: initial.textColor);
    _order = TextEditingController(text: initial.order.toString());
    _startAt = initial.startAt;
    _endAt = initial.endAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _imageUrl.dispose();
    _buttonText.dispose();
    _buttonUrl.dispose();
    _backgroundColor.dispose();
    _textColor.dispose();
    _order.dispose();
    super.dispose();
  }

  _ContentDraft _draft({bool forceDisabled = false}) {
    return _ContentDraft(
      id: widget.initial.id,
      enabled: forceDisabled ? false : _enabled,
      placement: _safePlacement(_placement),
      style: _safeStyle(_style),
      title: _title.text.trim(),
      message: _message.text.trim(),
      imageUrl: _imageUrl.text.trim(),
      buttonText: _buttonText.text.trim(),
      buttonUrl: _buttonUrl.text.trim(),
      backgroundColor: _safeHex(_backgroundColor.text, '#172B43'),
      textColor: _safeHex(_textColor.text, '#F8FBFF'),
      order: int.tryParse(_order.text.trim()) ?? 100,
      startAt: forceDisabled ? null : _startAt,
      endAt: forceDisabled ? null : _endAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg2,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      title: Text(
        widget.initial.id.isEmpty ? 'Créer une carte' : 'Modifier la carte',
        style: GoogleFonts.barlowCondensed(
          color: AppColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 590,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                activeColor: AppColors.gold,
                title: Text(
                  'Afficher dans l’app',
                  style: GoogleFonts.barlow(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Tu peux préparer une carte et la garder cachée.',
                  style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 12),
                ),
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _placementPicker()),
                  const SizedBox(width: 10),
                  Expanded(child: _stylePicker()),
                ],
              ),
              const SizedBox(height: 10),
              _field(
                controller: _title,
                label: 'Titre',
                hint: 'Ex : Votez avant le coup d’envoi',
                maxLength: 100,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _message,
                label: 'Texte',
                hint: 'Ton message pour les joueurs...',
                maxLines: 4,
                maxLength: 900,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _imageUrl,
                label: 'Image',
                hint: 'https://... ou gs://bucket/image.png',
                keyboardType: TextInputType.url,
                maxLength: 600,
              ),
              if (_imageUrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: RemoteImage(
                    source: _imageUrl.text.trim(),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _buttonText,
                      label: 'Bouton',
                      hint: 'Ex : Voter maintenant',
                      maxLength: 45,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      controller: _buttonUrl,
                      label: 'Lien du bouton',
                      hint: 'https://...',
                      keyboardType: TextInputType.url,
                      maxLength: 600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _backgroundColor,
                      label: 'Fond HEX',
                      hint: '#172B43',
                      maxLength: 9,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      controller: _textColor,
                      label: 'Texte HEX',
                      hint: '#F8FBFF',
                      maxLength: 9,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 92,
                    child: _field(
                      controller: _order,
                      label: 'Ordre',
                      hint: '100',
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _dateRow(),
              const SizedBox(height: 8),
              Text(
                'Astuce : l’image accepte aussi un chemin Firebase Storage gs:// comme ceux que tu utilises déjà.',
                style: GoogleFonts.barlow(
                  color: AppColors.grey,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(_draft()),
                icon: const Icon(Icons.publish_rounded, size: 18),
                label: Text(
                  widget.initial.id.isEmpty ? 'PUBLIER LA CARTE' : 'ENREGISTRER',
                  style: GoogleFonts.barlow(fontWeight: FontWeight.w900),
                ),
              ),
              if (widget.initial.id.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_draft(forceDisabled: true)),
                  icon: const Icon(Icons.visibility_off_rounded, size: 18),
                  label: Text(
                    'DÉSACTIVER',
                    style: GoogleFonts.barlow(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placementPicker() {
    const options = [
      {'value': 'home_top', 'label': 'Accueil · haut'},
      {'value': 'home_after_team', 'label': 'Accueil · après équipe'},
      {'value': 'home_bottom', 'label': 'Accueil · bas'},
      {'value': 'profile', 'label': 'Page profil'},
    ];
    return _dropdown(
      label: 'Emplacement',
      value: _safePlacement(_placement),
      options: options,
      onChanged: (value) => setState(() => _placement = _safePlacement(value ?? 'home_top')),
    );
  }

  Widget _stylePicker() {
    const options = [
      {'value': 'hero', 'label': 'Grande carte'},
      {'value': 'compact', 'label': 'Carte compacte'},
      {'value': 'alert', 'label': 'Alerte lumineuse'},
    ];
    return _dropdown(
      label: 'Style',
      value: _safeStyle(_style),
      options: options,
      onChanged: (value) => setState(() => _style = _safeStyle(value ?? 'hero')),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<Map<String, String>> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: AppColors.bg2,
      iconEnabledColor: AppColors.gold,
      decoration: InputDecoration(labelText: label),
      style: GoogleFonts.barlow(color: AppColors.text, fontWeight: FontWeight.w700),
      items: options
          .map((option) => DropdownMenuItem<String>(
                value: option['value'],
                child: Text(
                  option['label']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlow(color: AppColors.text, fontSize: 14),
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _dateRow() {
    final fmt = DateFormat('d MMM HH:mm', 'fr_FR');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg3.withOpacity(0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Programmation optionnelle',
            style: GoogleFonts.barlow(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDateTime(start: true),
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  label: Text(_startAt == null ? 'Début' : fmt.format(_startAt!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDateTime(start: false),
                  icon: const Icon(Icons.stop_rounded, size: 17),
                  label: Text(_endAt == null ? 'Fin' : fmt.format(_endAt!)),
                ),
              ),
            ],
          ),
          if (_startAt != null || _endAt != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _startAt = null;
                  _endAt = null;
                }),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Effacer les dates'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime({required bool start}) async {
    final now = DateTime.now();
    final current = start ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.gold),
        ),
        child: child!,
      ),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.gold),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startAt = picked;
      } else {
        _endAt = picked;
      }
    });
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.sentences,
      style: GoogleFonts.barlow(color: AppColors.text, fontSize: 14),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterStyle: GoogleFonts.barlow(color: AppColors.grey, fontSize: 11),
        hintStyle: GoogleFonts.barlow(color: AppColors.grey, fontSize: 13),
      ),
    );
  }

  String _safePlacement(String value) {
    const allowed = {'home_top', 'home_after_team', 'home_bottom', 'profile'};
    return allowed.contains(value) ? value : 'home_top';
  }

  String _safeStyle(String value) {
    const allowed = {'hero', 'compact', 'alert'};
    return allowed.contains(value) ? value : 'hero';
  }

  String _safeHex(String value, String fallback) {
    final trimmed = value.trim();
    final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    final ok = RegExp(r'^[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(hex);
    return ok ? '#$hex' : fallback;
  }
}
