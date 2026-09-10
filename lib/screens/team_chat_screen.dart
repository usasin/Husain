import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_display.dart';

/// Salon d'équipe amélioré : présence légère, message épinglé,
/// contrôle admin, lecture limitée pour maîtriser le coût Firestore.
class TeamChatScreen extends StatefulWidget {
  const TeamChatScreen({super.key});

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _presenceTimer;
  AppProvider? _provider;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<AppProvider>();
    _startPresence();
  }

  @override
  void dispose() {
    final provider = _provider;
    if (provider != null) {
      unawaited(provider.leaveTeamChatPresence());
    }
    _presenceTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startPresence() {
    final prov = _provider ?? context.read<AppProvider>();
    if (prov.myTeam == null) return;
    unawaited(prov.touchTeamChatPresence());
    _presenceTimer ??= Timer.periodic(const Duration(seconds: 90), (_) {
      unawaited(prov.touchTeamChatPresence());
    });
  }

  Future<void> _send(AppProvider prov) async {
    if (_sending || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final error = await prov.sendTeamMessage(_controller.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final team = prov.myTeam;

    return StreamBuilder<CommunitySettings>(
      stream: prov.communitySettingsStream(),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data ?? const CommunitySettings();
        final disabled = !settings.teamChatEnabled;

        return Scaffold(
          backgroundColor: AppColors.bg0,
          appBar: AppBar(
            backgroundColor: AppColors.bg1,
            titleSpacing: 0,
            title: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.mexicoGreen.withOpacity(0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.mexicoGreen.withOpacity(0.35)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.forum_rounded,
                    color: AppColors.mexicoGreen, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team?.name.toUpperCase() ?? context.tr('SALON ÉQUIPE','TEAM CHAT'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 20,
                        letterSpacing: 1.2,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      disabled
                          ? context.tr('Désactivé par l’admin','Disabled by admin')
                          : context.tr('Pronos, chambrage et réactions entre coéquipiers','Predictions, banter and teammate reactions'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlow(fontSize: 11, color: AppColors.text2),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          body: team == null
              ? _noTeam(context)
              : Column(children: [
                  _topPanel(prov, settings, disabled),
                  Expanded(
                    child: disabled
                        ? _disabled(context.tr('Le salon équipe est momentanément désactivé par l’admin.','Team chat is temporarily disabled by the admin.'))
                        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: prov.teamChatStream(),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(color: AppColors.gold),
                                );
                              }

                              final docs = (snap.data?.docs ?? [])
                                  .where((doc) => !prov.isUserBlocked(
                                      (doc.data()['userId'] ?? '').toString()))
                                  .toList();
                              if (docs.isEmpty) return _welcome(team.name);
                              _jumpToEnd();

                              return ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                                itemCount: docs.length,
                                itemBuilder: (context, i) {
                                  final current = docs[i].data();
                                  final previous = i > 0 ? docs[i - 1].data() : null;
                                  return _bubbleWithDate(
                                    prov,
                                    docs[i].id,
                                    current,
                                    previous,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  if (!disabled) _quickReplies(prov),
                  if (!disabled) _inputBar(prov),
                ]),
        );
      },
    );
  }

  Widget _topPanel(AppProvider prov, CommunitySettings settings, bool disabled) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            disabled ? Icons.lock_rounded : Icons.bolt_rounded,
            color: disabled ? AppColors.canadaRed : AppColors.mexicoGreen,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              disabled
                  ? context.tr('Salon fermé temporairement','Chat temporarily closed')
                  : context.tr('Salon actif · 50 derniers messages','Chat active · latest 50 messages'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.barlowCondensed(
                color: disabled ? AppColors.canadaRed : AppColors.text2,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        if (settings.pinnedMessage.isNotEmpty) ...[
          const SizedBox(height: 9),
          _pinned(settings.pinnedMessage),
        ],
        const SizedBox(height: 7),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: prov.teamChatPresenceStream(),
          builder: (context, snap) => _presenceLine(snap.data?.docs ?? const []),
        ),
      ]),
    );
  }

  Widget _pinned(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.barlow(color: AppColors.text, fontSize: 12.5))),
      ]),
    );
  }

  Widget _presenceLine(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();
    final online = docs.where((d) {
      final ts = d.data()['activeUntil'];
      return ts is Timestamp && ts.toDate().isAfter(now);
    }).toList();

    final names = online
        .take(3)
        .map((d) => (d.data()['name'] ?? context.tr('Joueur','Player')).toString())
        .join(', ');

    return Text(
      online.isEmpty
          ? context.tr('Personne dans le salon pour l’instant','Nobody is in the chat right now')
          : (context.isEnglish
              ? '${online.length} teammate${online.length == 1 ? '' : 's'} online${names.isEmpty ? '' : ' · $names'}'
              : '${online.length} membre(s) présent(s)${names.isEmpty ? '' : ' · $names'}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 11.5),
    );
  }

  Widget _disabled(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(message,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 14, height: 1.4)),
      ),
    );
  }

  Widget _noTeam(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🛡️', style: TextStyle(fontSize: 46)),
          const SizedBox(height: 12),
          Text(context.tr('Rejoins une équipe','Join a team'),
              style: GoogleFonts.barlowCondensed(
                  color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            context.tr('Le salon est privé : seuls les membres de ton équipe peuvent lire et écrire.','This chat is private: only your teammates can read and write.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 14, height: 1.35),
          ),
        ]),
      ),
    );
  }

  Widget _welcome(String teamName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💬', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 14),
          Text(context.tr('Salon $teamName','$teamName chat'),
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                  color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Écrivez vos réactions avant et pendant les matchs. Les présences sont affichées pour savoir qui est dans le salon.',
              'Share reactions before and during matches. Presence shows who is currently in the chat.',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 14, height: 1.4),
          ),
        ]),
      ),
    );
  }

  Widget _bubbleWithDate(
    AppProvider prov,
    String messageId,
    Map<String, dynamic> data,
    Map<String, dynamic>? previous,
  ) {
    final ts = data['createdAt'];
    final dt = ts is Timestamp ? ts.toDate() : null;
    final prevTs = previous?['createdAt'];
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
              DateFormat('EEE d MMM', context.isEnglish ? 'en_US' : 'fr_FR').format(dt),
              style: GoogleFonts.barlowCondensed(color: AppColors.text2, fontSize: 11),
            ),
          ),
        ),
      _bubble(prov, messageId, data, dt),
    ]);
  }

  Widget _bubble(
    AppProvider prov,
    String messageId,
    Map<String, dynamic> data,
    DateTime? dt,
  ) {
    final isMe = data['userId'] == prov.currentUser?.id;
    final name = (data['name'] ?? context.tr('Joueur','Player')).toString();
    final avatar = (data['avatar'] ?? '⚽').toString();
    final authorId = (data['userId'] ?? '').toString();
    final message = (data['message'] ?? '').toString();
    final time = dt == null ? '' : DateFormat('HH:mm').format(dt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1E4976) : AppColors.bg2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isMe ? 15 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 15),
          ),
          border: Border.all(
            color: isMe
                ? AppColors.cyan.withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AvatarBubble(avatar: avatar, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlowCondensed(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 28),
                    padding: const EdgeInsets.only(left: 6),
                    tooltip: context.tr('Signaler ou bloquer','Report or block'),
                    onPressed: () => _openMessageActions(
                      prov,
                      messageId: messageId,
                      authorId: authorId,
                      authorName: name,
                      message: message,
                    ),
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 17, color: AppColors.text2),
                  ),
                ]),
              ),
            Text(
              message,
              style: GoogleFonts.barlow(color: AppColors.text, fontSize: 14.5, height: 1.3),
            ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(time,
                  style: GoogleFonts.barlow(color: AppColors.grey, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMessageActions(
    AppProvider prov, {
    required String messageId,
    required String authorId,
    required String authorName,
    required String message,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg2,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: AppColors.canadaRed),
            title: Text(context.tr('Signaler ce message','Report this message')),
            subtitle: Text(context.tr(
              'Le signalement sera envoyé à la modération.',
              'The report will be sent to moderation.',
            )),
            onTap: () => Navigator.pop(sheetContext, 'report'),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded, color: AppColors.canadaRed),
            title: Text(context.tr('Bloquer $authorName','Block $authorName')),
            subtitle: Text(context.tr(
              'Ses messages seront immédiatement masqués.',
              'Their messages will be hidden immediately.',
            )),
            onTap: () => Navigator.pop(sheetContext, 'block'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;

    String? error;
    if (action == 'report') {
      error = await prov.reportMessage(
        messageId: messageId,
        reportedUserId: authorId,
        reportedUserName: authorName,
        message: message,
        chatType: 'team',
        teamId: prov.myTeam?.id,
      );
    } else if (action == 'block') {
      error = await prov.blockUser(authorId, authorName);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? (action == 'report'
            ? context.tr('Message signalé à la modération.','Message reported to moderation.')
            : context.tr('$authorName a été bloqué.','$authorName has been blocked.'))),
        backgroundColor: error == null ? AppColors.mexicoGreen : AppColors.canadaRed,
      ),
    );
  }

  Widget _quickReplies(AppProvider prov) {
    final replies = context.isEnglish ? ['🔥 Come on!', '⚽ Big game', '👏 Well played', '😱 Incredible'] : ['🔥 Allez !', '⚽ Gros match', '👏 Bien joué', '😱 Incroyable'];
    return Container(
      color: AppColors.bg1,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: replies
              .map((reply) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(reply, style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w800)),
                      onPressed: _sending ? null : () {
                        _controller.text = reply;
                        _send(prov);
                      },
                      backgroundColor: AppColors.bg2,
                      side: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ))
              .toList(),
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
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 600,
              style: GoogleFonts.barlow(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                counterText: '',
                hintText: context.tr('Message à ton équipe…','Message your team…'),
                hintStyle: GoogleFonts.barlow(color: AppColors.grey),
                filled: true,
                fillColor: AppColors.bg2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => _send(prov),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'team-chat-send',
            backgroundColor: AppColors.gold,
            foregroundColor: const Color(0xFF1A1A1A),
            onPressed: _sending ? null : () => _send(prov),
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ]),
      ),
    );
  }
}
