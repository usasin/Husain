import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/teams_data.dart';
import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/messaging_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_display.dart';

/// Tribune commune d'un match.
/// Elle s'ouvre automatiquement autour du coup d'envoi :
/// - 45 minutes avant le match
/// - jusqu'à environ 5h après, pour couvrir prolongation + tirs au but.
class MatchLoungeScreen extends StatefulWidget {
  final FootballMatch? initialMatch;

  const MatchLoungeScreen({super.key, this.initialMatch});

  @override
  State<MatchLoungeScreen> createState() => _MatchLoungeScreenState();
}

class _MatchLoungeScreenState extends State<MatchLoungeScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _presenceTimer;
  AppProvider? _provider;
  bool _sending = false;
  String? _presenceMatchId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<AppProvider>();
    _ensurePresence();
  }

  @override
  void dispose() {
    final matchId = _presenceMatchId;
    final provider = _provider;
    if (matchId != null && provider != null) {
      unawaited(provider.leaveMatchRoomPresence(matchId));
    }
    _presenceTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  FootballMatch? _activeMatch(AppProvider prov) {
    final active = prov.activeMatchLoungeMatch();
    if (active != null) return active;
    return widget.initialMatch;
  }

  void _ensurePresence() {
    final prov = _provider ?? context.read<AppProvider>();
    final match = _activeMatch(prov);
    if (match == null || _presenceMatchId == match.id) return;

    _presenceMatchId = match.id;
    unawaited(prov.touchMatchRoomPresence(match.id));
    unawaited(MessagingService.instance.subscribeMatch(match.id));
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      unawaited(prov.touchMatchRoomPresence(match.id));
    });
  }

  Future<void> _send(AppProvider prov, FootballMatch match) async {
    if (_sending || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final error = await prov.sendMatchRoomMessage(match, _controller.text);
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
      try {
        _scroll.position.jumpTo(_scroll.position.maxScrollExtent);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final match = _activeMatch(prov);

    if (match == null) return _closed(prov);

    _ensurePresence();
    final isClub = match.competitionId != 'world-cup-2026';
    final home = isClub ? (match.homeName ?? match.homeCode) : (kTeams[match.homeCode]?.name ?? match.homeName ?? match.homeCode);
    final away = isClub ? (match.awayName ?? match.awayCode) : (kTeams[match.awayCode]?.name ?? match.awayName ?? match.awayCode);

    return StreamBuilder<CommunitySettings>(
      stream: prov.communitySettingsStream(),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data ?? const CommunitySettings();
        final disabled = !settings.matchLoungeEnabled;

        return Scaffold(
          backgroundColor: AppColors.bg0,
          appBar: AppBar(
            backgroundColor: AppColors.bg1,
            titleSpacing: 0,
            title: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.trophyGradient,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.stadium_rounded, color: Color(0xFF151515), size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TRIBUNE DU MATCH',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 20,
                        letterSpacing: 1.2,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      '$home vs $away',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlow(fontSize: 11, color: AppColors.text2),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          body: Column(children: [
            _matchHeader(prov, match, settings, disabled),
            Expanded(
              child: disabled
                  ? _disabled(context.tr('La tribune du match est désactivée par l’admin.','Match lounge is disabled by the admin.'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: prov.matchRoomStream(match.id),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppColors.gold),
                          );
                        }
                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) return _welcome(home, away);
                        _jumpToEnd();
                        return ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          itemCount: docs.length,
                          itemBuilder: (_, i) => _bubble(prov, docs[i].data()),
                        );
                      },
                    ),
            ),
            if (!disabled) _inputBar(prov, match),
          ]),
        );
      },
    );
  }

  Widget _closed(AppProvider prov) {
    final next = prov.nextLoungeMatch();
    final title = next == null
        ? context.tr('Aucune tribune ouverte','No match lounge is open')
        : 'Prochaine tribune : ${next.competitionId != 'world-cup-2026' ? (next.homeName ?? next.homeCode) : (kTeams[next.homeCode]?.name ?? next.homeName ?? next.homeCode)} vs ${next.competitionId != 'world-cup-2026' ? (next.awayName ?? next.awayCode) : (kTeams[next.awayCode]?.name ?? next.awayName ?? next.awayCode)}';
    final subtitle = next == null
        ? context.tr('La tribune s’ouvrira automatiquement autour des matchs.','The lounge opens automatically around match time.')
        : 'Ouverture 45 minutes avant le coup d’envoi (${DateFormat('dd/MM HH:mm').format(next.dateTime)}).';

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(backgroundColor: AppColors.bg1, title: Text(context.tr('Tribune du match','Match lounge'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🏟️', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                    color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 14, height: 1.35)),
          ]),
        ),
      ),
    );
  }

  Widget _matchHeader(AppProvider prov, FootballMatch match, CommunitySettings settings, bool disabled) {
    final score = prov.scores[match.id];
    final live = prov.liveStatusFor(match.id) ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _teamChip(match.homeCode),
          const SizedBox(width: 8),
          Text(
            score == null ? 'VS' : '${score.homeScore} - ${score.awayScore}',
            style: GoogleFonts.bebasNeue(color: AppColors.gold, fontSize: 24, letterSpacing: 1.2),
          ),
          const SizedBox(width: 8),
          _teamChip(match.awayCode),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: disabled ? AppColors.canadaRed.withOpacity(0.12) : AppColors.mexicoGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: disabled ? AppColors.canadaRed.withOpacity(0.35) : AppColors.mexicoGreen.withOpacity(0.35)),
            ),
            child: Text(disabled ? context.tr('FERMÉ','CLOSED') : (live.isEmpty ? context.tr('OUVERT','OPEN') : live),
              style: GoogleFonts.barlowCondensed(
                color: disabled ? AppColors.canadaRed : AppColors.mexicoGreen,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ]),
        if (settings.pinnedMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          _pinned(settings.pinnedMessage),
        ],
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: prov.matchRoomPresenceStream(match.id),
          builder: (context, snap) => _presenceLine(snap.data?.docs ?? const []),
        ),
      ]),
    );
  }

  Widget _teamChip(String code) {
    final team = kTeams[code];
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(team?.name ?? code,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
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
        .map((d) => (d.data()['name'] ?? 'Joueur').toString())
        .join(', ');

    return Text(
      online.isEmpty
          ? context.tr('Aucun supporter actif pour l’instant','No active supporters right now')
          : '${online.length} supporter(s) présent(s)${names.isEmpty ? '' : ' · $names'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 11.5),
    );
  }

  Widget _welcome(String home, String away) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔥', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 14),
          Text(context.tr('La tribune est ouverte','The lounge is open'),
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                  color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            context.tr('Supporters de $home, de $away ou neutres : réagissez avant, pendant et après le match.', '$home fans, $away fans or neutrals: react before, during and after the match.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 14, height: 1.4),
          ),
        ]),
      ),
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

  Widget _bubble(AppProvider prov, Map<String, dynamic> data) {
    final isMe = data['userId'] == prov.currentUser?.id;
    final name = (data['name'] ?? 'Joueur').toString();
    final avatar = (data['avatar'] ?? '⚽').toString();
    final message = (data['message'] ?? '').toString();
    final ts = data['createdAt'];
    final dt = ts is Timestamp ? ts.toDate() : null;
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
          border: Border.all(color: isMe ? AppColors.cyan.withOpacity(0.25) : Colors.white.withOpacity(0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AvatarBubble(avatar: avatar, size: 20),
                const SizedBox(width: 6),
                Text(name,
                    style: GoogleFonts.barlowCondensed(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    )),
              ]),
            ),
          Text(message, style: GoogleFonts.barlow(color: AppColors.text, fontSize: 14.5, height: 1.3)),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerRight,
            child: Text(time, style: GoogleFonts.barlow(color: AppColors.grey, fontSize: 10)),
          ),
        ]),
      ),
    );
  }

  Widget _inputBar(AppProvider prov, FootballMatch match) {
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
                hintText: context.tr('Réagir dans la tribune…','React in the lounge…'),
                hintStyle: GoogleFonts.barlow(color: AppColors.grey),
                filled: true,
                fillColor: AppColors.bg2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => _send(prov, match),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'match-lounge-send',
            backgroundColor: AppColors.gold,
            foregroundColor: const Color(0xFF1A1A1A),
            onPressed: _sending ? null : () => _send(prov, match),
            child: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ]),
      ),
    );
  }
}
