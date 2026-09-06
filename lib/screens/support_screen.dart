import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Conversation d'aide du joueur, style WhatsApp (temps réel).
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
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
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await prov.sendSupportMessage(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _controller.clear();
    _jumpToEnd();
  }

  void _jumpToEnd() {
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
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        titleSpacing: 0,
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withOpacity(0.4)),
            ),
            alignment: Alignment.center,
            child: const Text('🎧', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUPPORT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    letterSpacing: 1.2,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  'On te répond dès que possible',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlow(
                    fontSize: 11,
                    color: AppColors.text2,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: prov.supportThreadStream(),
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

              prov.markSupportReadByUser(docs);

              if (docs.isEmpty) return _welcome();
              _jumpToEnd();

              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final prevData = i > 0 ? docs[i - 1].data() : null;
                  return _bubbleWithDate(data, prevData);
                },
              );
            },
          ),
        ),
        _inputBar(prov),
      ]),
    );
  }

  Widget _welcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text('Un souci, une question, une idée ?',
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                    color: AppColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Écris ton message ci-dessous : la conversation reste ici, '
              'et la réponse apparaîtra dans ce fil.',
              textAlign: TextAlign.center,
              style: GoogleFonts.barlow(
                  color: AppColors.text2, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubbleWithDate(
      Map<String, dynamic> data, Map<String, dynamic>? prevData) {
    final ts = data['createdAt'];
    final dt = ts is Timestamp ? ts.toDate() : null;
    final prevTs = prevData?['createdAt'];
    final prevDt = prevTs is Timestamp ? prevTs.toDate() : null;

    final showDate = dt != null &&
        (prevDt == null ||
            dt.day != prevDt.day ||
            dt.month != prevDt.month ||
            dt.year != prevDt.year);

    return Column(children: [
      if (showDate)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              DateFormat('EEE d MMM', 'fr_FR').format(dt),
              style: GoogleFonts.barlowCondensed(
                  color: AppColors.text2, fontSize: 11),
            ),
          ),
        ),
      _bubble(data, dt),
    ]);
  }

  Widget _bubble(Map<String, dynamic> data, DateTime? dt) {
    final isMe = data['sender'] != 'admin';
    final read = data['readByAdmin'] == true;
    final time = dt == null ? '' : DateFormat('HH:mm').format(dt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1E4976) : AppColors.bg2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 3),
            bottomRight: Radius.circular(isMe ? 3 : 14),
          ),
          border: Border.all(
              color: isMe
                  ? AppColors.cyan.withOpacity(0.25)
                  : Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🎧', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text('Support',
                      style: GoogleFonts.barlowCondensed(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            Text((data['message'] ?? '').toString(),
                style: GoogleFonts.barlow(
                    color: AppColors.text, fontSize: 14.5, height: 1.3)),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(time,
                  style: GoogleFonts.barlow(
                      color: AppColors.grey, fontSize: 10)),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(Icons.done_all_rounded,
                    size: 13,
                    color: read ? AppColors.cyan : AppColors.grey),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _inputBar(AppProvider prov) {
    return SafeArea(
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
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style:
                    GoogleFonts.barlow(color: AppColors.text, fontSize: 15),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  hintText: 'Écris ton message…',
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
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
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
    );
  }
}
