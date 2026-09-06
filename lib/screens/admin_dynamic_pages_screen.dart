import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/matches_data.dart';
import '../data/teams_data.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/remote_image.dart';
import 'dynamic_page_screen.dart';

/// ADMIN : création de pages entières pilotées depuis Firebase.
class AdminDynamicPagesScreen extends StatelessWidget {
  const AdminDynamicPagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        title: Text(
          'PAGES DYNAMIQUES',
          style: GoogleFonts.bebasNeue(
            fontSize: 22,
            letterSpacing: 1.4,
            color: AppColors.text,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Ajouter une page',
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
          'PAGE',
          style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('dynamicPages').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }

          final docs = (snap.data?.docs ?? []).toList()
            ..sort((a, b) {
              final ad = _DynamicPageDraft.fromDoc(a);
              final bd = _DynamicPageDraft.fromDoc(b);
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
                      child: const Icon(Icons.article_rounded, color: AppColors.gold, size: 34),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune page dynamique',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlowCondensed(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Crée une page complète : règlement, sponsor, finale, message spécial… sans mise à jour Play Store.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 14, height: 1.3),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Créer ma première page'),
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
              final draft = _DynamicPageDraft.fromDoc(doc);
              return _AdminDynamicPageTile(
                draft: draft,
                onEdit: () => _openEditor(context, doc: doc),
                onPreview: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DynamicPageScreen(pageId: doc.id, fallbackTitle: draft.title),
                  ),
                ),
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

    final initial = doc == null ? _DynamicPageDraft.empty() : _DynamicPageDraft.fromDoc(doc);
    final result = await showDialog<_DynamicPageDraft>(
      context: context,
      builder: (_) => _DynamicPageEditorDialog(initial: initial),
    );
    if (result == null) return;

    if (result.enabled && !result.hasContent) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ajoute au moins un titre, un texte ou une image.'),
        ));
      }
      return;
    }

    final data = result.toFirestore(prov.firebaseUid ?? prov.currentUser?.id ?? 'admin');
    try {
      if (doc == null) {
        await FirebaseFirestore.instance.collection('dynamicPages').add(data);
      } else {
        await FirebaseFirestore.instance.collection('dynamicPages').doc(doc.id).set(data, SetOptions(merge: true));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(doc == null ? 'Page publiée ✅' : 'Page mise à jour ✅'),
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
      await FirebaseFirestore.instance.collection('dynamicPages').doc(id).set({
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action impossible : ${e.code}')));
      }
    }
  }

  Future<void> _duplicate(BuildContext context, _DynamicPageDraft draft) async {
    try {
      final copy = draft.copyForDuplicate();
      await FirebaseFirestore.instance.collection('dynamicPages').add(
        copy.toFirestore(context.read<AppProvider>().firebaseUid ?? 'admin'),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Page dupliquée ✅')));
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duplication impossible : ${e.code}')));
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
          title.isEmpty ? 'Cette page sera supprimée.' : 'Supprimer “$title” ?',
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
      await FirebaseFirestore.instance.collection('dynamicPages').doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Page supprimée ✅')));
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression impossible : ${e.code}')));
      }
    }
  }
}

class _AdminDynamicPageTile extends StatelessWidget {
  final _DynamicPageDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onDuplicate;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AdminDynamicPageTile({
    required this.draft,
    required this.onEdit,
    required this.onPreview,
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
                    child: const Icon(Icons.article_rounded, color: AppColors.gold),
                  )
                      : RemoteImage(source: draft.imageUrl, borderRadius: BorderRadius.circular(15)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(draft.enabled ? 'ACTIVE' : 'CACHÉE', statusColor),
                          _chip(draft.pageType == 'match_compare' ? 'COMPARATIF' : 'PAGE', draft.pageType == 'match_compare' ? AppColors.gold : AppColors.grey),
                          if (draft.showOnHome) _chip('ACCUEIL', AppColors.cyan),
                          if (draft.showOnProfile) _chip('PROFIL', AppColors.violet),
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
                      if (draft.matchId.isNotEmpty) ...[
                        Text(_adminMatchLabel(draft.matchId), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.barlow(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                      ],
                      if (draft.subtitle.isNotEmpty)
                        Text(
                          draft.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 13, height: 1.2),
                        ),
                      if (window.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(window, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.barlow(color: AppColors.grey, fontSize: 11)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _miniAction(Icons.edit_rounded, 'Modifier', onEdit),
                          _miniAction(Icons.remove_red_eye_rounded, 'Voir', onPreview),
                          _miniAction(draft.enabled ? Icons.visibility_off_rounded : Icons.visibility_rounded, draft.enabled ? 'Cacher' : 'Activer', onToggle),
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

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.barlowCondensed(color: color, fontSize: 11, fontWeight: FontWeight.w900),
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
            Text(label, style: GoogleFonts.barlow(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _DynamicPageDraft {
  final String id;
  final bool enabled;
  final bool showOnHome;
  final bool showOnProfile;
  final String title;
  final String subtitle;
  final String body;
  final String imageUrl;
  final String buttonText;
  final String buttonUrl;
  final String pageType;
  final String matchId;
  final String backgroundColor;
  final String textColor;
  final int order;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime updatedAt;

  const _DynamicPageDraft({
    required this.id,
    required this.enabled,
    required this.showOnHome,
    required this.showOnProfile,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.imageUrl,
    required this.buttonText,
    required this.buttonUrl,
    required this.pageType,
    required this.matchId,
    required this.backgroundColor,
    required this.textColor,
    required this.order,
    required this.startAt,
    required this.endAt,
    required this.updatedAt,
  });

  factory _DynamicPageDraft.empty() => _DynamicPageDraft(
    id: '',
    enabled: true,
    showOnHome: true,
    showOnProfile: false,
    title: '',
    subtitle: '',
    body: '',
    imageUrl: '',
    buttonText: '',
    buttonUrl: '',
    pageType: 'classic',
    matchId: '',
    backgroundColor: '#081525',
    textColor: '#F8FBFF',
    order: 100,
    startAt: null,
    endAt: null,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  factory _DynamicPageDraft.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _DynamicPageDraft(
      id: doc.id,
      enabled: data['enabled'] == true,
      showOnHome: data['showOnHome'] == true,
      showOnProfile: data['showOnProfile'] == true,
      title: (data['title'] ?? '').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      buttonText: (data['buttonText'] ?? '').toString(),
      buttonUrl: (data['buttonUrl'] ?? '').toString(),
      pageType: (data['pageType'] ?? 'classic').toString(),
      matchId: (data['matchId'] ?? '').toString(),
      backgroundColor: (data['backgroundColor'] ?? '#081525').toString(),
      textColor: (data['textColor'] ?? '#F8FBFF').toString(),
      order: DynamicPageData.toInt(data['order'], 100),
      startAt: DynamicPageData.toDate(data['startAt']),
      endAt: DynamicPageData.toDate(data['endAt']),
      updatedAt: DynamicPageData.toDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get hasContent {
    if (pageType == 'match_compare' && matchId.trim().isNotEmpty) return true;
    return title.trim().isNotEmpty || subtitle.trim().isNotEmpty || body.trim().isNotEmpty || imageUrl.trim().isNotEmpty;
  }

  String get windowLabel {
    final fmt = DateFormat('d MMM HH:mm', 'fr_FR');
    if (startAt == null && endAt == null) return '';
    if (startAt != null && endAt != null) return 'Du ${fmt.format(startAt!)} au ${fmt.format(endAt!)}';
    if (startAt != null) return 'À partir du ${fmt.format(startAt!)}';
    return 'Jusqu’au ${fmt.format(endAt!)}';
  }

  _DynamicPageDraft copyForDuplicate() => _DynamicPageDraft(
    id: '',
    enabled: false,
    showOnHome: showOnHome,
    showOnProfile: showOnProfile,
    title: title.isEmpty ? 'Copie' : '$title · copie',
    subtitle: subtitle,
    body: body,
    imageUrl: imageUrl,
    buttonText: buttonText,
    buttonUrl: buttonUrl,
    pageType: pageType,
    matchId: matchId,
    backgroundColor: backgroundColor,
    textColor: textColor,
    order: order + 1,
    startAt: startAt,
    endAt: endAt,
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toFirestore(String updatedBy) => {
    'enabled': enabled && hasContent,
    'showOnHome': showOnHome,
    'showOnProfile': showOnProfile,
    'title': _cut(title.trim(), 120),
    'subtitle': _cut(subtitle.trim(), 240),
    'body': _cut(body.trim(), 4000),
    'imageUrl': _cut(imageUrl.trim(), 700),
    'buttonText': _cut(buttonText.trim(), 45),
    'buttonUrl': _cut(buttonUrl.trim(), 700),
    'pageType': pageType == 'match_compare' ? 'match_compare' : 'classic',
    'matchId': pageType == 'match_compare' ? _cut(matchId.trim(), 40) : '',
    'backgroundColor': _safeHex(backgroundColor, '#081525'),
    'textColor': _safeHex(textColor, '#F8FBFF'),
    'order': order,
    'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
    'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': updatedBy,
    if (id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
  };

  static String _cut(String value, int max) => value.length <= max ? value : value.substring(0, max);

  static String _safeHex(String value, String fallback) {
    final trimmed = value.trim();
    final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    final ok = RegExp(r'^[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(hex);
    return ok ? '#$hex' : fallback;
  }
}

class _DynamicPageEditorDialog extends StatefulWidget {
  final _DynamicPageDraft initial;
  const _DynamicPageEditorDialog({required this.initial});

  @override
  State<_DynamicPageEditorDialog> createState() => _DynamicPageEditorDialogState();
}

class _DynamicPageEditorDialogState extends State<_DynamicPageEditorDialog> {
  late bool _enabled;
  late bool _showOnHome;
  late bool _showOnProfile;
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _body;
  late final TextEditingController _imageUrl;
  late final TextEditingController _buttonText;
  late final TextEditingController _buttonUrl;
  String _pageType = 'classic';
  String _matchId = '';
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
    _showOnHome = initial.showOnHome;
    _showOnProfile = initial.showOnProfile;
    _title = TextEditingController(text: initial.title);
    _subtitle = TextEditingController(text: initial.subtitle);
    _body = TextEditingController(text: initial.body);
    _imageUrl = TextEditingController(text: initial.imageUrl);
    _buttonText = TextEditingController(text: initial.buttonText);
    _buttonUrl = TextEditingController(text: initial.buttonUrl);
    _pageType = initial.pageType == 'match_compare' ? 'match_compare' : 'classic';
    _matchId = initial.matchId;
    _backgroundColor = TextEditingController(text: initial.backgroundColor);
    _textColor = TextEditingController(text: initial.textColor);
    _order = TextEditingController(text: initial.order.toString());
    _startAt = initial.startAt;
    _endAt = initial.endAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _body.dispose();
    _imageUrl.dispose();
    _buttonText.dispose();
    _buttonUrl.dispose();
    _backgroundColor.dispose();
    _textColor.dispose();
    _order.dispose();
    super.dispose();
  }

  _DynamicPageDraft _draft({bool forceDisabled = false}) => _DynamicPageDraft(
    id: widget.initial.id,
    enabled: forceDisabled ? false : _enabled,
    showOnHome: _showOnHome,
    showOnProfile: _showOnProfile,
    title: _title.text.trim(),
    subtitle: _subtitle.text.trim(),
    body: _body.text.trim(),
    imageUrl: _imageUrl.text.trim(),
    buttonText: _buttonText.text.trim(),
    buttonUrl: _buttonUrl.text.trim(),
    pageType: _pageType,
    matchId: _pageType == 'match_compare' ? _matchId : '',
    backgroundColor: _backgroundColor.text.trim(),
    textColor: _textColor.text.trim(),
    order: int.tryParse(_order.text.trim()) ?? 100,
    startAt: forceDisabled ? null : _startAt,
    endAt: forceDisabled ? null : _endAt,
    updatedAt: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg2,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      title: Text(
        widget.initial.id.isEmpty ? 'Créer une page' : 'Modifier la page',
        style: GoogleFonts.barlowCondensed(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                activeColor: AppColors.gold,
                title: Text('Publier la page', style: GoogleFonts.barlow(color: AppColors.text, fontWeight: FontWeight.w800)),
                subtitle: Text('Désactive pour préparer la page sans la montrer.', style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 12)),
                onChanged: (value) => setState(() => _enabled = value),
              ),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _showOnHome,
                      activeColor: AppColors.cyan,
                      title: Text('Accueil', style: GoogleFonts.barlow(color: AppColors.text, fontWeight: FontWeight.w800)),
                      onChanged: (value) => setState(() => _showOnHome = value),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _showOnProfile,
                      activeColor: AppColors.violet,
                      title: Text('Profil', style: GoogleFonts.barlow(color: AppColors.text, fontWeight: FontWeight.w800)),
                      onChanged: (value) => setState(() => _showOnProfile = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _pageTypeSelector(),
              if (_pageType == 'match_compare') ...[
                const SizedBox(height: 10),
                _matchSelector(),
              ],
              const SizedBox(height: 10),
              _field(controller: _title, label: _pageType == 'match_compare' ? 'Titre optionnel' : 'Titre de la page', hint: _pageType == 'match_compare' ? 'Ex : Comparatif du match' : 'Ex : Finale 2026', maxLength: 120),
              const SizedBox(height: 10),
              _field(controller: _subtitle, label: 'Sous-titre', hint: 'Petit texte affiché sur la carte', maxLength: 240),
              const SizedBox(height: 10),
              _field(controller: _body, label: 'Contenu complet', hint: 'Texte de la page. Utilise - pour faire des puces.', maxLines: 8, maxLength: 4000),
              const SizedBox(height: 10),
              _field(controller: _imageUrl, label: 'Image principale', hint: 'https://... ou gs://bucket/image.png', keyboardType: TextInputType.url, maxLength: 700),
              if (_imageUrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                AspectRatio(aspectRatio: 16 / 9, child: RemoteImage(source: _imageUrl.text.trim(), borderRadius: BorderRadius.circular(14))),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(controller: _buttonText, label: 'Bouton', hint: 'Ex : Voir le site', maxLength: 45)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(controller: _buttonUrl, label: 'Lien bouton', hint: 'https://...', keyboardType: TextInputType.url, maxLength: 700)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(controller: _backgroundColor, label: 'Fond HEX', hint: '#081525', maxLength: 9)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(controller: _textColor, label: 'Texte HEX', hint: '#F8FBFF', maxLength: 9)),
                  const SizedBox(width: 10),
                  SizedBox(width: 92, child: _field(controller: _order, label: 'Ordre', hint: '100', keyboardType: TextInputType.number, maxLength: 4)),
                ],
              ),
              const SizedBox(height: 6),
              _dateRow(),
              const SizedBox(height: 8),
              Text(
                _pageType == 'match_compare'
                    ? 'Conseil : choisis un match. La page génère automatiquement forme récente, derniers résultats, buteurs et votes.'
                    : 'Conseil : garde une page courte et utile. Exemple : règlement, finale, cadeau, sponsor ou message spécial.',
                style: GoogleFonts.barlow(color: AppColors.grey, fontSize: 12, height: 1.25),
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
                label: Text(widget.initial.id.isEmpty ? 'PUBLIER LA PAGE' : 'ENREGISTRER', style: GoogleFonts.barlow(fontWeight: FontWeight.w900)),
              ),
              if (widget.initial.id.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_draft(forceDisabled: true)),
                  icon: const Icon(Icons.visibility_off_rounded, size: 18),
                  label: Text('DÉSACTIVER', style: GoogleFonts.barlow(fontWeight: FontWeight.w800)),
                ),
              ],
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
            ],
          ),
        ),
      ],
    );
  }


  Widget _pageTypeSelector() {
    final items = const [
      DropdownMenuItem<String>(
        value: 'classic',
        child: Text('Page classique', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      DropdownMenuItem<String>(
        value: 'match_compare',
        child: Text('Comparatif match', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ];

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
          Text('Type de page', style: GoogleFonts.barlow(color: AppColors.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _pageType,
            isExpanded: true,
            dropdownColor: AppColors.bg2,
            style: GoogleFonts.barlow(color: AppColors.text, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            selectedItemBuilder: (context) => const [
              Text('Page classique', maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Comparatif match', maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            items: items,
            onChanged: (value) => setState(() {
              _pageType = value ?? 'classic';
              if (_pageType != 'match_compare') {
                _matchId = '';
              }
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _pageType == 'match_compare'
                ? 'Comparatif automatique entre deux équipes.'
                : 'Page simple avec image, texte et bouton.',
            style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 12, height: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _matchSelector() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('matches').snapshots(),
      builder: (context, matchSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('results').snapshots(),
          builder: (context, resultSnap) {
            final resultData = <String, Map<String, dynamic>>{
              for (final doc in resultSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                doc.id: doc.data(),
            };

            final firestoreOptions = (matchSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .map((doc) => _AdminMatchOption.fromDoc(doc, resultData))
                .where((m) => m.phaseKey != 'groupe')
                .toList()
              ..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt));

            final fallbackOptions = kMatches
                .where((m) => m.phase != MatchPhase.groupe)
                .map((m) => _AdminMatchOption.fromLocalResolved(m, resultData))
                .toList()
              ..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt));

            final options = firestoreOptions.isNotEmpty ? firestoreOptions : fallbackOptions;
            final ids = options.map((m) => m.id).toSet();
            final currentValue = ids.contains(_matchId) ? _matchId : (options.isNotEmpty ? options.first.id : null);

            if (currentValue != null && currentValue != _matchId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _pageType == 'match_compare' && _matchId != currentValue) {
                  setState(() => _matchId = currentValue);
                }
              });
            }

            if (options.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg3.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  matchSnap.connectionState == ConnectionState.waiting || resultSnap.connectionState == ConnectionState.waiting
                      ? 'Chargement des matchs...'
                      : 'Aucun match trouvé. Synchronise les matchs depuis le mode admin.',
                  style: GoogleFonts.barlow(color: AppColors.text2, fontWeight: FontWeight.w700),
                ),
              );
            }

            return DropdownButtonFormField<String>(
              value: currentValue,
              isExpanded: true,
              dropdownColor: AppColors.bg2,
              style: GoogleFonts.barlow(color: AppColors.text, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: 'Match à comparer',
                helperText: 'Les équipes des 8es/quarts sont résolues avec les résultats déjà saisis.',
                helperMaxLines: 3,
              ),
              selectedItemBuilder: (context) => options
                  .map((m) => Text(m.shortLabel, maxLines: 1, overflow: TextOverflow.ellipsis))
                  .toList(),
              items: options
                  .map((m) => DropdownMenuItem<String>(
                value: m.id,
                child: Text(m.longLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
              ))
                  .toList(),
              onChanged: (value) => setState(() => _matchId = value ?? ''),
            );
          },
        );
      },
    );
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
      style: GoogleFonts.barlow(color: AppColors.text, fontWeight: FontWeight.w600),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterStyle: GoogleFonts.barlow(color: AppColors.grey, fontSize: 10),
      ),
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
          Text('Programmation optionnelle', style: GoogleFonts.barlow(color: AppColors.text, fontWeight: FontWeight.w800)),
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
      builder: (context, child) => Theme(data: Theme.of(context), child: child ?? const SizedBox.shrink()),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (time == null || !mounted) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startAt = value;
      } else {
        _endAt = value;
      }
    });
  }
}



class _AdminMatchOption {
  final String id;
  final String homeCode;
  final String awayCode;
  final String phaseKey;
  final String phaseLabel;
  final DateTime kickoffAt;
  final String venue;

  const _AdminMatchOption({
    required this.id,
    required this.homeCode,
    required this.awayCode,
    required this.phaseKey,
    required this.phaseLabel,
    required this.kickoffAt,
    required this.venue,
  });

  factory _AdminMatchOption.fromLocal(FootballMatch match) {
    return _AdminMatchOption(
      id: match.id,
      homeCode: match.homeCode,
      awayCode: match.awayCode,
      phaseKey: match.phase.name,
      phaseLabel: _adminPhaseLabel(match.phase),
      kickoffAt: match.dateTime,
      venue: match.venue,
    );
  }

  factory _AdminMatchOption.fromLocalResolved(
      FootballMatch match,
      Map<String, Map<String, dynamic>> results,
      ) {
    final resolved = _resolveMatchCodesForAdmin(match, results) ?? [match.homeCode, match.awayCode];
    return _AdminMatchOption(
      id: match.id,
      homeCode: resolved[0],
      awayCode: resolved[1],
      phaseKey: match.phase.name,
      phaseLabel: _adminPhaseLabel(match.phase),
      kickoffAt: match.dateTime,
      venue: match.venue,
    );
  }

  factory _AdminMatchOption.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      Map<String, Map<String, dynamic>> results,
      ) {
    final data = doc.data();
    final id = (data['matchId'] ?? doc.id).toString();
    final local = _localMatchById(id);
    final result = results[id] ?? const <String, dynamic>{};

    var rawHome = (result['homeCodeResolved'] ?? data['homeCodeResolved'] ?? data['homeCode'] ?? local?.homeCode ?? '').toString().trim();
    var rawAway = (result['awayCodeResolved'] ?? data['awayCodeResolved'] ?? data['awayCode'] ?? local?.awayCode ?? '').toString().trim();

    if (rawHome.isEmpty || rawHome == 'TBD' || rawAway.isEmpty || rawAway == 'TBD') {
      final resolved = local == null ? null : _resolveMatchCodesForAdmin(local, results);
      if (resolved != null) {
        rawHome = resolved[0];
        rawAway = resolved[1];
      }
    }

    final phase = (data['phase'] ?? local?.phase.name ?? '').toString().trim().toLowerCase();
    return _AdminMatchOption(
      id: id,
      homeCode: rawHome.isEmpty ? 'TBD' : rawHome,
      awayCode: rawAway.isEmpty ? 'TBD' : rawAway,
      phaseKey: phase,
      phaseLabel: _adminPhaseLabelFromKey(phase),
      kickoffAt: _readKickoff(data, fallback: local?.dateTime),
      venue: (data['venue'] ?? local?.venue ?? '').toString(),
    );
  }

  String get homeName => kTeams[homeCode]?.name ?? (homeCode == 'TBD' ? 'À confirmer' : homeCode);
  String get awayName => kTeams[awayCode]?.name ?? (awayCode == 'TBD' ? 'À confirmer' : awayCode);

  String get dateLabel {
    if (kickoffAt.millisecondsSinceEpoch <= 0) return '';
    return DateFormat('dd/MM HH:mm').format(kickoffAt);
  }

  String get shortLabel => '$phaseLabel · $homeName vs $awayName';

  String get longLabel {
    final time = dateLabel.isEmpty ? '' : ' · $dateLabel';
    return '$id · $phaseLabel · $homeName vs $awayName$time';
  }
}

DateTime _readKickoff(Map<String, dynamic> data, {DateTime? fallback}) {
  final raw = data['kickoffAt'];
  if (raw is Timestamp) return raw.toDate().toLocal();
  final rawParis = data['kickoffLocalParis'];
  if (rawParis is String && rawParis.trim().isNotEmpty) {
    return DateTime.tryParse(rawParis)?.toLocal() ?? fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}


FootballMatch? _localMatchById(String id) {
  for (final match in kMatches) {
    if (match.id == id) return match;
  }
  return null;
}

const Map<String, List<String>> _adminFeeders = {
  'M089': ['M074', 'M077'], 'M090': ['M073', 'M075'],
  'M091': ['M076', 'M078'], 'M092': ['M079', 'M080'],
  'M093': ['M083', 'M084'], 'M094': ['M081', 'M082'],
  'M095': ['M086', 'M088'], 'M096': ['M085', 'M087'],
  'M097': ['M089', 'M090'], 'M098': ['M093', 'M094'],
  'M099': ['M091', 'M092'], 'M100': ['M095', 'M096'],
  'M101': ['M097', 'M098'], 'M102': ['M099', 'M100'],
  'M103': ['M101', 'M102'],
  'M104': ['M101', 'M102'],
};

List<String>? _resolveMatchCodesForAdmin(
    FootballMatch match,
    Map<String, Map<String, dynamic>> results, [
      Set<String>? seen,
    ]) {
  final resultData = results[match.id] ?? const <String, dynamic>{};
  final directHome = (resultData['homeCodeResolved'] ?? '').toString().trim();
  final directAway = (resultData['awayCodeResolved'] ?? '').toString().trim();
  if (directHome.isNotEmpty && directAway.isNotEmpty) {
    return [directHome, directAway];
  }

  if (match.homeCode != 'TBD' && match.awayCode != 'TBD') {
    return [match.homeCode, match.awayCode];
  }

  final feed = _adminFeeders[match.id];
  if (feed == null) return [match.homeCode, match.awayCode];
  final guard = seen ?? <String>{};
  if (!guard.add(match.id)) return [match.homeCode, match.awayCode];

  final first = _qualifiedCodeFromFeedForAdmin(feed[0], results, forThirdPlace: match.id == 'M103', seen: guard);
  final second = _qualifiedCodeFromFeedForAdmin(feed[1], results, forThirdPlace: match.id == 'M103', seen: guard);
  return [first ?? match.homeCode, second ?? match.awayCode];
}

String? _qualifiedCodeFromFeedForAdmin(
    String matchId,
    Map<String, Map<String, dynamic>> results, {
      required bool forThirdPlace,
      required Set<String> seen,
    }) {
  final result = (results[matchId]?['result'] ?? '').toString();
  if (result != 'HOME' && result != 'AWAY') return null;
  final match = _localMatchById(matchId);
  if (match == null) return null;
  final resolved = _resolveMatchCodesForAdmin(match, results, seen) ?? [match.homeCode, match.awayCode];
  final wantHome = forThirdPlace ? result == 'AWAY' : result == 'HOME';
  final code = wantHome ? resolved[0] : resolved[1];
  return code == 'TBD' ? null : code;
}

String _adminPhaseLabelFromKey(String key) {
  switch (key) {
    case 'groupe':
    case 'group':
      return 'Groupe';
    case 'seizieme':
    case '16e':
    case 'round_of_32':
      return '16e';
    case 'huitieme':
    case '8e':
    case 'round_of_16':
      return '8e';
    case 'quart':
    case 'quarter':
    case 'quarter_final':
      return 'Quart';
    case 'demi':
    case 'semi':
    case 'semi_final':
      return 'Demi';
    case 'troisieme':
    case 'third_place':
      return '3e place';
    case 'finale':
    case 'final':
      return 'Finale';
    default:
      return key.isEmpty ? 'Phase' : key;
  }
}

String _adminMatchLabel(String matchId) {
  for (final match in kMatches) {
    if (match.id == matchId) return _matchLabel(match);
  }
  return matchId;
}

String _matchLabel(FootballMatch match) {
  final home = kTeams[match.homeCode]?.name ?? match.homeCode;
  final away = kTeams[match.awayCode]?.name ?? match.awayCode;
  final phase = _adminPhaseLabel(match.phase);
  return '${match.id} · $phase · $home vs $away · ${match.date} ${match.time}';
}

String _adminPhaseLabel(MatchPhase p) {
  switch (p) {
    case MatchPhase.groupe:
      return 'Groupe';
    case MatchPhase.seizieme:
      return '16e';
    case MatchPhase.huitieme:
      return '8e';
    case MatchPhase.quart:
      return 'Quart';
    case MatchPhase.demi:
      return 'Demi';
    case MatchPhase.troisieme:
      return '3e place';
    case MatchPhase.finale:
      return 'Finale';
  }
}


FootballMatch? _firstKnockoutMatch() {
  for (final match in kMatches) {
    if (match.phase != MatchPhase.groupe) return match;
  }
  return kMatches.isNotEmpty ? kMatches.first : null;
}
