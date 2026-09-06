import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/matches_data.dart';
import '../data/teams_data.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/dynamic_page_screen.dart';
import '../theme/app_theme.dart';
import 'remote_image.dart';

/// Cartes d’accès vers des pages entières dynamiques.
/// Collection Firestore : dynamicPages/{id}
class DynamicPagesFeed extends StatelessWidget {
  final String placement; // home ou profile
  final EdgeInsets margin;
  final int? limit;

  const DynamicPagesFeed({
    super.key,
    required this.placement,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('dynamicPages').snapshots(),
      builder: (context, snap) {
        final now = DateTime.now();
        final pages = (snap.data?.docs ?? [])
            .map(DynamicPageData.fromDoc)
            .where((page) {
          if (!page.isVisibleAt(now)) return false;
          if (placement == 'home') return page.showOnHome;
          if (placement == 'profile') return page.showOnProfile;
          return false;
        })
            .toList()
          ..sort((a, b) {
            final order = a.order.compareTo(b.order);
            if (order != 0) return order;
            return b.updatedAt.compareTo(a.updatedAt);
          });

        final visible = limit == null ? pages : pages.take(limit!).toList();
        if (visible.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: margin,
          child: Column(
            children: [
              for (final page in visible) ...[
                _DynamicPageTile(page: page),
                if (page != visible.last) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DynamicPageTile extends StatelessWidget {
  final DynamicPageData page;
  const _DynamicPageTile({required this.page});

  @override
  Widget build(BuildContext context) {
    final fg = DynamicPageData.parseHex(page.textColor, AppColors.text);
    final bg = DynamicPageData.parseHex(page.backgroundColor, AppColors.bg2);
    final prov = context.watch<AppProvider>();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DynamicPageScreen(
                pageId: page.id,
                fallbackTitle: page.title,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: page.imageUrl.isEmpty
                      ? Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg3.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.article_rounded, color: AppColors.gold, size: 30),
                  )
                      : RemoteImage(
                    source: page.imageUrl,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.gold.withOpacity(0.34)),
                        ),
                        child: Text(
                          page.pageType == 'match_compare' ? 'COMPARATIF MATCH' : 'PAGE SPÉCIALE',
                          style: GoogleFonts.barlowCondensed(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _feedPageTitle(page),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlowCondensed(
                          color: fg,
                          fontSize: 20,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (page.pageType == 'match_compare' && page.matchId.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _feedMatchLabel(page.matchId, prov),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlow(
                            color: AppColors.gold.withOpacity(0.95),
                            fontSize: 12,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (page.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          page.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlow(
                            color: fg.withOpacity(0.86),
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: AppColors.gold, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


String _feedMatchLabel(String matchId, AppProvider prov) {
  final match = _feedMatchById(matchId);
  if (match == null) return matchId;
  final resolved = _resolveFeedMatchDeep(match, prov);
  final home = kTeams[resolved.homeCode]?.name ?? (resolved.homeCode == 'TBD' ? 'À confirmer' : resolved.homeCode);
  final away = kTeams[resolved.awayCode]?.name ?? (resolved.awayCode == 'TBD' ? 'À confirmer' : resolved.awayCode);
  return '$home vs $away';
}

FootballMatch? _feedMatchById(String id) {
  for (final match in kMatches) {
    if (match.id == id) return match;
  }
  return null;
}

const Map<String, List<String>> _feedCompareFeeders = {
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

FootballMatch _resolveFeedMatchDeep(FootballMatch match, AppProvider prov, [Set<String>? seen]) {
  final direct = prov.resolveMatch(match);
  if (!direct.isTBD && direct.awayCode != 'TBD') return direct;

  final feed = _feedCompareFeeders[match.id];
  if (feed == null) return direct;
  final guard = seen ?? <String>{};
  if (!guard.add(match.id)) return direct;

  final home = _qualifiedFeedCode(feed[0], prov, forThirdPlace: match.id == 'M103', seen: guard);
  final away = _qualifiedFeedCode(feed[1], prov, forThirdPlace: match.id == 'M103', seen: guard);
  return direct.copyWith(
    homeCode: direct.homeCode != 'TBD' ? direct.homeCode : (home ?? 'TBD'),
    awayCode: direct.awayCode != 'TBD' ? direct.awayCode : (away ?? 'TBD'),
  );
}

String? _qualifiedFeedCode(
    String matchId,
    AppProvider prov, {
      required bool forThirdPlace,
      required Set<String> seen,
    }) {
  final result = prov.results[matchId];
  if (result != 'HOME' && result != 'AWAY') return null;
  final base = _feedMatchById(matchId);
  if (base == null) return null;
  final resolved = _resolveFeedMatchDeep(base, prov, seen);
  if (resolved.homeCode == 'TBD' || resolved.awayCode == 'TBD') return null;
  final wantHome = forThirdPlace ? result == 'AWAY' : result == 'HOME';
  return wantHome ? resolved.homeCode : resolved.awayCode;
}


String _feedPageTitle(DynamicPageData page) {
  if (page.title.isNotEmpty) return page.title;
  if (page.pageType == 'match_compare') return 'Comparatif du match';
  return 'Page dynamique';
}
