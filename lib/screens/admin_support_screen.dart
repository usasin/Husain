import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'admin_content_screen.dart';

/// Page ADMIN : toutes les conversations d'aide, style WhatsApp.
class AdminSupportScreen extends StatelessWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        title: Text('MESSAGERIE ADMIN',
            style: GoogleFonts.bebasNeue(
                fontSize: 22, letterSpacing: 1.4, color: AppColors.text)),
        actions: [
          IconButton(
            tooltip: 'Contenu dynamique',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminContentScreen()),
            ),
            icon: const Icon(Icons.dashboard_customize_rounded, color: AppColors.cyan),
          ),
          IconButton(
            tooltip: 'Annonce à tous les joueurs',
            onPressed: () => _editAnnouncement(context, prov),
            icon: const Icon(Icons.campaign_rounded, color: AppColors.gold),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: prov.adminSupportStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.gold));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text('Aucune demande pour le moment.',
                  style: GoogleFonts.barlow(
                      color: AppColors.text2, fontSize: 14)),
            );
          }

          // Regroupe par joueur : dernier message + nb non lus.
          final threads = <String, Map<String, dynamic>>{};
          for (final d in docs) {
            final data = d.data();
            final uid = (data['userId'] ?? '').toString();
            if (uid.isEmpty) continue;
            final t = threads.putIfAbsent(uid, () => {
                  'name': (data['name'] ?? 'Joueur').toString(),
                  'last': data,
                  'unread': 0,
                });
            if (data['sender'] == 'user' && data['readByAdmin'] != true) {
              t['unread'] = (t['unread'] as int) + 1;
            }
          }

          final entries = threads.entries.toList();

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final uid = entries[i].key;
              final t = entries[i].value;
              final last = t['last'] as Map<String, dynamic>;
              final unread = t['unread'] as int;
              final ts = last['createdAt'];
              final when = ts is Timestamp
                  ? DateFormat('d MMM · HH:mm', 'fr_FR').format(ts.toDate())
                  : '';

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AdminSupportChatScreen(
                          userId: uid,
                          userName: (t['name'] ?? 'Joueur').toString()))),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: unread > 0
                              ? AppColors.gold.withOpacity(0.45)
                              : Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.cyan.withOpacity(0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (t['name'] as String).isNotEmpty
                              ? (t['name'] as String)
                                  .characters.first.toUpperCase()
                              : '?',
                          style: GoogleFonts.barlowCondensed(
                              color: AppColors.cyan,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(t['name'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.barlowCondensed(
                                        color: AppColors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                              ),
                              Text(when,
                                  style: GoogleFonts.barlow(
                                      color: AppColors.grey, fontSize: 11)),
                            ]),
                            const SizedBox(height: 2),
                            Row(children: [
                              if (last['sender'] == 'admin')
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(Icons.reply_rounded,
                                      size: 13, color: AppColors.grey),
                                ),
                              Expanded(
                                child: Text(
                                    (last['message'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.barlow(
                                        color: AppColors.text2,
                                        fontSize: 13)),
                              ),
                              if (unread > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: const BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text('$unread',
                                      style: GoogleFonts.barlowCondensed(
                                          color: const Color(0xFF1A1A1A),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)),
                                ),
                            ]),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editAnnouncement(BuildContext context, AppProvider prov) async {
    final snap = await FirebaseFirestore.instance
        .collection('system')
        .doc('appConfig')
        .get();
    final draft = _AnnouncementDraft.fromMap(snap.data() ?? {});

    if (!context.mounted) return;
    final result = await showDialog<_AnnouncementDraft>(
      context: context,
      builder: (ctx) => _AnnouncementEditorDialog(initial: draft),
    );
    if (result == null) return;

    if (result.enabled && !result.hasContent) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ajoute au moins un titre, un message, une image ou un lien avant de publier.'),
        ));
      }
      return;
    }

    final error = await prov.adminSetAnnouncement(
      enabled: result.enabled,
      title: result.title,
      message: result.message,
      buttonText: result.buttonText,
      url: result.url,
      imageUrl: result.imageUrl,
      textColor: result.textColor,
      backgroundColor: result.backgroundColor,
      animation: result.animation,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ??
            (result.enabled && result.hasContent
                ? 'Annonce publiée à tous les joueurs ✅'
                : 'Annonce retirée ✅')),
      ));
    }
  }
}

class _AnnouncementDraft {
  bool enabled;
  String title;
  String message;
  String buttonText;
  String url;
  String imageUrl;
  String textColor;
  String backgroundColor;
  String animation;

  _AnnouncementDraft({
    required this.enabled,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.url,
    required this.imageUrl,
    required this.textColor,
    required this.backgroundColor,
    required this.animation,
  });

  bool get hasContent =>
      title.trim().isNotEmpty ||
      message.trim().isNotEmpty ||
      url.trim().isNotEmpty ||
      imageUrl.trim().isNotEmpty;

  factory _AnnouncementDraft.fromMap(Map<String, dynamic> data) {
    final legacy = (data['announcement'] ?? '').toString();
    final title = (data['announcementTitle'] ?? '').toString();
    final message = (data['announcementMessage'] ?? legacy).toString();
    final buttonText = (data['announcementButtonText'] ?? '').toString();
    final url = (data['announcementUrl'] ?? '').toString();
    final imageUrl = (data['announcementImageUrl'] ?? '').toString();
    final textColor = (data['announcementTextColor'] ?? '#F8FBFF').toString();
    final backgroundColor =
        (data['announcementBackgroundColor'] ?? '#172B43').toString();
    final animation = _safeAnimation(
      (data['announcementAnimation'] ?? 'none').toString(),
    );

    final hasContent = title.trim().isNotEmpty ||
        message.trim().isNotEmpty ||
        url.trim().isNotEmpty ||
        imageUrl.trim().isNotEmpty ||
        legacy.trim().isNotEmpty;

    final rawEnabled = data['announcementEnabled'];

    return _AnnouncementDraft(
      // Important : si aucune annonce n'existe encore, le bouton ne doit pas
      // donner l'impression que l'annonce est déjà publiée.
      enabled: rawEnabled is bool ? rawEnabled : hasContent,
      title: title,
      message: message,
      buttonText: buttonText,
      url: url,
      imageUrl: imageUrl,
      textColor: textColor,
      backgroundColor: backgroundColor,
      animation: animation,
    );
  }

  static String _safeAnimation(String value) {
    final cleaned = value.trim().toLowerCase();
    const allowed = {'none', 'glow', 'marquee', 'pulse'};
    return allowed.contains(cleaned) ? cleaned : 'none';
  }
}

class _AnnouncementEditorDialog extends StatefulWidget {
  final _AnnouncementDraft initial;
  const _AnnouncementEditorDialog({required this.initial});

  @override
  State<_AnnouncementEditorDialog> createState() =>
      _AnnouncementEditorDialogState();
}

class _AnnouncementEditorDialogState
    extends State<_AnnouncementEditorDialog> {
  late bool _enabled;
  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _buttonText;
  late final TextEditingController _url;
  late final TextEditingController _imageUrl;
  late final TextEditingController _textColor;
  late final TextEditingController _backgroundColor;
  late String _animation;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _enabled = initial.enabled;
    _title = TextEditingController(text: initial.title);
    _message = TextEditingController(text: initial.message);
    _buttonText = TextEditingController(text: initial.buttonText);
    _url = TextEditingController(text: initial.url);
    _imageUrl = TextEditingController(text: initial.imageUrl);
    _textColor = TextEditingController(text: initial.textColor);
    _backgroundColor = TextEditingController(text: initial.backgroundColor);
    _animation = _safeAnimation(initial.animation);
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _buttonText.dispose();
    _url.dispose();
    _imageUrl.dispose();
    _textColor.dispose();
    _backgroundColor.dispose();
    super.dispose();
  }

  _AnnouncementDraft _draft({bool forceDisabled = false, bool forceEnabled = false}) {
    final enabled = forceDisabled ? false : (forceEnabled ? true : _enabled);

    return _AnnouncementDraft(
      enabled: enabled,
      title: forceDisabled ? '' : _title.text.trim(),
      message: forceDisabled ? '' : _message.text.trim(),
      buttonText: forceDisabled ? '' : _buttonText.text.trim(),
      url: forceDisabled ? '' : _url.text.trim(),
      imageUrl: forceDisabled ? '' : _imageUrl.text.trim(),
      textColor: forceDisabled ? '#F8FBFF' : _safeHex(_textColor.text, '#F8FBFF'),
      backgroundColor:
          forceDisabled ? '#172B43' : _safeHex(_backgroundColor.text, '#172B43'),
      animation: forceDisabled ? 'none' : _safeAnimation(_animation),
    );
  }

  String _safeHex(String value, String fallback) {
    final trimmed = value.trim();
    final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    final ok = RegExp(r'^[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(hex);
    return ok ? '#$hex' : fallback;
  }

  String _safeAnimation(String value) {
    final cleaned = value.trim().toLowerCase();
    const allowed = {'none', 'glow', 'marquee', 'pulse'};
    return allowed.contains(cleaned) ? cleaned : 'none';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg2,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      title: Text(
        '📢 Annonce enrichie',
        style: GoogleFonts.barlowCondensed(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 560,
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
                  'Annonce active',
                  style: GoogleFonts.barlow(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Désactive pour cacher l’annonce sans supprimer les champs.',
                  style: GoogleFonts.barlow(
                    color: AppColors.text2,
                    fontSize: 12,
                  ),
                ),
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 10),
              _field(
                controller: _title,
                label: 'Titre',
                hint: 'Ex : Les 16èmes sont ouverts !',
                maxLength: 90,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _message,
                label: 'Message',
                hint: 'Ton texte d’annonce...',
                maxLines: 4,
                maxLength: 700,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _imageUrl,
                label: 'URL image optionnelle',
                hint: 'https://.../image.jpg',
                keyboardType: TextInputType.url,
                maxLength: 500,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _url,
                label: 'Lien cliquable optionnel',
                hint: 'https://... ou www...',
                keyboardType: TextInputType.url,
                maxLength: 500,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _buttonText,
                label: 'Texte du bouton',
                hint: 'Ex : Voir le tableau',
                maxLength: 40,
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
                ],
              ),
              const SizedBox(height: 10),
              _animationPicker(),
              const SizedBox(height: 8),
              Text(
                'Astuce : pour une vidéo, mets plutôt un lien YouTube/TikTok dans “Lien cliquable”.',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(context).pop(_draft(forceEnabled: true)),
                icon: const Icon(Icons.publish_rounded, size: 18),
                label: Text(
                  'PUBLIER L’ANNONCE',
                  style: GoogleFonts.barlow(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text2,
                  side: BorderSide(color: Colors.white.withOpacity(0.18)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(context).pop(_draft(forceDisabled: true)),
                icon: const Icon(Icons.visibility_off_rounded, size: 18),
                label: Text(
                  'RETIRER / DÉSACTIVER',
                  style: GoogleFonts.barlow(fontWeight: FontWeight.w800),
                ),
              ),
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

  Widget _animationPicker() {
    const options = [
      {'value': 'none', 'label': 'Aucune animation'},
      {'value': 'glow', 'label': 'Glow lumineux'},
      {'value': 'marquee', 'label': 'Texte défilant droite → gauche'},
      {'value': 'pulse', 'label': 'Pulse léger'},
    ];

    return DropdownButtonFormField<String>(
      value: _safeAnimation(_animation),
      isExpanded: true,
      dropdownColor: AppColors.bg2,
      iconEnabledColor: AppColors.gold,
      decoration: const InputDecoration(
        labelText: 'Animation de l’annonce',
      ),
      style: GoogleFonts.barlow(
        color: AppColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      selectedItemBuilder: (context) => options
          .map(
            (option) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                option['label']!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: GoogleFonts.barlow(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option['value']!,
              child: Text(
                option['label']!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: GoogleFonts.barlow(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() {
        _animation = _safeAnimation(value ?? 'none');
      }),
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
      textCapitalization: TextCapitalization.sentences,
      style: GoogleFonts.barlow(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterStyle: GoogleFonts.barlow(color: AppColors.grey, fontSize: 11),
        hintStyle: GoogleFonts.barlow(color: AppColors.grey, fontSize: 13),
      ),
    );
  }
}

/// Conversation admin <-> un joueur.
class AdminSupportChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const AdminSupportChatScreen(
      {super.key, required this.userId, required this.userName});

  @override
  State<AdminSupportChatScreen> createState() => _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState extends State<AdminSupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(AppProvider prov) async {
    if (_controller.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await prov.adminSendSupportReply(
        widget.userId, widget.userName, _controller.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        title: Text(widget.userName.toUpperCase(),
            style: GoogleFonts.bebasNeue(
                fontSize: 20, letterSpacing: 1.2, color: AppColors.text)),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('support')
                .where('userId', isEqualTo: widget.userId)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold));
              }
              final docs = (snap.data?.docs ?? []).toList()
                ..sort((a, b) {
                  final ta = a.data()['createdAt'];
                  final tb = b.data()['createdAt'];
                  if (ta is! Timestamp) return 1;
                  if (tb is! Timestamp) return -1;
                  return ta.compareTo(tb);
                });

              prov.markSupportReadByAdmin(docs);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scroll.hasClients) return;
                final position = _scroll.position;
                if (position.isScrollingNotifier.value) return;
                try {
                  position.jumpTo(position.maxScrollExtent);
                } catch (_) {
                  // Sécurité : évite les erreurs si l'écran est fermé pendant le scroll.
                }
              });

              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final isMe = data['sender'] == 'admin';
                  final ts = data['createdAt'];
                  final time = ts is Timestamp
                      ? DateFormat('d MMM HH:mm', 'fr_FR').format(ts.toDate())
                      : '';
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF3A2E10)
                            : AppColors.bg2,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(isMe ? 14 : 3),
                          bottomRight: Radius.circular(isMe ? 3 : 14),
                        ),
                        border: Border.all(
                            color: isMe
                                ? AppColors.gold.withOpacity(0.3)
                                : Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text((data['message'] ?? '').toString(),
                              style: GoogleFonts.barlow(
                                  color: AppColors.text,
                                  fontSize: 14.5,
                                  height: 1.3)),
                          const SizedBox(height: 2),
                          Text(time,
                              style: GoogleFonts.barlow(
                                  color: AppColors.grey, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            color: AppColors.bg1,
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.barlow(
                        color: AppColors.text, fontSize: 15),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      hintText: 'Répondre à ${widget.userName}…',
                      hintStyle: GoogleFonts.barlow(
                          color: AppColors.grey, fontSize: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _send(prov),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                      color: AppColors.gold, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF1A1A1A)))
                      : const Icon(Icons.send_rounded,
                          color: Color(0xFF1A1A1A), size: 21),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
