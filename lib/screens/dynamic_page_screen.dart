import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/matches_data.dart';
import '../data/teams_data.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/flag_widget.dart';
import '../widgets/club_crest.dart';
import '../widgets/remote_image.dart';
import 'calendar_screen.dart';

/// Page entière pilotée depuis Firebase.
/// Collection : dynamicPages/{pageId}
class DynamicPageScreen extends StatelessWidget {
  final String pageId;
  final String? fallbackTitle;

  const DynamicPageScreen({
    super.key,
    required this.pageId,
    this.fallbackTitle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('dynamicPages').doc(pageId).snapshots(),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final data = snap.data?.data();
        final page = data == null ? null : DynamicPageData.fromMap(pageId, data);

        return Scaffold(
          backgroundColor: AppColors.bg0,
          appBar: AppBar(
            backgroundColor: AppColors.bg1,
            title: Text(
              _dynamicPageTitle(page, fallbackTitle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.bebasNeue(
                color: AppColors.text,
                fontSize: 22,
                letterSpacing: 1.4,
              ),
            ),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : page == null
              ? const _DynamicPageEmptyState(
            title: 'Page introuvable',
            message: 'Cette page dynamique n’existe plus ou n’est pas encore publiée.',
          )
              : page.pageType == 'match_compare'
              ? _MatchComparePageBody(page: page)
              : _DynamicPageBody(page: page),
        );
      },
    );
  }
}

class _DynamicPageBody extends StatelessWidget {
  final DynamicPageData page;
  const _DynamicPageBody({required this.page});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!page.isVisibleAt(now)) {
      return const _DynamicPageEmptyState(
        title: 'Page non disponible',
        message: 'Cette page n’est pas active pour le moment.',
      );
    }

    final bg = DynamicPageData.parseHex(page.backgroundColor, AppColors.bg0);
    final fg = DynamicPageData.parseHex(page.textColor, AppColors.text);
    final uri = DynamicPageData.safeUri(page.buttonUrl);

    return Container(
      color: bg,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (page.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: RemoteImage(source: page.imageUrl),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.bg2.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.gold.withOpacity(0.22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.gold.withOpacity(0.34)),
                      ),
                      child: Text(
                        'INFO OFFICIELLE',
                        style: GoogleFonts.barlowCondensed(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (page.title.isNotEmpty)
                      Text(
                        page.title,
                        style: GoogleFonts.bebasNeue(
                          color: fg,
                          fontSize: 34,
                          height: 0.98,
                          letterSpacing: 1.4,
                        ),
                      ),
                    if (page.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        page.subtitle,
                        style: GoogleFonts.barlow(
                          color: fg.withOpacity(0.88),
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (page.body.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _BodyText(text: page.body, color: fg),
                    ],
                    if (uri != null) ...[
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                            page.buttonText.isEmpty ? 'OUVRIR' : page.buttonText,
                            style: GoogleFonts.barlowCondensed(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  final Color color;
  const _BodyText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((p) {
        final bullet = p.startsWith('- ') || p.startsWith('• ');
        final clean = bullet ? p.substring(2).trim() : p;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bullet) ...[
                Text('•', style: TextStyle(color: AppColors.gold, fontSize: 18, height: 1.25)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  clean,
                  style: GoogleFonts.barlow(
                    color: color.withOpacity(0.92),
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DynamicPageEmptyState extends StatelessWidget {
  final String title;
  final String message;
  const _DynamicPageEmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.13),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withOpacity(0.30)),
              ),
              child: const Icon(Icons.article_outlined, color: AppColors.gold, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 14, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}


class _MatchComparePageBody extends StatelessWidget {
  final DynamicPageData page;
  const _MatchComparePageBody({required this.page});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!page.isVisibleAt(now)) {
      return const _DynamicPageEmptyState(
        title: 'Page non disponible',
        message: 'Ce comparatif n’est pas actif pour le moment.',
      );
    }

    final prov = context.watch<AppProvider>();
    final baseMatch = _findMatch(page.matchId);
    if (baseMatch == null) {
      return const _DynamicPageEmptyState(
        title: 'Match introuvable',
        message: 'Choisis un match valide dans l’admin pour générer le comparatif.',
      );
    }

    final match = _resolveMatchDeepForCompare(baseMatch, prov);
    if (match.isTBD) {
      return const _DynamicPageEmptyState(
        title: 'Équipes à confirmer',
        message: 'Le comparatif sera disponible dès que les deux équipes du match seront connues.',
      );
    }

    final bg = DynamicPageData.parseHex(page.backgroundColor, AppColors.bg0);
    final fg = DynamicPageData.parseHex(page.textColor, AppColors.text);
    final isClub = match.competitionId != 'world-cup-2026';
    final home = !isClub ? kTeams[match.homeCode] : null;
    final away = !isClub ? kTeams[match.awayCode] : null;
    final homeName = isClub ? (match.homeName ?? match.homeCode) : (home?.name ?? match.homeName ?? match.homeCode);
    final awayName = isClub ? (match.awayName ?? match.awayCode) : (away?.name ?? match.awayName ?? match.awayCode);
    final title = page.title.isNotEmpty ? page.title : '$homeName vs $awayName';
    final phase = _phaseLabel(match.phase);
    final dateLabel = _matchDateLabel(match);
    final voteStats = _VoteStats.fromVotes(prov.votes, match.id);
    final score = prov.scores[match.id];
    final isFinished = prov.results[match.id] != null;
    final isLive = (prov.isLiveMatch(match.id) || match.hasStarted) && !isFinished;

    return Container(
      color: bg,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (page.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: RemoteImage(source: page.imageUrl),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _CompareHero(
                title: title,
                subtitle: page.subtitle,
                match: match,
                phase: phase,
                dateLabel: dateLabel,
                fg: fg,
                isLive: isLive,
                isFinished: isFinished,
                score: score,
              ),
              if (page.body.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Message admin',
                  icon: Icons.campaign_rounded,
                  child: _BodyText(text: page.body, color: fg),
                ),
              ],
              const SizedBox(height: 12),
              _VoteCompareCard(
                match: match,
                voteStats: voteStats,
                homeName: homeName,
                awayName: awayName,
              ),
              const SizedBox(height: 12),
              _TeamsFormCompareCard(match: match, prov: prov),
              const SizedBox(height: 12),
              _LastMatchesCompareCard(match: match, prov: prov),
              const SizedBox(height: 12),
              _TeamTopScorersCompareCard(homeCode: match.homeCode, awayCode: match.awayCode),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CalendarScreen()),
                      ),
                      icon: const Icon(Icons.how_to_vote_rounded, size: 18),
                      label: Text(
                        page.buttonText.isEmpty ? 'VOTER / VOIR LES MATCHS' : page.buttonText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900, letterSpacing: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              if (DynamicPageData.safeUri(page.buttonUrl) != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(DynamicPageData.safeUri(page.buttonUrl)!, mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: Text('OUVRIR LE LIEN', style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final FootballMatch match;
  final String phase;
  final String dateLabel;
  final Color fg;
  final bool isLive;
  final bool isFinished;
  final MatchScore? score;

  const _CompareHero({
    required this.title,
    required this.subtitle,
    required this.match,
    required this.phase,
    required this.dateLabel,
    required this.fg,
    required this.isLive,
    required this.isFinished,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final isClub = match.competitionId != 'world-cup-2026';
    final home = !isClub ? kTeams[match.homeCode] : null;
    final away = !isClub ? kTeams[match.awayCode] : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withOpacity(0.16),
            AppColors.bg2.withOpacity(0.86),
            AppColors.bg3.withOpacity(0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withOpacity(0.28)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 14))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: phase.toUpperCase(), color: AppColors.gold, icon: Icons.emoji_events_rounded),
              _Pill(label: isFinished ? 'TERMINÉ' : isLive ? 'EN DIRECT' : 'À JOUER', color: isFinished ? AppColors.grey : isLive ? AppColors.canadaRed : AppColors.mexicoGreen, icon: isLive ? Icons.flash_on_rounded : Icons.schedule_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.bebasNeue(color: fg, fontSize: 34, height: 0.98, letterSpacing: 1.2),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: GoogleFonts.barlow(color: fg.withOpacity(0.86), fontSize: 14, fontWeight: FontWeight.w700, height: 1.25)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _TeamFace(team: home, code: match.homeCode, explicitName: match.homeName, crestUrl: match.homeCrestUrl, isClub: isClub, alignRight: false)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    if (score != null)
                      Text(score!.display, style: GoogleFonts.bebasNeue(color: AppColors.gold, fontSize: 38, height: 0.92, letterSpacing: 1.8))
                    else
                      Text('VS', style: GoogleFonts.bebasNeue(color: AppColors.gold, fontSize: 34, height: 0.92, letterSpacing: 1.8)),
                    const SizedBox(height: 4),
                    Text(match.localTime, style: GoogleFonts.barlowCondensed(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Expanded(child: _TeamFace(team: away, code: match.awayCode, explicitName: match.awayName, crestUrl: match.awayCrestUrl, isClub: isClub, alignRight: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: AppColors.gold, size: 16),
              const SizedBox(width: 7),
              Expanded(child: Text(dateLabel, style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w700))),
              const Icon(Icons.location_on_rounded, color: AppColors.gold, size: 16),
              const SizedBox(width: 5),
              Flexible(child: Text(match.venue, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w700))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamFace extends StatelessWidget {
  final TeamInfo? team;
  final String code;
  final String? explicitName;
  final String? crestUrl;
  final bool isClub;
  final bool alignRight;
  const _TeamFace({required this.team, required this.code, required this.explicitName, required this.crestUrl, required this.isClub, required this.alignRight});

  @override
  Widget build(BuildContext context) {
    final name = isClub ? (explicitName ?? code) : (team?.name ?? explicitName ?? code);
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isClub)
          ClubCrest(url: crestUrl, clubName: name, size: 46)
        else
          FlagWidget(flagCode: team?.flagCode ?? '', fallbackEmoji: team?.emoji ?? '🏳️', size: 46),
        const SizedBox(height: 7),
        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: alignRight ? TextAlign.right : TextAlign.left, style: GoogleFonts.barlowCondensed(color: AppColors.text, fontSize: 18, height: 1.0, fontWeight: FontWeight.w900)),
        Text(code, style: GoogleFonts.barlow(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
      ],
    );
  }
}

class _VoteCompareCard extends StatelessWidget {
  final FootballMatch match;
  final _VoteStats voteStats;
  final String homeName;
  final String awayName;
  const _VoteCompareCard({required this.match, required this.voteStats, required this.homeName, required this.awayName});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Pronostic des utilisateurs',
      icon: Icons.how_to_vote_rounded,
      child: voteStats.total == 0
          ? Text('Aucun vote pour le moment. Sois le premier à pronostiquer ce match.', style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 14, height: 1.3))
          : Column(
        children: [
          _VoteBar(label: homeName, count: voteStats.home, total: voteStats.total, color: AppColors.usaBlue),
          const SizedBox(height: 8),
          _VoteBar(label: 'Match nul', count: voteStats.draw, total: voteStats.total, color: AppColors.gold),
          const SizedBox(height: 8),
          _VoteBar(label: awayName, count: voteStats.away, total: voteStats.total, color: AppColors.canadaRed),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${voteStats.total} vote${voteStats.total > 1 ? 's' : ''}', style: GoogleFonts.barlow(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _VoteBar({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.barlow(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800))),
            Text('${(ratio * 100).round()}%', style: GoogleFonts.barlowCondensed(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 9,
            backgroundColor: Colors.white.withOpacity(0.08),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TeamsFormCompareCard extends StatelessWidget {
  final FootballMatch match;
  final AppProvider prov;
  const _TeamsFormCompareCard({required this.match, required this.prov});

  @override
  Widget build(BuildContext context) {
    final home = _TeamForm.from(match.homeCode, prov, excludeMatchId: match.id);
    final away = _TeamForm.from(match.awayCode, prov, excludeMatchId: match.id);
    return _InfoCard(
      title: 'Forme récente',
      icon: Icons.insights_rounded,
      child: Row(
        children: [
          Expanded(child: _FormSide(code: match.homeCode, form: home)),
          Container(width: 1, height: 72, color: Colors.white.withOpacity(0.08), margin: const EdgeInsets.symmetric(horizontal: 10)),
          Expanded(child: _FormSide(code: match.awayCode, form: away, right: true)),
        ],
      ),
    );
  }
}

class _FormSide extends StatelessWidget {
  final String code;
  final _TeamForm form;
  final bool right;
  const _FormSide({required this.code, required this.form, this.right = false});

  @override
  Widget build(BuildContext context) {
    final team = kTeams[code];
    return Column(
      crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(team?.name ?? code, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: right ? TextAlign.right : TextAlign.left, style: GoogleFonts.barlowCondensed(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          alignment: right ? WrapAlignment.end : WrapAlignment.start,
          children: form.letters.isEmpty
              ? [Text('Aucun match', style: GoogleFonts.barlow(color: AppColors.grey, fontSize: 12))]
              : form.letters.map((l) => _FormDot(letter: l)).toList(),
        ),
        const SizedBox(height: 8),
        Text('${form.goalsFor} BP · ${form.goalsAgainst} BC', style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _FormDot extends StatelessWidget {
  final String letter;
  const _FormDot({required this.letter});

  @override
  Widget build(BuildContext context) {
    final color = letter == 'V' ? AppColors.mexicoGreen : letter == 'N' ? AppColors.gold : AppColors.canadaRed;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.45))),
      child: Text(letter, style: GoogleFonts.barlowCondensed(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
    );
  }
}

class _LastMatchesCompareCard extends StatelessWidget {
  final FootballMatch match;
  final AppProvider prov;
  const _LastMatchesCompareCard({required this.match, required this.prov});

  @override
  Widget build(BuildContext context) {
    final homeRows = _recentRows(match.homeCode, prov, excludeMatchId: match.id);
    final awayRows = _recentRows(match.awayCode, prov, excludeMatchId: match.id);
    return _InfoCard(
      title: 'Derniers matchs joués',
      icon: Icons.history_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 420;
          final left = _RecentColumn(code: match.homeCode, rows: homeRows);
          final right = _RecentColumn(code: match.awayCode, rows: awayRows, right: true);
          if (stack) {
            return Column(children: [left, const SizedBox(height: 12), right]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)]);
        },
      ),
    );
  }
}

class _RecentColumn extends StatelessWidget {
  final String code;
  final List<_RecentMatchRow> rows;
  final bool right;
  const _RecentColumn({required this.code, required this.rows, this.right = false});

  @override
  Widget build(BuildContext context) {
    final team = kTeams[code];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          textDirection: right ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          children: [
            FlagWidget(flagCode: team?.flagCode ?? '', fallbackEmoji: team?.emoji ?? '🏳️', size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(team?.name ?? code, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: right ? TextAlign.right : TextAlign.left, style: GoogleFonts.barlowCondensed(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900))),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text('Aucun résultat renseigné.', style: GoogleFonts.barlow(color: AppColors.grey, fontSize: 12))
        else
          ...rows.map((row) => _RecentRowWidget(row: row)),
      ],
    );
  }
}

class _RecentRowWidget extends StatelessWidget {
  final _RecentMatchRow row;
  const _RecentRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    final color = row.letter == 'V' ? AppColors.mexicoGreen : row.letter == 'N' ? AppColors.gold : AppColors.canadaRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(color: AppColors.bg3.withOpacity(0.78), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
            child: Text(row.letter, style: GoogleFonts.barlowCondensed(color: color, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.barlow(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Text(row.score, style: GoogleFonts.barlowCondensed(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _TeamTopScorersCompareCard extends StatelessWidget {
  final String homeCode;
  final String awayCode;
  const _TeamTopScorersCompareCard({required this.homeCode, required this.awayCode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('system').doc('topScorers').snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final raw = (data?['scorers'] as List?) ?? const [];
        final scorers = raw.whereType<Map>().toList();
        final home = _firstScorerFor(scorers, homeCode);
        final away = _firstScorerFor(scorers, awayCode);
        return _InfoCard(
          title: 'Buteurs à suivre',
          icon: Icons.sports_soccer_rounded,
          child: Row(
            children: [
              Expanded(child: _ScorerSide(code: homeCode, scorer: home)),
              Container(width: 1, height: 62, color: Colors.white.withOpacity(0.08), margin: const EdgeInsets.symmetric(horizontal: 10)),
              Expanded(child: _ScorerSide(code: awayCode, scorer: away, right: true)),
            ],
          ),
        );
      },
    );
  }
}

class _ScorerSide extends StatelessWidget {
  final String code;
  final Map? scorer;
  final bool right;
  const _ScorerSide({required this.code, required this.scorer, this.right = false});

  @override
  Widget build(BuildContext context) {
    final team = kTeams[code];
    final name = (scorer?['name'] ?? 'À venir').toString();
    final goals = (scorer?['goals'] is num) ? (scorer!['goals'] as num).toInt() : 0;
    return Column(
      crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        FlagWidget(flagCode: team?.flagCode ?? '', fallbackEmoji: team?.emoji ?? '🏳️', size: 28),
        const SizedBox(height: 6),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: right ? TextAlign.right : TextAlign.left, style: GoogleFonts.barlowCondensed(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
        Text(scorer == null ? 'Buteur non renseigné' : '$goals but${goals > 1 ? 's' : ''}', style: GoogleFonts.barlow(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _InfoCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(0.74),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(title.toUpperCase(), style: GoogleFonts.barlowCondensed(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Pill({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.34))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.barlowCondensed(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
        ],
      ),
    );
  }
}

class _VoteStats {
  final int home;
  final int draw;
  final int away;
  const _VoteStats({required this.home, required this.draw, required this.away});
  int get total => home + draw + away;

  factory _VoteStats.fromVotes(Map<String, String> votes, String matchId) {
    var h = 0, d = 0, a = 0;
    for (final entry in votes.entries) {
      if (!entry.key.endsWith('__$matchId')) continue;
      if (entry.value == Prediction.home.key) h++;
      if (entry.value == Prediction.draw.key) d++;
      if (entry.value == Prediction.away.key) a++;
    }
    return _VoteStats(home: h, draw: d, away: a);
  }
}

class _TeamForm {
  final List<String> letters;
  final int goalsFor;
  final int goalsAgainst;
  const _TeamForm({required this.letters, required this.goalsFor, required this.goalsAgainst});

  factory _TeamForm.from(String teamCode, AppProvider prov, {required String excludeMatchId}) {
    final rows = _recentRows(teamCode, prov, excludeMatchId: excludeMatchId, limit: 5);
    return _TeamForm(
      letters: rows.map((e) => e.letter).toList(),
      goalsFor: rows.fold<int>(0, (sum, row) => sum + row.goalsFor),
      goalsAgainst: rows.fold<int>(0, (sum, row) => sum + row.goalsAgainst),
    );
  }
}

class _RecentMatchRow {
  final String label;
  final String score;
  final String letter;
  final int goalsFor;
  final int goalsAgainst;
  const _RecentMatchRow({required this.label, required this.score, required this.letter, required this.goalsFor, required this.goalsAgainst});
}

FootballMatch? _findMatch(String id) {
  for (final match in kMatches) {
    if (match.id == id) return match;
  }
  return null;
}


const Map<String, List<String>> _compareFeeders = {
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

FootballMatch _resolveMatchDeepForCompare(FootballMatch match, AppProvider prov, [Set<String>? seen]) {
  final direct = prov.resolveMatch(match);
  if (!direct.isTBD && direct.awayCode != 'TBD') return direct;

  final feed = _compareFeeders[match.id];
  if (feed == null) return direct;
  final guard = seen ?? <String>{};
  if (!guard.add(match.id)) return direct;

  final home = _qualifiedCodeForCompare(feed[0], prov, forThirdPlace: match.id == 'M103', seen: guard);
  final away = _qualifiedCodeForCompare(feed[1], prov, forThirdPlace: match.id == 'M103', seen: guard);
  return direct.copyWith(
    homeCode: direct.homeCode != 'TBD' ? direct.homeCode : (home ?? 'TBD'),
    awayCode: direct.awayCode != 'TBD' ? direct.awayCode : (away ?? 'TBD'),
  );
}

String? _qualifiedCodeForCompare(
    String matchId,
    AppProvider prov, {
      required bool forThirdPlace,
      required Set<String> seen,
    }) {
  final result = prov.results[matchId];
  if (result != 'HOME' && result != 'AWAY') return null;
  final base = _findMatch(matchId);
  if (base == null) return null;
  final resolved = _resolveMatchDeepForCompare(base, prov, seen);
  if (resolved.homeCode == 'TBD' || resolved.awayCode == 'TBD') return null;
  final wantHome = forThirdPlace ? result == 'AWAY' : result == 'HOME';
  return wantHome ? resolved.homeCode : resolved.awayCode;
}

List<_RecentMatchRow> _recentRows(String teamCode, AppProvider prov, {required String excludeMatchId, int limit = 3}) {
  final matches = kMatches.map((m) => _resolveMatchDeepForCompare(m, prov)).where((m) {
    if (m.id == excludeMatchId) return false;
    if (prov.scores[m.id] == null) return false;
    return m.homeCode == teamCode || m.awayCode == teamCode;
  }).toList()
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  return matches.take(limit).map((m) {
    final score = prov.scores[m.id]!;
    final isHome = m.homeCode == teamCode;
    final gf = isHome ? score.homeScore : score.awayScore;
    final ga = isHome ? score.awayScore : score.homeScore;
    final opponentCode = isHome ? m.awayCode : m.homeCode;
    final opponent = kTeams[opponentCode]?.name ?? opponentCode;
    final letter = gf > ga ? 'V' : gf == ga ? 'N' : 'D';
    return _RecentMatchRow(
      label: '${_shortDate(m.dateTime)} · ${isHome ? 'vs' : 'c.'} $opponent',
      score: '$gf-$ga',
      letter: letter,
      goalsFor: gf,
      goalsAgainst: ga,
    );
  }).toList();
}

Map? _firstScorerFor(List<Map> scorers, String code) {
  for (final s in scorers) {
    if ((s['code'] ?? '').toString() == code) return s;
  }
  return null;
}

String _phaseLabel(MatchPhase p) {
  switch (p) {
    case MatchPhase.groupe:
      return 'Groupe';
    case MatchPhase.seizieme:
      return '16e de finale';
    case MatchPhase.huitieme:
      return '8e de finale';
    case MatchPhase.quart:
      return 'Quart de finale';
    case MatchPhase.demi:
      return 'Demi-finale';
    case MatchPhase.troisieme:
      return '3e place';
    case MatchPhase.finale:
      return 'Finale';
  }
}

String _matchDateLabel(FootballMatch match) {
  final fmt = DateFormat('EEEE d MMMM', 'fr_FR');
  final value = fmt.format(match.dateTime);
  return '${value[0].toUpperCase()}${value.substring(1)} · ${match.localTime}';
}

String _shortDate(DateTime dt) {
  const months = ['','jan','fév','mar','avr','mai','juin','juil','août','sept','oct','nov','déc'];
  return '${dt.day} ${months[dt.month]}';
}

String _dynamicPageTitle(DynamicPageData? page, String? fallbackTitle) {
  if (page == null) return fallbackTitle ?? 'Page';
  if (page.title.isNotEmpty) return page.title;
  if (page.pageType == 'match_compare') {
    final match = _findMatch(page.matchId);
    if (match != null && !match.isTBD) {
      final isClub = match.competitionId != 'world-cup-2026';
      final home = isClub ? (match.homeName ?? match.homeCode) : (kTeams[match.homeCode]?.name ?? match.homeName ?? match.homeCode);
      final away = isClub ? (match.awayName ?? match.awayCode) : (kTeams[match.awayCode]?.name ?? match.awayName ?? match.awayCode);
      return '$home vs $away';
    }
    return 'Comparatif match';
  }
  return fallbackTitle ?? 'Page';
}

class DynamicPageData {
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

  const DynamicPageData({
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

  factory DynamicPageData.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return DynamicPageData.fromMap(doc.id, doc.data());
  }

  factory DynamicPageData.fromMap(String id, Map<String, dynamic> data) {
    return DynamicPageData(
      id: id,
      enabled: data['enabled'] == true,
      showOnHome: data['showOnHome'] == true,
      showOnProfile: data['showOnProfile'] == true,
      title: (data['title'] ?? '').toString().trim(),
      subtitle: (data['subtitle'] ?? '').toString().trim(),
      body: (data['body'] ?? '').toString().trim(),
      imageUrl: (data['imageUrl'] ?? '').toString().trim(),
      buttonText: (data['buttonText'] ?? '').toString().trim(),
      buttonUrl: (data['buttonUrl'] ?? '').toString().trim(),
      pageType: (data['pageType'] ?? 'classic').toString().trim(),
      matchId: (data['matchId'] ?? '').toString().trim(),
      backgroundColor: (data['backgroundColor'] ?? '#081525').toString(),
      textColor: (data['textColor'] ?? '#F8FBFF').toString(),
      order: toInt(data['order'], 100),
      startAt: toDate(data['startAt']),
      endAt: toDate(data['endAt']),
      updatedAt: toDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool isVisibleAt(DateTime now) {
    if (!enabled) return false;
    if (pageType == 'match_compare' && matchId.isNotEmpty) {
      // Une page comparatif peut générer tout son contenu depuis le match.
    } else if (title.isEmpty && subtitle.isEmpty && body.isEmpty && imageUrl.isEmpty) {
      return false;
    }
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  static int toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Uri? safeUri(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  static Color parseHex(String raw, Color fallback) {
    var hex = raw.trim().toUpperCase().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : Color(value);
  }
}
