import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/teams_data.dart';
import '../providers/app_provider.dart';
import '../widgets/flag_widget.dart';

/// Écran « Meilleurs buteurs » : pronostic Soulier d'Or + podium top 3 + liste.
/// Lit `system/topScorers` (alimenté par la Cloud Function). Aucun token exposé.
class TopScorersScreen extends StatelessWidget {
  const TopScorersScreen({super.key});

  static const Color _silver = Color(0xFFD7DEE8);
  static const Color _bronze = Color(0xFFE0A06A);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('system')
              .doc('topScorers')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data?.data();
            final raw = (data?['scorers'] as List?) ?? const [];
            final scorers = raw.whereType<Map>().toList();

            return CustomScrollView(
              key: const PageStorageKey<String>('top_scorers_scroll'),
              primary: false,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header()),
                if (scorers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _pronosticCard(context, prov, scorers),
                  ),
                if (scorers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Aucun buteur pour le moment.\n'
                          'Le classement se remplira au fil des matchs.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.barlowCondensed(
                            color: AppColors.text2,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(child: _podium(scorers)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _entrance(_row(scorers[i + 3], i + 4), i),
                        childCount:
                            scorers.length > 3 ? scorers.length - 3 : 0,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
  }

  // ─── Pronostic Soulier d'Or ───────────────────────────────
  Widget _pronosticCard(
      BuildContext context, AppProvider prov, List<Map> scorers) {
    final pick = prov.myGoldenBootPick;
    final counts = prov.goldenBootCounts();
    final total = prov.goldenBootVoteCount;

    String? favName;
    int favCount = 0;
    counts.forEach((name, n) {
      if (n > favCount) {
        favCount = n;
        favName = name;
      }
    });

    final pickCode = pick?['code'] ?? '';
    final pickInfo = kTeams[pickCode];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.cyan.withOpacity(0.16),
            AppColors.bg2,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.cyan.withOpacity(0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🔮', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'MON PRONOSTIC SOULIER D\u2019OR',
              style: GoogleFonts.barlowCondensed(
                color: AppColors.cyan,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (pick != null)
            Row(children: [
              FlagWidget(
                flagCode: pickInfo?.flagCode ?? '',
                size: 34,
                fallbackEmoji: pickInfo?.emoji ?? '🏳️',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (pick['name'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openPicker(context, prov, scorers),
                child: Text(
                  'Modifier',
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.cyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ])
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openPicker(context, prov, scorers),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: const Color(0xFF06222A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.how_to_vote_rounded, size: 18),
                label: Text(
                  'Choisis qui sera meilleur buteur',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (favName != null && total > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Favori de la communauté : $favName  ·  $favCount/$total vote${total > 1 ? "s" : ""}',
              style: GoogleFonts.barlowCondensed(
                color: AppColors.text2,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPicker(
      BuildContext context, AppProvider prov, List<Map> scorers) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(children: [
                    const Text('🔮', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'Qui sera Soulier d\u2019Or ?',
                      style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 22,
                        letterSpacing: 1,
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: scorers.length,
                    itemBuilder: (_, i) {
                      final s = scorers[i];
                      final name = (s['name'] ?? '').toString();
                      final code = (s['code'] ?? '').toString();
                      final goals =
                          (s['goals'] is num) ? (s['goals'] as num).toInt() : 0;
                      final t = kTeams[code];
                      final selected =
                          prov.myGoldenBootPick?['name'] == name;
                      return InkWell(
                        onTap: () async {
                          final err =
                              await prov.setGoldenBootPick(name, code);
                          if (!sheetCtx.mounted) return;
                          Navigator.of(sheetCtx).pop();
                          messenger?.showSnackBar(
                            SnackBar(
                              content: Text(err ??
                                  'Pronostic enregistré : $name 🔮'),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.cyan.withOpacity(0.14)
                                : AppColors.bg3,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.cyan
                                  : Colors.white.withOpacity(0.12),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(children: [
                            FlagWidget(
                              flagCode: t?.flagCode ?? '',
                              size: 30,
                              fallbackEmoji: t?.emoji ?? '🏳️',
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.barlowCondensed(
                                  color: AppColors.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '$goals',
                              style: GoogleFonts.bebasNeue(
                                color: AppColors.gold,
                                fontSize: 22,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              goals > 1 ? 'buts' : 'but',
                              style: GoogleFonts.barlowCondensed(
                                color: AppColors.text2,
                                fontSize: 10,
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.cyan, size: 20),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── En-tête ──────────────────────────────────────────────
  Widget _header() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withOpacity(0.30),
            AppColors.gold.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.gold.withOpacity(0.45)),
      ),
      child: Row(children: [
        const Text('⚽', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MEILLEURS BUTEURS',
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                fontSize: 26,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'Soulier d\u2019or — Coupe du Monde 2026',
              style: GoogleFonts.barlowCondensed(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ]),
    );
  }

  // ─── Podium top 3 ─────────────────────────────────────────
  Widget _entrance(Widget child, int order) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + order.clamp(0, 6) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Widget _podium(List<Map> scorers) {
    final first = scorers.isNotEmpty ? scorers[0] : null;
    final second = scorers.length > 1 ? scorers[1] : null;
    final third = scorers.length > 2 ? scorers[2] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.bg3,
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _entrance(_podiumPlace(second, 2, _silver, 96), 1)),
          Expanded(child: _entrance(_podiumPlace(first, 1, AppColors.gold, 124), 0)),
          Expanded(child: _entrance(_podiumPlace(third, 3, _bronze, 78), 2)),
        ],
      ),
    );
  }

  Widget _podiumPlace(Map? s, int rank, Color color, double height) {
    if (s == null) return const SizedBox.shrink();
    final name = (s['name'] ?? '').toString();
    final code = (s['code'] ?? '').toString();
    final goals = (s['goals'] is num) ? (s['goals'] as num).toInt() : 0;
    final t = kTeams[code];
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : '🥉';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: TextStyle(fontSize: rank == 1 ? 30 : 24)),
        const SizedBox(height: 6),
        _Pulse(
          enabled: rank == 1,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: FlagWidget(
              flagCode: t?.flagCode ?? '',
              size: rank == 1 ? 40 : 32,
              fallbackEmoji: t?.emoji ?? '🏳️',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.85), color.withOpacity(0.35)],
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$goals',
                style: GoogleFonts.bebasNeue(
                  color: const Color(0xFF1A1A1A),
                  fontSize: rank == 1 ? 34 : 28,
                  height: 1,
                ),
              ),
              Text(
                goals > 1 ? 'buts' : 'but',
                style: GoogleFonts.barlowCondensed(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Ligne 4e et + ────────────────────────────────────────
  Widget _row(Map s, int rank) {
    final name = (s['name'] ?? '').toString();
    final team = (s['team'] ?? '').toString();
    final code = (s['code'] ?? '').toString();
    final goals = (s['goals'] is num) ? (s['goals'] as num).toInt() : 0;
    final assists = (s['assists'] is num) ? (s['assists'] as num).toInt() : 0;
    final t = kTeams[code];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(children: [
        SizedBox(
          width: 26,
          child: Text(
            '$rank',
            textAlign: TextAlign.center,
            style: GoogleFonts.bebasNeue(color: AppColors.text2, fontSize: 20),
          ),
        ),
        const SizedBox(width: 8),
        FlagWidget(
          flagCode: t?.flagCode ?? '',
          size: 30,
          fallbackEmoji: t?.emoji ?? '🏳️',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.barlowCondensed(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (team.isNotEmpty)
                Text(
                  team,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    color: AppColors.text2,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$goals',
              style: GoogleFonts.bebasNeue(
                color: AppColors.gold,
                fontSize: 24,
                height: 1,
              ),
            ),
            Text(
              goals > 1 ? 'buts' : 'but',
              style: GoogleFonts.barlowCondensed(
                color: AppColors.text2,
                fontSize: 10,
              ),
            ),
          ],
        ),
        if (assists > 0) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$assists',
                style: GoogleFonts.barlowCondensed(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'passes',
                style: GoogleFonts.barlowCondensed(
                  color: AppColors.text2,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ]),
    );
  }
}

class _Pulse extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const _Pulse({required this.child, this.enabled = true});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.08)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}
