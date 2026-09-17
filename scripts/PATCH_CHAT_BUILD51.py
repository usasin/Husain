from pathlib import Path

ROOT = Path('.')
SCREENS = ROOT / 'lib' / 'screens'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'PRONO4 BUILD51 chat patch failed: {label} not found')
    return text.replace(old, new, 1)


def patch_team_chat() -> None:
    path = SCREENS / 'team_chat_screen.dart'
    s = path.read_text()

    s = replace_once(s,
"""                                  final current = docs[i].data();
                                  final previous = i > 0 ? docs[i - 1].data() : null;
                                  return _bubbleWithDate(prov, current, previous);
""",
"""                                  final current = docs[i].data();
                                  final previous = i > 0 ? docs[i - 1].data() : null;
                                  return _bubbleWithDate(
                                    prov,
                                    docs[i].id,
                                    current,
                                    previous,
                                  );
""", 'team list builder')

    s = replace_once(s,
"""  Widget _blockHelpChip() {
    return ActionChip(
      avatar: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.lime),
      label: Text(
        context.tr('Bloquer un joueur ? touche ⋮', 'Block a player? tap ⋮'),
        style: GoogleFonts.inter(
          color: AppColors.text2,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: AppColors.bg2,
      side: BorderSide(color: AppColors.lime.withOpacity(.18)),
      visualDensity: VisualDensity.compact,
      onPressed: _showBlockingHelp,
    );
  }

  Future<void> _showBlockingHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Bloquer un joueur', 'Block a player')),
        content: Text(
          context.tr(
            'Touche ⋮ à droite du message du joueur, puis « Bloquer ». Ses messages seront masqués pour toi. Tu peux le débloquer dans Profil > Paramètres > Joueurs bloqués.',
            'Tap ⋮ to the right of the player’s message, then “Block”. Their messages will be hidden for you. You can unblock them in Profile > Settings > Blocked players.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Compris', 'Got it')),
          ),
        ],
      ),
    );
  }
""",
"""  Widget _blockHelpChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lime.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.lime.withOpacity(.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.shield_outlined, size: 15, color: AppColors.lime),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.tr(
              'Sous chaque pseudo : Bloquer ou Signaler',
              'Under each player name: Block or Report',
            ),
            style: GoogleFonts.inter(
              color: AppColors.text2,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ]),
    );
  }
""", 'team help chip')

    s = replace_once(s,
"""  Widget _bubbleWithDate(
    AppProvider prov,
    Map<String, dynamic> data,
    Map<String, dynamic>? previous,
  ) {
""",
"""  Widget _bubbleWithDate(
    AppProvider prov,
    String messageId,
    Map<String, dynamic> data,
    Map<String, dynamic>? previous,
  ) {
""", 'team bubbleWithDate signature')

    s = replace_once(s, "      _bubble(prov, data, dt),\n", "      _bubble(prov, messageId, data, dt),\n", 'team bubble call')
    s = replace_once(s,
"""  Widget _bubble(AppProvider prov, Map<String, dynamic> data, DateTime? dt) {
""",
"""  Widget _bubble(
    AppProvider prov,
    String messageId,
    Map<String, dynamic> data,
    DateTime? dt,
  ) {
""", 'team bubble signature')

    s = replace_once(s,
"""            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AvatarBubble(avatar: avatar, size: 20),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: userId.isEmpty
                        ? null
                        : () => _showUserActions(prov, userId, name, avatar),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(name,
                            style: GoogleFonts.barlowCondensed(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(width: 4),
                        Icon(Icons.more_horiz_rounded,
                            size: 14, color: AppColors.grey),
                      ]),
                    ),
                  ),
                ]),
              ),
""",
"""            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      AvatarBubble(avatar: avatar, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlowCondensed(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _messageActionChip(
                          icon: Icons.block_rounded,
                          label: context.tr('Bloquer', 'Block'),
                          color: AppColors.canadaRed,
                          onTap: userId.isEmpty
                              ? null
                              : () => _showUserActions(prov, userId, name, avatar),
                        ),
                        _messageActionChip(
                          icon: Icons.flag_outlined,
                          label: context.tr('Signaler', 'Report'),
                          color: AppColors.gold,
                          onTap: userId.isEmpty
                              ? null
                              : () => _reportTeamMessage(
                                    prov,
                                    messageId: messageId,
                                    userId: userId,
                                    name: name,
                                    message: (data['message'] ?? '').toString(),
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
""", 'team visible actions')

    marker = "  Future<void> _showUserActions(\n"
    helper = """  Widget _messageActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  Future<void> _reportTeamMessage(
    AppProvider prov, {
    required String messageId,
    required String userId,
    required String name,
    required String message,
  }) async {
    final uid = prov.currentUser?.id;
    String? error;
    if (uid == null || uid.isEmpty) {
      error = context.tr('Profil indisponible.', 'Profile unavailable.');
    } else {
      try {
        await FirebaseFirestore.instance.collection('contentReports').add({
          'reporterId': uid,
          'reportedUserId': userId,
          'reportedUserName': name,
          'messageId': messageId,
          'message': message,
          'chatType': 'team',
          'teamId': prov.myTeam?.id,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
      } catch (_) {
        error = context.tr('Signalement impossible pour le moment.', 'Unable to report right now.');
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? context.tr('Message signalé à la modération.', 'Message reported to moderation.')),
      backgroundColor: error == null ? AppColors.mexicoGreen : AppColors.canadaRed,
    ));
  }

"""
    if marker not in s:
        raise SystemExit('PRONO4 BUILD51 chat patch failed: team helper marker not found')
    s = s.replace(marker, helper + marker, 1)
    path.write_text(s)


def patch_match_lounge() -> None:
    path = SCREENS / 'match_lounge_screen.dart'
    s = path.read_text()

    s = replace_once(s,
"""                          itemBuilder: (_, i) => _bubble(prov, docs[i].data()),
""",
"""                          itemBuilder: (_, i) => _bubble(
                            prov,
                            match,
                            docs[i].id,
                            docs[i].data(),
                          ),
""", 'match list builder')

    s = replace_once(s,
"""  Widget _blockHelpChip() {
    return ActionChip(
      avatar: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.lime),
      label: Text(
        context.tr('Bloquer un joueur ? touche ⋮', 'Block a player? tap ⋮'),
        style: GoogleFonts.inter(
          color: AppColors.text2,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: AppColors.bg2,
      side: BorderSide(color: AppColors.lime.withOpacity(.18)),
      visualDensity: VisualDensity.compact,
      onPressed: _showBlockingHelp,
    );
  }

  Future<void> _showBlockingHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Bloquer un joueur', 'Block a player')),
        content: Text(
          context.tr(
            'Touche ⋮ à droite du message du joueur, puis « Bloquer ». Ses messages seront masqués pour toi. Tu peux le débloquer dans Profil > Paramètres > Joueurs bloqués.',
            'Tap ⋮ to the right of the player’s message, then “Block”. Their messages will be hidden for you. You can unblock them in Profile > Settings > Blocked players.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Compris', 'Got it')),
          ),
        ],
      ),
    );
  }
""",
"""  Widget _blockHelpChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lime.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.lime.withOpacity(.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.shield_outlined, size: 15, color: AppColors.lime),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.tr(
              'Sous chaque pseudo : Bloquer ou Signaler',
              'Under each player name: Block or Report',
            ),
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }
""", 'match help chip')

    s = replace_once(s,
"""  Widget _bubble(AppProvider prov, Map<String, dynamic> data) {
""",
"""  Widget _bubble(
    AppProvider prov,
    FootballMatch match,
    String messageId,
    Map<String, dynamic> data,
  ) {
""", 'match bubble signature')

    s = replace_once(s,
"""          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AvatarBubble(avatar: avatar, size: 20),
                const SizedBox(width: 6),
                InkWell(
                  onTap: userId.isEmpty
                      ? null
                      : () => _showUserActions(prov, userId, name, avatar),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(name,
                          style: GoogleFonts.barlowCondensed(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          )),
                      const SizedBox(width: 4),
                      Icon(Icons.more_horiz_rounded,
                          size: 14, color: AppColors.grey),
                    ]),
                  ),
                ),
              ]),
            ),
""",
"""          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    AvatarBubble(avatar: avatar, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlowCondensed(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _messageActionChip(
                      icon: Icons.block_rounded,
                      label: context.tr('Bloquer', 'Block'),
                      color: AppColors.canadaRed,
                      onTap: userId.isEmpty ? null : () => _showUserActions(prov, userId, name, avatar),
                    ),
                    _messageActionChip(
                      icon: Icons.flag_outlined,
                      label: context.tr('Signaler', 'Report'),
                      color: AppColors.gold,
                      onTap: userId.isEmpty ? null : () => _reportMatchMessage(
                        prov,
                        match: match,
                        messageId: messageId,
                        userId: userId,
                        name: name,
                        message: message,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
""", 'match visible actions')

    marker = "  Future<void> _showUserActions(\n"
    helper = """  Widget _messageActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  Future<void> _reportMatchMessage(
    AppProvider prov, {
    required FootballMatch match,
    required String messageId,
    required String userId,
    required String name,
    required String message,
  }) async {
    final uid = prov.currentUser?.id;
    String? error;
    if (uid == null || uid.isEmpty) {
      error = context.tr('Profil indisponible.', 'Profile unavailable.');
    } else {
      try {
        await FirebaseFirestore.instance.collection('contentReports').add({
          'reporterId': uid,
          'reportedUserId': userId,
          'reportedUserName': name,
          'messageId': messageId,
          'message': message,
          'chatType': 'match',
          'matchId': match.id,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
      } catch (_) {
        error = context.tr('Signalement impossible pour le moment.', 'Unable to report right now.');
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? context.tr('Message signalé à la modération.', 'Message reported to moderation.')),
      backgroundColor: error == null ? AppColors.mexicoGreen : AppColors.canadaRed,
    ));
  }

"""
    if marker not in s:
        raise SystemExit('PRONO4 BUILD51 chat patch failed: match helper marker not found')
    s = s.replace(marker, helper + marker, 1)
    path.write_text(s)


patch_team_chat()
patch_match_lounge()
print('PRONO4 BUILD51 chat patch applied')
